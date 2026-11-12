# st_clean_settreeparam_out_bindings.py
# Purpose: Remove stale bindings whose source property starts with "out:" on
#          STT_SetTreeParam nodes. After Batch 1 deleted the out:* fields from
#          FSTT_SetTreeParamInstanceData, existing assets still reference them
#          as binding sources, which makes StateTree compilation fail.
#
# Dependency: UDZStateTreeEditTools::CleanStaleSetTreeParamOutBindings (DZToolsets plugin).
#
# Usage (editor MUST be closed; writes assets):
#   UnrealEditor-Cmd.exe DZProject.uproject -run=pythonscript -script=".../st_clean_settreeparam_out_bindings.py" -unattended -nopause -nosplash -NullRHI
#   Add -Execute to actually save changes; without it the script runs in DRY mode.
#
# Pitfalls:
#   1. Save uses only_if_is_dirty=False because C++ side may not mark the asset dirty.

import sys
import unreal

_CMD_LINE = (unreal.SystemLibrary.get_command_line() if hasattr(unreal, "SystemLibrary") else " ".join(sys.argv)).lower()
DRY = "-execute" not in _CMD_LINE

ASSET_DIR = "/Game/Blueprint/StateTree"


def list_state_tree_assets():
    ar = unreal.AssetRegistryHelpers.get_asset_registry()
    assets = ar.get_assets_by_path(unreal.Paths.normalize_directory_name(ASSET_DIR), recursive=True)
    paths = []
    for asset in assets:
        if asset.asset_class_path.asset_name == "StateTree":
            paths.append(str(asset.package_name))
    return sorted(paths)


def main():
    unreal.log("[st_clean_settreeparam_out_bindings] DRY={}".format(DRY))

    tree_paths = list_state_tree_assets()
    unreal.log("[st_clean_settreeparam_out_bindings] found {} StateTree asset(s) under {}".format(len(tree_paths), ASSET_DIR))

    total_removed = 0
    for path in tree_paths:
        try:
            tree = unreal.load_asset(path)
            if tree is None:
                unreal.log_warning("[st_clean_settreeparam_out_bindings] load failed: {}".format(path))
                continue

            removed = unreal.DZStateTreeEditTools.clean_stale_set_tree_param_out_bindings(tree)
            unreal.log("[st_clean_settreeparam_out_bindings] {} -> removed={}".format(path, removed))
            total_removed += removed

            if removed > 0 and not DRY:
                unreal.EditorAssetLibrary.save_loaded_asset(tree, only_if_is_dirty=False)
        except Exception as e:
            unreal.log_error("[st_clean_settreeparam_out_bindings] error on {}: {}".format(path, e))

    unreal.log("[st_clean_settreeparam_out_bindings] total_removed={} (DRY={})".format(total_removed, DRY))
    return 0


if __name__ == "__main__":
    sys.exit(main())
