# st_set_05002102_ref_defaults.py
# Purpose: Set the default ref types for StateTreeBlueprintPropertyRef parameters in
#          ST_Sub_05002102_Battle. The linked-state feed from ST_05002102 supplies the
#          actual runtime value, but each Battle parameter must know its concrete ref type.
#
# Usage (editor MUST be closed):
#   UnrealEditor-Cmd.exe DZProject.uproject -run=pythonscript ^
#     -script=".../st_set_05002102_ref_defaults.py" -stdout -unattended -nopause -nosplash -NullRHI -noscc
#   Add -Execute to save Battle and Main. Without it the run is DRY-only.
#
# Pitfalls:
#   1. FStateTreeBlueprintPropertyRef defaults must use UDZStateTreeEditTools::
#      SetTreeParameterRefDefault; it writes through ImportText_Direct.
#   2. Native struct paths have no leading F, e.g. /Script/DZProject.AttackTaskData.
#   3. Save uses only_if_is_dirty=False because the C++ helper does not mark the asset dirty.

import sys
import unreal


MAIN = "/Game/Blueprint/StateTree/05002102/ST_05002102"
BATTLE = "/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle"
TAG = "[st-set-ref]"

REF_DEFAULTS = [
    ("ACTOR_TARGET", "Object", "/Script/Engine.Actor"),
    ("ATTACK_TARGET", "Object", "/Script/Engine.Actor"),
    ("POINT_TARGET", "Struct", "/Script/CoreUObject.Vector"),
    ("HAS_POINT_TARGET", "Bool", ""),
    ("EnemyAttackData", "Struct", "/Script/DZProject.AttackTaskData"),
    ("EnemyPlayMontageTag", "Struct", "/Script/GameplayTags.GameplayTag"),
]

_CMD_LINE = (unreal.SystemLibrary.get_command_line()
             if hasattr(unreal, "SystemLibrary") else " ".join(sys.argv)).lower()
EXECUTE = "-execute" in _CMD_LINE


def log(text):
    unreal.log_warning("{} {}".format(TAG, text))


def load_tree(path, label):
    tree = unreal.EditorAssetLibrary.load_asset(path)
    if not isinstance(tree, unreal.StateTree):
        log("LOADFAIL {} {}".format(label, path))
        return None
    log("LOADED {} {}".format(label, path))
    return tree


def set_ref_defaults(tree):
    ok = 0
    failed = 0
    for param_name, ref_type, type_path in REF_DEFAULTS:
        try:
            result = unreal.DZStateTreeEditTools.set_tree_parameter_ref_default(
                tree, param_name, ref_type, type_path
            )
            if bool(result):
                log("SETREF {} ok type={} path={}".format(param_name, ref_type, type_path or "None"))
                ok += 1
            else:
                log("SETREF {} failed type={} path={}".format(param_name, ref_type, type_path or "None"))
                failed += 1
        except Exception as error:
            log("SETREF {} exception: {}".format(param_name, error))
            failed += 1
    return ok, failed


def compile_tree(tree, label):
    result = unreal.DZStateTreeEditTools.compile_state_tree(tree)
    success = bool(result.get_editor_property("bSucceeded"))
    messages = []
    for message in result.get_editor_property("messages"):
        messages.append(str(message.get_editor_property("message")))
    if success:
        log("COMPILE {} ok messages={}".format(label, len(messages)))
    else:
        log("COMPILE {} failed messages={}".format(label, len(messages)))
        for message in messages:
            log("COMPILE {} msg {}".format(label, message))
    return success


def save_tree(tree, label):
    saved = unreal.EditorAssetLibrary.save_loaded_asset(tree, only_if_is_dirty=False)
    log("SAVED {} {}".format(label, bool(saved)))
    return bool(saved)


def main():
    log("MODE execute={}".format(EXECUTE))
    battle = load_tree(BATTLE, "BATTLE")
    main_tree = load_tree(MAIN, "MAIN")
    if battle is None or main_tree is None:
        return 2

    ok, failed = set_ref_defaults(battle)
    if failed:
        log("RESULT abort set ok={} failed={}".format(ok, failed))
        return 3

    if not compile_tree(battle, "BATTLE"):
        log("RESULT abort battle-compile")
        return 4
    if not compile_tree(main_tree, "MAIN"):
        log("RESULT abort main-compile")
        return 5

    if EXECUTE:
        if not save_tree(battle, "BATTLE"):
            return 6
        if not save_tree(main_tree, "MAIN"):
            return 7

    log("RESULT ok set={} execute={}".format(ok, EXECUTE))
    return 0


if __name__ == "__main__":
    sys.exit(main())
