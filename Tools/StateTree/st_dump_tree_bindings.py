# st_dump_tree_bindings.py - dump root parameters + all property bindings of a StateTree asset
import sys
import unreal

TREES = [
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SelectTarget",
    "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle",
    "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack",
    "/Game/Blueprint/StateTree/05002102/ST_05002102",
]


def dump(path):
    tree = unreal.load_asset(path)
    if tree is None:
        unreal.log_error("[dump] load failed: " + path)
        return
    unreal.log_warning("=== " + path + " ===")

    params = unreal.DZStateTreeEditTools.get_tree_parameters(tree)
    names = []
    for p in params:
        names.append(str(p.get_editor_property("name")))
    unreal.log_warning("ROOT_PARAMS: " + ", ".join(names))

    zero = unreal.Guid()
    bindings = unreal.DZStateTreeEditTools.get_property_bindings(tree, zero)
    unreal.log_warning("BINDINGS({}):".format(len(bindings)))
    for b in bindings:
        unreal.log_warning("{} <= {}".format(
            b.get_editor_property("target_path"),
            b.get_editor_property("source_path")))


def main():
    for path in TREES:
        dump(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
