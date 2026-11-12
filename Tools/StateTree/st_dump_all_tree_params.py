# st_dump_all_tree_params.py - dump root parameters of every StateTree asset
import sys
import unreal

ASSET_DIR = "/Game/Blueprint/StateTree"


def list_trees():
    ar = unreal.AssetRegistryHelpers.get_asset_registry()
    assets = ar.get_assets_by_path(unreal.Paths.normalize_directory_name(ASSET_DIR), recursive=True)
    paths = []
    for asset in assets:
        if asset.asset_class_path.asset_name == "StateTree":
            paths.append(str(asset.package_name))
    return sorted(paths)


def dump(path):
    tree = unreal.load_asset(path)
    if tree is None:
        unreal.log_error("[params] load failed: " + path)
        return
    params = unreal.DZStateTreeEditTools.get_tree_parameters(tree)
    names = [str(p.get_editor_property("name")) for p in params]
    unreal.log("[params] {:60s} count={} :: {}".format(path, len(names), ", ".join(names)))


def main():
    for path in list_trees():
        dump(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
