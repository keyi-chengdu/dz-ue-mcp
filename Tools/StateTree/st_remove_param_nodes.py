# -*- coding: utf-8 -*-
# Remove STT_SetTreeParam nodes whose binding source is the given task type.
# Used to roll back Running-task nodes (FindTarget/Attack): their out properties only get
# values on the "found frame"/"end frame", so the node's unconditional first-tick write
# would write empty values. Those tasks use in-code write-through instead.
# Usage (headless, editor MUST be closed): ... -script=<this> -Execute
import unreal

EXECUTE = "-Execute" in unreal.SystemLibrary.get_command_line()

# 来源为这些任务类型的节点要摘除（Running 多帧任务，走代码写穿）
SOURCE_TASKS = ["STT_FindTarget", "STT_Attack"]

TREES = [
    "/Game/Blueprint/StateTree/05002101/ST_05002101",
    "/Game/Blueprint/StateTree/05002102/ST_05002102",
    "/Game/Blueprint/StateTree/05002103/ST_05002103",
    "/Game/Blueprint/StateTree/05002104/ST_05002104",
    "/Game/Blueprint/StateTree/05002105/ST_05002105",
    "/Game/Blueprint/StateTree/05003101/ST_05003101",
    "/Game/Blueprint/StateTree/05004101/ST_05004101",
    "/Game/Blueprint/StateTree/05002101/ST_Sub_05002101_Battle",
    "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle",
    "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack",
    "/Game/Blueprint/StateTree/05002103/ST_Sub_05002103_Battle",
    "/Game/Blueprint/StateTree/05002104/ST_Sub_05002104_Battle",
    "/Game/Blueprint/StateTree/05002105/ST_Sub_05002105_Battle",
    "/Game/Blueprint/StateTree/05003101/ST_Sub_05003101_Battle",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_NoCombat",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SelectTarget",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SurroundPlayer_Melee",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SurroundPlayer_Ranged",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_Turn",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_HurtReaction",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_Jump",
]


def main():
    total = 0
    for path in TREES:
        asset = unreal.EditorAssetLibrary.load_asset(path)
        if not isinstance(asset, unreal.StateTree):
            unreal.log_warning("RMV-SKIP {} type={}".format(path, type(asset).__name__))
            continue
        tree_removed = 0
        for src in SOURCE_TASKS:
            try:
                tree_removed += unreal.DZAISystemUtil.remove_set_tree_param_nodes_by_source(asset, src)
            except Exception as e:
                unreal.log_error("RMV-EXC {} {}: {}".format(path, src, e))
        unreal.log_warning("RMV-TREE {} removed={}".format(path, tree_removed))
        total += tree_removed
        if EXECUTE and tree_removed > 0:
            unreal.EditorAssetLibrary.save_loaded_asset(asset, only_if_is_dirty=False)
    unreal.log_warning("RMV-RESULT total={} execute={}".format(total, EXECUTE))


try:
    main()
except Exception as e:
    unreal.log_error("RMV-TOPEXC {}".format(e))
