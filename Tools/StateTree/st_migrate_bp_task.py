# st_migrate_bp_task.py - migrate STT_Enemy_Turn and STT_LineTrace off TryGetTreeParam
import unreal

def migrate_bp(path, param_key, var_name):
    bp = unreal.load_asset(path)
    if bp is None:
        unreal.log_error("load failed: " + path)
        return False
    
    unreal.log("Migrating " + path + " param=" + param_key + " var=" + var_name)
    
    graph = unreal.BlueprintEditorLibrary.find_event_graph(bp)
    if graph is None:
        unreal.log_error("no event graph: " + path)
        return False
    
    unreal.log("Got event graph: " + graph.get_name())
    for node in graph.nodes:
        unreal.log("  Node: " + node.get_name() + " Class: " + node.get_class().get_name())
        if node.get_class().get_name() == "K2Node_CallFunction":
            fn = node.get_editor_property("function_reference")
            if fn:
                unreal.log("    Function: " + str(fn.get_editor_property("member_name")))
    
    return True

if __name__ == "__main__":
    migrate_bp("/Game/Blueprint/StateTree/Common/Task/STT_Enemy_Turn", "ACTOR_TARGET", "InTargetActor")
    migrate_bp("/Game/Blueprint/StateTree/Common/Task/STT_LineTrace", "ACTOR_TARGET", "InTargetActor")
