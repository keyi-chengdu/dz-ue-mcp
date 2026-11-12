# -*- coding: utf-8 -*-
# Read-only dump of the 05002102 target chain: DA -> main tree -> battle subtree
# -> parallel tree. Focuses on parameters, bindings, global tasks, transitions,
# and target/move/parallel nodes.
#
# Usage (editor MUST be closed):
#   UnrealEditor-Cmd.exe DZProject.uproject -run=pythonscript
#     -script="<this file>" -stdout -unattended -nopause -nosplash -NullRHI -noscc

import sys
import unreal


DA = "/Game/Asset/Enemy/DA_05002102"
TREES = [
    "/Game/Blueprint/StateTree/05002102/ST_05002102",
    "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle",
    "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack",
]
TAG = "[st-05002102-chain]"

RELEVANT_TYPES = {
    "STT_AskForBattleTarget",
    "STT_TryAddToBattleSequence",
    "STT_CaptureEventActor",
    "STT_FindTarget",
    "STT_MoveToTarget",
    "STT_RandomAndSetVal",
    "StateTreeRunParallelStateTreeTask",
    "STT_Attack",
}

RELEVANT_TYPE_MARKERS = ("STC_",)


def log(text):
    unreal.log_warning("{} {}".format(TAG, text))


def log_error(text):
    unreal.log_error("{} {}".format(TAG, text))


def ascii_text(value):
    text = str(value)
    return text.encode("unicode_escape").decode("ascii")


def object_name(value):
    if value is None:
        return "<none>"
    return str(getattr(value, "get_name", lambda: "<unnamed>")())


def object_path(value):
    if value is None:
        return "<none>"
    return str(getattr(value, "get_path_name", lambda: "<no-path>")())


def dump_da():
    log("DA begin")
    try:
        da = unreal.EditorAssetLibrary.load_asset(DA)
    except Exception as error:
        log_error("  DA load failed: {}".format(error))
        return
    if not da:
        log_error("  DA load failed: {}".format(DA))
        return
    log("  DA object={} class={}".format(object_path(da), object_name(da.get_class())))
    for prop in ("server_state_tree",):
        try:
            value = da.get_editor_property(prop)
            log("  {}={}".format(prop, object_path(value)))
        except Exception as error:
            log_error("  {} read failed: {}".format(prop, error))
    log("DA end")


def dump_parameters(tree, label):
    try:
        params = unreal.DZStateTreeEditTools.get_tree_parameters(tree)
    except Exception as error:
        log_error("PARAMS {} failed: {}".format(label, error))
        return
    log("PARAMS {} count={}".format(label, len(params)))
    for param in params:
        log("  PARAM name={} value_type={} object_path={} container={}".format(
            param.get_editor_property("name"),
            param.get_editor_property("value_type"),
            param.get_editor_property("type_object_path"),
            param.get_editor_property("container_type")))


def dump_bindings(tree, label):
    try:
        bindings = unreal.DZStateTreeEditTools.get_property_bindings(tree, unreal.Guid())
    except Exception as error:
        log_error("BINDINGS {} failed: {}".format(label, error))
        return
    log("BINDINGS {} count={}".format(label, len(bindings)))
    for index, binding in enumerate(bindings):
        log("  BINDING[{}] target_id={} target='{}' source_id={} source='{}'".format(
            index,
            binding.get_editor_property("target_struct_id"),
            binding.get_editor_property("target_path"),
            binding.get_editor_property("source_struct_id"),
            binding.get_editor_property("source_path")))


def exported_text(value):
    try:
        return value.export_text()
    except Exception:
        return str(value)


def struct_type_name(value):
    text = exported_text(value)
    if not text or text == "None":
        return "<empty>"
    return text.split("(", 1)[0].split(".")[-1]


def node_type_name(node):
    return struct_type_name(node.get_editor_property("node"))


def relevant_node(node):
    type_name = node_type_name(node)
    return type_name in RELEVANT_TYPES or type_name.startswith(RELEVANT_TYPE_MARKERS)


def dump_editor_node(tree, node, label, force=False):
    type_name = node_type_name(node)
    if not force and not relevant_node(node):
        return

    node_id = node.get_editor_property("id")
    log("    NODE {} id={} type={}".format(label, node_id, type_name))
    log("      NODE_TEXT={}".format(ascii_text(exported_text(node.get_editor_property("node")))))
    instance_text = exported_text(node.get_editor_property("instance"))
    log("      INSTANCE_TEXT={}".format(ascii_text(instance_text)))
    instance_object = node.get_editor_property("instance_object")
    log("      INSTANCE_OBJECT={}".format(object_path(instance_object)))


def dump_editor_node_list(tree, nodes, label, force=False):
    nodes = nodes or []
    log("    {} count={}".format(label, len(nodes)))
    for index, node in enumerate(nodes):
        dump_editor_node(tree, node, "{}[{}]".format(label, index), force)


