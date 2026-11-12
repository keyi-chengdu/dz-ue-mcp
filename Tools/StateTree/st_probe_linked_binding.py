# st_probe_linked_binding.py - check whether a linked state's State Parameters can be bound from the parent tree's Parameters
import sys
import unreal

TREE = "/Game/Blueprint/StateTree/05003101/ST_05003101"


def main():
    tree = unreal.load_asset(TREE)
    if tree is None:
        unreal.log_error("[probe3] load failed")
        return 1

    bindings = unreal.DZStateTreeEditTools.get_property_bindings(tree, unreal.Guid())
    unreal.log("[probe3] parent bindings total={}".format(len(bindings)))
    for b in bindings:
        unreal.log("[probe3]   src={} -> tgt={}".format(
            b.get_editor_property("source_path"),
            b.get_editor_property("target_path")))

    return 0


if __name__ == "__main__":
    sys.exit(main())
