# -*- coding: utf-8 -*-
"""Audit or fix Blueprint parent classes for GameplayAbility assets.

Run with the editor closed:
  UnrealEditor-Cmd.exe DZProject.uproject -run=pythonscript \
    -script="<this file>" -stdout -unattended -nopause -nosplash -NullRHI -noscc

Optional command-line options:
  -GasMode=audit|fix            Default is audit; fix writes and saves.
  -Asset=/Game/Path/Asset       Overrides the built-in audit list for one asset.
  -Parent=/Script/Module.Class  Required with -Asset=-Mode=fix.

The built-in list records the 2026-11-11 enemy GA normalization decision:
PlayMontage migrates to the _New C++ shell; Attack intentionally remains on the
event-dispatch base so Blueprint/Lua can implement concrete attacks.
"""

import re
import sys
import unreal


AUDIT_SPECS = [
    ("/Game/Blueprint/Character/Enemy/Common/GA_Enemy_PlayMontage",
     "/Script/DZProject.DZGA_EnemyPlayMontage_New"),
    ("/Game/Blueprint/Character/Enemy/Common/GA_Enemy_Attack",
     "/Script/DZProject.DZGA_EnemyAttackBase"),
]


def log(message):
    unreal.log_warning("[gas-parent] {}".format(message))


def error(message):
    unreal.log_error("[gas-parent] {}".format(message))


def command_options():
    command_line = unreal.SystemLibrary.get_command_line()
    options = {}
    pattern = re.compile(r'(?P<key>[A-Za-z][A-Za-z0-9_]*)=(?:"(?P<quoted>[^"]*)"|(?P<plain>[^\s]+))')
    for match in pattern.finditer(command_line):
        key = match.group("key").lower()
        options[key] = match.group("quoted") or match.group("plain")
    return options


def load_asset(path):
    asset = unreal.EditorAssetLibrary.load_asset(path)
    if not asset:
        error("load failed: {}".format(path))
    return asset


def parent_name(asset):
    parent = asset.get_blueprint_parent_class() if asset else None
    return parent.get_name() if parent else "<none>"


def check_one(asset_path, expected_path):
    asset = load_asset(asset_path)
    expected = unreal.load_class(None, expected_path) if asset else None
    if asset and not expected:
        error("parent class load failed: {}".format(expected_path))

    actual = parent_name(asset)
    expected_name = expected.get_name() if expected else "<none>"
    ok = bool(expected and actual == expected_name)
    log("{} actual={} expected={} ok={}".format(asset_path, actual, expected_name, ok))
    if not ok:
        error("expected {} parent={}".format(asset_path, expected_path))
    return ok


def fix_one(asset_path, expected_path):
    asset = load_asset(asset_path)
    expected = unreal.load_class(None, expected_path) if asset else None
    if not asset or not expected:
        return False

    actual = parent_name(asset)
    if actual != expected.get_name():
        log("reparent {} {} -> {}".format(asset_path, actual, expected.get_name()))
        unreal.BlueprintEditorLibrary.reparent_blueprint(asset, expected)

    if not unreal.BlueprintEditorLibrary.compile_blueprint(asset):
        error("compile failed: {}".format(asset_path))
        return False

    saved = unreal.EditorAssetLibrary.save_loaded_asset(asset, only_if_is_dirty=False)
    final = parent_name(asset)
    log("save={} final={}".format(saved, final))
    return bool(saved and final == expected.get_name())


def main():
    options = command_options()
    mode = options.get("gasmode", "audit").lower()
    asset_override = options.get("asset", "")
    parent_override = options.get("parent", "")

    if asset_override:
        if not parent_override:
            error("-Parent is required when -Asset is supplied")
            return 2
        specs = [(asset_override, parent_override)]
    else:
        specs = AUDIT_SPECS

    if mode not in ("audit", "fix"):
        error("unknown -GasMode={} (use audit or fix)".format(mode))
        return 2

    failures = 0
    for asset_path, expected_path in specs:
        if mode == "fix":
            ok = fix_one(asset_path, expected_path)
        else:
            ok = check_one(asset_path, expected_path)
        failures += 0 if ok else 1

    log("SUMMARY mode={} assets={} failures={}".format(mode, len(specs), failures))
    return failures


if __name__ == "__main__":
    raise SystemExit(main())
