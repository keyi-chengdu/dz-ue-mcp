# st_fix_05002102_parallel_actor_value.py
# Purpose: Restore ACTOR_TARGET to plain Object Actor value flow.
#          ParallelAttack consumes explicit Actor inputs. The completion event
#          path is intentionally left untouched.
#
# Usage (editor MUST be closed):
#   UnrealEditor-Cmd.exe DZProject.uproject -run=pythonscript
#     -script="<this file>" [-Execute] -stdout -unattended -nopause -nosplash
#     -NullRHI -noscc
#
# Pitfalls:
#   1. AddPropertyBinding has replace semantics, but old Ref bindings are
#      removed first with their real FName paths.
#   2. Battle's RunParallel node embeds ParallelAttack's parameter bag. In a
#      fresh command-line process, load and save Parallel first, then load
#      Battle so PostLoad syncs it from the latest in-memory Parallel.
#   3. C++ helpers do not always mark assets dirty; save with
#      only_if_is_dirty=False and verify mtime/size.

import gc
import os
import sys
import unreal


MAIN = "/Game/Blueprint/StateTree/05002102/ST_05002102"
BATTLE = "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle"
PARALLEL = "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack"
PARAM_NAME = "ACTOR_TARGET"
OBJECT_PATH = "/Script/Engine.Actor"
PARENT_TARGET_PATH = "StateTree.Parameters.Value.ACTOR_TARGET"
CONTENT_ROOT = "C:/UE/Projects/DZ_Project_New/DZ_Content/Content"
TAG = "[st-fix-pa-value]"

# Exact node-type marker -> (old Ref property, explicit input property).
VALUE_INPUT_MAP = {
    "/Script/DZProject.STT_AskForBattleTarget": ("RefActorTarget", "InActorTarget"),
    "/Script/DZProject.STT_RayCheck": ("RefTargetActor", "InTargetActor"),
    "/Script/DZProject.STC_Server_CheckDistance": ("RefTargetActor", "InTargetActor"),
    "/Script/DZProject.STT_FindTarget": ("RefTargetActor", "InTargetActor"),
    "/Script/DZProject.STT_MoveToTarget": ("RefActorTarget", "InActorTarget"),
    "/Script/DZProject.STT_TryAddToBattleSequence": ("RefActorTarget", "InTargetActor"),
    "/Script/DZProject.STT_Attack": ("RefActorTarget", "InActorTarget"),
    "/Script/DZProject.STC_Server_Simple": ("RefActorTarget", "InActorTarget"),
    "/Script/DZProject.STC_Server_HasBattleTarget": ("RefActorTarget", "InActorTarget"),
}


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


def exported_text(value):
    try:
        return value.export_text()
    except Exception:
        return str(value) if value else ""


def asset_disk_path(game_path):
    relative = game_path[len("/Game/"):]
    return os.path.join(CONTENT_ROOT, relative + ".uasset")


def file_stat(game_path):
    try:
        info = os.stat(asset_disk_path(game_path))
        return {"mtime": info.st_mtime, "size": info.st_size}
    except OSError as error:
        log_error("STAT failed {}: {}".format(asset_disk_path(game_path), error))
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
    found = None
    for param in params:
        name = str(param.get_editor_property("name"))
        if name == PARAM_NAME:
            value_type = str(param.get_editor_property("value_type"))
            type_path = str(param.get_editor_property("type_object_path"))
            found = (value_type, type_path)
    log("PARAM {} type=({})".format(label, found))
    return found


def read_bindings(tree):
    return unreal.DZStateTreeEditTools.get_property_bindings(tree, unreal.Guid())


def root_id(tree):
    return unreal.DZStateTreeEditTools.get_root_parameters_id(tree)


def node_type_path(node):
    return exported_text(node.get_editor_property("node")).split("(", 1)[0]


def iter_node_groups(editor_data):
    def walk(state):
        groups = (
            state.get_editor_property("tasks"),
            state.get_editor_property("enter_conditions"),
            state.get_editor_property("considerations"),
        )
        for nodes in groups:
            for node in nodes or []:
                yield node
        for transition in state.get_editor_property("transitions") or []:
            for node in transition.get_editor_property("conditions") or []:
                yield node
        for child in state.get_editor_property("children") or []:
            for node in walk(child):
                yield node

    for state in editor_data.get_editor_property("sub_trees") or []:
        for node in walk(state):
            yield node
    for node in editor_data.get_editor_property("global_tasks") or []:
        yield node
    for node in editor_data.get_editor_property("evaluators") or []:
        yield node


