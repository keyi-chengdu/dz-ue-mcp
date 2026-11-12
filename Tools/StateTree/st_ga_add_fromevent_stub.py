# st_ga_add_fromevent_stub.py
# Purpose: add the K2_ActivateAbilityFromEvent empty stub to GA_Enemy_PlayMontage.
#          GA blueprints keep their graph in "Gameplay Ability Graph"; MCP's add_event is
#          EventGraph-only and BlueprintEditorLibrary.add_event_override does not take effect
#          there, so we call the C++ tool UDZStateTreeEditTools::AddBlueprintEventStub.
#
# Usage (editor MUST be closed):
#   UnrealEditor-Cmd.exe DZProject.uproject -run=pythonscript -script=".../st_ga_add_fromevent_stub.py" -unattended -nopause -nosplash -NullRHI

import sys
import unreal

BP_PATH = "/Game/Blueprint/Character/Enemy/Common/GA_Enemy_PlayMontage.GA_Enemy_PlayMontage"
EVENT_NAME = "K2_ActivateAbilityFromEvent"


def main():
    bp = unreal.load_asset(BP_PATH)
    if bp is None:
        unreal.log_error("[ga_stub] load failed: " + BP_PATH)
        return 1

    added = unreal.DZStateTreeEditTools.add_blueprint_event_stub(bp, unreal.Name(EVENT_NAME))
    unreal.log("[ga_stub] added={}".format(added))

    unreal.BlueprintEditorLibrary.compile_blueprint(bp)
    unreal.EditorAssetLibrary.save_loaded_asset(bp, only_if_is_dirty=False)

    # 验证：图里是否出现该事件节点
    graphs = unreal.BlueprintEditorLibrary.list_graphs(bp)
    for g in graphs:
        name = str(unreal.BlueprintEditorLibrary.get_name(g))
        if "Ability" in name:
            unreal.log("[ga_stub] graph '{}' nodes:".format(name))
            try:
                nodes = g.get_editor_property("nodes")
                for n in nodes:
                    unreal.log("[ga_stub]    {}".format(n.get_class().get_name()))
            except Exception as exc:  # noqa: BLE001
                unreal.log("[ga_stub]    (nodes unreadable: {})".format(exc))

    unreal.log("[ga_stub] compiled + saved")
    return 0


if __name__ == "__main__":
    sys.exit(main())
