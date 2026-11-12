# st_inspect_tree.py - inspect root params and bindings of a single StateTree
import unreal

def main():
    path = "/Game/Blueprint/StateTree/05002101/ST_Sub_05002101_Battle"
    tree = unreal.load_asset(path)
    if tree is None:
        unreal.log_error("load failed")
        return
    params = unreal.DZStateTreeEditTools.get_tree_parameters(tree)
    unreal.log("ROOT PARAMS ({}):".format(len(params)))
    for p in params:
        unreal.log("  {} ({})".format(str(p.name), str(p.value_type)))

if __name__ == "__main__":
    main()
