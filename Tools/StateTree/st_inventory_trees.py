# -*- coding: utf-8 -*-
# Read-only inventory for every StateTree under a package path. The JSON dump
# preserves node instance text, state parameter bags, linked assets, transition
# settings, condition expressions, and binding IDs so a later rebuild can be
# diffed or replayed.
#
# Usage (editor MUST be closed; no assets are modified):
#   UnrealEditor-Cmd.exe DZProject.uproject -run=pythonscript
#     -script="<this file>" -stdout -unattended -nopause -nosplash -NullRHI -noscc

import json
import os
import sys
import unreal


ASSET_DIR = "/Game/Blueprint/StateTree"
OUTPUT = r"C:\UE\Projects\DZ_Project_New\.dsh\st_work\st_inventory_trees.json"


def text(value):
    if value is None:
        return ""
    try:
        return value.export_text()
    except Exception:
        return str(value)


def safe_property(obj, name):
    try:
        return obj.get_editor_property(name)
    except Exception:
        return None


def type_name(node):
    node_value = safe_property(node, "node")
    if node_value is None:
        return "<empty>"
    exported = text(node_value)
    if not exported or exported == "None":
        return "<empty>"
    return exported.split("(", 1)[0].split(".")[-1]


def node_dict(node):
    return {
        "id": str(safe_property(node, "id")),
        "type": type_name(node),
        "node_text": text(safe_property(node, "node")),
        "instance_text": text(safe_property(node, "instance")),
        "instance_object": str(safe_property(node, "instance_object")),
        "expression_indent": safe_property(node, "expression_indent"),
        "expression_operand": str(safe_property(node, "expression_operand")),
    }


def node_list(nodes):
    return [node_dict(node) for node in (nodes or [])]


def transition_dict(transition):
    required = safe_property(transition, "required_event")
    return {
        "id": str(safe_property(transition, "id")),
        "whole_text": text(transition),
        "trigger": str(safe_property(transition, "trigger")),
        "priority": str(safe_property(transition, "priority")),
        "target_text": text(safe_property(transition, "state")),
        "required_event_text": text(required),
        "delay_transition": bool(safe_property(transition, "bDelayTransition")),
        "delay_duration": safe_property(transition, "delay_duration"),
        "delay_random_variance": safe_property(transition, "delay_random_variance"),
        "enabled": bool(safe_property(transition, "bTransitionEnabled")),
        "reactivate_target_state": str(safe_property(transition, "reactivate_target_state")),
        "conditions": node_list(safe_property(transition, "conditions")),
    }


def state_dict(state):
    required = safe_property(state, "required_event_to_enter")
    parameters = safe_property(state, "parameters")
    return {
        "id": str(safe_property(state, "id")),
        "name": str(safe_property(state, "name")),
        "description": str(safe_property(state, "description")),
        "tag_text": text(safe_property(state, "tag")),
        "color_text": text(safe_property(state, "color_ref")),
        "type": str(safe_property(state, "type")),
        "selection_behavior": str(safe_property(state, "selection_behavior")),
        "tasks_completion": str(safe_property(state, "tasks_completion")),
        "linked_subtree_text": text(safe_property(state, "linked_subtree")),
        "linked_asset": str(safe_property(state, "linked_asset")),
        "custom_tick_rate": safe_property(state, "custom_tick_rate"),
        "has_custom_tick_rate": bool(safe_property(state, "bHasCustomTickRate")),
        "copy_parameter_bindings_on_tick": bool(safe_property(state, "bCopyParameterBindingsOnTick")),
        "parameters_text": text(parameters),
        "check_prerequisites_when_activating_child_directly": bool(
            safe_property(state, "bCheckPrerequisitesWhenActivatingChildDirectly")
        ),
        "has_required_event_to_enter": bool(safe_property(state, "bHasRequiredEventToEnter")),
        "required_event_to_enter_text": text(required),
        "weight": safe_property(state, "weight"),
        "enabled": bool(safe_property(state, "bEnabled")),
        "enter_conditions": node_list(safe_property(state, "enter_conditions")),
        "tasks": node_list(safe_property(state, "tasks")),
        "considerations": node_list(safe_property(state, "considerations")),
        "single_task": node_dict(safe_property(state, "single_task")) if safe_property(state, "single_task") else None,
        "transitions": [transition_dict(item) for item in (safe_property(state, "transitions") or [])],
        "children": [state_dict(item) for item in (safe_property(state, "children") or [])],
    }


def tree_dict(path):
    tree = unreal.EditorAssetLibrary.load_asset(path)
    if not isinstance(tree, unreal.StateTree):
        return None
    editor_data = None
    try:
        editor_data = unreal.StateTreeEditorData.get_editor_data(tree)
    except Exception as error:
        unreal.log_warning("[inventory] editor-data failed {}: {}".format(path, error))

    return {
        "package": path,
        "object_path": str(tree.get_path_name()),
        "root_parameter_bag_text": text(safe_property(editor_data, "root_parameter_property_bag")),
        "global_tasks_completion": str(safe_property(editor_data, "global_tasks_completion")),
        "evaluators": node_list(safe_property(editor_data, "evaluators")),
        "global_tasks": node_list(safe_property(editor_data, "global_tasks")),
        "subtrees": [state_dict(item) for item in (safe_property(editor_data, "sub_trees") or [])],
        "bindings": [
            {
                "source_id": str(item.get_editor_property("source_struct_id")),
                "source_path": str(item.get_editor_property("source_path")),
                "target_id": str(item.get_editor_property("target_struct_id")),
                "target_path": str(item.get_editor_property("target_path")),
            }
            for item in (unreal.DZStateTreeEditTools.get_property_bindings(tree, unreal.Guid()) or [])
        ],
    }


def list_trees():
    registry = unreal.AssetRegistryHelpers.get_asset_registry()
    assets = registry.get_assets_by_path(unreal.Paths.normalize_directory_name(ASSET_DIR), recursive=True)
    return sorted(str(asset.package_name) for asset in assets if asset.asset_class_path.asset_name == "StateTree")


def main():
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    paths = [path for path in list_trees() if "/Temp/" not in path]
    records = []
    for path in paths:
        unreal.log_warning("[inventory] {}".format(path))
        record = tree_dict(path)
        if record:
            records.append(record)
    with open(OUTPUT, "w", encoding="utf-8") as handle:
        json.dump(records, handle, ensure_ascii=False, indent=2)
    unreal.log_warning("[inventory] trees={} output={}".format(len(records), OUTPUT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
