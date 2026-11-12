# -*- coding: utf-8 -*-
import unreal

EXECUTE = "-Execute" in unreal.SystemLibrary.get_command_line()
unreal.log_warning("PROBE-START execute={}".format(EXECUTE))

PARAM_FIELDS = [
    ("ACTOR_TARGET",        "Object", "/Script/Engine.Actor"),
    ("ATTACK_TARGET",       "Object", "/Script/Engine.Actor"),
    ("HAS_POINT_TARGET",    "Bool",   "None"),
    ("POINT_TARGET",        "Struct", "/Script/CoreUObject.Vector"),
    ("EnemyAttackData",     "Struct", "/Script/DZProject.AttackTaskData"),
    ("EnemyPlayMontageTag", "Struct", "/Script/GameplayTags.GameplayTag"),
    # 2026-10-28 补：无 Context 回调通道（移动结束/受击）的写穿键参数化——
    # 之前因回调拿不到 Context 列为"永不配"，现由 UNetStateTreeComponent::SetTreeParamAndPublish 写穿
    ("MoveRequestOver",     "Bool",   "None"),
    ("LAST_SELFATTACKER",   "Object", "/Script/Engine.Actor"),
]

MAIN_TREES = [
    "/Game/Blueprint/StateTree/05002101/ST_05002101",
    # ST_05002101_TEST 已删除（2026-10-28 用户清理测试残留，连同 BP_Evaluator_Test/BP_Task_Test）
    "/Game/Blueprint/StateTree/05002102/ST_05002102",
    "/Game/Blueprint/StateTree/05002103/ST_05002103",
    "/Game/Blueprint/StateTree/05002104/ST_05002104",
    "/Game/Blueprint/StateTree/05002105/ST_05002105",
    "/Game/Blueprint/StateTree/05003101/ST_05003101",
    "/Game/Blueprint/StateTree/05004101/ST_05004101",
]


def inject_tree(path):
    asset = unreal.EditorAssetLibrary.load_asset(path)
    unreal.log_warning("PROBE-LOAD {} type={}".format(path, type(asset).__name__))
    if not isinstance(asset, unreal.StateTree):
        unreal.log_error("PROBE-SKIP {}".format(path))
        return False
    ok_count = 0
    for name, ptype, tpath in PARAM_FIELDS:
        try:
            r = unreal.DZAISystemUtil.add_state_tree_global_parameter(asset, name, ptype, tpath)
            unreal.log_warning("PROBE-FIELD {} {} -> {}".format(path, name, r))
            if r:
                ok_count += 1
        except Exception as e:
            unreal.log_error("PROBE-EXC {} {}: {}".format(path, name, e))
    if EXECUTE:
        unreal.EditorAssetLibrary.save_loaded_asset(asset, only_if_is_dirty=False)
    unreal.log_warning("PROBE-TREE {} {}/{} saved={}".format(path, ok_count, len(PARAM_FIELDS), EXECUTE))
    return ok_count == len(PARAM_FIELDS)


def main():
    ok, fail = 0, 0
    for p in MAIN_TREES:
        try:
            if inject_tree(p):
                ok += 1
            else:
                fail += 1
        except Exception as e:
            unreal.log_error("PROBE-TREEEXC {}: {}".format(p, e))
            fail += 1
    unreal.log_warning("PROBE-RESULT ok={} fail={} mode={}".format(ok, fail, "EXECUTE" if EXECUTE else "DRY"))


try:
    main()
except Exception as e:
    unreal.log_error("PROBE-TOPEXC {}".format(e))
unreal.log_warning("PROBE-END")
