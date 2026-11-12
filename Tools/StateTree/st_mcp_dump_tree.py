#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""通过 unreal MCP（编辑器在线）dump StateTree 的结构：状态名/类型/任务/转移/进入条件。

用法（编辑器需已启动且 MCP 在 127.0.0.1:8000）：
    python st_mcp_dump_tree.py /Game/Blueprint/StateTree/05002101/ST_05002101.ST_05002101
    python st_mcp_dump_tree.py <path1> <path2> ...

输出为缩进文本树，任务/条件只显示 struct 类型短名（STT_PlayMontage 等），
转移显示 trigger + 目标 linkType/target name + 条件类型 + reactivateTargetState。
"""
import json
import sys
import urllib.request

URL = "http://127.0.0.1:8000/mcp"
STS = "state_tree_toolset.toolsets.state_tree.StateTreeTools"
OBJ = "editor_toolset.toolsets.object.ObjectTools"

_sid = None


def post(payload, timeout=120):
    headers = {"Content-Type": "application/json",
               "Accept": "application/json, text/event-stream"}
    if _sid:
        headers["mcp-session-id"] = _sid
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(URL, data=data, headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        sid = resp.headers.get("mcp-session-id")
        body = resp.read().decode("utf-8")
    text = body
    if "event:" in body:
        text = "".join(ln[5:].strip() for ln in body.splitlines() if ln.startswith("data:"))
    return sid, text


def init():
    global _sid
    _sid, _ = post({"jsonrpc": "2.0", "id": 1, "method": "initialize",
                    "params": {"protocolVersion": "2025-11-25", "capabilities": {},
                               "clientInfo": {"name": "st-dump", "version": "1.0"}}}, timeout=30)
    post({"jsonrpc": "2.0", "method": "notifications/initialized"})


def call(toolset, tool, args):
    _, text = post({"jsonrpc": "2.0", "id": 2, "method": "tools/call",
                    "params": {"name": "call_tool",
                               "arguments": {"toolset_name": toolset,
                                             "tool_name": tool,
                                             "arguments": args}}})
    obj = json.loads(text)
    res = obj.get("result", {})
    if res.get("isError"):
        raise RuntimeError(res.get("content", [{}])[0].get("text", "unknown error"))
    txt = res["content"][0]["text"]
    return json.loads(txt)["returnValue"]


def short_type(node_json):
    """从 editor node 的序列化 JSON 里猜 struct 短名。"""
    def walk(v):
        if isinstance(v, dict):
            for k in ("_structType", "structType", "struct", "Struct"):
                if k in v and isinstance(v[k], str):
                    s = v[k]
                    return s.rsplit(".", 1)[-1].rsplit("/", 1)[-1]
            for vv in v.values():
                r = walk(vv)
                if r:
                    return r
        elif isinstance(v, list):
            for vv in v:
                r = walk(vv)
                if r:
                    return r
        return None
    return walk(node_json) or "<unknown>"


def state_props(ref):
    vals = call(OBJ, "get_properties",
                {"instance": {"refPath": ref},
                 "properties": ["Name", "ID", "Type", "SelectionBehavior", "bEnabled", "Weight"]})
    return json.loads(vals)


def dump_state(ref, depth, out):
    p = state_props(ref)
    pad = "  " * depth
    out.append("%s[%s] %s  (Type=%s, Sel=%s, Enabled=%s, Weight=%s)" % (
        pad, p.get("ID", "")[:8], p.get("Name", "?"), p.get("Type"),
        p.get("SelectionBehavior"), p.get("bEnabled"), p.get("Weight")))

    tasks = call(STS, "get_tasks", {"state": {"refPath": ref}})
    for t in tasks:
        out.append("%s  TASK %s" % (pad, short_type(t)))

    conds = call(STS, "get_enter_conditions", {"state": {"refPath": ref}})
    for c in conds:
        out.append("%s  ENTERCOND %s" % (pad, short_type(c)))

    for tr in call(STS, "get_transitions", {"state": {"refPath": ref}}):
        st = tr.get("state") or {}
        cnds = ",".join(short_type(c) for c in (tr.get("conditions") or [])) or "-"
        out.append("%s  TRANS trigger=%s prio=%s enabled=%s target=%s(%s) reactivate=%s conds=%s" % (
            pad, tr.get("trigger"), tr.get("priority"), tr.get("bTransitionEnabled"),
            st.get("name"), st.get("linkType"), tr.get("reactivateTargetState"), cnds))

    for ch in call(STS, "get_children", {"state": {"refPath": ref}}):
        dump_state(ch["refPath"], depth + 1, out)


def dump_tree(tree_path, out):
    out.append("=" * 100)
    out.append("TREE %s" % tree_path)
    out.append("=" * 100)
    for r in call(STS, "get_root_states", {"state_tree": {"refPath": tree_path}}):
        dump_state(r["refPath"], 0, out)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    sys.stdout.reconfigure(encoding="utf-8")
    init()
    out = []
    for path in sys.argv[1:]:
        try:
            dump_tree(path, out)
        except Exception as e:  # noqa: BLE001
            out.append("!! FAILED %s: %s" % (path, e))
    text = "\n".join(out)
    print(text)
    with open("st_dump_tree.txt", "w", encoding="utf-8") as f:
        f.write(text)
    print("\n[saved] st_dump_tree.txt")
    return 0


if __name__ == "__main__":
    sys.exit(main())
