# st_bind_linked_state_feed.py
# 给所有树的链接态建立「树根参数 -> 链接态 State Parameters」供数绑定。
#
# 为什么需要：引擎进入链接态子树时把 linked state 的 State Parameters 当作子树的全局参数
# （StateTreeExecutionContext.cpp:7842-7845）。子树 task 绑定 Parameters.X 的数据源就是这里。
# 缺这条绑定 = 子树 task 读到默认值（空 Actor / false / 零向量）。
#
# Usage (editor MUST be closed):
#   add -Execute to actually write; otherwise DRY.

import sys
import unreal

_CMD = " ".join(sys.argv).lower()
_UE = ""
try:
    _UE = (unreal.SystemLibrary.get_command_line() or "").lower()
except Exception:  # noqa: BLE001
    pass
DRY = ("-execute" not in _CMD) and ("-execute" not in _UE)

ASSET_DIR = "/Game/Blueprint/StateTree"

PARAM_NAMES = [
    "ACTOR_TARGET",
    "ATTACK_TARGET",
    "HAS_POINT_TARGET",
    "POINT_TARGET",
    "LAST_SELFATTACKER",
    "EnemyAttackData",
    "EnemyPlayMontageTag",
    "MoveRequestOver",
]


def list_trees():
    ar = unreal.AssetRegistryHelpers.get_asset_registry()
    assets = ar.get_assets_by_path(unreal.Paths.normalize_directory_name(ASSET_DIR), recursive=True)
    return sorted(str(a.package_name) for a in assets if a.asset_class_path.asset_name == "StateTree")


def main():
    unreal.log("[feedbind] DRY={}".format(DRY))

    names = [unreal.Name(n) for n in PARAM_NAMES]
    total = 0

    for path in list_trees():
        tree = unreal.load_asset(path)
        if tree is None:
            unreal.log_error("[feedbind] load failed: " + path)
            continue

        if DRY:
            linked = unreal.DZStateTreeEditTools.describe_linked_states(tree)
            if linked:
                unreal.log("[feedbind] {} -> DRY, linked states {}".format(path, len(linked)))
            continue

        changed = unreal.DZStateTreeEditTools.bind_linked_state_parameters_from_tree(tree, names)
        if changed > 0:
            unreal.log("[feedbind] {} -> +{}".format(path, changed))
            total += changed
            unreal.EditorAssetLibrary.save_loaded_asset(tree, only_if_is_dirty=False)

    unreal.log("[feedbind] TOTAL={} (DRY={})".format(total, DRY))
    return 0


if __name__ == "__main__":
    sys.exit(main())
