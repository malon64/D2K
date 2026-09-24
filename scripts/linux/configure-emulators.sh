#!/usr/bin/env bash
# Merges the D2K overlays in docs/emulator-configs/linux/ into each emulator's
# own Linux configuration. Only the overlay's keys change, so BIOS paths,
# controllers, saves and user preferences survive. --check verifies them.
set -euo pipefail

if [[ ${1:-} == --self-test ]]; then
    test_home=$(mktemp -d)
    trap 'rm -rf "$test_home"' EXIT
    HOME="$test_home" XDG_CONFIG_HOME="$test_home/.config" "$0"
    HOME="$test_home" XDG_CONFIG_HOME="$test_home/.config" "$0" --check
    echo 'Emulator configuration self-test passed.'
    exit 0
fi
if [[ $# -gt 1 || ( $# -eq 1 && $1 != --check ) ]]; then
    echo "Usage: $0 [--check|--self-test]" >&2
    exit 2
fi

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

python3 - "$repo_root" "$config_home" "$HOME" "$software_dir" "${1:-}" <<'PY'
import configparser
import json
import pathlib
import re
import sys

repo, config_home, home, software = map(pathlib.Path, sys.argv[1:5])
check = sys.argv[5] == "--check"
templates = repo / "docs/emulator-configs/linux"


def read_ini(path):
    config = configparser.RawConfigParser(interpolation=None, strict=False)
    config.optionxform = str
    if path.exists():
        config.read(path, encoding="utf-8-sig")
    return config


def overlay_ini(template, destination):
    """Set each template key in place, keeping the file's comments and order."""
    lines = destination.read_text(encoding="utf-8").splitlines(keepends=True) if destination.exists() else []
    for section in (overlay := read_ini(template)).sections():
        values = dict(overlay.items(section))
        out, current, seen = [], None, set()

        def flush():
            out.extend(f"{key} = {value}\n" for key, value in values.items() if key not in seen)

        for line in lines:
            header = re.match(r"^\[([^]]+)\]", line)
            if header:
                if current == section:
                    flush()
                current = header.group(1)
            key = next((k for k in values if current == section
                        and re.match(rf"^{re.escape(k)}\s*=", line)), None)
            if key:
                out.append(f"{key} = {values[key]}\n")
                seen.add(key)
            else:
                out.append(line)
        if current == section:
            flush()
        elif not any(re.match(rf"^\[{re.escape(section)}\]", line) for line in lines):
            if out and out[-1].strip():
                out.append("\n")
            out.append(f"[{section}]\n")
            flush()
        lines = out
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text("".join(lines), encoding="utf-8")


def ini_mismatches(template, destination):
    actual = read_ini(destination)
    for section in (expected := read_ini(template)).sections():
        for key, value in expected.items(section):
            # Qt apps (Azahar) rewrite "key\default" flags whenever a value
            # equals their built-in default; only the real values matter.
            if key.endswith("\\default"):
                continue
            if actual.get(section, key, fallback=None) != value:
                yield f"[{section}] {key}"


def overlay_json(template, destination):
    def merge(base, extra):
        for key, value in extra.items():
            if isinstance(value, dict) and isinstance(base.get(key), dict):
                merge(base[key], value)
            else:
                base[key] = value
        return base

    data = json.loads(destination.read_text(encoding="utf-8")) if destination.exists() else {}
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(merge(data, json.loads(template.read_text(encoding="utf-8"))), indent=4) + "\n",
                           encoding="utf-8")


def json_mismatches(template, destination):
    def walk(expected, actual, path):
        for key, value in expected.items():
            here = f"{path}/{key}"
            if isinstance(value, dict):
                yield from walk(value, actual.get(key, {}) if isinstance(actual, dict) else {}, here)
            elif not isinstance(actual, dict) or actual.get(key) != value:
                yield here

    actual = json.loads(destination.read_text(encoding="utf-8")) if destination.exists() else {}
    yield from walk(json.loads(template.read_text(encoding="utf-8")), actual, "")


# (template under docs/emulator-configs/linux, emulator's own config file)
targets = [
    ("dolphin/Dolphin.ini", config_home / "dolphin-emu/Dolphin.ini"),
    ("duckstation/settings.ini", home / ".local/share/duckstation/settings.ini"),
    ("flycast/emu.cfg", config_home / "flycast/emu.cfg"),
    ("azahar/qt-config.ini", home / ".var/app/org.azahar_emu.Azahar/config/azahar-emu/qt-config.ini"),
    ("ppsspp/ppsspp.ini", home / ".var/app/org.ppsspp.PPSSPP/config/ppsspp/PSP/SYSTEM/ppsspp.ini"),
    ("mupen64plus/mupen64plus.cfg", config_home / "mupen64plus/mupen64plus.cfg"),
    ("shipwright/shipofharkinian.json", software / "shipwright/shipofharkinian.json"),
]
# melonDS is copied whole by install.sh and patched before each launch by
# launch-emulator.sh, because melonDS rewrites its TOML on exit.

problems = []
for name, destination in targets:
    template = templates / name
    is_json = template.suffix == ".json"
    if check:
        found = list((json_mismatches if is_json else ini_mismatches)(template, destination))
        problems += [f"{name}: {item}" for item in found]
    else:
        (overlay_json if is_json else overlay_ini)(template, destination)

if check:
    if problems:
        raise SystemExit("Emulator configuration differs from the D2K overlays:\n  " + "\n  ".join(problems))
    print("Emulator configuration check passed.")
else:
    print("Emulator configuration applied.")
PY
