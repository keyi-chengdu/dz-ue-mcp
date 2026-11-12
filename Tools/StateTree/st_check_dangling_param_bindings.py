# st_check_dangling_param_bindings.py
# 检查每棵树的绑定：源是 Parameters.X 但本树根参数包没有 X（悬空绑定，运行时不生效）
import sys
import unreal

ASSET_DIR = "/Game/Blueprint/StateTree"


def list_trees():
    ar = unreal.AssetRegistryHelpers.get_asset_registry()
    assets = ar.get_assets_by_path(unreal.Paths.normalize_directory_name(ASSET_DIR), recursive=True)
    return sorted(str(a.package_name) for a in assets if a.asset_class_path.asset_name == "StateTree")


def main():
    total_dangling = 0

    for path in list_trees():
        tree = unreal.load_asset(path)
        if tree is None:
            continue

        params = unreal.DZStateTreeEditTools.get_tree_parameters(tree)
        root_names = set(str(p.get_editor_property("name")) for p in params)

        bindings = unreal.DZStateTreeEditTools.get_property_bindings(tree, unreal.Guid())
        dangling = []
        for b in bindings:
            src = str(b.get_editor_property("source_path"))
            # 绑定源串形如 "Parameters.ACTOR_TARGET" 或 "ACTOR_TARGET"
            leaf = src.split(".")[-1].strip()
            if isinstance(leaf, str) and leaf and leaf not in root_names:
                # 只关心看起来像全局参数（全大写/已知名字）的源
                if leaf.isupper() or leaf in (
                    "ACTOR_TARGET", "ATTACK_TARGET", "HAS_POINT_TARGET", "POINT_TARGET",
                    "LAST_SELFATTACKER", "EnemyAttackData", "EnemyPlayMontageTag",
                    "MoveRequestOver", "ParallelAttackBehavior"):
                    dangling.append("{} -> {}".format(src, b.get_editor_property("target_path")))

        if dangling:
            unreal.log("[dangle] {}  rootParams={}".format(path, sorted(root_names)))
            for d in dangling:
                unreal.log("[dangle]     " + d)
            total_dangling += len(dangling)

    unreal.log("[dangle] TOTAL={}".format(total_dangling))
    return 0


if __name__ == "__main__":
    sys.exit(main())
