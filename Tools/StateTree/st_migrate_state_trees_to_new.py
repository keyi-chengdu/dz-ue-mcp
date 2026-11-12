# -*- coding: utf-8 -*-
# Rebuild production StateTrees under Temp as *_New. Source trees are read-only;
# each target is created from zero and then receives an ID-preserving topology clone.
# C++ DZ nodes are upgraded to _New instances, linked assets and RunParallel references
# are redirected, and the common parameter face is rebuilt.
#
# Usage (editor MUST be closed):
#   UnrealEditor-Cmd.exe DZProject.uproject -run=pythonscript
#     -script="<this file>" -stdout -unattended -nopause -nosplash -NullRHI -noscc
#     [-Execute]

import re
import sys
import unreal


SOURCE_ROOT = "/Game/Blueprint/StateTree"
TARGET_ROOT = "/Game/Blueprint/StateTree/Temp"
SCHEMA_PATH = "/Script/DZProject.DZAIStateTreeSchema_New"
PARALLEL_VARIABLE_NAME = "ParallelAttackBehavior"
RUN_PARALLEL_TYPE_NAME = "StateTreeRunParallelStateTreeTask"

# Main trees keep value parameters; linked subtrees expose matching Ref pillars.
VALUE_PARAMS = {
    "ACTOR_TARGET": ("Object", "/Script/Engine.Actor"),
    "ATTACK_TARGET": ("Object", "/Script/Engine.Actor"),
    "LAST_SELFATTACKER": ("Object", "/Script/Engine.Actor"),
    "HAS_POINT_TARGET": ("Bool", ""),
    "POINT_TARGET": ("Struct", "/Script/CoreUObject.Vector"),
    "EnemyAttackData": ("Struct", "/Script/DZProject.AttackTaskData"),
    "EnemyPlayMontageTag": ("Struct", "/Script/GameplayTags.GameplayTag"),
}

REF_DEFAULTS = {
    "ACTOR_TARGET": ("Object", "/Script/Engine.Actor"),
    "ATTACK_TARGET": ("Object", "/Script/Engine.Actor"),
    "LAST_SELFATTACKER": ("Object", "/Script/Engine.Actor"),
    "HAS_POINT_TARGET": ("Bool", ""),
    "POINT_TARGET": ("Struct", "/Script/CoreUObject.Vector"),
    "EnemyAttackData": ("Struct", "/Script/DZProject.AttackTaskData"),
    "EnemyPlayMontageTag": ("Struct", "/Script/GameplayTags.GameplayTag"),
}

REF_BINDING_RULES = [
    ("/Script/DZProject.STT_AskForBattleTarget_New", "RefActorTarget", "ACTOR_TARGET"),
    ("/Script/DZProject.STT_AskForBattleTarget_New", "RefLastSelfAttacker", "LAST_SELFATTACKER"),
    ("/Script/DZProject.STT_TryAddToBattleSequence_New", "RefActorTarget", "ACTOR_TARGET"),
    ("/Script/DZProject.STT_TryAddToBattleSequence_New", "RefAttackTarget", "ATTACK_TARGET"),
    ("/Script/DZProject.STT_Attack_New", "RefActorTarget", "ACTOR_TARGET"),
    ("/Script/DZProject.STT_Attack_New", "RefAttackTarget", "ATTACK_TARGET"),
    ("/Script/DZProject.STT_Attack_New", "RefAttackTaskData", "EnemyAttackData"),
    ("/Script/DZProject.STT_FindTarget_New", "RefTargetActor", "ACTOR_TARGET"),
    ("/Script/DZProject.STT_FindTarget_New", "RefHasPointTarget", "HAS_POINT_TARGET"),
    ("/Script/DZProject.STT_FindTarget_New", "RefPointTarget", "POINT_TARGET"),
    ("/Script/DZProject.STT_MoveToTarget_New", "RefActorTarget", "ACTOR_TARGET"),
    ("/Script/DZProject.STT_MoveToTarget_New", "RefTargetPoint", "POINT_TARGET"),
    ("/Script/DZProject.STT_MoveToTarget_New", "RefHasPointTarget", "HAS_POINT_TARGET"),
    ("/Script/DZProject.STC_Server_HasBattleTarget_New", "RefActorTarget", "ACTOR_TARGET"),
    ("/Script/DZProject.STC_Server_HasBattleTarget_New", "RefAttackTarget", "ATTACK_TARGET"),
    ("/Script/DZProject.STC_Server_CheckHasTarget_New", "RefActorTarget", "ACTOR_TARGET"),
    ("/Script/DZProject.STC_Server_CheckDistance_New", "RefTargetActor", "ACTOR_TARGET"),
]

