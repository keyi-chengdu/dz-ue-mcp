# st_dump_subtree_tasks_dsl.py - dump a subtree's graph DSL to see its tasks/conditions and bindings
import sys
import unreal

TREES = [
    "/Game/Blueprint/StateTree/05003101/ST_Sub_05003101_Battle",
]


def main():
    for path in TREES:
        tree = unreal.load_asset(path)
        if tree is None:
            unreal.log_error("[dsl] load failed: " + path)
            continue
        unreal.log("[dsl] ===== " + path)
        dsl = unreal.DZStateTreeEditTools.dump_state_tree_bindings(tree)
        for line in str(dsl).splitlines():
            unreal.log("[dsl]   " + line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
