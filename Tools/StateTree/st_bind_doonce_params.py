# st_bind_doonce_params.py
# Purpose: 把「只执行一次（STC_Server_DoOnce）」的完成标记真正落到树级 Parameters：
#   1) 读节点 TagKey（旧的“标识 Key”，如 "1"/"2"），按 KEY_MAP 映射成参数名；
#   2) 把节点 TagKey 改写为该参数名（运行时写回的就是这个参数）；
#   3) 根参数包缺同名 Bool 参数则补上；
#   4) 把实例数据 InDone 绑定到 Parameters.<参数名>。
#
# 依赖：UDZStateTreeEditTools::BindDoOnceParameters（DZToolsets 插件）。
#
# 用法（编辑器必须先关闭；默认 DRY）：
#   UnrealEditor-Cmd.exe DZProject.uproject -run=pythonscript -script=".../st_bind_doonce_params.py" -unattended -nopause -nosplash -NullRHI
#   加 -Execute 才真正写资产并保存。
#
# 背景：GetTreeParam 清零后 DoOnce 改读实例数据 InDone；若 InDone 未绑定、TagKey 又不在根参数包里，
#   写回只落黑板，条件永远为真 → 状态每帧重进（敌人【初次生成】每帧重播出生蒙太奇）。
#   结果从 DZ_Content/Saved/Logs/DZProject.log 里搜 [st_bind_doonce] 读取。

import sys
import unreal

_CMD_LINE = (unreal.SystemLibrary.get_command_line() if hasattr(unreal, "SystemLibrary") else " ".join(sys.argv)).lower()
DRY = "-execute" not in _CMD_LINE

ASSET_DIR = "/Game/Blueprint/StateTree"

# 旧“标识 Key” → 参数名（Parameters 下的 bool 字段，语义化命名）
KEY_MAP = {
    "1": "Done_InitialSpawn",   # 【初次生成】只播一次出生蒙太奇
    "2": "Done_SummonBuff",     # 【召唤并强化】只召唤一次
}


def list_state_tree_assets():
    ar = unreal.AssetRegistryHelpers.get_asset_registry()
    assets = ar.get_assets_by_path(unreal.Paths.normalize_directory_name(ASSET_DIR), recursive=True)
    paths = []
    for asset in assets:
        if asset.asset_class_path.asset_name == "StateTree":
            paths.append(str(asset.package_name))
    return sorted(paths)


def main():
    unreal.log("[st_bind_doonce] DRY={} assets under {}".format(DRY, ASSET_DIR))
    mapping = {k: unreal.Name(v) for k, v in KEY_MAP.items()}

    total_changed = 0
    for path in list_state_tree_assets():
        try:
            tree = unreal.load_asset(path)
            if tree is None:
                unreal.log_warning("[st_bind_doonce] load failed: {}".format(path))
                continue
            removed = unreal.DZStateTreeEditTools.remove_bindings_with_empty_source_path(tree)
            overridden = unreal.DZStateTreeEditTools.override_linked_state_parameters(tree, [])
            changed = unreal.DZStateTreeEditTools.bind_do_once_parameters(tree, mapping)
            unreal.log("[st_bind_doonce] {} -> removed_empty_source={} overridden={} changed={}".format(
                path, removed, overridden, changed))
            total_changed += changed
            if (removed or overridden or changed) and not DRY:
                unreal.EditorAssetLibrary.save_loaded_asset(tree, only_if_is_dirty=False)
            for line in unreal.DZStateTreeEditTools.dump_all_bindings(tree):
                unreal.log("[bind] {} | {}".format(path.rsplit("/", 1)[-1], line))
        except Exception as e:  # noqa: BLE001
            unreal.log_error("[st_bind_doonce] error on {}: {}".format(path, e))

    unreal.log("[st_bind_doonce] total_changed={} (DRY={})".format(total_changed, DRY))
    return 0


if __name__ == "__main__":
    sys.exit(main())