ORDER = [
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_Turn",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_HurtReaction",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_Jump",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_NavLinkJump",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_NoCombat",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SelectTarget",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SurroundPlayer_Melee",
    "/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SurroundPlayer_Ranged",
    "/Game/Blueprint/StateTree/05002101/ST_Sub_05002101_Battle",
    "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack",
    "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle",
    "/Game/Blueprint/StateTree/05002103/ST_Sub_05002103_Battle",
    "/Game/Blueprint/StateTree/05002104/ST_Sub_05002104_Battle",
    "/Game/Blueprint/StateTree/05002105/ST_Sub_05002105_Battle",
    "/Game/Blueprint/StateTree/05003101/ST_Sub_05003101_Battle",
    "/Game/Blueprint/StateTree/EnemyTest/ST_Enemy_Test",
    "/Game/Blueprint/StateTree/EnemyTest/ST_RangeEnemy_Test",
    "/Game/Blueprint/StateTree/05002101/ST_05002101",
    "/Game/Blueprint/StateTree/05002102/ST_05002102",
    "/Game/Blueprint/StateTree/05002103/ST_05002103",
    "/Game/Blueprint/StateTree/05002104/ST_05002104",
    "/Game/Blueprint/StateTree/05002105/ST_05002105",
    "/Game/Blueprint/StateTree/05003101/ST_05003101",
    "/Game/Blueprint/StateTree/05004101/ST_05004101",
]


def command_line():
    return unreal.SystemLibrary.get_command_line().lower()


DRY = "-execute" not in command_line()
TOOLS = unreal.DZStateTreeEditTools
TAG = "[st-to-new]"


def log(message):
    unreal.log_warning("{} {}".format(TAG, message))


def error(message):
    unreal.log_error("{} {}".format(TAG, message))


def source_relative(path):
    return path[len(SOURCE_ROOT):].strip("/")


def target_package(source):
    relative = source_relative(source)
    parts = relative.split("/")
    name = parts[-1] + "_New"
    return "/".join([TARGET_ROOT] + parts[:-1] + [name])


def package_parts(package):
    object_name = package.rsplit("/", 1)[-1]
    directory = package.rsplit("/", 1)[0]
    return directory, object_name


def object_path(package):
    directory, name = package_parts(package)
    return package + "." + name


def old_linked_package(value):
    match = re.search(r"/Game/Blueprint/StateTree/[^' ]+", str(value))
    if not match:
        return None
    package = match.group(0).rsplit(".", 1)[0]
    if package == SOURCE_ROOT or package.startswith(TARGET_ROOT):
        return None
    return package


def iter_states(state):
    yield state
    for child in state.get_editor_property("children") or []:
        for nested in iter_states(child):
            yield nested


def node_type_name(node):
    node_value = node.get_editor_property("node")
    exported = node_value.export_text()
    if not exported or exported == "None":
        return "<empty>"
    return exported.split("(", 1)[0].split(".")[-1]


def package_from_object(value):
    match = re.search(r"/Game/Blueprint/StateTree/[^' ]+", str(value))
    return match.group(0).rsplit(".", 1)[0] if match else None


def normalized_node_type(type_name):
    return type_name[:-4] if type_name.endswith("_New") else type_name


def normalized_struct_text(value):
    text = str(value)
    text = re.sub(r"(_New)(?=[\.\(\s,=]|$)", "", text)
    return text


def required_event_signature(event):
    text = event.export_text() if event else ""
    match = re.search(r'Tag=\(TagName="([^"]*)"\)', text)
    tag = match.group(1) if match else ""
    payload = text.split("PayloadStruct=", 1)[1] if "PayloadStruct=" in text else "None"
    payload = payload.split(",", 1)[0].split(")", 1)[0]
    return "{}|{}".format(tag, normalized_struct_text(payload))


def node_type_signature(nodes):
    return [
        {
            "type": normalized_node_type(node_type_name(node)),
            "operand": str(node.get_editor_property("expression_operand")),
            "indent": node.get_editor_property("expression_indent"),
        }
        for node in (nodes or [])
    ]


def register_state_ids(source_state, target_state, id_map):
    if not source_state or not target_state:
        return
    id_map[str(source_state.get_editor_property("id"))] = target_state.get_editor_property("id")
    source_children = source_state.get_editor_property("children") or []
    target_children = target_state.get_editor_property("children") or []
    for source_child, target_child in zip(source_children, target_children):
        register_state_ids(source_child, target_child, id_map)


