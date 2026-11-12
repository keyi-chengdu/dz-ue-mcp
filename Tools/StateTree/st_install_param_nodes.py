# -*- coding: utf-8 -*-
# Install STT_SetTreeParam nodes for Task output properties and bind outputs -> node inputs.
# Idempotent: states that already contain a SetTreeParam writing the same param are skipped.
# Usage (headless, editor MUST be closed): UnrealEditor-Cmd ... -script=<this> -Execute
import unreal

EXECUTE = "-Execute" in unreal.SystemLibrary.get_command_line()
unreal.log_warning("INSTALL-START execute={}".format(EXECUTE))

TREES = [
    # 主树
    "/Game/Blueprint/StateTree/05002101/ST_05002101",
    "/Game/Blueprint/StateTree/05002102/ST_05002102",
    "/Game/Blueprint/StateTree/05002103/ST_05002103",
    "/Game/Blueprint/StateTree/05002104/ST_05002104",
    "/Game/Blueprint/StateTree/05002105/ST_05002105",
    "/Game/Blueprint/StateTree/05003101/ST_05003101",
    "/Game/Blueprint/StateTree/05004101/ST_05004101",
    # 全部子树（2026-10-28 统一改造：Task 输出一律走写穿节点，绕过子树绑定分叉）
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
            unreal.log_warning("INSTALL-SKIP {} type={}".format(path, type(asset).__name__))
            continue
        try:
            count = unreal.DZAISystemUtil.install_param_out_nodes(asset)
        except Exception as e:
            unreal.log_error("INSTALL-EXC {}: {}".format(path, e))
            continue
        unreal.log_warning("INSTALL-TREE {} added={}".format(path, count))
        total += count
        if EXECUTE and count > 0:
            unreal.EditorAssetLibrary.save_loaded_asset(asset, only_if_is_dirty=False)
    unreal.log_warning("INSTALL-RESULT total={} execute={}".format(total, EXECUTE))


try:
    main()
except Exception as e:
    unreal.log_error("INSTALL-TOPEXC {}".format(e))
