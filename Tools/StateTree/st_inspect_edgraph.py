# st_inspect_edgraph.py - inspect EdGraph methods
import unreal

bp = unreal.load_asset("/Game/Blueprint/StateTree/Common/Task/STT_Enemy_Turn")
graph = unreal.BlueprintEditorLibrary.find_event_graph(bp)
print("EdGraph methods:")
for m in dir(graph):
    if not m.startswith("_"):
        print("  " + m)
