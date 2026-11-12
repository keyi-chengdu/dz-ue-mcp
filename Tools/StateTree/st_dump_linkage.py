# st_dump_linkage.py - dump State Parameters of linked states + bindings, per tree
import sys
import unreal

TREES = [
    "/Game/Blueprint/StateTree/05003101/ST_05003101",
]

CANDIDATE_APIS = [
    "describe_state_tree",
    "get_state_parameters",
    "dump_state_tree_states",
]


def main():
    avail = [n for n in CANDIDATE_APIS if hasattr(unreal.DZStateTreeEditTools, n)]
    unreal.log("[link] available detail apis: {}".format(avail))

    for path in TREES:
        tree = unreal.load_asset(path)
        if tree is None:
            unreal.log_error("[link] load failed: " + path)
            continue

        unreal.log("[link] ===== " + path + " =====")
        params = unreal.DZStateTreeEditTools.get_tree_parameters(tree)
        unreal.log("[link] ROOT: {}".format(
            ", ".join(str(p.get_editor_property("name")) for p in params)))

        bindings = unreal.DZStateTreeEditTools.get_property_bindings(tree, unreal.Guid())
        unreal.log("[link] BINDINGS({})".format(len(bindings)))
        for b in bindings:
            src = b.get_editor_property("source_path")
            tgt = b.get_editor_property("target_path")
            unreal.log("[link]   src={}  ->  tgt={}".format(src, tgt))

    return 0


if __name__ == "__main__":
    sys.exit(main())
