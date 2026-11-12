# st_fix_05002102_parallel_actor_ref.py
# Purpose: Convert ParallelAttack ACTOR_TARGET to StateTreeBlueprintPropertyRef and
#          bind Battle RunParallel.StateTree.Parameters.Value.ACTOR_TARGET to it.
#
# Usage (editor MUST be closed):
#   UnrealEditor-Cmd.exe DZProject.uproject -run=pythonscript
#     -script="<this file>" [-Execute] -stdout -unattended -nopause -nosplash
#     -NullRHI -noscc
#
# Pitfalls:
#   1. A stale Battle package contains the old RunParallel nested parameter bag.
#      Execute therefore saves Parallel, unloads it, and loads Battle fresh.
#   2. Ref defaults must use SetTreeParameterRefDefault (ImportText_Direct).
#   3. GetPropertyBindings can return display-name paths. Rebuild with real FNames.
#   4. C++ helpers do not mark assets dirty, so save with only_if_is_dirty=False.

import gc
import os
import sys
import unreal


PARALLEL = "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack"
BATTLE = "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle"
RUN_PARALLEL_TYPE_PATH = "/Script/StateTreeModule.StateTreeRunParallelStateTreeTask"
PARAM_NAME = "ACTOR_TARGET"
REF_STRUCT_PATH = "/Script/StateTreeModule.StateTreeBlueprintPropertyRef"
OBJECT_PATH = "/Script/Engine.Actor"
PARENT_TARGET_PATH = "StateTree.Parameters.Value.ACTOR_TARGET"
CONTENT_ROOT = "C:/UE/Projects/DZ_Project_New/DZ_Content/Content"
TAG = "[st-fix-pa-ref]"
RAYCHECK_TASK_PATH = "/Script/DZProject.STT_RayCheck"
BLUEPRINT_RAYCHECK_TOKEN = "/Game/Blueprint/StateTree/Common/Task/STT_LineTrace.STT_LineTrace_C"

TARGET_ID_MAP = {
    "180ea13a4acff494aa82ffbba4154d2e": {
        "old": "InTargetActor",
        "new": "RefTargetActor",
    },
    "9f30a51544f66a43aa1bdea4890175fe": {
        "old": "InActorTarget",
        "new": "RefActorTarget",
    },
}

CLEANUP_RULES = [
    {
        "NodeType": "/Script/DZProject.STT_Attack",
        "InputPropertyName": "InActorTarget",
        "ParamName": PARAM_NAME,
    },
]


_CMD_LINE = (unreal.SystemLibrary.get_command_line()
             if hasattr(unreal, "SystemLibrary") else " ".join(sys.argv)).lower()
EXECUTE = "-execute" in _CMD_LINE


def log(text):
    unreal.log_warning("{} {}".format(TAG, text))


def log_error(text):
    unreal.log_error("{} {}".format(TAG, text))


def ascii_text(value):
    return str(value).encode("unicode_escape").decode("ascii")


def normalized(value):
    return str(value).replace(" ", "").replace("_", "").replace("-", "").lower()


def guid_is_valid(value):
    return normalized(value.to_string()) != "00000000000000000000000000000000"


def asset_disk_path(game_path):
    relative = game_path[len("/Game/"):]
    return os.path.join(CONTENT_ROOT, relative + ".uasset")


def file_stat(game_path):
    path = asset_disk_path(game_path)
    try:
        info = os.stat(path)
        return {"mtime": info.st_mtime, "size": info.st_size}
    except OSError as error:
        log_error("STAT failed {}: {}".format(path, error))
        return None


def load_tree(path, label):
    tree = unreal.EditorAssetLibrary.load_asset(path)
    if not isinstance(tree, unreal.StateTree):
        log_error("LOAD failed {} {}".format(label, path))
        return None
    log("LOADED {} {}".format(label, path))
    return tree