def state_signature(source_state, target_state, id_map, source_package, tree_target_package):
    source_linked = source_state.get_editor_property("linked_asset")
    target_linked = target_state.get_editor_property("linked_asset")
    expected_linked = None
    if source_linked:
        linked_source_package = package_from_object(source_linked)
        expected_linked = target_package(linked_source_package) if linked_source_package else None
    actual_linked = package_from_object(target_linked) if target_linked else None

    failures = []
    if expected_linked != actual_linked:
        failures.append("linked asset {} != {}".format(expected_linked, actual_linked))
    for prop in ("name", "type", "selection_behavior", "tasks_completion"):
        if str(source_state.get_editor_property(prop)) != str(target_state.get_editor_property(prop)):
            failures.append("{}: {} != {}".format(
                prop,
                source_state.get_editor_property(prop),
                target_state.get_editor_property(prop)))
    if bool(source_state.get_editor_property("bEnabled")) != bool(target_state.get_editor_property("bEnabled")):
        failures.append("enabled mismatch")
    if required_event_signature(source_state.get_editor_property("required_event_to_enter")) != required_event_signature(
            target_state.get_editor_property("required_event_to_enter")):
        failures.append("required event mismatch")

    for collection in ("enter_conditions", "tasks", "considerations"):
        source_nodes = node_type_signature(source_state.get_editor_property(collection))
        target_nodes = node_type_signature(target_state.get_editor_property(collection))
        if source_nodes != target_nodes:
            failures.append("{} nodes: {} != {}".format(collection, source_nodes, target_nodes))

    source_transitions = source_state.get_editor_property("transitions") or []
    target_transitions = target_state.get_editor_property("transitions") or []
    if len(source_transitions) != len(target_transitions):
        failures.append("transition count {} != {}".format(len(source_transitions), len(target_transitions)))
    else:
        for index, (source_transition, target_transition) in enumerate(zip(source_transitions, target_transitions)):
            transition_failures = []
            for prop in ("trigger", "priority", "bDelayTransition", "delay_duration", "delay_random_variance", "bTransitionEnabled"):
                if str(source_transition.get_editor_property(prop)) != str(target_transition.get_editor_property(prop)):
                    transition_failures.append("{} {} != {}".format(
                        prop,
                        source_transition.get_editor_property(prop),
                        target_transition.get_editor_property(prop)))
            source_target_id = str(source_transition.get_editor_property("state").export_text().split("ID=", 1)[1].split(",", 1)[0])
            expected_target_id = id_map.get(source_target_id)
            actual_target_id = target_transition.get_editor_property("state").export_text().split("ID=", 1)[1].split(",", 1)[0]
            if expected_target_id and str(expected_target_id) != actual_target_id:
                transition_failures.append("target {} != {}".format(expected_target_id, actual_target_id))
            if required_event_signature(source_transition.get_editor_property("required_event")) != required_event_signature(
                    target_transition.get_editor_property("required_event")):
                transition_failures.append("event")
            source_conditions = node_type_signature(source_transition.get_editor_property("conditions"))
            target_conditions = node_type_signature(target_transition.get_editor_property("conditions"))
            if source_conditions != target_conditions:
                transition_failures.append("conditions")
            if transition_failures:
                failures.append("transition[{}]: {}".format(index, "; ".join(transition_failures)))

    source_children = source_state.get_editor_property("children") or []
    target_children = target_state.get_editor_property("children") or []
    if len(source_children) != len(target_children):
        failures.append("child count {} != {}".format(len(source_children), len(target_children)))
    else:
        for index, (source_child, target_child) in enumerate(zip(source_children, target_children)):
            child_failures = state_signature(source_child, target_child, id_map, source_package, tree_target_package)
            for child_failure in child_failures:
                failures.append("child[{}] {}".format(index, child_failure))
    return failures


def global_node_signature(source_data, target_data, skip_damaged_evaluator=False):
    failures = []
    for collection in ("evaluators", "global_tasks"):
        source_nodes_collection = source_data.get_editor_property(collection)
        if skip_damaged_evaluator and collection == "evaluators":
            source_nodes_collection = [
                node for node in source_nodes_collection or []
                if node_type_name(node) != "StateTreeBlueprintEvaluatorWrapper"
            ]
        source_nodes = node_type_signature(source_nodes_collection)
        target_nodes = node_type_signature(target_data.get_editor_property(collection))
        if source_nodes != target_nodes:
            failures.append("{}: {} != {}".format(collection, source_nodes, target_nodes))
    if str(source_data.get_editor_property("global_tasks_completion")) != str(
            target_data.get_editor_property("global_tasks_completion")):
        failures.append("global task completion")
    return failures


