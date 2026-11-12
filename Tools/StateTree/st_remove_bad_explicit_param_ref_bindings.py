# st_remove_bad_explicit_param_ref_bindings.py
# Purpose: Remove Parameters.<BlueprintPropertyRef> -> explicit non-Ref task/condition
#          input bindings created by an older BindTaskInputsFromTreeParameters run.
#
# Dependency: UDZStateTreeEditTools::RemoveExplicitInputsBoundToRefParameters.
# The C++ helper preserves Parameters.<Ref> -> Ref-field and Parameters.<Value> ->
# In-field bindings, and reuses the rule set from st_bind_task_inputs.py.
#
# Usage (editor MUST be closed; writes assets with -Execute):
#   UnrealEditor-Cmd.exe DZProject.uproject -run=pythonscript \
#     -script="<this file>" -unattended -nopause -nosplash -NullRHI -noscc
#   Add -Execute to save; without it the script runs in DRY mode.

import os
import sys
import unreal

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from st_bind_task_inputs import build_rule_objects  # noqa: E402


ASSET_DIR = "/Game/Blueprint/StateTree"


def list_state_tree_assets():
    registry = unreal.AssetRegistryHelpers.get_asset_registry()
    assets = registry.get_assets_by_path(
        unreal.Paths.normalize_directory_name(ASSET_DIR), recursive=True
    )
    paths = []
    for asset in assets:
        if asset.asset_class_path.asset_name == "StateTree":
            paths.append(str(asset.package_name))
    return sorted(paths)


def main():
    command_line = unreal.SystemLibrary.get_command_line().lower()
    dry = "-execute" not in command_line
    unreal.log_warning("[st_remove_bad_explicit_param_ref_bindings] DRY={}".format(dry))

    rules = build_rule_objects()
    if not rules:
        unreal.log_error("[st_remove_bad_explicit_param_ref_bindings] no valid rules; aborting.")
        return 1

    tree_paths = list_state_tree_assets()
    unreal.log_warning(
        "[st_remove_bad_explicit_param_ref_bindings] found {} StateTree asset(s)".format(
            len(tree_paths)
        )
    )

    total_removed = 0
    saved = 0
    for path in tree_paths:
        try:
            tree = unreal.load_asset(path)
            if not isinstance(tree, unreal.StateTree):
                unreal.log_warning("[st_remove_bad_explicit_param_ref_bindings] skip {} type={}".format(path, type(tree).__name__))
                continue

            removed = unreal.DZStateTreeEditTools.remove_explicit_inputs_bound_to_ref_parameters(tree, rules)
            total_removed += removed
            unreal.log_warning(
                "[st_remove_bad_explicit_param_ref_bindings] {} -> removed={}".format(path, removed)
            )

            if removed > 0 and not dry:
                saved_asset = unreal.EditorAssetLibrary.save_loaded_asset(tree, only_if_is_dirty=False)
                if saved_asset:
                    saved += 1
                else:
                    unreal.log_error("[st_remove_bad_explicit_param_ref_bindings] save failed: {}".format(path))
        except Exception as exc:
            unreal.log_error("[st_remove_bad_explicit_param_ref_bindings] error on {}: {}".format(path, exc))

    unreal.log_warning(
        "[st_remove_bad_explicit_param_ref_bindings] total_removed={} saved={} DRY={}".format(
            total_removed, saved, dry
        )
    )
    return 0 if dry or saved == total_removed else 1


if __name__ == "__main__":
    sys.exit(main())
