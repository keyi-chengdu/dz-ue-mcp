#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""通过 unreal MCP dump 指定 StateTree 的完整节点数据（含 instance 默认值）。

用法：
    python st_mcp_dump_detail.py /Game/Blueprint/StateTree/05002101/ST_05002101.ST_05002101 [out.txt]

输出：每状态一行 header，随后 tasks/enter conditions/transitions 每个节点输出
紧凑 JSON（含 node / instance / executionRuntimeData 绑定信息），便于排查
"参数是否绑定、默认值是什么"。
"""
import json
import sys

sys.path.insert(0, r"C:\UE\Projects\DZ_Project_New\.agents\skills\dz-ue-tools\Tools\StateTree")
import st_mcp_dump_tree as T  # noqa: E402


def state_props(ref):
    return T.state_props(ref)


def compact(obj, limit=4000):
    s = json.dumps(obj, ensure_ascii=False)
    return s if len(s) <= limit else s[:limit] + "...<%d chars>" % len(s)


def dump_state(ref, depth, out):
    p = state_props(ref)
    pad = "  " * depth
    out.append("%s### %s  ID=%s Type=%s" % (pad, p.get("Name"), p.get("ID"), p.get("Type")))
    for tag, tool in (("TASK", "get_tasks"), ("ENTERCOND", "get_enter_conditions")):
        for n in T.call(T.STS, tool, {"state": {"refPath": ref}}):
            out.append("%s%s %s" % (pad, tag, compact(n)))
    for tr in T.call(T.STS, "get_transitions", {"state": {"refPath": ref}}):
        st = tr.get("state") or {}
        out.append("%sTRANS trigger=%s target=%s(%s) reactivate=%s" % (
            pad, tr.get("trigger"), st.get("name"), st.get("linkType"), tr.get("reactivateTargetState")))
        for c in (tr.get("conditions") or []):
            out.append("%s  TRANS-COND %s" % (pad, compact(c)))
    for ch in T.call(T.STS, "get_children", {"state": {"refPath": ref}}):
        dump_state(ch["refPath"], depth + 1, out)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    out_file = args[-1] if args[-1].endswith(".txt") else "st_detail.txt"
    tree_paths = [p for p in args if not p.endswith(".txt")]
    T.init()
    out = []
    for path in tree_paths:
        out.append("=" * 100)
        out.append("TREE %s" % path)
        for r in T.call(T.STS, "get_root_states", {"state_tree": {"refPath": path}}):
            dump_state(r["refPath"], 0, out)
    text = "\n".join(out)
    with open(out_file, "w", encoding="utf-8") as f:
        f.write(text)
    print("[saved] %s (%d lines)" % (out_file, len(out)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
