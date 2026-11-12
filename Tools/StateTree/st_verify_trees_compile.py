# st_verify_trees_compile.py - compile every StateTree and report per-asset result
import sys
import unreal

ASSET_DIR = "/Game/Blueprint/StateTree"


def list_trees():
    ar = unreal.AssetRegistryHelpers.get_asset_registry()
    assets = ar.get_assets_by_path(unreal.Paths.normalize_directory_name(ASSET_DIR), recursive=True)
    return sorted(str(a.package_name) for a in assets if a.asset_class_path.asset_name == "StateTree")


def main():
    ok = 0
    bad = []
    for path in list_trees():
        tree = unreal.load_asset(path)
        if tree is None:
            bad.append((path, "load failed"))
            continue
        result = unreal.DZStateTreeEditTools.compile_state_tree(tree)
        success = bool(result.get_editor_property("bSucceeded"))
        if success:
            ok += 1
        else:
            msgs = []
            for m in result.get_editor_property("messages"):
                msgs.append(str(m.get_editor_property("message")))
            bad.append((path, " | ".join(msgs)[:300]))

    unreal.log_warning("[verify] OK={} BAD={}".format(ok, len(bad)))
    for path, msg in bad:
        unreal.log_warning("[verify] BAD " + path)
        unreal.log_warning("[verify]     " + msg)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
