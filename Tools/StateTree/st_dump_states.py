# -*- coding: utf-8 -*-
# Read-only dump of StateTree states + task nodes (via C++ UDZAISystemUtil::DumpStateTreeStates).
# Usage (headless, editor MUST be closed): UnrealEditor-Cmd ... -run=pythonscript -script=<this file>
import unreal

TREES = [
    "/Game/Blueprint/StateTree/05002101/ST_05002101",
    "/Game/Blueprint/StateTree/05002102/ST_05002102",
    "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle",
    "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack",
    "/Game/Blueprint/StateTree/05002103/ST_05002103",
    "/Game/Blueprint/StateTree/05002104/ST_05002104",
    "/Game/Blueprint/StateTree/05002105/ST_05002105",
    "/Game/Blueprint/StateTree/05003101/ST_05003101",
    "/Game/Blueprint/StateTree/05004101/ST_05004101",
    "/Game/Blueprint/StateTree/05002101/ST_Sub_05002101_Battle",
]


def main():
    for path in TREES:
        asset = unreal.EditorAssetLibrary.load_asset(path)
        if not isinstance(asset, unreal.StateTree):
            unreal.log_warning("ST-SKIP {} type={}".format(path, type(asset).__name__))
            continue
        try:
            text = unreal.DZAISystemUtil.dump_state_tree_states(asset)
        except Exception as e:
            unreal.log_error("ST-EXC {}: {}".format(path, e))
            continue
        unreal.log_warning("ST-TREE {}".format(path))
        for line in str(text).split("\n"):
            unreal.log_warning("ST-LINE {}".format(line))
    unreal.log_warning("ST-DONE")


try:
    main()
except Exception as e:
    unreal.log_error("ST-TOPEXC {}".format(e))
