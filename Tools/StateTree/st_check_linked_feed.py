# st_check_linked_feed.py
# 检查每个链接态（LinkedAsset）的 State Parameters 是否已从主树根参数供数。
# 判断口径：
#   - 链接态 State Parameters 里有某字段（引擎会把它当子树的全局参数传入）
#   - 树绑定里存在「源 = 树根参数 Parameters.X」→「目标 = 该链接态 State Parameter X」
# 两者都满足才算已供数；只有字段没有绑定 = 缺供数（子树拿到默认值）。
import sys
import unreal

ASSET_DIR = "/Game/Blueprint/StateTree"

# 子树需要受数的字段（与 st_fill_subtree_root_params.py 保持一致）
WANTED = [
    "ACTOR_TARGET",
    "ATTACK_TARGET",
    "HAS_POINT_TARGET",
    "POINT_TARGET",
    "LAST_SELFATTACKER",
    "EnemyAttackData",
    "EnemyPlayMontageTag",
    "MoveRequestOver",
]


def list_trees():
    ar = unreal.AssetRegistryHelpers.get_asset_registry()
    assets = ar.get_assets_by_path(unreal.Paths.normalize_directory_name(ASSET_DIR), recursive=True)
    return sorted(str(a.package_name) for a in assets if a.asset_class_path.asset_name == "StateTree")


def norm(name):
    """把显示名归一化：'ACTOR TARGET' -> 'ACTOR_TARGET'"""
    return str(name).replace(" ", "_").strip()


def main():
    for path in list_trees():
        tree = unreal.load_asset(path)
        if tree is None:
            continue

        linked_lines = unreal.DZStateTreeEditTools.describe_linked_states(tree)
        if not linked_lines:
            continue

        bindings = unreal.DZStateTreeEditTools.get_property_bindings(tree, unreal.Guid())
        # 收集所有目标端名字（归一化）
        fed_targets = set()
        for b in bindings:
            tgt = norm(b.get_editor_property("target_path"))
            if tgt:
                fed_targets.add(tgt)
                # 也加入叶子名
                fed_targets.add(tgt.split(".")[-1])

        unreal.log("[feed] ==== " + path)
        for line in linked_lines:
            text = str(line)
            # 解析 "… | LinkedAsset=… | Parameters: A, B"
            params_part = text.split("Parameters:")[-1].strip()
            declared = [] if params_part == "<none>" else [p.strip() for p in params_part.split(",")]

            # 该链接态声明了哪些 WANTED 字段
            declared_wanted = [w for w in WANTED if w in declared]
            missing_decl = [w for w in WANTED if w not in declared]

            # 声明了但是否有绑定喂它
            unfed = []
            for w in declared_wanted:
                if w not in fed_targets and norm(w) not in fed_targets:
                    unfed.append(w)

            unreal.log("[feed]   {}".format(text.split(" | LinkedAsset")[0]))
            unreal.log("[feed]       declared={} ".format(declared))
            if missing_decl:
                unreal.log("[feed]       NOT_DECLARED={}".format(missing_decl))
            if unfed:
                unreal.log("[feed]       DECLARED_BUT_UNFED={}".format(unfed))

    return 0


if __name__ == "__main__":
    sys.exit(main())
