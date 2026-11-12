# -*- coding: utf-8 -*-
# Read-only dump of StateTree root parameters (via DZStateTreeEditTools::GetTreeParameters).
# Usage (headless, editor MUST be closed): UnrealEditor-Cmd ... -run=pythonscript -script=<this file>
import unreal

TREES = [
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SelectTarget",
    "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle",
    "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack",
    "/Game/Blueprint/StateTree/05002102/ST_05002102",
]


def main():
    for path in TREES:
        asset = unreal.EditorAssetLibrary.load_asset(path)
        if not isinstance(asset, unreal.StateTree):
            unreal.log_warning("PARAM-SKIP {} type={}".format(path, type(asset).__name__))
            continue

        unreal.log_warning("PARAM-TREE {}".format(path))
        try:
            parameters = unreal.DZStateTreeEditTools.get_tree_parameters(asset)
        except Exception as e:
            unreal.log_error("PARAM-EXC {}: {}".format(path, e))
            continue

        for item in parameters:
            unreal.log_warning(
                "PARAM-LINE {} name={} type={} object_path={} container={}".format(
                    path, item.name, item.value_type, item.type_object_path, item.container_type
                )
            )
    unreal.log_warning("PARAM-DONE")


try:
    main()
except Exception as e:
    unreal.log_error("PARAM-TOPEXC {}".format(e))