def dump_parameters(tree, label):
    params = unreal.DZStateTreeEditTools.get_tree_parameters(tree)
    log("PARAMS {} count={}".format(label, len(params)))
    found = None
    for param in params:
        name = str(param.get_editor_property("name"))
        value_type = str(param.get_editor_property("value_type"))
        type_path = str(param.get_editor_property("type_object_path"))
        log("  PARAM name={} type={} path={}".format(name, value_type, type_path))
        if name == PARAM_NAME:
            found = (value_type, type_path)
    return found


def walk_states(tree, visitor, state=None):
    if state is None:
        editor_data = unreal.StateTreeEditorData.get_editor_data(tree)
        states = editor_data.get_editor_property("sub_trees")
    else:
        states = state.get_editor_property("children")

    for state in states:
        visitor(state)
        walk_states(tree, visitor, state)


def find_task_by_id(tree, task_id):
    wanted = normalized(task_id.to_string())

    def search_state(state):
        for task in state.get_editor_property("tasks") or []:
            if normalized(task.get_editor_property("id").to_string()) == wanted:
                return state, task
        return None, None

    def search_tree(state):
        found_state, found_task = search_state(state)
        if found_task is not None:
            search_tree.result = (found_state, found_task)
            return
        for child in state.get_editor_property("children") or []:
            search_tree(child)

    search_tree.result = (None, None)
    editor_data = unreal.StateTreeEditorData.get_editor_data(tree)
    for state in editor_data.get_editor_property("sub_trees") or []:
        search_tree(state)
        if search_tree.result[1] is not None:
            break
    return search_tree.result


def find_run_parallel_nodes(tree):
    nodes = []

    def visit(state):
        for task in state.get_editor_property("tasks") or []:
            node_text = task.get_editor_property("node").export_text()
            if RUN_PARALLEL_TYPE_PATH in node_text:
                nodes.append(task)

    walk_states(tree, visit)
    return nodes


def read_bindings(tree):
    return unreal.DZStateTreeEditTools.get_property_bindings(tree, unreal.Guid())


def capture_param_bindings(bindings, root_id):
    captured = []
    root_text = root_id.to_string()
    for binding in bindings:
        source_id = binding.get_editor_property("source_struct_id")
        source_path = binding.get_editor_property("source_path")
        if source_id.to_string() == root_text and normalized(source_path).startswith(
                normalized(PARAM_NAME)):
            captured.append((binding.get_editor_property("target_struct_id"),
                             binding.get_editor_property("target_path")))
    return captured


def binding_exists(tree, source_id, target_id, target_path):
    source_text = normalized(source_id.to_string())
    target_text = normalized(target_id.to_string())
    for binding in read_bindings(tree):
        if (normalized(binding.get_editor_property("source_struct_id").to_string()) ==
                source_text and
                normalized(binding.get_editor_property("target_struct_id").to_string()) ==
                target_text and
                normalized(binding.get_editor_property("target_path")) ==
                normalized(target_path)):
            return True
    return False


def build_cleanup_rules():
    rules = []
    for spec in CLEANUP_RULES:
        node_type = unreal.find_object(None, spec["NodeType"])
        if node_type is None:
            log_error("RULE type not found: {}".format(spec["NodeType"]))
            continue
        rule = unreal.DZStateTreeInputBindingRule()
        rule.node_type = node_type
        rule.input_property_name = spec["InputPropertyName"]
        rule.param_name = spec["ParamName"]
        rules.append(rule)
    return rules


def dump_node_details(tree, captured):
    """Dump enough raw text to distinguish native tasks from blueprint wrappers."""
    wanted = {normalized(item[0].to_string()) for item in captured}

    def visit(state):
        state_name = str(state.get_editor_property("name"))
        for task in state.get_editor_property("tasks") or []:
            task_id = task.get_editor_property("id").to_string()
            if normalized(task_id) not in wanted:
                continue
            node = task.get_editor_property("node")
            instance = task.get_editor_property("instance")
            log("NODE state='{}' id={} display='{}'".format(
                ascii_text(state_name), task_id, task_id))
            log("  NODE-TEXT {}".format(ascii_text(node.export_text())))
            log("  INSTANCE-TEXT {}".format(
                ascii_text(instance.export_text()) if instance else "<null>"))

    walk_states(tree, visit)