def iter_nodes(editor_data):
    for group_name in ("evaluators", "global_tasks"):
        for node in editor_data.get_editor_property(group_name) or []:
            yield node
    for root in editor_data.get_editor_property("sub_trees") or []:
        for state in iter_states(root):
            for collection in ("enter_conditions", "tasks", "considerations"):
                for node in state.get_editor_property(collection) or []:
                    yield node
            for transition in state.get_editor_property("transitions") or []:
                for node in transition.get_editor_property("conditions") or []:
                    yield node


def resolve_node_type(path):
    if path.endswith("_C"):
        return unreal.load_class(None, path)
    return unreal.find_object(None, path)


def build_ref_rules():
    rules = []
    for node_path, field, param in REF_BINDING_RULES:
        node_type = resolve_node_type(node_path)
        if node_type is None:
            error("missing binding node type: " + node_path)
            continue
        rule = unreal.DZStateTreeInputBindingRule()
        rule.node_type = node_type
        rule.input_property_name = field
        rule.param_name = param
        rule.overwrite_existing = True
        rules.append(rule)
    return rules


def parameter_matches(parameter, value_type, type_path):
    return (
        str(parameter.value_type) == value_type
        and str(parameter.type_object_path) == type_path
    )


def is_ref_parameter(parameter):
    return parameter.type_object_path == "/Script/StateTreeModule.StateTreeBlueprintPropertyRef"


def prepare_main_parameters(tree):
    existing = {str(item.name): item for item in TOOLS.get_tree_parameters(tree)}
    for name, (value_type, type_path) in VALUE_PARAMS.items():
        parameter = existing.get(name)
        if parameter and parameter_matches(parameter, value_type, type_path):
            continue
        if parameter:
            TOOLS.remove_tree_parameter(tree, name)
        TOOLS.add_tree_parameter(tree, name, value_type, type_path)
    TOOLS.remove_tree_parameter(tree, PARALLEL_VARIABLE_NAME)


def prepare_subtree_parameters(tree):
    existing = {str(item.name): item for item in TOOLS.get_tree_parameters(tree)}
    for name, (ref_type, type_path) in REF_DEFAULTS.items():
        parameter = existing.get(name)
        if parameter and is_ref_parameter(parameter):
            continue
        if parameter:
            TOOLS.remove_tree_parameter(tree, name)
        TOOLS.add_tree_parameter(tree, name, "Struct", "/Script/StateTreeModule.StateTreeBlueprintPropertyRef")
        TOOLS.set_tree_parameter_ref_default(tree, name, ref_type, type_path)


def clear_standard_parameter_targets(tree):
    root_id = TOOLS.get_root_parameters_id(tree)
    removed = 0
    for name in VALUE_PARAMS:
        try:
            if TOOLS.has_property_binding(tree, root_id, name):
                TOOLS.remove_property_binding(tree, root_id, name)
                removed += 1
        except Exception:
            pass
    return removed


def clear_stale_new_task_bindings(tree):
    names = [
        "EnemyPlayMontageTag", "EnemyAttackData", "OutMontageTag",
        "OutActorTarget", "OutAttackTarget", "OutHasPointTarget", "OutPointTarget",
    ]
    return TOOLS.remove_bindings_by_leaf_names(tree, names)


def preserve_schema_ai_controller(tree, source_asset):
    source_data = unreal.StateTreeEditorData.get_editor_data(source_asset)
    source_schema = source_data.get_editor_property("schema") if source_data else None
    ai_controller = None
    try:
        ai_controller = source_schema.get_editor_property("AIControllerClass") if source_schema else None
    except Exception:
        ai_controller = None
    if ai_controller:
        TOOLS.set_schema_ai_controller_class(tree, ai_controller)


def redirect_linked_assets(tree, package_map, target_objects):
    changed = 0
    source_by_target = {target_package(source): source for source in package_map}
    editor_data = unreal.StateTreeEditorData.get_editor_data(tree)
    for root in editor_data.get_editor_property("sub_trees") or []:
        for state in iter_states(root):
            linked = state.get_editor_property("linked_asset")
            if not linked:
                continue
            linked_package = None
            match = re.search(r"/Game/Blueprint/StateTree/[^' ]+", str(linked))
            if match:
                linked_package = match.group(0).rsplit(".", 1)[0]
            if linked_package and linked_package.startswith(TARGET_ROOT):
                clean_package = linked_package[:-len("_Failed")] if linked_package.endswith("_Failed") else linked_package
                linked_package = source_by_target.get(linked_package, linked_package)
                if linked_package.startswith(TARGET_ROOT):
                    linked_package = source_by_target.get(clean_package, clean_package)
            if not linked_package or linked_package == SOURCE_ROOT:
                continue
            target_package_name = package_map.get(linked_package)
            if not target_package_name:
                error("no target mapping for linked asset: " + linked_package)
                continue
            target = target_objects.get(linked_package)
            if target is None:
                target = unreal.load_asset(target_package_name)
            if not target:
                error("cannot load linked target: " + target_package_name)
                continue
            TOOLS.set_state_link(state, None, target)
            changed += 1
    return changed


