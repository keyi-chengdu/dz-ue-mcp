"""Inspect/configure the ST_Test generic parallel-event chain through remote Python.

Usage (system Python, current project editor running):
  python st_parallel_event_remote.py inspect
  python st_parallel_event_remote.py bind
  python st_parallel_event_remote.py setup

The script selects the editor whose project path contains DZ_Project_New.
"""
import sys
import time
from pathlib import Path

UE_PYTHON = Path(r"C:\UE\Engines\UE_5.8\Engine\Plugins\Experimental\PythonScriptPlugin\Content\Python")
sys.path.insert(0, str(UE_PYTHON))
import remote_execution  # noqa: E402


START_MCP_CODE = r"""
import unreal
unreal.SystemLibrary.execute_console_command(None, 'ModelContextProtocol.StartServer 8000')
"""

QUIT_CODE = r"""
import unreal
unreal.SystemLibrary.execute_console_command(None, 'QUIT_EDITOR')
"""

SIMULATE_CODE = r"""
import unreal
level_editor = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
level_editor.load_level('/Game/Maps/Test_Level/Lv_Test_AI')
unreal.SystemLibrary.execute_console_command(None, 'Log LogDZAI Verbose')
unreal.SystemLibrary.execute_console_command(None, 'Log LogStateTree Verbose')
level_editor.editor_play_simulate()
"""

STOP_PIE_CODE = r"""
import unreal
level_editor = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
level_editor.editor_request_end_play()
"""

INSPECT_CODE = r"""
import unreal

TOOLS = unreal.DZStateTreeEditTools

def walk(tree, state, depth=0):
    info = TOOLS.describe_state(state)
    unreal.log_warning('STATE ' + ('  ' * depth) + str(info.name) + ' | ' + str(state.get_path_name()))
    unreal.log_warning('  REQUIRED_EVENT ' + str(state.get_editor_property('required_event_to_enter')) + ' | HAS=' + str(state.get_editor_property('bHasRequiredEventToEnter')))
    for task in info.tasks:
        unreal.log_warning('  TASK ' + str(task.name) + ' | ' + str(task.node_type) + ' | ' + str(task.iD))
        unreal.log_warning('    ' + str(TOOLS.get_node_properties(tree, task.iD)))
    for child in info.children:
        walk(tree, child, depth + 1)

for path in [
    '/Game/Blueprint/StateTree/Temp/ST_Test.ST_Test',
    '/Game/Blueprint/StateTree/Temp/ST_ParTest.ST_ParTest',
]:
    tree = unreal.load_asset(path)
    unreal.log_warning('TREE ' + path)
    unreal.log_warning('PARAMS ' + str(TOOLS.get_tree_parameters(tree)))
    editor_data = unreal.StateTreeEditorData.get_editor_data(tree)
    for root in editor_data.get_editor_property('sub_trees') or []:
        walk(tree, root)
"""

ACTORS_CODE = r"""
import unreal
actors = unreal.EditorLevelLibrary.get_all_level_actors()
for actor in actors:
    name = actor.get_name()
    if 'DefaultPawn' in name or 'STPar' in name or 'Runner' in name:
        unreal.log_warning('ACTOR ' + name + ' | ' + actor.get_class().get_path_name())
        for component in actor.get_components_by_class(unreal.StateTreeComponent):
            unreal.log_warning('  ST ' + component.get_path_name())
            unreal.log_warning('  ' + str(component))
"""

PROBE_CODE = r"""
import unreal
unreal.log_warning('SPAWN ' + str(unreal.EditorLevelLibrary.spawn_actor_from_class.__doc__))
unreal.log_warning('NEWOBJECT ' + str(unreal.new_object.__doc__))
unreal.log_warning('ST METHODS ' + str([x for x in dir(unreal.StateTreeComponent) if 'tree' in x.lower() or 'register' in x.lower() or 'logic' in x.lower()]))
unreal.log_warning('ST REF METHODS ' + str([x for x in dir(unreal.StateTreeReference) if 'tree' in x.lower() or 'param' in x.lower()]))
unreal.log_warning('ACTOR COMPONENT METHODS ' + str([x for x in dir(unreal.Actor) if 'component' in x.lower()]))
unreal.log_warning('ST CLASS ' + unreal.StateTreeComponent.static_class().get_path_name()
                  + ' | SCENE_RUNNER=' + str(hasattr(unreal, 'SceneSTRunner')))
"""

SETUP_CODE = r"""
import unreal
tree = unreal.load_asset('/Game/Blueprint/StateTree/Temp/ST_Test.ST_Test')
runner = None
for actor in unreal.EditorLevelLibrary.get_all_level_actors():
    component = actor.get_component_by_class(unreal.StateTreeComponent)
    if component:
        runner = (actor, component)
        break

if runner is None:
    actor = unreal.EditorLevelLibrary.spawn_actor_from_class(unreal.SceneSTRunner, unreal.Vector(0, 0, 100))
    if actor is None:
        raise RuntimeError('failed to spawn SceneSTRunner')
    actor.set_actor_label('STParRunner')
    component = actor.get_component_by_class(unreal.StateTreeComponent)
    if component is None:
        raise RuntimeError('SceneSTRunner has no StateTreeComponent')
    runner = (actor, component)

actor, component = runner
component.set_state_tree(tree)
component.set_start_logic_automatically(True)
unreal.log_warning(
    'RUNNER ' + actor.get_path_name() + ' | ' + component.get_path_name()
    + ' | STATUS=' + str(component.get_state_tree_run_status()))
"""

BIND_EXISTING_CODE = r"""
import unreal
tree = unreal.load_asset('/Game/Blueprint/StateTree/Temp/ST_Test.ST_Test')
bound = 0
for actor in unreal.EditorLevelLibrary.get_all_level_actors():
    for component in actor.get_components_by_class(unreal.StateTreeComponent):
        component.set_state_tree(tree)
        component.set_start_logic_automatically(True)
        bound += 1
        unreal.log_warning(
            'BOUND ' + actor.get_name() + ' | ' + component.get_name()
            + ' | STATUS=' + str(component.get_state_tree_run_status()))
unreal.log_warning('BOUND_COUNT ' + str(bound))
"""


def main():
    remote = remote_execution.RemoteExecution()
    remote.start()
    try:
        deadline = time.time() + 10
        node = None
        while time.time() < deadline and node is None:
            node = next((n for n in remote.remote_nodes if 'DZ_Project_New' in n['project_root']), None)
            if node is None:
                time.sleep(0.2)
        if node is None:
            raise RuntimeError('DZ_Project_New editor was not discovered')
        remote.open_command_connection(node['node_id'])
        remote.run_command(START_MCP_CODE, raise_on_failure=True)
        action = sys.argv[1] if len(sys.argv) > 1 else 'inspect'
        code = (
            ACTORS_CODE if action == 'actors'
            else PROBE_CODE if action == 'probe'
            else SETUP_CODE if action in ('setup', 'ensure')
            else BIND_EXISTING_CODE if action == 'bind'
            else SIMULATE_CODE if action == 'simulate'
            else STOP_PIE_CODE if action == 'stop'
            else QUIT_CODE if action == 'quit'
            else INSPECT_CODE
        )
        result = remote.run_command(code, raise_on_failure=True)
        print(result)
    finally:
        remote.stop()


if __name__ == '__main__':
    main()
