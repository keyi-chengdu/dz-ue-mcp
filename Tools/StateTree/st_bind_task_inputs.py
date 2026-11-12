# st_bind_task_inputs.py
# Purpose: Batch-bind task/condition instance-data inputs to tree-level Parameters for the
#          GetTreeParam zero-out migration (Batch 2). After Batch 1 added explicit InXxx
#          inputs with fallbacks, this script wires those inputs to the matching root
#          Parameters so runtime no longer needs the fallback path.
#
# Dependency: UDZStateTreeEditTools::BindTaskInputsFromTreeParameters (DZToolsets plugin).
#
# Usage (editor MUST be closed; writes assets):
#   UnrealEditor-Cmd.exe DZProject.uproject -run=pythonscript -script=".../st_bind_task_inputs.py" -unattended -nopause -nosplash -NullRHI
#   Add -Execute to actually save changes; without it the script runs in DRY mode.
#
# Pitfalls:
#   1. NodeType strings use UHT names (no leading F), e.g. /Script/DZProject.STT_Attack.
#   2. Dynamic-key nodes such as FSTC_Server_DoOnce are NOT handled here (must be refactored).
#   3. Blueprint tasks are not in the default rule set; add their Blueprint classes to RULES if needed.
#   4. Save uses only_if_is_dirty=False because C++ side may not mark the asset dirty.

import sys
import unreal

_CMD_LINE = (unreal.SystemLibrary.get_command_line() if hasattr(unreal, "SystemLibrary") else " ".join(sys.argv)).lower()
DRY = "-execute" not in _CMD_LINE

# ---------------------------------------------------------------------------
# Binding rules: NodeType -> InstanceData input property -> root Parameter name
# ---------------------------------------------------------------------------
RULES = [
    # Task: AskForBattleTarget
    {"NodeType": "/Script/DZProject.STT_AskForBattleTarget", "InputPropertyName": "InActorTarget",        "ParamName": "ACTOR_TARGET"},
    {"NodeType": "/Script/DZProject.STT_AskForBattleTarget", "InputPropertyName": "InLastSelfAttacker",   "ParamName": "LAST_SELFATTACKER"},
    # Task: TryAddToBattleSequence
    {"NodeType": "/Script/DZProject.STT_TryAddToBattleSequence", "InputPropertyName": "InTargetActor",   "ParamName": "ACTOR_TARGET"},
    # NOTE: FSTTTryAddBattleSequenceInstanceData 只有 InTargetActor，没有 InAttackTarget。
    # Task: Attack
    {"NodeType": "/Script/DZProject.STT_Attack", "InputPropertyName": "InActorTarget",    "ParamName": "ACTOR_TARGET"},
    {"NodeType": "/Script/DZProject.STT_Attack", "InputPropertyName": "InAttackTarget",   "ParamName": "ATTACK_TARGET"},
    # Task: FindTarget
    {"NodeType": "/Script/DZProject.STT_FindTarget", "InputPropertyName": "InHasPointTarget", "ParamName": "HAS_POINT_TARGET"},
    {"NodeType": "/Script/DZProject.STT_FindTarget", "InputPropertyName": "InPointTarget",    "ParamName": "POINT_TARGET"},
    # Task: MoveToTarget
    {"NodeType": "/Script/DZProject.STT_MoveToTarget", "InputPropertyName": "InActorTarget",    "ParamName": "ACTOR_TARGET"},
    {"NodeType": "/Script/DZProject.STT_MoveToTarget", "InputPropertyName": "InHasPointTarget", "ParamName": "HAS_POINT_TARGET"},
    {"NodeType": "/Script/DZProject.STT_MoveToTarget", "InputPropertyName": "InTargetPoint",    "ParamName": "POINT_TARGET"},
    # Task: FaceTo
    {"NodeType": "/Script/DZProject.STT_FaceTo", "InputPropertyName": "InActorTarget", "ParamName": "ACTOR_TARGET"},
    # Task: SetCurTargetInBlackBoard
    {"NodeType": "/Script/DZProject.STT_SetCurTargetInBlackBoard", "InputPropertyName": "InActorTarget", "ParamName": "ACTOR_TARGET"},
    # Condition: CheckHasTarget
    {"NodeType": "/Script/DZProject.STC_Server_CheckHasTarget", "InputPropertyName": "InActorTarget",    "ParamName": "ACTOR_TARGET"},
    {"NodeType": "/Script/DZProject.STC_Server_CheckHasTarget", "InputPropertyName": "InHasPointTarget", "ParamName": "HAS_POINT_TARGET"},
    # Condition: CheckDistance
    {"NodeType": "/Script/DZProject.STC_Server_CheckDistance", "InputPropertyName": "InTargetActor", "ParamName": "ACTOR_TARGET"},
    # Condition: HasBattleTarget
    {"NodeType": "/Script/DZProject.STC_Server_HasBattleTarget", "InputPropertyName": "InAttackTarget", "ParamName": "ATTACK_TARGET"},
    {"NodeType": "/Script/DZProject.STC_Server_HasBattleTarget", "InputPropertyName": "InActorTarget",  "ParamName": "ACTOR_TARGET"},
    {"NodeType": "/Script/DZProject.STC_Server_HasBattleTarget", "InputPropertyName": "RefAttackTarget", "ParamName": "ATTACK_TARGET"},
    {"NodeType": "/Script/DZProject.STC_Server_HasBattleTarget", "InputPropertyName": "RefActorTarget",  "ParamName": "ACTOR_TARGET"},
]

