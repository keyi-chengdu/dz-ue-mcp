# st_dump_bp_task.py - read-only dump of Blueprint task graphs.
# UE 5.8 command-line usage:
# UnrealEditor-Cmd.exe <uproject> -run=pythonscript -script="<this>" -unattended -nopause -nosplash -NullRHI -noscc
import unreal
from editor_toolset.toolsets.blueprint import BlueprintTools


OUTPUT_PATH = r"C:\Users\02\AppData\Local\Temp\st_dump_bp_task.out"
ASSET_PATHS = [
    "/Game/Blueprint/StateTree/Common/Task/STT_LineTrace",
    "/Game/Blueprint/StateTree/Common/Task/BP_ANS_Enemy_FaceTarget",
]


def dump_bp(path):
    bp = unreal.load_asset(path)
    if bp is None:
        return f"LOAD FAILED {path}\n"

    lines = [f"=== {path} ==="]
    parent = BlueprintTools.get_parent(bp)
    lines.append(f"parent={parent.get_name()} path={parent.get_path_name()}")

    variables = unreal.BlueprintEditorLibrary.list_member_variable_names(bp, False)
    lines.append("member_variables=" + ",".join(str(v) for v in variables))

    event_graph = unreal.BlueprintEditorLibrary.find_event_graph(bp)
    if event_graph is None:
        lines.append("event_graph=<none>")
    else:
        graph_editor = unreal.BlueprintGraphEditor.get_graph_editor(event_graph)
        local_variables = graph_editor.list_local_variable_names()
        lines.append("event_graph=" + event_graph.get_name())
        lines.append("local_variables=" + ",".join(str(v) for v in local_variables))
        dsl = BlueprintTools.read_graph_dsl(event_graph)
        lines.append("BEGIN DSL")
        lines.extend(dsl.splitlines())
        lines.append("END DSL")
    lines.append("")
    return "\n".join(lines)


def main():
    chunks = []
    for path in ASSET_PATHS:
        chunks.append(dump_bp(path))
    with open(OUTPUT_PATH, "w", encoding="utf-8") as output_file:
        output_file.write("\n".join(chunks))
    unreal.log_warning(f"DUMP-BP-TASK output={OUTPUT_PATH}")


main()