def fix_range_enemy(tree):
    editor_data = unreal.StateTreeEditorData.get_editor_data(tree)
    removed = 0
    for node in editor_data.get_editor_property("evaluators") or []:
        if node_type_name(node) == "StateTreeBlueprintEvaluatorWrapper":
            try:
                node_id = node.get_editor_property("id")
                TOOLS.remove_node(tree, node_id)
                removed += 1
            except Exception as remove_error:
                error("cannot remove damaged evaluator: {}".format(remove_error))
    return removed


def bind_doonce_parameters(tree):
    editor_data = unreal.StateTreeEditorData.get_editor_data(tree)
    root_id = TOOLS.get_root_parameters_id(tree)
    bound = 0
    used_names = set()
    for root in editor_data.get_editor_property("sub_trees") or []:
        for state in iter_states(root):
            index = 0
            for node in state.get_editor_property("enter_conditions") or []:
                if node_type_name(node) != "STC_Server_DoOnce_New":
                    continue
                index += 1
                state_name = str(state.get_editor_property("name"))
                suffix = str(node.get_editor_property("id")).replace("-", "")[-6:]
                param_name = "Done_{}_{}_{}".format(state_name, index, suffix)
                clean = re.sub(r"[^A-Za-z0-9_]", "_", param_name)
                while clean in used_names:
                    clean += "_D"
                used_names.add(clean)
                TOOLS.add_tree_parameter(tree, clean, "Bool", "")
                node_type = resolve_node_type("/Script/DZProject.STC_Server_DoOnce_New")
                if not node_type:
                    error("missing DoOnce_New binding node type")
                    continue
                for field in ("InDone", "RefDoneParam"):
                    rule = unreal.DZStateTreeInputBindingRule()
                    rule.node_type = node_type
                    rule.input_property_name = field
                    rule.param_name = clean
                    rule.overwrite_existing = True
                    try:
                        bound += TOOLS.bind_task_inputs_from_tree_parameters(tree, [rule])
                    except Exception as bind_error:
                        error("DoOnce bind failed {} {}: {}".format(clean, field, bind_error))
    return bound


def run_parallel_nodes(tree):
    editor_data = unreal.StateTreeEditorData.get_editor_data(tree)
    for root in editor_data.get_editor_property("sub_trees") or []:
        for state in iter_states(root):
            for node in state.get_editor_property("tasks") or []:
                if node_type_name(node) == RUN_PARALLEL_TYPE_NAME:
                    yield state, node


def direct_specify_parallel_tree(tree, target_package):
    changed = 0
    bound = 0
    direct_target = object_path(target_package)
    root_id = TOOLS.get_root_parameters_id(tree)

    for state, node in run_parallel_nodes(tree):
        node_id = node.get_editor_property("id")
        TOOLS.set_node_properties(
            tree,
            node_id,
            {"StateTree": "(StateTree={})".format(direct_target)},
        )
        TOOLS.upgrade_parallel_tree_references(tree, [direct_target], [direct_target])
        changed += 1

        for field in VALUE_PARAMS:
            binding = unreal.DZStateTreePropertyBinding()
            binding.set_editor_property("source_struct_id", root_id)
            binding.set_editor_property("source_path", field)
            binding.set_editor_property("target_struct_id", node_id)
            binding.set_editor_property("target_path", "StateTree.Parameters.Value." + field)
            TOOLS.add_property_binding(tree, binding)
            bound += 1

    return changed, bound


def normalized_binding_name(value):
    return re.sub(r"[^A-Za-z0-9]", "", str(value)).lower()


def compile_and_save(tree, source):
    result = TOOLS.compile_state_tree(tree)
    success = bool(result.get_editor_property("bSucceeded"))
    messages = []
    for message in result.get_editor_property("messages"):
        severity = str(message.get_editor_property("severity"))
        text = str(message.get_editor_property("message"))
        if severity != "Info":
            messages.append("[{}] {}".format(severity, text))
    if DRY:
        log("COMPILE-DRY {} success={} messages={}".format(source, success, " | ".join(messages) or "none"))
        return success
    saved = unreal.EditorAssetLibrary.save_loaded_asset(tree, only_if_is_dirty=False)
    log("COMPILE-SAVE {} success={} saved={} messages={}".format(
        source, success, saved, " | ".join(messages) or "none"))
    return success and bool(saved)


