# st_probe_parallel_ref_binding.py
# Purpose: Dry-run a parent-tree parameter binding into a RunParallel task's
#          nested StateTree.Parameters bag. This script never saves assets.
#
# Usage (editor MUST be closed):
#   UnrealEditor-Cmd.exe DZProject.uproject -run=pythonscript ^
#     -script=".../st_probe_parallel_ref_binding.py" ^
#     -unattended -nopause -nosplash -NullRHI -noscc

import sys
import unreal


BATTLE = "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle"
PARALLEL = "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack"
RUN_PARALLEL_TYPE_PATH = "/Script/StateTreeModule.StateTreeRunParallelStateTreeTask"
SOURCE_PATH = "ACTOR_TARGET"
TARGET_PATH = "StateTree.Parameters.Value.ACTOR_TARGET"
PARAM_NAME = "ACTOR_TARGET"
RUN_PARALLEL_TYPE_NAME = "StateTreeRunParallelStateTreeTask"
TAG = "[par-ref-probe]"


def log(text):
    unreal.log_warning("{} {}".format(TAG, text))


def log_error(text):
    unreal.log_error("{} {}".format(TAG, text))


def dump_parameters(tree, label):
    params = unreal.DZStateTreeEditTools.get_tree_parameters(tree)
    log("PARAMS {} count={}".format(label, len(params)))
    for param in params:
        log("  PARAM name={} value_type={} object_path={} container={}".format(
            param.get_editor_property("name"),
            param.get_editor_property("value_type"),
            param.get_editor_property("type_object_path"),
            param.get_editor_property("container_type")))


def walk_states(tree, visitor, state=None):
    if state is None:
        editor_data = unreal.StateTreeEditorData.get_editor_data(tree)
        states = editor_data.get_editor_property("sub_trees")
    else:
        states = state.get_editor_property("children")

    for state in states:
        visitor(state)
        walk_states(tree, visitor, state)


def find_run_parallel_nodes(tree):
    nodes = []

    def visit(state_info):
        tasks = state_info.get_editor_property("tasks")
        for task in tasks:
            node_text = task.get_editor_property("node").export_text()
            if RUN_PARALLEL_TYPE_PATH in node_text:
                nodes.append(task)

    walk_states(tree, visit)
    return nodes


def normalized_path(path):
    # PropertyBindingPath renders display names with spaces. Compare the
    # property identity without display-name spacing and case.
    return str(path).replace(" ", "").replace("_", "").lower()


def dump_run_parallel(task):
    node_id = task.get_editor_property("id")
    log("FOUND node_id={}".format(node_id))
    try:
        log("  NODE_TEXT {}".format(task.get_editor_property("node").export_text()))
    except Exception as error:
        log_error("  node export failed: {}".format(error))
    try:
        log("  INSTANCE_TEXT {}".format(task.get_editor_property("instance").export_text()))
    except Exception as error:
        log_error("  instance export failed: {}".format(error))


def build_rule(node_type):
    rule = unreal.DZStateTreeInputBindingRule()
    rule.node_type = node_type
    rule.input_property_name = TARGET_PATH
    rule.param_name = PARAM_NAME
    rule.overwrite_existing = True
    return rule


def read_bindings(tree):
    return unreal.DZStateTreeEditTools.get_property_bindings(tree, unreal.Guid())


def matched_bindings(bindings):
    out = []
    for binding in bindings:
        target_path = normalized_path(binding.get_editor_property("target_path"))
        if normalized_path(TARGET_PATH) in target_path:
            out.append(binding)
    return out


def dump_binding(binding):
    log("  BINDING target_id={} target={} source_id={} source={}".format(
        binding.get_editor_property("target_struct_id"),
        binding.get_editor_property("target_path"),
        binding.get_editor_property("source_struct_id"),
        binding.get_editor_property("source_path")))