def release_parallel():
    """Drop references and best-effort unload so Battle reloads saved Parallel."""
    gc.collect()
    unload = getattr(unreal.EditorAssetLibrary, "unload_asset", None)
    if unload is None:
        log("UNLOAD API unavailable; Battle reuses corrected in-memory Parallel")
        return
    if not unload(PARALLEL):
        log("UNLOAD returned false; continuing with fresh Battle load")


def classify_capture(tree, target_id):
    state, task = find_task_by_id(tree, target_id)
    if task is None:
        return None, None
    node_text = task.get_editor_property("node").export_text() or ""
    if BLUEPRINT_RAYCHECK_TOKEN in node_text:
        return "raycheck", state
    if "/Script/DZProject.STT_Attack" in node_text:
        return "attack", state
    return None, state


def replace_blueprint_raycheck(tree, target_id, new_root_id):
    state, _task = find_task_by_id(tree, target_id)
    if state is None:
        log_error("RAYCHECK state not found target_id={}".format(target_id.to_string()))
        return None

    unreal.DZStateTreeEditTools.remove_node(tree, target_id)
    if find_task_by_id(tree, target_id)[1] is not None:
        log_error("RAYCHECK remove failed target_id={}".format(target_id.to_string()))
        return None

    node_type = unreal.find_object(None, RAYCHECK_TASK_PATH)
    if node_type is None:
        log_error("RAYCHECK native type not found: {}".format(RAYCHECK_TASK_PATH))
        return None

    new_id = unreal.DZStateTreeEditTools.add_state_task_node(state, node_type)
    if not guid_is_valid(new_id):
        log_error("RAYCHECK native node add failed")
        return None

    binding = unreal.DZStateTreePropertyBinding()
    binding.set_editor_property("source_struct_id", new_root_id)
    binding.set_editor_property("source_path", PARAM_NAME)
    binding.set_editor_property("target_struct_id", new_id)
    binding.set_editor_property("target_path", "RefTargetActor")
    try:
        unreal.DZStateTreeEditTools.add_property_binding(tree, binding)
    except Exception as error:
        log_error("RAYCHECK native bind failed: {}".format(error))
        return None

    log("RAYCHECK-REPLACE old={} new={}".format(target_id.to_string(), new_id.to_string()))
    return new_id


def rebuild_downstream(tree, captured, new_root_id, replacements):
    added = 0
    new_root_text = new_root_id.to_string()
    for target_id, old_target_path, kind in captured:
        normalized_target = normalized(target_id.to_string())
        mapping = TARGET_ID_MAP.get(normalized_target)
        final_target_id = replacements.get(normalized_target, target_id)
        if not mapping:
            log_error("UNKNOWN target_id={} path='{}'".format(
                target_id.to_string(), ascii_text(old_target_path)))
            return -1, -1

        old_path = mapping["old"]
        target_path = mapping["new"]
        binding = unreal.DZStateTreePropertyBinding()
        binding.set_editor_property("source_struct_id", new_root_id)
        binding.set_editor_property("source_path", PARAM_NAME)
        binding.set_editor_property("target_struct_id", final_target_id)
        binding.set_editor_property("target_path", target_path)
        log("REBIND target_id={} final_target_id={} old='{}' new='{}' source_id={}".format(
            target_id.to_string(), final_target_id.to_string(), ascii_text(old_target_path),
            ascii_text(target_path), new_root_text))
        try:
            unreal.DZStateTreeEditTools.add_property_binding(tree, binding)
        except Exception as error:
            log_error("REBIND failed: {}".format(error))
            return -1
        added += 1
    return added


