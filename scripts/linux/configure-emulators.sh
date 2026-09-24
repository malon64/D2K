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
import json
import pathlib
import re
import sys

repo, config_home, home, software = map(pathlib.Path, sys.argv[1:5])
check = sys.argv[5] == "--check"
templates = repo / "docs/emulator-configs/linux"


def read_ini(path):
    """{section: {key: value}} from "key = value" lines. Line-based on purpose:
    melonDS's TOML has top-level keys and multi-line arrays that configparser
    rejects; anything that is not a section header or key line is ignored."""
    sections, current = {}, None
    text = path.read_text(encoding="utf-8-sig") if path.exists() else ""
    for line in text.splitlines():
        header = re.match(r"^\[([^]]+)\]\s*$", line)
        if header:
            current = sections.setdefault(header.group(1), {})
            continue
        pair = re.match(r"^([^\s#;=][^=]*?)\s*=\s*(.*?)\s*$", line)
        if pair and current is not None:
            current.setdefault(pair.group(1), pair.group(2))
    return sections


def overlay_ini(template, destination):
    """Set each template key in place, keeping the file's comments and order."""
    raw = destination.read_text(encoding="utf-8") if destination.exists() else ""
    # PPSSPP's controls.ini starts with a UTF-8 BOM; keep it, but keep it out
    # of the first section header so that header is still recognised.
    bom = "\N{BYTE ORDER MARK}" if raw.startswith("\N{BYTE ORDER MARK}") else ""
    lines = raw[len(bom):].splitlines(keepends=True)
    for section, values in read_ini(template).items():
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
    destination.write_text(bom + "".join(lines), encoding="utf-8")


def ini_mismatches(template, destination):
    actual = read_ini(destination)
    for section, expected in read_ini(template).items():
        for key, value in expected.items():
            # Qt apps (Azahar) rewrite "key\default" flags whenever a value
            # equals their built-in default; only the real values matter.
            if key.endswith("\\default"):
                continue
            if actual.get(section, {}).get(key) != value:
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