def dump_node(tree, node_id, label):
    log("NODE {}".format(label))
    try:
        props = unreal.DZStateTreeEditTools.get_node_properties(tree, node_id)
    except Exception as error:
        log_error("  get_node_properties failed: {}".format(error))
        return
    instance_props = props.get_editor_property("instance_properties")
    state_tree = instance_props.get("StateTree", "<missing>")
    log("  StateTree={}".format(state_tree))


def dump_bindable_sources(tree, node_id):
    try:
        sources = unreal.DZStateTreeEditTools.get_bindable_sources(tree, node_id)
    except Exception as error:
        log_error("  get_bindable_sources failed: {}".format(error))
        return
    log("BINDABLE_SOURCES count={}".format(len(sources)))
    for source in sources:
        log("  SOURCE id={} name={} category={} source={}".format(
            source.get_editor_property("id"),
            source.get_editor_property("name"),
            source.get_editor_property("category"),
            source.get_editor_property("source")))


def dump_compile(result):
    succeeded = result.get_editor_property("bSucceeded")
    log("COMPILE succeeded={}".format(succeeded))
    for message in result.get_editor_property("messages") or []:
        log("  COMPILE {} {}".format(
            message.get_editor_property("severity"),
            message.get_editor_property("message")))
    return succeeded


def main():
    battle = unreal.load_asset(BATTLE)
    parallel = unreal.load_asset(PARALLEL)
    if not battle or not parallel:
        log_error("asset load failed battle={} parallel={}".format(bool(battle), bool(parallel)))
        return 1

    dump_parameters(battle, "BATTLE")
    dump_parameters(parallel, "PARALLEL")

    node_type = unreal.find_object(None, RUN_PARALLEL_TYPE_PATH)
    if not node_type:
        log_error("RunParallel node type not found")
        return 1

    before = matched_bindings(read_bindings(battle))
    log("BEFORE matched={}".format(len(before)))
    for binding in before:
        dump_binding(binding)

    parameter_id = unreal.DZStateTreeEditTools.get_root_parameters_id(battle)
    log("PARAMETER_ID tool={}".format(parameter_id.to_string()))

    # First show the batch tool result. Its filter deliberately skips Ref -> non-Ref.
    rule = build_rule(node_type)
    changed = unreal.DZStateTreeEditTools.bind_task_inputs_from_tree_parameters(battle, [rule])
    log("BATCH_BIND changed={}".format(changed))

    # Now test the engine path directly. This deliberately bypasses the DZ batch
    # filter and still performs no save; only the in-memory editor data changes.
    nodes = find_run_parallel_nodes(battle)
    log("RUN_PARALLEL nodes={}".format(len(nodes)))
    before_count = len(before)

    for node in nodes:
        node_id = node.get_editor_property("id")
        dump_run_parallel(node)
        dump_bindable_sources(battle, node_id)

        binding = unreal.DZStateTreePropertyBinding()
        binding.set_editor_property("source_struct_id", parameter_id)
        binding.set_editor_property("source_path", SOURCE_PATH)
        binding.set_editor_property("target_struct_id", node_id)
        binding.set_editor_property("target_path", TARGET_PATH)
        try:
            unreal.DZStateTreeEditTools.add_property_binding(battle, binding)
        except Exception as error:
            log_error("ADD_BINDING failed: {}".format(error))

    after = matched_bindings(read_bindings(battle))
    added = len(after) - before_count
    log("DIRECT_BIND added={}".format(added))
    log("AFTER matched={}".format(len(after)))
    for binding in after:
        dump_binding(binding)

    result = unreal.DZStateTreeEditTools.compile_state_tree(battle)
    compile_ok = dump_compile(result)

    passed = bool(after) and compile_ok
    log("RESULT batch_changed={} direct_added={} bindings={} compile={}".format(
        changed, added, len(after), compile_ok))
    return 0 if passed else 2


if __name__ == "__main__":
    sys.exit(main())
