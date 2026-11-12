# st_check_enemy_ai_controller.py - inspect BP_Enemy CDO AI controller settings
import unreal

BP = "/Game/Blueprint/Character/Enemy/Common/BP_Enemy"


def main():
    bp = unreal.load_asset(BP)
    if bp is None:
        unreal.log_error("[aicheck] load failed: " + BP)
        return 1

    cdo = unreal.get_default_object(unreal.load_class(None, BP + ".BP_Enemy_C"))
    if cdo is None:
        unreal.log_error("[aicheck] no CDO")
        return 1

    for prop in ("AIControllerClass", "AutoPossessAI", "bAutoPossessAI"):
        try:
            value = cdo.get_editor_property(prop)
            unreal.log("[aicheck] {} = {}".format(prop, value))
        except Exception as exc:  # noqa: BLE001
            unreal.log("[aicheck] {} -> {}".format(prop, exc))

    # 组件清单
    try:
        comps = cdo.get_editor_property("BlueprintCreatedComponents")
        names = []
        for c in comps:
            if c:
                names.append("{}:{}".format(c.get_name(), c.get_class().get_name()))
        unreal.log("[aicheck] components = {}".format(names))
    except Exception as exc:  # noqa: BLE001
        unreal.log("[aicheck] components -> {}".format(exc))

    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
