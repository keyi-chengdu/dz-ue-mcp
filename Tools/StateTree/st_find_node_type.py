# st_find_node_type.py - find which states contain a given node struct name in a tree
import sys
import unreal

TREES = [
    "/Game/Blueprint/StateTree/05002101/ST_05002101",
    "/Game/Blueprint/StateTree/05002101/ST_Sub_05002101_Battle",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_NoCombat",
]

NEEDLES = ["STT_PlayMontage", "STT_SetTreeParam"]


def main():
    for path in TREES:
        tree = unreal.load_asset(path)
        if tree is None:
            unreal.log_error("[nodefind] load failed " + path)
            continue
        unreal.log("[nodefind] ===== " + path)
        try:
            text = unreal.DZStateTreeEditTools.dump_state_tree_states(tree)
        except Exception as exc:  # noqa: BLE001
            unreal.log("[nodefind] dump unavailable: {}".format(exc))
            text = ""
        for line in str(text).splitlines():
            if any(n in line for n in NEEDLES):
                unreal.log("[nodefind]   " + line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