def dump_compile(result, label):
    succeeded = bool(result.get_editor_property("bSucceeded"))
    messages = result.get_editor_property("messages") or []
    if succeeded:
        log("COMPILE {} ok messages={}".format(label, len(messages)))
    else:
        log_error("COMPILE {} failed messages={}".format(label, len(messages)))

    for message in messages:
        line = "{} {}".format(message.get_editor_property("severity"),
                              message.get_editor_property("message"))
        if succeeded:
            log("  COMPILE-MESSAGE {}".format(ascii_text(line)))
        else:
            log_error("  COMPILE-MESSAGE {}".format(ascii_text(line)))
    return succeeded


def compile_tree(tree, label):
    return dump_compile(unreal.DZStateTreeEditTools.compile_state_tree(tree), label)


def save_tree(tree, game_path, label, before):
    saved = unreal.EditorAssetLibrary.save_loaded_asset(tree, only_if_is_dirty=False)
    after = file_stat(game_path) if saved else None
    changed = bool(before and after and (after["mtime"] != before["mtime"] or
                                         after["size"] != before["size"]))
    log("SAVE {} saved={} changed={} before=({}, {}) after=({}, {})".format(
        label, bool(saved), changed,
        before["mtime"] if before else -1, before["size"] if before else -1,
        after["mtime"] if after else -1, after["size"] if after else -1))
    return bool(saved) and changed


def fix_parallel():
    parallel = load_tree(PARALLEL, "PARALLEL")
    if parallel is None:
        return 2

    before_params = dump_parameters(parallel, "PARALLEL-BEFORE")
    log("BEFORE param={}".format(before_params))
    if before_params == ("Struct", REF_STRUCT_PATH):
        log("PARALLEL already migrated; skip modification phase")
        release_parallel()
        return 0

    root_id = unreal.DZStateTreeEditTools.get_root_parameters_id(parallel)
    captured = capture_param_bindings(read_bindings(parallel), root_id)
    log("CAPTURED downstream bindings={}".format(len(captured)))
    for target_id, target_path in captured:
        log("  CAPTURE target_id={} path='{}'".format(
            target_id.to_string(), ascii_text(target_path)))

    classified = []
    for target_id, target_path in captured:
        kind, _state = classify_capture(parallel, target_id)
        log("CLASSIFY target_id={} kind={}".format(target_id.to_string(), kind))
        if kind not in ("raycheck", "attack"):
            log_error("UNKNOWN downstream node target_id={}".format(target_id.to_string()))
            return 5
        classified.append((target_id, target_path, kind))
    dump_node_details(parallel, classified)

    unreal.DZStateTreeEditTools.add_tree_parameter(
        parallel, PARAM_NAME, "Struct", REF_STRUCT_PATH)

    after_params = dump_parameters(parallel, "PARALLEL-AFTER")
    if after_params != ("Struct", REF_STRUCT_PATH):
        log_error("PARAM conversion failed got={}".format(after_params))
        return 3

    ref_ok = bool(unreal.DZStateTreeEditTools.set_tree_parameter_ref_default(
        parallel, PARAM_NAME, "Object", OBJECT_PATH))
    log("SETREF ok={} type=Object path={}".format(ref_ok, OBJECT_PATH))
    if not ref_ok:
        return 4

    new_root_id = unreal.DZStateTreeEditTools.get_root_parameters_id(parallel)
    replacements = {}
    for target_id, _old_target_path, kind in classified:
        if kind != "raycheck":
            continue
        replacement_id = replace_blueprint_raycheck(parallel, target_id, new_root_id)
        if replacement_id is None:
            return 5
        replacements[normalized(target_id.to_string())] = replacement_id

    cleanup_rules = build_cleanup_rules()
    removed = int(unreal.DZStateTreeEditTools.
                  remove_explicit_inputs_bound_to_ref_parameters(
                      parallel, cleanup_rules))
    log("REMOVE count={}".format(removed))
    # RayCheck bindings are removed with the blueprint node itself. Only
    # native Attack bindings go through the explicit-input cleanup helper.
    expected_cleanup_count = sum(
        1 for _target_id, _target_path, kind in classified if kind == "attack")
    if removed != expected_cleanup_count:
        for item in read_bindings(parallel):
            source_id = item.get_editor_property("source_struct_id")
            if (normalized(source_id.to_string()) ==
                    normalized(new_root_id.to_string()) and
                    normalized(item.get_editor_property("source_path")) ==
                    normalized(PARAM_NAME)):
                log("AFTER-REMOVE target_id={} path='{}'".format(
                    item.get_editor_property("target_struct_id").to_string(),
                    ascii_text(item.get_editor_property("target_path"))))
        log_error("REMOVE count expected={} got={}".format(
            expected_cleanup_count, removed))
        return 5

    for target_id, old_target_path, _kind in classified:
        if binding_exists(parallel, new_root_id, target_id, old_target_path):
            log_error("OLD binding remains target_id={} path='{}'".format(
                target_id.to_string(), ascii_text(old_target_path)))
            return 5

    rebound = rebuild_downstream(parallel, classified, new_root_id, replacements)
    log("REBIND count={}".format(rebound))
    if rebound != len(captured):
        log_error("REBIND count expected={} removed={} rebound={}".format(
            len(captured), removed, rebound))
        return 5

    if not compile_tree(parallel, "PARALLEL"):
        return 6

    parallel_before = None
    if EXECUTE:
        parallel_before = file_stat(PARALLEL)
        if not parallel_before:
            return 7
        if not save_tree(parallel, PARALLEL, "PARALLEL", parallel_before):
            log_error("SAVE verification failed PARALLEL")
            return 8

    release_parallel()

    return 0


