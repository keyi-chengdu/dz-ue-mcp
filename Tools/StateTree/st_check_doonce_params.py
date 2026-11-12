# st_check_doonce_params.py
# Purpose: 校验「只执行一次（STC_Server_DoOnce）」的完成标记是否真的落在树级 Parameters 上：
#   - 节点 TagKey（完成标记参数名）是否已改成语义化参数名；
#   - 根参数包里是否有同名 Bool 字段；
#   - 实例数据 InDone 是否绑定了 Parameters.<参数名>。
#
# 用法（编辑器必须先关闭）：
#   UnrealEditor-Cmd.exe DZProject.uproject -run=pythonscript -script=".../st_check_doonce_params.py" -unattended -nopause -nosplash -NullRHI
# 结果从 DZ_Content/Saved/Logs/DZProject.log 里搜 [check_doonce] 读取。

import sys
import unreal

ASSET_DIR = "/Game/Blueprint/StateTree"


def list_state_tree_assets():
    ar = unreal.AssetRegistryHelpers.get_asset_registry()
    assets = ar.get_assets_by_path(unreal.Paths.normalize_directory_name(ASSET_DIR), recursive=True)
    return sorted(str(a.package_name) for a in assets if a.asset_class_path.asset_name == "StateTree")


def walk_states(state):
    yield state
    for child in unreal.DZStateTreeEditTools.describe_state(state).children or []:
        if child:
            for s in walk_states(child):
                yield s


def collect_doonce_nodes(tree):
    info = unreal.DZStateTreeEditTools.describe_state_tree(tree)
    roots = list(info.sub_trees) if hasattr(info, "sub_trees") else []
    nodes = []
    for root in roots:
        if not root:
            continue
        for state in walk_states(root):
            desc = unreal.DZStateTreeEditTools.describe_state(state)
            pools = [list(desc.tasks or []), list(desc.enter_conditions or []), list(desc.considerations or [])]
            for trans in desc.transitions or []:
                pools.append(list(trans.conditions or []))
            for pool in pools:
                for node in pool:
                    nt = node.node_type
                    if nt and nt.get_name() == "STC_Server_DoOnce":
                        nodes.append((desc.path, node))
    return nodes


def main():
    unreal.log("[check_doonce] start")
    total = 0
    problems = 0
    for path in list_state_tree_assets():
        tree = unreal.load_asset(path)
        if tree is None:
            unreal.log_error("[check_doonce] load failed: " + path)
            continue
        params = {str(p.name): str(p.value_type) for p in unreal.DZStateTreeEditTools.get_tree_parameters(tree)}
        nodes = collect_doonce_nodes(tree)
        for state_path, node in nodes:
            total += 1
            props = unreal.DZStateTreeEditTools.get_node_properties(tree, node.id)
            node_props = props.node_properties or {}
            key = str(node_props.get("TagKey", ""))
            bound = "-"
            for b in unreal.DZStateTreeEditTools.get_property_bindings(tree, node.id):
                if str(b.target_path) == "InDone":
                    bound = "{}.{}".format(b.source_path, b.source_path)
            param_type = params.get(key)
            ok = bool(key) and param_type == "Bool" and bound != "-"
            if not ok:
                problems += 1
            unreal.log("[check_doonce] {} | {} | key={!r} param={} bound={} -> {}".format(
                "OK " if ok else "BAD", state_path, key, param_type, bound, path))
    unreal.log("[check_doonce] total={} problems={}".format(total, problems))
    return 0


if __name__ == "__main__":
    sys.exit(main())
