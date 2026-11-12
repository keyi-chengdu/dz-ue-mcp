#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""解析 st_mcp_dump_detail.py 的输出，汇总 DoOnce / 未绑定 In 输入 的节点位置。

用法：python st_report_doonce.py st_detail_all.txt
输出：
  TREE ...
    STATE 路径
      DoOnce TagKey=... InDone绑定=有/无 NodeID=...
"""
import json
import re
import sys


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "st_detail_all.txt"
    sys.stdout.reconfigure(encoding="utf-8")
    tree = None
    state_path = []
    for raw in open(path, encoding="utf-8"):
        line = raw.rstrip("\n")
        if line.startswith("TREE "):
            tree = line[5:].strip()
            state_path = []
            print("\nTREE %s" % tree)
        m = re.match(r"^(\s*)### (.*?)\s{2}ID=(\S+) Type=(\S+)$", line)
        if m:
            depth = len(m.group(1)) // 2
            state_path = state_path[:depth] + [m.group(2)]
            continue
        m = re.match(r"^(\s*)(TASK|ENTERCOND|TRANS-COND) (\{.*)$", line)
        if not m:
            continue
        try:
            node = json.loads(m.group(3))
        except Exception:
            continue
        n = node.get("node", {}) or {}
        t = n.get("_structType", "")
        inst = node.get("instance", {}) or {}
        rt = node.get("executionRuntimeData", {}) or {}
        if "DoOnce" in t:
            print("  %-70s node=%s key=%r inDone=%r runtime=%s id=%s" % (
                " / ".join(state_path), t.rsplit(".", 1)[-1],
                n.get("tagKey"), inst.get("inDone"),
                "BOUND" if rt else "EMPTY", node.get("iD")))
        elif "PlayMontage" in t:
            print("  %-70s node=%s tag=%r bExit=%r runtime=%s id=%s" % (
                " / ".join(state_path), t.rsplit(".", 1)[-1],
                (inst.get("montageTag") or {}).get("tagName"),
                inst.get("bExitEndAbility"), "BOUND" if rt else "EMPTY", node.get("iD")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