def find_node(tree, node_id):
    wanted = normalized(node_id.to_string())
    editor_data = unreal.StateTreeEditorData.get_editor_data(tree)
    for node in iter_node_groups(editor_data):
        if normalized(node.get_editor_property("id").to_string()) == wanted:
            return node
    return None


def mapping_for_node(node):
    type_path = node_type_path(node)
    for marker, mapping in VALUE_INPUT_MAP.items():
        if type_path.startswith(marker):
            return type_path, mapping
    return type_path, None


def instance_properties(tree, node_id):
    node = find_node(tree, node_id)
    if not node:
        return ""
    return ascii_text(exported_text(node.get_editor_property("instance"))).lower()


def same_guid(left, right):
    return normalized(left.to_string()) == normalized(right.to_string())


def binding_exists(tree, source_id, target_id, target_path):
    wanted_source = normalized(source_id.to_string())
    if not unreal.DZStateTreeEditTools.has_property_binding(tree, target_id, target_path):
        return False
    for binding in read_bindings(tree):
        if (normalized(binding.get_editor_property("source_struct_id").to_string()) == wanted_source and
                normalized(binding.get_editor_property(
                    "target_struct_id").to_string()) == normalized(target_id.to_string())):
            return True
    return False


def make_binding(tree, source_id, target_id, target_path):
    binding = unreal.DZStateTreePropertyBinding()
    binding.set_editor_property("source_struct_id", source_id)
    binding.set_editor_property("source_path", PARAM_NAME)
    binding.set_editor_property("target_struct_id", target_id)
    binding.set_editor_property("target_path", target_path)
    unreal.DZStateTreeEditTools.add_property_binding(tree, binding)


def dump_bindable_sources(tree, target_id, label):
    sources = unreal.DZStateTreeEditTools.get_bindable_sources(tree, target_id)
    log("SOURCES {} count={}".format(label, len(sources)))
    for source in sources:
        struct_type = source.get_editor_property("struct_type")
        log("  SOURCE id={} name='{}' category='{}' type='{}'".format(
            source.get_editor_property("id").to_string(),
            source.get_editor_property("name"),
            source.get_editor_property("category"),
            struct_type.get_name() if struct_type else "None"))
    return sources


def compile_tree(tree, label):
    result = unreal.DZStateTreeEditTools.compile_state_tree(tree)
    succeeded = bool(result.get_editor_property("bSucceeded"))
    messages = result.get_editor_property("messages") or []
    log("COMPILE {} ok={} messages={}".format(label, succeeded, len(messages)))
    for message in messages:
        line = "{} {}".format(message.get_editor_property("severity"),
                              message.get_editor_property("message"))
        if succeeded:
            log("  MESSAGE {}".format(ascii_text(line)))
        else:
            log_error("  MESSAGE {}".format(ascii_text(line)))
    return succeeded


def save_tree(tree, path, label):
    before = file_stat(path)
    saved = unreal.EditorAssetLibrary.save_loaded_asset(tree, only_if_is_dirty=False)
    after = file_stat(path) if saved else None
    changed = bool(before and after and
                   (before["mtime"] != after["mtime"] or before["size"] != after["size"]))
    log("SAVE {} saved={} changed={} before=({}, {}) after=({}, {})".format(
        label, bool(saved), changed,
        before["mtime"] if before else -1, before["size"] if before else -1,
        after["mtime"] if after else -1, after["size"] if after else -1))
    return bool(saved and changed)


def release_parallel():
    # EditorAssetLibrary.unload_asset is unavailable in command-line Python.
    # The fresh process ordering above is sufficient: Parallel is loaded,
    # converted and saved before Battle is loaded.
    gc.collect()
    log("RELEASE PARALLEL gc-complete")
    return True


