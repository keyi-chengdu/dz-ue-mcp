# st_migrate_bp_trygetparam.py
# Purpose: Batch 3 of the GetTreeParam zero-out migration.
#          STT_Enemy_Turn / STT_LineTrace are Blueprint StateTree tasks that still call
#          DZAISystemUtil::TryGetTreeParam (the Blueprint read channel). This script replaces
#          those calls with InstanceData member-variable reads through
#          UDZStateTreeEditTools::MigrateBlueprintTaskOffTryGetTreeParam (DZToolsets).
#
# Why two phases:
#   A member variable added in the current process is not yet part of the Blueprint's
#   SkeletonGeneratedClass, so UK2Node_VariableGet cannot resolve it and produces zero pins.
#   Phase A adds + compiles + saves the variables, then the asset is reloaded from disk;
#   Phase B creates the variable-get nodes and rewires/destroys the TryGetTreeParam nodes.
#
# Usage (editor MUST be closed):
#   UnrealEditor-Cmd.exe DZProject.uproject -run=pythonscript -script=".../st_migrate_bp_trygetparam.py" -unattended -nopause -nosplash -NullRHI
#   Add -Execute to actually modify + save assets; otherwise DRY mode.

import sys
import unreal

_CMD_LINE = (unreal.SystemLibrary.get_command_line() if hasattr(unreal, "SystemLibrary") else " ".join(sys.argv)).lower()
DRY = "-execute" not in _CMD_LINE
PHASE_B_ONLY = "-phasebonly" in _CMD_LINE

# Blueprint asset -> [(ParamKey, MemberVariableName)]
TARGETS = {
    "/Game/Blueprint/StateTree/Common/Task/STT_Enemy_Turn": [
        ("ACTOR_TARGET", "InTargetActor"),
        ("POINT_TARGET", "InPointTarget"),
    ],
    "/Game/Blueprint/StateTree/Common/Task/STT_LineTrace": [
        ("ACTOR_TARGET", "InTargetActor"),
    ],
}


def build_mappings(pairs):
    out = []
    for param_key, var_name in pairs:
        mapping = unreal.DZBlueprintTreeParamMapping()
        mapping.set_editor_property("param_key", param_key)
        mapping.set_editor_property("variable_name", var_name)
        out.append(mapping)
    return out


def main():
    unreal.log("[st_migrate_bp_trygetparam] DRY={} PHASE_B_ONLY={}".format(DRY, PHASE_B_ONLY))

    total_vars = 0
    total_rewired = 0

    for path, pairs in TARGETS.items():
        bp = unreal.load_asset(path)
        if bp is None:
            unreal.log_error("[st_migrate_bp_trygetparam] load failed: {}".format(path))
            continue

        mappings = build_mappings(pairs)
        if DRY:
            unreal.log("[st_migrate_bp_trygetparam] {} -> DRY, keys {}".format(path, [p[0] for p in pairs]))
            continue

        if not PHASE_B_ONLY:
            # Phase A: ensure member variables exist, then persist so the next process sees them.
            added = unreal.DZStateTreeEditTools.migrate_blueprint_task_off_try_get_tree_param(bp, mappings, True)
            unreal.log("[st_migrate_bp_trygetparam] {} phase A added={}".format(path, added))
            total_vars += added
            if added > 0:
                unreal.EditorAssetLibrary.save_loaded_asset(bp, only_if_is_dirty=False)
                unreal.log("[st_migrate_bp_trygetparam] {} saved; re-run with -PhaseBOnly to rewire.".format(path))
                continue

        # Phase B: rewire TryGetTreeParam nodes onto the member variables.
        rewired = unreal.DZStateTreeEditTools.migrate_blueprint_task_off_try_get_tree_param(bp, mappings, False)
        unreal.log("[st_migrate_bp_trygetparam] {} phase B rewired={}".format(path, rewired))
        total_rewired += rewired

        if rewired > 0:
            unreal.EditorAssetLibrary.save_loaded_asset(bp, only_if_is_dirty=False)

    unreal.log("[st_migrate_bp_trygetparam] total_vars={} total_rewired={} (DRY={})".format(
        total_vars, total_rewired, DRY))
    return 0


if __name__ == "__main__":
    sys.exit(main())
