# st_dump_subtree_detail.py - dump a subtree's root params, per-state state parameters, and all bindings
import sys
import unreal

TREES = [
    "/Game/Blueprint/StateTree/05003101/ST_Sub_05003101_Battle",
]


def dump_state_params(tree):
    """Walk states and print each state's State Parameters (via DescribeStateTree node info is not enough)."""
    info = unreal.DZStateTreeEditTools.describe_state_tree(tree)
    return info


def main():
    for path in TREES:
        tree = unreal.load_asset(path)
        if tree is None:
            unreal.log_error("[sub] load failed: " + path)
            continue

        unreal.log("[sub] ===== " + path + " =====")

        params = unreal.DZStateTreeEditTools.get_tree_parameters(tree)
        root_names = [str(p.get_editor_property("name")) for p in params]
        unreal.log("[sub] ROOT_PARAMS({}): {}".format(len(root_names), ", ".join(root_names)))

        zero = unreal.Guid()
        bindings = unreal.DZStateTreeEditTools.get_property_bindings(tree, zero)
        unreal.log("[sub] BINDINGS({})".format(len(bindings)))
        for b in bindings:
            unreal.log("[sub]   src={}  ->  tgt={}".format(
                b.get_editor_property("source_path"),
                b.get_editor_property("target_path")))

        # 状态结构
        states = unreal.DZStateTreeEditTools.dump_state_tree_states(tree) if hasattr(
            unreal.DZStateTreeEditTools, "dump_state_tree_states") else None
        if states:
            unreal.log("[sub] STATES:\n{}".format(states))

    return 0


if __name__ == "__main__":
    sys.exit(main())