def capture_actor_bindings(tree, source_id):
    captured = []
    run_parallel = []
    source_text = normalized(source_id.to_string())
    wanted_param = normalized(PARAM_NAME)
    wanted_parent = normalized(PARENT_TARGET_PATH)
    for binding in read_bindings(tree):
        source_path = binding.get_editor_property("source_path")
        if (normalized(binding.get_editor_property("source_struct_id").to_string()) != source_text or
                normalized(source_path) != wanted_param):
            continue
        target_id = binding.get_editor_property("target_struct_id")
        target_path = binding.get_editor_property("target_path")
        if normalized(target_path) == wanted_parent:
            run_parallel.append(binding)
        else:
            captured.append(binding)
    log("CAPTURE value_targets={} run_parallel={}".format(
        len(captured), len(run_parallel)))
    for index, binding in enumerate(captured):
        log("  VALUE[{}] target_id={} target='{}'".format(
            index,
            binding.get_editor_property("target_struct_id").to_string(),
            ascii_text(binding.get_editor_property("target_path"))))
    return captured, run_parallel


def remove_old_value_binding(tree, source_id, binding, node_type_path, mapping):
    target_id = binding.get_editor_property("target_struct_id")
    old_ref, explicit_input = mapping
    properties = instance_properties(tree, target_id)
    if old_ref.lower() not in properties:
        log_error("OLD property missing type={} property={}".format(
            node_type_path, old_ref))
        return False
    if explicit_input.lower() not in properties:
        log_error("INPUT property missing type={} property={}".format(
            node_type_path, explicit_input))
        return False
    try:
        unreal.DZStateTreeEditTools.remove_property_binding(
            tree, target_id, old_ref)
    except Exception as error:
        log_error("REMOVE failed type={} error={}".format(
            node_type_path, ascii_text(error)))
        return False
    log("REMOVED {} target_id={} old={}".format(
        node_type_path, target_id.to_string(), old_ref))
    return True


def bind_value_input(tree, source_id, binding, node_type_path, mapping):
    target_id = binding.get_editor_property("target_struct_id")
    _old_ref, explicit_input = mapping
    try:
        make_binding(tree, source_id, target_id, explicit_input)
    except Exception as error:
        log_error("BIND failed type={} error={}".format(
            node_type_path, ascii_text(error)))
        return False
    if not binding_exists(tree, source_id, target_id, explicit_input):
        log("BINDINGS after failed add:")
        for item in read_bindings(tree):
            if normalized(item.get_editor_property(
                    "target_struct_id").to_string()) == normalized(target_id.to_string()):
                log("  BIND source_id={} source='{}' target='{}'".format(
                    item.get_editor_property("source_struct_id").to_string(),
                    ascii_text(item.get_editor_property("source_path")),
                    ascii_text(item.get_editor_property("target_path"))))
        log_error("BIND verification failed type={} input={}".format(
            node_type_path, explicit_input))
        return False
    log("BOUND {} target_id={} input={}".format(
        node_type_path, target_id.to_string(), explicit_input))
    return True


