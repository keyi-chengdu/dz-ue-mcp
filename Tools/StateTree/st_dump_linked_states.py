# st_dump_linked_states.py - for every StateTree, dump its linked subtrees and the State Parameters on each link
import sys
import unreal

ASSET_DIR = "/Game/Blueprint/StateTree"


def list_trees():
    ar = unreal.AssetRegistryHelpers.get_asset_registry()
    assets = ar.get_assets_by_path(unreal.Paths.normalize_directory_name(ASSET_DIR), recursive=True)
    return sorted(str(a.package_name) for a in assets if a.asset_class_path.asset_name == "StateTree")


def main():
    for path in list_trees():
        tree = unreal.load_asset(path)
        if tree is None:
            unreal.log_error("[link] load failed: " + path)
            continue

        lines = unreal.DZStateTreeEditTools.describe_linked_states(tree)
        if not lines:
            continue

        unreal.log("[link] ===== " + path)
        for line in lines:
            unreal.log("[link]   " + str(line))

    return 0


if __name__ == "__main__":
    sys.exit(main())