# All StateTree assets under the AI behavior tree folder.
ASSET_DIR = "/Game/Blueprint/StateTree"


def build_rule_objects():
    out = []
    for r in RULES:
        node_type_path = r["NodeType"]
        # C++ node structs live at /Script/Module.StructName.
        # Blueprint node classes live at /Game/.../BP.BP_C.
        node_type = unreal.find_object(None, node_type_path)
        if node_type is None and node_type_path.endswith("_C"):
            node_type = unreal.load_class(None, node_type_path)
        if node_type is None:
            unreal.log_warning("[st_bind_task_inputs] failed to resolve NodeType: {}".format(node_type_path))
            continue

        rule = unreal.DZStateTreeInputBindingRule()
        rule.node_type = node_type
        rule.input_property_name = r["InputPropertyName"]
        rule.param_name = r["ParamName"]
        rule.overwrite_existing = True
        out.append(rule)
    return out


def list_state_tree_assets():
    ar = unreal.AssetRegistryHelpers.get_asset_registry()
    assets = ar.get_assets_by_path(unreal.Paths.normalize_directory_name(ASSET_DIR), recursive=True)
    paths = []
    for asset in assets:
        if asset.asset_class_path.asset_name == "StateTree":
            paths.append(str(asset.package_name))
    return sorted(paths)


def main():
    unreal.log("[st_bind_task_inputs] DRY={}".format(DRY))

    rules = build_rule_objects()
    if not rules:
        unreal.log_error("[st_bind_task_inputs] no valid rules; aborting.")
        return 1

    tree_paths = list_state_tree_assets()
    unreal.log("[st_bind_task_inputs] found {} StateTree asset(s) under {}".format(len(tree_paths), ASSET_DIR))

    total_changed = 0
    for path in tree_paths:
        try:
            tree = unreal.load_asset(path)
            if tree is None:
                unreal.log_warning("[st_bind_task_inputs] load failed: {}".format(path))
                continue

            changed = unreal.DZStateTreeEditTools.bind_task_inputs_from_tree_parameters(tree, rules)
            unreal.log("[st_bind_task_inputs] {} -> changed={}".format(path, changed))
            total_changed += changed

            if changed > 0 and not DRY:
                unreal.EditorAssetLibrary.save_loaded_asset(tree, only_if_is_dirty=False)
        except Exception as e:
            unreal.log_error("[st_bind_task_inputs] error on {}: {}".format(path, e))

    unreal.log("[st_bind_task_inputs] total_changed={} (DRY={})".format(total_changed, DRY))
    return 0 if DRY or total_changed >= 0 else 1


if __name__ == "__main__":
    sys.exit(main())
