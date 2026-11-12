# st_dump_pa_targets.py
# Purpose: Read-only diagnostic dump for the 05002102 ParallelAttack target chain.
# Usage (headless, editor MUST be closed):
#   UnrealEditor-Cmd.exe DZProject.uproject -run=pythonscript ^
#     -script=".../st_dump_pa_targets.py" -unattended -nopause -nosplash -NullRHI -noscc

import sys
import unreal


PARALLEL = "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack"
BATTLE = "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle"
TAG = "[pa-targets]"


def log(text):
    unreal.log_warning("{} {}".format(TAG, text))


def log_error(text):
    unreal.log_error("{} {}".format(TAG, text))


def safe(value, default="<none>"):
    return default if value is None else value


def dump_parameter(param):
    log("  PARAM name={} value_type={} object_path={} container={}".format(
        param.get_editor_property("name"),
        param.get_editor_property("value_type"),
        param.get_editor_property("type_object_path"),
        param.get_editor_property("container_type")))


def dump_parameters(tree, label):
    log("PARAMS {} begin".format(label))
    try:
        params = unreal.DZStateTreeEditTools.get_tree_parameters(tree)
    except Exception as error:
        log_error("  PARAMS {} failed: {}".format(label, error))
        return
    log("  PARAMS {} count={}".format(label, len(params)))
    for param in params:
        dump_parameter(param)


def dump_bindings(tree, label):
    log("BINDINGS {} begin".format(label))
    try:
        bindings = unreal.DZStateTreeEditTools.get_property_bindings(tree, unreal.Guid())
    except Exception as error:
        log_error("  BINDINGS {} failed: {}".format(label, error))
        return
    log("  BINDINGS {} count={}".format(label, len(bindings)))
    for index, binding in enumerate(bindings):
        source_id = binding.get_editor_property("source_struct_id")
        target_id = binding.get_editor_property("target_struct_id")
        source_path = binding.get_editor_property("source_path")
        target_path = binding.get_editor_property("target_path")
        log("  BINDING[{}] target_id={} target='{}' source_id={} source='{}'".format(
            index, target_id, target_path, source_id, source_path))
        dump_bindable_sources(tree, target_id, index)


def dump_bindable_sources(tree, target_id, binding_index):
    try:
        sources = unreal.DZStateTreeEditTools.get_bindable_sources(tree, target_id)
    except Exception as error:
        log_error("    SOURCES binding[{}] failed: {}".format(binding_index, error))
        return
    log("    SOURCES binding[{}] count={}".format(binding_index, len(sources)))
    for source in sources:
        struct_type = safe(source.get_editor_property("struct_type"))
        struct_name = getattr(struct_type, "get_name", lambda: "<no-name>")()
        struct_path = getattr(struct_type, "get_path_name", lambda: "<no-path>")()
        log("      SOURCE id={} name={} category={} data_source={} struct={} path={}".format(
            source.get_editor_property("id"),
            source.get_editor_property("name"),
            source.get_editor_property("category"),
            source.get_editor_property("source"),
            struct_name,
            struct_path))


def dump_properties(tree, node_id, label):
    try:
        props = unreal.DZStateTreeEditTools.get_node_properties(tree, node_id)
    except Exception as error:
        log_error("    PROPERTIES {} id={} failed: {}".format(label, node_id, error))
        return

    instance_props = props.get_editor_property("instance_properties")
    node_props = props.get_editor_property("node_properties")
    log("    PROPERTIES {} id={} instance_count={} node_count={}".format(
        label, node_id, len(instance_props), len(node_props)))
    for key, value in instance_props.items():
        log("      INSTANCE {} = {}".format(key, value))
    for key, value in node_props.items():
        log("      NODE {} = {}".format(key, value))


def dump_node(tree, node, label):
    node_id = node.get_editor_property("id")
    node_type = safe(node.get_editor_property("node_type"))
    type_name = getattr(node_type, "get_name", lambda: "<no-type>")()
    log("    NODE {} id={} type={} name='{}' description='{}'".format(
        label,
        node_id,
        type_name,
        node.get_editor_property("name"),
        node.get_editor_property("description")))
    dump_properties(tree, node_id, label)


def dump_node_list(tree, nodes, label):
    for index, node in enumerate(nodes or []):
        dump_node(tree, node, "{}[{}]".format(label, index))


def dump_state(tree, state, depth=0):
    if not state:
        return
    try:
        info = unreal.DZStateTreeEditTools.describe_state(state)
    except Exception as error:
        log_error("{}STATE dump failed: {}".format("  " * depth, error))
        return

    indent = "  " * depth
    state_path = info.get_editor_property("path")
    state_name = info.get_editor_property("name")
    state_type = info.get_editor_property("type")
    state_enabled = info.get_editor_property("bEnabled")
    parameters_id = info.get_editor_property("parametersID")
    log("{}STATE path='{}' name='{}' type={} enabled={} parameters_id={}".format(
        indent, state_path, state_name, state_type, state_enabled, parameters_id))

    child_indent = indent + "  "
    dump_node_list(tree, info.get_editor_property("enterConditions"), "EC", )
    dump_node_list(tree, info.get_editor_property("tasks"), "TASK")
    dump_node_list(tree, info.get_editor_property("considerations"), "SCORE")

    transitions = info.get_editor_property("transitions") or []
    for index, transition in enumerate(transitions):
        settings = transition.get_editor_property("settings")
        target = safe(settings.get_editor_property("target_state"))
        target_path = getattr(target, "get_path_name", lambda: "<no-target>")()
        log("{}  TRANSITION[{}] id={} trigger={} type={} target={} tag={}".format(
            child_indent,
            index,
            transition.get_editor_property("id"),
            settings.get_editor_property("trigger"),
            settings.get_editor_property("type"),
            target_path,
            settings.get_editor_property("required_event_tag")))
        dump_node_list(tree, transition.get_editor_property("conditions"),
                       "TRANS[{}]COND".format(index))

    children = info.get_editor_property("children") or []
    for child in children:
        dump_state(tree, child, depth + 1)


def dump_tree(tree, label):
    log("TREE {} begin object={}".format(label, safe(tree.get_path_name())))
    dump_parameters(tree, label)
    dump_bindings(tree, label)
    try:
        info = unreal.DZStateTreeEditTools.describe_state_tree(tree)
    except Exception as error:
        log_error("TREE {} describe failed: {}".format(label, error))
        return

    schema = safe(info.get_editor_property("schemaClass"))
    log("  SCHEMA={} root_parameters_id={}".format(
        getattr(schema, "get_path_name", lambda: "<no-schema>")(),
        info.get_editor_property("rootParametersID")))
    dump_node_list(tree, info.get_editor_property("evaluators"), "EVALUATOR")
    dump_node_list(tree, info.get_editor_property("globalTasks"), "GLOBAL_TASK")

    subtrees = info.get_editor_property("subTrees") or []
    log("  SUBTREES count={}".format(len(subtrees)))
    for index, state in enumerate(subtrees):
        dump_state(tree, state, 2)
    log("TREE {} end".format(label))


def main():
    parallel = unreal.load_asset(PARALLEL)
    battle = unreal.load_asset(BATTLE)
    if not parallel:
        log_error("parallel load failed: {}".format(PARALLEL))
        return 1
    if not battle:
        log_error("battle load failed: {}".format(BATTLE))
        return 1

    dump_tree(parallel, "PARALLEL")
    dump_parameters(battle, "BATTLE")
    dump_bindings(battle, "BATTLE")
    log("DONE")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        unreal.log_error("{} TOP-LEVEL {}".format(TAG, error))
        sys.exit(2)
