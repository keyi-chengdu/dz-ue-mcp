# st_check_enemy_asset.py - inspect UDZEnemyAsset fields for a given EnemyID
import sys
import unreal

ASSET_DIRS = [
    "/Game/Asset/Enemy",
]


def find_asset(enemy_id):
    ar = unreal.AssetRegistryHelpers.get_asset_registry()
    for d in ASSET_DIRS:
        assets = ar.get_assets_by_path(unreal.Paths.normalize_directory_name(d), recursive=False)
        for a in assets:
            if a.asset_name == "DA_" + enemy_id:
                return str(a.package_name)
    return None


def dump(enemy_id):
    path = find_asset(enemy_id)
    if not path:
        unreal.log_error("[enemyasset] not found for " + enemy_id)
        return
    obj = unreal.load_asset(path)
    if obj is None:
        unreal.log_error("[enemyasset] load failed " + path)
        return

    unreal.log("[enemyasset] {} -> {}".format(enemy_id, path))
    for prop in ("DZAIController", "BP_EnemyCharacter", "EnemyType", "EnemyRankType"):
        try:
            unreal.log("[enemyasset]   {} = {}".format(prop, obj.get_editor_property(prop)))
        except Exception as exc:  # noqa: BLE001
            unreal.log("[enemyasset]   {} -> {}".format(prop, exc))


def main():
    for eid in ("05002101", "05003101"):
        dump(eid)
    return 0


if __name__ == "__main__":
    sys.exit(main())