def register_struct_ids(state, label, ids, depth):
    if not state:
        return
    state_id = exported_text(state.get_editor_property("id"))
    ids[state_id] = "{}STATE[depth={}]".format("  " * depth, depth)
    for index, child in enumerate(state.get_editor_property("children") or []):
        register_struct_ids(child, "{}[{}]".format(label, index), ids, depth + 1)
    node_groups = (
        ("EC", state.get_editor_property("enter_conditions")),
        ("TASK", state.get_editor_property("tasks")),
        ("SCORE", state.get_editor_property("considerations")),
    )
    for group_name, nodes in node_groups:
        for index, node in enumerate(nodes or []):
            ids[exported_text(node.get_editor_property("id"))] = "{} {}[{}]".format(label, group_name, index)
    for index, transition in enumerate(state.get_editor_property("transitions") or []):
        for index2, node in enumerate(transition.get_editor_property("conditions") or []):
            ids[exported_text(node.get_editor_property("id"))] = "{} TRANS[{}]COND[{}]".format(label, index, index2)


def dump_editor_state(tree, state, ids, depth=0):
    if not state:
        return
    indent = "  " * depth
    linked_text = exported_text(state.get_editor_property("linked_subtree"))
    log("{}STATE name={} id={} type={} behavior={} completion={} enabled={}".format(
        indent,
        ascii_text(state.get_editor_property("name")),
        state.get_editor_property("id"),
        state.get_editor_property("type"),
        state.get_editor_property("selection_behavior"),
        state.get_editor_property("tasks_completion"),
        state.get_editor_property("bEnabled")))
    log("{}  LINKED_ASSET={} LINKED_SUBTREE={}".format(
        indent,
        object_path(state.get_editor_property("linked_asset")),
        ascii_text(linked_text)))

    dump_editor_node_list(tree, state.get_editor_property("enter_conditions"), "EC")
    dump_editor_node_list(tree, state.get_editor_property("tasks"), "TASK")
    dump_editor_node_list(tree, state.get_editor_property("considerations"), "SCORE")

    transitions = state.get_editor_property("transitions") or []
    log("{}  TRANSITIONS count={}".format(indent, len(transitions)))
    for index, transition in enumerate(transitions):
        log("{}    TRANSITION[{}] id={} trigger={} priority={} enabled={} target={}".format(
            indent,
            index,
            transition.get_editor_property("id"),
            transition.get_editor_property("trigger"),
            transition.get_editor_property("priority"),
            transition.get_editor_property("bTransitionEnabled"),
            ascii_text(exported_text(transition.get_editor_property("state")))))
        required_event = transition.get_editor_property("required_event")
        log("{}      REQUIRED_EVENT={}".format(indent, ascii_text(exported_text(required_event))))
        dump_editor_node_list(tree, transition.get_editor_property("conditions"),
                              "TRANS[{}]COND".format(index))

    children = state.get_editor_property("children") or []
    log("{}  CHILDREN count={}".format(indent, len(children)))
    for index, child in enumerate(children):
        dump_editor_state(tree, child, ids, depth + 1)


def dump_tree(tree, label):
    log("TREE {} begin object={}".format(label, object_path(tree)))
    dump_parameters(tree, label)
    dump_bindings(tree, label)

    editor_data = None
    try:
        editor_data = unreal.StateTreeEditorData.get_editor_data(tree)
    except Exception as error:
        log_error("  GET-EDITOR-DATA failed: {}".format(ascii_text(error)))
    if not editor_data:
        editor_data = unreal.find_object(None, "{}:StateTreeEditorData_0".format(label))

    if not editor_data:
        log_error("  EDITOR-DATA not found")
        return

    log("  EDITOR_DATA={} schema={}".format(
        object_path(editor_data), object_path(editor_data.get_editor_property("schema"))))
    ids = {}
    subtrees = editor_data.get_editor_property("sub_trees") or []
    for index, state in enumerate(subtrees):
        register_struct_ids(state, "SUBTREE[{}]".format(index), ids, 0)

    dump_editor_node_list(tree, editor_data.get_editor_property("evaluators"), "EVALUATOR", True)
    dump_editor_node_list(tree, editor_data.get_editor_property("global_tasks"), "GLOBAL_TASK", True)
    log("  GLOBAL_TASKS_COMPLETION={}".format(
        editor_data.get_editor_property("global_tasks_completion")))
    log("  SUBTREES count={}".format(len(subtrees)))
    for index, state in enumerate(subtrees):
        dump_editor_state(tree, state, ids, 2)

    bindings = unreal.DZStateTreeEditTools.get_property_bindings(tree, unreal.Guid())
    log("  BINDING_OWNERS count={}".format(len(bindings)))
    for index, binding in enumerate(bindings):
        target_id = exported_text(binding.get_editor_property("target_struct_id"))
        source_id = exported_text(binding.get_editor_property("source_struct_id"))
        log("    OWNER-BINDING[{}] target_owner={} source_owner={} target='{}' source='{}'".format(
            index,
            ids.get(target_id, "<unknown>"),
            ids.get(source_id, "<unknown>"),
            binding.get_editor_property("target_path"),
            binding.get_editor_property("source_path")))
    log("TREE {} end".format(label))


def main():
    dump_da()
    for path in TREES:
        tree = unreal.load_asset(path)
        if not tree:
            log_error("TREE-LOAD failed {}".format(path))
            continue
        dump_tree(tree, path)
    log("DONE")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        unreal.log_error("{} TOP-LEVEL {}".format(TAG, error))
        sys.exit(2)
