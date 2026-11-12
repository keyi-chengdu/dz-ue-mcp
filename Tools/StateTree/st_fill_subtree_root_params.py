# st_fill_subtree_root_params.py
# 给子树补根参数字段：引擎在进入链接态子树时会把父树 linked state 的 State Parameters
# 当作子树的全局参数（StateTreeExecutionContext.cpp:7842-7845），因此子树内 task 的
# InXxx 可以绑到 Parameters.<同名字段> 受数。
#
# 本脚本从「主树根参数包」读取每个字段的值类型，然后给所有子树补齐同名缺失字段。
#
# Usage (editor MUST be closed):
#   add -Execute to actually write; otherwise DRY.

import sys
import unreal

_CMD = " ".join(sys.argv).lower()
_UE_CMD = ""
try:
    _UE_CMD = (unreal.SystemLibrary.get_command_line() or "").lower()
except Exception:  # noqa: BLE001
    pass
DRY = ("-execute" not in _CMD) and ("-execute" not in _UE_CMD)

# 主树（字段类型来源）
SOURCE_TREES = [
    "/Game/Blueprint/StateTree/05004101/ST_05004101",
]

# 需要补字段的子树
TARGET_TREES = [
    "/Game/Blueprint/StateTree/05002101/ST_Sub_05002101_Battle",
    "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle",
    "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack",
    "/Game/Blueprint/StateTree/05002103/ST_Sub_05002103_Battle",
    "/Game/Blueprint/StateTree/05002104/ST_Sub_05002104_Battle",
    "/Game/Blueprint/StateTree/05002105/ST_Sub_05002105_Battle",
    "/Game/Blueprint/StateTree/05003101/ST_Sub_05003101_Battle",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_HurtReaction",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_Jump",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_NoCombat",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SelectTarget",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SurroundPlayer_Melee",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SurroundPlayer_Ranged",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_Turn",
]

# 要补齐的字段（子集，按需）
WANTED = [
    "ACTOR_TARGET",
    "ATTACK_TARGET",
    "HAS_POINT_TARGET",
    "POINT_TARGET",
    "LAST_SELFATTACKER",
    "EnemyAttackData",
    "EnemyPlayMontageTag",
    "MoveRequestOver",
]


def read_types():
    """从主树读取字段 -> (ValueType, TypeObjectPath)。"""
    types = {}
    tree = unreal.load_asset(SOURCE_TREES[0])
    if tree is None:
        unreal.log_error("[fill] source tree load failed")
        return types
    params = unreal.DZStateTreeEditTools.get_tree_parameters(tree)
    for p in params:
        name = str(p.get_editor_property("name"))
        if name not in WANTED:
            continue
        types[name] = (
            str(p.get_editor_property("value_type")),
            str(p.get_editor_property("type_object_path")),
        )
    return types


def main():
    types = read_types()
    unreal.log("[fill] DRY={} types={}".format(DRY, types))
    if not types:
        unreal.log_error("[fill] no types resolved")
        return 1

    total_added = 0
    for path in TARGET_TREES:
        tree = unreal.load_asset(path)
        if tree is None:
            unreal.log_error("[fill] load failed: " + path)
            continue

        existing = set(str(p.get_editor_property("name"))
                       for p in unreal.DZStateTreeEditTools.get_tree_parameters(tree))
        missing = [n for n in WANTED if n in types and n not in existing]

        if not missing:
            unreal.log("[fill] {:70s} up-to-date".format(path))
            continue

        unreal.log("[fill] {:70s} missing={}".format(path, missing))
        if DRY:
            continue

        for name in missing:
            value_type, type_object = types[name]
            unreal.DZStateTreeEditTools.add_tree_parameter(
                tree,
                unreal.Name(name),
                unreal.Name(value_type),
                unreal.Name(type_object or ""))
            total_added += 1

        unreal.EditorAssetLibrary.save_loaded_asset(tree, only_if_is_dirty=False)
        unreal.log("[fill] {:70s} added {}".format(path, missing))

    unreal.log("[fill] TOTAL_ADDED={} (DRY={})".format(total_added, DRY))
    return 0


if __name__ == "__main__":
    sys.exit(main())