def convert_tree(tree, label, keep_run_parallel):
    source = root_id(tree)
    captured, run_parallel = capture_actor_bindings(tree, source)
    if keep_run_parallel and len(run_parallel) != 1:
        log_error("RUNPARALLEL count expected=1 got={}".format(len(run_parallel)))
        return False
    if not keep_run_parallel and run_parallel:
        log_error("Unexpected RunParallel binding in child tree")
        return False

    plans = []
    for binding in captured:
        target_id = binding.get_editor_property("target_struct_id")
        node = find_node(tree, target_id)
        if not node:
            log_error("NODE missing target_id={}".format(target_id.to_string()))
            return False
        type_path, mapping = mapping_for_node(node)
        if not mapping:
            log_error("NO VALUE MAPPING type='{}' target='{}'".format(
                ascii_text(type_path),
                ascii_text(binding.get_editor_property("target_path"))))
            return False
        properties = instance_properties(tree, target_id)
        old_ref, explicit_input = mapping
        if (not unreal.DZStateTreeEditTools.has_property_binding(tree, target_id, old_ref) and
                binding_exists(tree, source, target_id, explicit_input)):
            log("SKIP already value-bound type='{}' input={} target_id={}".format(
                ascii_text(type_path), explicit_input, target_id.to_string()))
            continue
        dump_bindable_sources(tree, target_id, ascii_text(
            binding.get_editor_property("target_path")))
        log("INSTANCE type='{}' has_old={} has_input={}".format(
            ascii_text(type_path),
            old_ref.lower() in properties,
            explicit_input.lower() in properties))
        if old_ref.lower() not in properties or explicit_input.lower() not in properties:
            log_error("INSTANCE property missing type='{}' old={} input={}".format(
                ascii_text(type_path), old_ref, explicit_input))
            return False
        plans.append((binding, type_path, mapping))

    if not EXECUTE:
        for binding, type_path, mapping in plans:
            target_id = binding.get_editor_property("target_struct_id")
            log("PLAN remove={} bind={}->{} target_id={}".format(
                mapping[0], PARAM_NAME, mapping[1], target_id.to_string()))
        log("PLAN convert parameter {} Ref->Object; DRY leaves {} unchanged".format(
            PARAM_NAME, label))
        return True

    for binding, type_path, mapping in plans:
        if not remove_old_value_binding(tree, source, binding, type_path, mapping):
            return False

    before_param = dump_parameters(tree, "{}-BEFORE".format(label))
    if before_param == ("Struct", "/Script/StateTreeModule.StateTreeBlueprintPropertyRef"):
        unreal.DZStateTreeEditTools.add_tree_parameter(
            tree, PARAM_NAME, "Object", OBJECT_PATH)
    elif before_param != ("Object", OBJECT_PATH):
        log_error("Unexpected input parameter type={}".format(before_param))
        return False
    after_param = dump_parameters(tree, "{}-AFTER".format(label))
    if after_param != ("Object", OBJECT_PATH):
        log_error("PARAM conversion failed got={}".format(after_param))
        return False

    for binding, type_path, mapping in plans:
        if not bind_value_input(tree, source, binding, type_path, mapping):
            return False

    for binding, type_path, mapping in plans:
        target_id = binding.get_editor_property("target_struct_id")
        old_ref, explicit_input = mapping
        if unreal.DZStateTreeEditTools.has_property_binding(tree, target_id, old_ref):
            log_error("Old Ref binding remains type={} property={}".format(
                type_path, old_ref))
            return False
        if not binding_exists(tree, source, target_id, explicit_input):
            log_error("New input binding missing type={} property={}".format(
                type_path, explicit_input))
            return False

    _remaining, retained_parent = capture_actor_bindings(tree, source)
    if keep_run_parallel and len(retained_parent) != 1:
        log_error("RunParallel binding count expected=1 got={}".format(
            len(retained_parent)))
        return False
    if not keep_run_parallel and retained_parent:
        log_error("Unexpected parent binding remains")
        return False

    return compile_tree(tree, label)


def fix_parallel():
    tree = load_tree(PARALLEL, "PARALLEL")
    if not tree:
        return 2
    if not convert_tree(tree, "PARALLEL", keep_run_parallel=False):
        return 3
    if not EXECUTE:
        log("DRY skips Parallel save/reload and Battle conversion")
        return 0
    current_param = dump_parameters(tree, "PARALLEL-CURRENT")
    if current_param == ("Object", OBJECT_PATH):
        log("PARALLEL already converted; skip save and keep current instance")
        return 0
    if not save_tree(tree, PARALLEL, "PARALLEL"):
        return 4
    if not release_parallel():
        return 5
    return 0


def fix_battle():
    tree = load_tree(BATTLE, "BATTLE")
    if not tree:
        return 12
    before_param = dump_parameters(tree, "BATTLE")
    if before_param != ("Struct", "/Script/StateTreeModule.StateTreeBlueprintPropertyRef"):
        log_error("Unexpected Battle input parameter type={}".format(before_param))
        return 13
    if not convert_tree(tree, "BATTLE", keep_run_parallel=True):
        return 14
    if not save_tree(tree, BATTLE, "BATTLE"):
        return 15
    return 0


def verify_main():
    tree = load_tree(MAIN, "MAIN")
    if not tree:
        return False
    found = dump_parameters(tree, "MAIN")
    return found == ("Object", OBJECT_PATH)


def main():
    log("MODE execute={}".format(EXECUTE))
    if not verify_main():
        return 1
    result = fix_parallel()
    if result:
        log("RESULT failed parallel step={}".format(result))
        return result
    if EXECUTE:
        result = fix_battle()
    log("RESULT {}".format("ok" if result == 0 else "failed step={}".format(result)))
    return result


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        unreal.log_error("{} TOP-LEVEL {}".format(TAG, ascii_text(error)))
        sys.exit(20)