def copy_file(template, destination):
    """D2K owns the whole file (Flycast's keyboard mapping)."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(template.read_text(encoding="utf-8"), encoding="utf-8")


def file_mismatches(template, destination):
    if not destination.exists() or destination.read_text(encoding="utf-8") != template.read_text(encoding="utf-8"):
        yield "differs"


# Ship of Harkinian keeps its keyboard bindings as mapping objects whose IDs
# embed the key (e.g. "P0-B32768-KB45"), listed per button/stick direction
# under Port1. Merging would leave the old keys bound too, so every port-0
# keyboard mapping is replaced; gamepad (SDL) mappings are kept.
SOH_BUTTONS = {"CRight": 1, "CLeft": 2, "CDown": 4, "CUp": 8, "R": 16, "L": 32,
               "DRight": 256, "DLeft": 512, "DDown": 1024, "DUp": 2048,
               "Start": 4096, "Z": 8192, "B": 16384, "A": 32768}
SOH_STICK = {"Left": 0, "Right": 1, "Up": 2, "Down": 3}


def soh_wanted(template):
    keys = json.loads(template.read_text(encoding="utf-8"))
    buttons = {f"P0-B{SOH_BUTTONS[name]}-KB{code}": (SOH_BUTTONS[name], code)
               for name, code in keys["buttons"].items()}
    stick = {f"P0-S0-D{SOH_STICK[name]}-KB{code}": (SOH_STICK[name], code)
             for name, code in keys["stick"].items()}
    return buttons, stick


def soh_controllers(data):
    return data.setdefault("CVars", {}).setdefault("gSettings", {}).setdefault("Controllers", {})


def overlay_soh_keyboard(template, destination):
    data = json.loads(destination.read_text(encoding="utf-8")) if destination.exists() else {}
    controllers = soh_controllers(data)
    button_maps = controllers.setdefault("ButtonMappings", {})
    axis_maps = controllers.setdefault("AxisDirectionMappings", {})
    port = controllers.setdefault("Port1", {})
    port["HasConfig"] = 1
    port_buttons = port.setdefault("Buttons", {})
    left_stick = port.setdefault("LeftStick", {"DeadzonePercentage": 20, "NotchSnapAngle": 0,
                                               "SensitivityPercentage": 100})
    keyboard_id = re.compile(r"^P0-(B\d+|S0-D\d)-KB\d+$")
    for mapping_id in [k for k in button_maps if keyboard_id.match(k)]:
        del button_maps[mapping_id]
    for mapping_id in [k for k in axis_maps if keyboard_id.match(k)]:
        del axis_maps[mapping_id]
    for table in (port_buttons, left_stick):
        for field, ids in list(table.items()):
            if field.endswith("MappingIds") and isinstance(ids, str):
                table[field] = "".join(f"{i}," for i in ids.split(",") if i and not keyboard_id.match(i))
    buttons, stick = soh_wanted(template)
    for mapping_id, (bitmask, code) in buttons.items():
        button_maps[mapping_id] = {"Bitmask": bitmask, "ButtonMappingClass": "KeyboardKeyToButtonMapping",
                                   "KeyboardScancode": code}
        field = f"{bitmask}ButtonMappingIds"
        port_buttons[field] = port_buttons.get(field, "") + f"{mapping_id},"
    direction_fields = {0: "Left", 1: "Right", 2: "Up", 3: "Down"}
    for mapping_id, (direction, code) in stick.items():
        axis_maps[mapping_id] = {"AxisDirectionMappingClass": "KeyboardKeyToAxisDirectionMapping",
                                 "Direction": direction, "KeyboardScancode": code, "Stick": 0}
        field = f"{direction_fields[direction]}AxisDirectionMappingIds"
        left_stick[field] = left_stick.get(field, "") + f"{mapping_id},"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(data, indent=4) + "\n", encoding="utf-8")


def soh_keyboard_mismatches(template, destination):
    data = json.loads(destination.read_text(encoding="utf-8")) if destination.exists() else {}
    controllers = soh_controllers(data)
    keyboard_id = re.compile(r"^P0-(B\d+|S0-D\d)-KB\d+$")
    actual = {k for k in (*controllers.get("ButtonMappings", {}), *controllers.get("AxisDirectionMappings", {}))
              if keyboard_id.match(k)}
    buttons, stick = soh_wanted(template)
    wanted = set(buttons) | set(stick)
    yield from (f"missing {k}" for k in sorted(wanted - actual))
    yield from (f"extra {k}" for k in sorted(actual - wanted))


HANDLERS = {
    "ini": (overlay_ini, ini_mismatches),
    "json": (overlay_json, json_mismatches),
    "file": (copy_file, file_mismatches),
    "soh-keyboard": (overlay_soh_keyboard, soh_keyboard_mismatches),
}

# (template under docs/emulator-configs/linux, emulator's own config file, kind)
# Display overlays and the D2K keyboard scheme (docs/controls.md).
ppsspp_system = home / ".var/app/org.ppsspp.PPSSPP/config/ppsspp/PSP/SYSTEM"
soh_settings = software / "shipwright/shipofharkinian.json"
targets = [
    ("dolphin/Dolphin.ini", config_home / "dolphin-emu/Dolphin.ini", "ini"),
    ("dolphin/GCPadNew.ini", config_home / "dolphin-emu/GCPadNew.ini", "ini"),
    ("duckstation/settings.ini", home / ".local/share/duckstation/settings.ini", "ini"),
    ("flycast/emu.cfg", config_home / "flycast/emu.cfg", "ini"),
    ("flycast/mappings/SDL_Keyboard.cfg", config_home / "flycast/mappings/SDL_Keyboard.cfg", "file"),
    ("azahar/qt-config.ini", home / ".var/app/org.azahar_emu.Azahar/config/azahar-emu/qt-config.ini", "ini"),
    ("ppsspp/ppsspp.ini", ppsspp_system / "ppsspp.ini", "ini"),
    ("ppsspp/controls.ini", ppsspp_system / "controls.ini", "ini"),
    ("mupen64plus/mupen64plus.cfg", config_home / "mupen64plus/mupen64plus.cfg", "ini"),
    ("shipwright/shipofharkinian.json", soh_settings, "json"),
    ("shipwright/keyboard.json", soh_settings, "soh-keyboard"),
    # melonDS.toml itself is copied whole by install.sh (and patched before
    # each launch); its [Instance0.Keyboard] keys are set here.
    ("melonds/keyboard.toml", config_home / "melonDS/melonDS.toml", "ini"),
]

problems = []
for name, destination, kind in targets:
    apply, mismatches = HANDLERS[kind]
    template = templates / name
    if check:
        problems += [f"{name}: {item}" for item in mismatches(template, destination)]
    else:
        apply(template, destination)

if check:
    if problems:
        raise SystemExit("Emulator configuration differs from the D2K overlays:\n  " + "\n  ".join(problems))
    print("Emulator configuration check passed.")
else:
    print("Emulator configuration applied.")
PY
