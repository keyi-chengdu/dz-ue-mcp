# st_check_ai_controller_comp.py - list components on BP_DZAIController CDO
import unreal

BP = "/Game/Core/BP_DZAIController"


def main():
    cls = unreal.load_class(None, BP + ".BP_DZAIController_C")
    if cls is None:
        unreal.log_error("[aicomp] class load failed")
        return 1

    cdo = unreal.get_default_object(cls)
    try:
        comps = cdo.get_editor_property("BlueprintCreatedComponents")
        for c in comps:
            if c:
                unreal.log("[aicomp] {} : {}".format(c.get_name(), c.get_class().get_name()))
        if not comps:
            unreal.log("[aicomp] <no blueprint-created components>")
    except Exception as exc:  # noqa: BLE001
        unreal.log("[aicomp] components -> {}".format(exc))

    # C++ 默认组件：用 FindComponentByClass 在 CDO 上试
    for name in ("NetStateTreeComponent",):
        try:
            found = cdo.get_editor_property(name)
            unreal.log("[aicomp] prop {} = {}".format(name, found))
        except Exception:  # noqa: BLE001
            pass

    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
