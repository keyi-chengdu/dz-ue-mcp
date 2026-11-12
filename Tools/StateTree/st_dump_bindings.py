# -*- coding: utf-8 -*-
# Read-only dump of StateTree editor property bindings (via C++ UDZAISystemUtil::DumpStateTreeBindings,
# which reflects into UStateTree::EditorData and its EditorBindings; Python cannot read those directly).
# Usage (headless, editor MUST be closed): UnrealEditor-Cmd ... -run=pythonscript -script=<this file>
import unreal

TREES = [
    "/Game/Blueprint/StateTree/05002101/ST_05002101",
    "/Game/Blueprint/StateTree/05002101/ST_Sub_05002101_Battle",
    "/Game/Blueprint/StateTree/05002102/ST_05002102",
    "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle",
    "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack",
    "/Game/Blueprint/StateTree/05002103/ST_05002103",
    "/Game/Blueprint/StateTree/05002104/ST_05002104",
    "/Game/Blueprint/StateTree/05002105/ST_05002105",
    "/Game/Blueprint/StateTree/05003101/ST_05003101",
    "/Game/Blueprint/StateTree/05004101/ST_05004101",
]


def main():
    for path in TREES:
        asset = unreal.EditorAssetLibrary.load_asset(path)
        if not isinstance(asset, unreal.StateTree):
            unreal.log_warning("DUMP-SKIP {} type={}".format(path, type(asset).__name__))
            continue
        try:
            text = unreal.DZAISystemUtil.dump_state_tree_bindings(asset)
        except Exception as e:
            unreal.log_error("DUMP-EXC {}: {}".format(path, e))
            continue
        unreal.log_warning("DUMP-TREE {}".format(path))
        for line in str(text).split("\n"):
            unreal.log_warning("DUMP-LINE {}".format(line))
    unreal.log_warning("DUMP-DONE")


try:
    main()
except Exception as e:
    unreal.log_error("DUMP-TOPEXC {}".format(e))