def list_only():
    for source in ORDER:
        target = target_package(source)
        exists = unreal.EditorAssetLibrary.does_asset_exist(target)
        log("MAP {} -> {} exists={}".format(source, target, exists))
    return 0


def verify_new():
    failures = []
    for source in ORDER:
        target = target_package(source)
        tree = unreal.EditorAssetLibrary.load_asset(target)
        if not tree:
            failures.append((source, "load failed"))
            continue
        result = TOOLS.compile_state_tree(tree)
        if not bool(result.get_editor_property("bSucceeded")):
            messages = [
                "[{}] {}".format(str(message.get_editor_property("severity")), str(message.get_editor_property("message")))
                for message in result.get_editor_property("messages")
                if str(message.get_editor_property("severity")) != "Info"
            ]
            failures.append((source, " | ".join(messages)))
        else:
            log("VERIFY-OK " + target)

    failed_asset = "/Game/Blueprint/StateTree/Temp/05003101/ST_Sub_05003101_Battle_New_Failed"
    if not failures and unreal.EditorAssetLibrary.does_asset_exist(failed_asset):
        if unreal.EditorAssetLibrary.delete_asset(failed_asset):
            log("CLEANED failed temporary asset")
        else:
            error("could not clean failed temporary asset")

    log("VERIFY-SUMMARY total={} failures={}".format(len(ORDER), len(failures)))
    for source, message in failures:
        error("VERIFY-FAILED {}: {}".format(source, message))
    return 1 if failures else 0


def audit_new():
    legacy_types = {
        "STT_AskForBattleTarget", "STT_Attack", "STT_CaptureEventActor", "STT_FaceTo",
        "STT_FindTarget", "STT_ModifyStateTags", "STT_MoveToTarget", "STT_PlayMontage",
        "STT_RayCheck", "STT_RandomAndSetVal", "STT_SetCurTargetInBlackBoard",
        "STT_SetTreeParam", "STT_TryAddToBattleSequence", "STT_SendParallelEvent",
        "STT_ApplyParallelEvent", "STC_Server_CheckDistance", "STC_Server_CheckHasTarget",
        "STC_Server_DoOnce", "STC_Server_EnemyHasEnterBattle", "STC_Server_HasAnyTag",
        "STC_Server_HasBattleTarget", "STC_Server_IsMaxUnAttackTime",
    }
    common_value_names = set(VALUE_PARAMS)
    total_states = 0
    total_ec = 0
    total_tasks = 0
    failures = []
    for source in ORDER:
        target = target_package(source)
        source_asset = unreal.EditorAssetLibrary.load_asset(source)
        target_asset = unreal.EditorAssetLibrary.load_asset(target)
        if not source_asset or not target_asset:
            failures.append("{}: load failed".format(source))
            continue
        source_data = unreal.StateTreeEditorData.get_editor_data(source_asset)
        target_data = unreal.StateTreeEditorData.get_editor_data(target_asset)
        schema_name = target_data.get_editor_property("schema").get_class().get_name()
        if schema_name != "DZAIStateTreeSchema_New":
            failures.append("{}: schema {}".format(source, schema_name))

        source_roots = source_data.get_editor_property("sub_trees") or []
        target_roots = target_data.get_editor_property("sub_trees") or []
        if len(source_roots) != len(target_roots):
            failures.append("{}: subtree count".format(source))
            continue
        id_map = {}
        for source_root, target_root in zip(source_roots, target_roots):
            register_state_ids(source_root, target_root, id_map)

        tree_failures = global_node_signature(source_data, target_data, source.endswith("ST_RangeEnemy_Test"))
        target_nodes = list(iter_nodes(target_data))
        for source_root, target_root in zip(source_roots, target_roots):
            tree_failures.extend(state_signature(source_root, target_root, id_map, source, target))
            for state in iter_states(target_root):
                total_states += 1
                total_ec += len(state.get_editor_property("enter_conditions") or [])
                total_tasks += len(state.get_editor_property("tasks") or [])

        target_types = [node_type_name(node) for node in target_nodes]
        found_legacy = sorted(set(target_types).intersection(legacy_types))
        if found_legacy:
            tree_failures.append("legacy nodes {}".format(found_legacy))

        is_main = source.rsplit("/", 1)[-1].startswith("ST_050") or source.rsplit("/", 1)[-1] in {"ST_Enemy_Test", "ST_RangeEnemy_Test"}
        parameters = TOOLS.get_tree_parameters(target_asset)
        parameter_names = {str(item.name) for item in parameters}
        parallel_variable_present = PARALLEL_VARIABLE_NAME in parameter_names
        run_parallel_count = 0
        direct_count = 0
        initialized_bindings = set()

        for state, node in run_parallel_nodes(tree):
            run_parallel_count += 1
            node_id = str(node.get_editor_property("id"))
            instance_text = str(node.get_editor_property("instance").export_text())
            direct_target = object_path(target)
            if direct_target not in instance_text:
                tree_failures.append("parallel target not direct")
            elif "Parameters=(Value=None)" not in instance_text:
                direct_count += 1

            for binding in TOOLS.get_property_bindings(tree, unreal.Guid()) or []:
                target_path = str(binding.get_editor_property("target_path"))
                compact_path = target_path.replace(" ", "")
                if compact_path.startswith("StateTree.Parameters.Value."):
                    leaf = compact_path.rsplit(".", 1)[-1]
                    for field in VALUE_PARAMS:
                        if normalized_binding_name(leaf) == normalized_binding_name(field):
                            initialized_bindings.add(field)

        missing_initialization = sorted(set(VALUE_PARAMS) - initialized_bindings)
        if missing_initialization:
            tree_failures.append("missing parallel init {}".format(missing_initialization))
        if run_parallel_count and direct_count != run_parallel_count:
            tree_failures.append("parallel init bag not synced")
        if parallel_variable_present:
            tree_failures.append("legacy parallel variable {}".format(PARALLEL_VARIABLE_NAME))

        if is_main:
            missing_parameters = sorted(common_value_names - parameter_names)
            if missing_parameters:
                tree_failures.append("missing root values {}".format(missing_parameters))
        else:
            for item in parameters:
                if str(item.name) in common_value_names and item.type_object_path != "/Script/StateTreeModule.StateTreeBlueprintPropertyRef":
                    tree_failures.append("non-ref pillar {}".format(item.name))

        if tree_failures:
            failures.append("{}: {}".format(source, " | ".join(tree_failures)))
        else:
            log("AUDIT-OK {}".format(target))

    log("AUDIT-SUMMARY trees={} states={} ec={} tasks={} failures={}".format(
        len(ORDER), total_states, total_ec, total_tasks, len(failures)))
    for failure in failures:
        error("AUDIT-FAILED {}".format(failure))
    return 1 if failures else 0