def bind_parent():
    battle = load_tree(BATTLE, "BATTLE")
    if battle is None:
        return 12

    nodes = find_run_parallel_nodes(battle)
    log("RUN_PARALLEL nodes={}".format(len(nodes)))
    if len(nodes) != 1:
        log_error("Expected exactly one RunParallel node")
        return 13

    root_id = unreal.DZStateTreeEditTools.get_root_parameters_id(battle)
    node_id = nodes[0].get_editor_property("id")
    binding = unreal.DZStateTreePropertyBinding()
    binding.set_editor_property("source_struct_id", root_id)
    binding.set_editor_property("source_path", PARAM_NAME)
    binding.set_editor_property("target_struct_id", node_id)
    binding.set_editor_property("target_path", PARENT_TARGET_PATH)

    if binding_exists(battle, root_id, node_id, PARENT_TARGET_PATH):
        log("PARENT-BIND already present; skip add")
    else:
        try:
            unreal.DZStateTreeEditTools.add_property_binding(battle, binding)
            log("PARENT-BIND added source_id={} target_id={}".format(
                root_id.to_string(), node_id.to_string()))
        except Exception as error:
            log_error("PARENT-BIND failed: {}".format(error))
            return 14

    matched = []
    root_text = root_id.to_string()
    for item in read_bindings(battle):
        if (item.get_editor_property("source_struct_id").to_string() == root_text and
                normalized(item.get_editor_property("source_path")) ==
                normalized(PARAM_NAME) and
                normalized(item.get_editor_property("target_path")) ==
                normalized(PARENT_TARGET_PATH)):
            matched.append(item)
    log("PARENT-BIND matched={}".format(len(matched)))
    if len(matched) != 1:
        return 15

    if not compile_tree(battle, "BATTLE"):
        return 16

    if EXECUTE:
        battle_before = file_stat(BATTLE)
        if not battle_before:
            return 17
        if not save_tree(battle, BATTLE, "BATTLE", battle_before):
            log_error("SAVE verification failed BATTLE")
            return 18

    return 0


def main():
    log("MODE execute={}".format(EXECUTE))
    result = fix_parallel()
    if result:
        log("RESULT failed parallel step={}".format(result))
        return result

    if EXECUTE:
        result = bind_parent()
    else:
        log("SKIP parent bind in DRY (Battle must load saved Parallel)")
        result = 0

    log("RESULT {}".format("ok" if result == 0 else "failed step={}".format(result)))
    return result


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        unreal.log_error("{} TOP-LEVEL {}".format(TAG, ascii_text(error)))
        sys.exit(20)
