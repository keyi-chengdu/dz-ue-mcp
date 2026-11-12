# st_inspect_edgraph2.py - inspect EdGraph nodes via get_editor_property
import unreal

bp = unreal.load_asset("/Game/Blueprint/StateTree/Common/Task/STT_Enemy_Turn")
graph = unreal.BlueprintEditorLibrary.find_event_graph(bp)
print("Graph name: " + graph.get_name())
nodes = graph.get_editor_property("nodes")
print("Nodes type: " + str(type(nodes)))
print("Nodes len: " + str(len(nodes)))
for node in nodes:
    print("  Node: " + node.get_name() + " Class: " + node.get_class().get_name())