def upgrade_new_targets():
    changed = 0
    failures = []
    for source in ORDER:
        target = target_package(source)
        tree = unreal.EditorAssetLibrary.load_asset(target)
        if not tree:
            failures.append(source)
            continue
        report = TOOLS.upgrade_dz_nodes_to_new(tree)
        tasks = 0
        conditions = 0
        for part in str(report).split(" ")[0:2]:
            try:
                value = int(part.split("=")[1])
                if "tasks" in part:
                    tasks = value
                elif "conditions" in part:
                    conditions = value
            except Exception:
                pass
        if tasks == 0 and conditions == 0:
            log("UPGRADE-OK no change " + target)
            continue
        result = TOOLS.compile_state_tree(tree)
        success = bool(result.get_editor_property("bSucceeded"))
        saved = unreal.EditorAssetLibrary.save_loaded_asset(tree, only_if_is_dirty=False)
        changed += int(success and saved)
        log("UPGRADE-SAVE {} report={} success={} saved={}".format(target, report.replace("\n", " | "), success, saved))
        if not (success and saved):
            failures.append(source)
    log("UPGRADE-SUMMARY changed={} failures={}".format(changed, len(failures)))
    return 1 if failures else 0


def execute():
    schema = unreal.find_object(None, SCHEMA_PATH)
    if not schema:
        schema = unreal.load_class(None, SCHEMA_PATH)
    if not schema:
        error("missing schema " + SCHEMA_PATH)
        return 2

    package_map = {source: target_package(source) for source in ORDER}
    parallel_old = "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack"
    parallel_new = package_map[parallel_old]
    parallel_source = object_path(parallel_old)
    parallel_target = object_path(parallel_new)
    parallel_sources = [parallel_source]
    parallel_targets = [parallel_target]
    ref_rules = build_ref_rules()
    standard_fields = list(VALUE_PARAMS.keys())
    target_objects = {}

    created = 0
    cloned = 0
    upgraded_reports = []
    failures = []

    for source in ORDER:
        target = package_map[source]
        directory, asset_name = package_parts(target)
        source_name = source.rsplit("/", 1)[-1]
        is_main = source_name.startswith("ST_050") or source_name in {"ST_Enemy_Test", "ST_RangeEnemy_Test"}
        feed_fields = list(VALUE_PARAMS.keys())
        if source_name == "ST_RangeEnemy_Test":
            feed_fields.extend(["SmallTurnLength", "BigTurnLength"])
        source_asset = unreal.EditorAssetLibrary.load_asset(source)
        if not source_asset:
            error("cannot load source: " + source)
            failures.append(source)
            continue
        if unreal.EditorAssetLibrary.does_asset_exist(target):
            tree = unreal.EditorAssetLibrary.load_asset(target)
            result = TOOLS.compile_state_tree(tree)
            if bool(result.get_editor_property("bSucceeded")) and not source.endswith(
                    "ST_Sub_05002102_Battle"):
                log("SKIP already-green target: " + target)
                target_objects[source] = tree
                continue
            log("REPAIR failed target: " + target)
        else:
            if not (unreal.EditorAssetLibrary.does_directory_exist(directory) or unreal.EditorAssetLibrary.make_directory(directory)):
                error("cannot prepare directory: " + directory)
                failures.append(source)
                continue
            tree = TOOLS.create_state_tree(directory, asset_name, schema)
            if not tree:
                error("cannot create target: " + target)
                failures.append(source)
                continue
            created += 1
            if not TOOLS.clone_editor_data_from_tree(tree, source_asset):
                error("cannot clone editor data: " + source)
                failures.append(source)
                continue
            cloned += 1
        target_objects[source] = tree

        TOOLS.set_tree_schema(tree, schema)

        if source.endswith("ST_RangeEnemy_Test"):
            removed = fix_range_enemy(tree)
            log("{} removed damaged evaluators={}".format(source, removed))

        report = TOOLS.upgrade_dz_nodes_to_new(tree)
        upgraded_reports.append("{}: {}".format(source, report))

        if is_main:
            prepare_main_parameters(tree)
            if source_name == "ST_RangeEnemy_Test":
                TOOLS.add_tree_parameter(tree, "SmallTurnLength", "Float", "")
                TOOLS.add_tree_parameter(tree, "BigTurnLength", "Float", "")
                TOOLS.set_tree_parameter_value_default(tree, "SmallTurnLength", "0.3")
                TOOLS.set_tree_parameter_value_default(tree, "BigTurnLength", "0.5")
        else:
            prepare_subtree_parameters(tree)
        clear_standard_parameter_targets(tree)
        clear_stale_new_task_bindings(tree)
        preserve_schema_ai_controller(tree, source_asset)

        linked = redirect_linked_assets(tree, package_map, target_objects)
        parallel_refs = TOOLS.upgrade_parallel_tree_references(tree, parallel_sources, parallel_targets)

        # Object feeds through Ref pillars are safe. Overridden state memory is required.
        if linked > 0 or is_main:
            overridden = TOOLS.override_linked_state_parameters(tree, standard_fields)
            fed = TOOLS.bind_linked_state_parameters_from_tree(tree, feed_fields)
        else:
            overridden = 0
            fed = 0

        ref_bindings = TOOLS.bind_task_inputs_from_tree_parameters(tree, ref_rules) if ref_rules else 0
        doonce_bindings = bind_doonce_parameters(tree)

        direct_parallel_count = 0
        parallel_init_count = 0
        if source.endswith("ST_Sub_05002102_Battle"):
            direct_parallel_count, parallel_init_count = direct_specify_parallel_tree(tree, parallel_new)

        success = compile_and_save(tree, source)
        log("TREE {} linked={} parallelRefs={} overrides={} feeds={} refBinds={} doOnceBinds={} directParallel={} parallelInit={}".format(
            source, linked, parallel_refs, overridden, fed, ref_bindings, doonce_bindings,
            direct_parallel_count, parallel_init_count))
        if not success:
            failures.append(source)

    log("SUMMARY created={} cloned={} failures={}".format(created, cloned, len(failures)))
    for report in upgraded_reports:
        log("UPGRADE " + report.replace("\n", " | "))
    for failure in failures:
        error("FAILED " + failure)
    return 1 if failures else 0


def main():
    if "-audit-new" in command_line():
        return audit_new()
    if "-verify-new" in command_line():
        return verify_new()
    if "-upgrade" in command_line():
        return upgrade_new_targets()
    if "-list-only" in command_line():
        return list_only()
    if DRY:
        log("DRY mode: use -Execute to create and save targets")
        return list_only()
    return execute()


if __name__ == "__main__":
    sys.exit(main())
