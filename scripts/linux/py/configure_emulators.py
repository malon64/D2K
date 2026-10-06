#!/usr/bin/env python3
"""Merges the D2K overlays in docs/emulator-configs/linux/ into each emulator's
own Linux configuration (called by configure-emulators.sh).

Usage: configure_emulators.py REPO CONFIG_HOME HOME SOFTWARE_DIR [--check]
"""
import json
import pathlib
import re
import sys

repo, config_home, home, software = map(pathlib.Path, sys.argv[1:5])
check = sys.argv[5] == "--check"
templates = repo / "docs/emulator-configs/linux"


def read_ini(path):
    """{section: {key: [values]}} from "key = value" lines. Line-based on
    purpose: melonDS's TOML has top-level keys and multi-line arrays that
    configparser rejects; anything that is not a section header or key line is
    ignored. A key repeated in a section keeps every value, in order:
    DuckStation stores several bindings for one button that way."""
    sections, current = {}, None
    text = path.read_text(encoding="utf-8-sig") if path.exists() else ""
    for line in text.splitlines():
        header = re.match(r"^\[([^]]+)\]\s*$", line)
        if header:
            current = sections.setdefault(header.group(1), {})
            continue
        pair = re.match(r"^([^\s#;=][^=]*?)\s*=\s*(.*?)\s*$", line)
        if pair and current is not None:
            current.setdefault(pair.group(1), []).append(pair.group(2))
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
            out.extend(f"{key} = {value}\n" for key, vals in values.items() if key not in seen for value in vals)

        for line in lines:
            header = re.match(r"^\[([^]]+)\]", line)
            if header:
                if current == section:
                    flush()
                current = header.group(1)
            key = next((k for k in values if current == section
                        and re.match(rf"^{re.escape(k)}\s*=", line)), None)
            if key:
                if key not in seen:  # first line of the key: write all its values
                    out.extend(f"{key} = {value}\n" for value in values[key])
                seen.add(key)        # later lines of the same key are dropped
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
            # An empty template value means "unbound"; PPSSPP drops such keys.
            if actual.get(section, {}).get(key, [""] if value == [""] else None) != value:
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


# Ship of Harkinian keeps its bindings as mapping objects whose IDs embed the
# input (e.g. "P0-B32768-KB45", "P0-S0-D2-SDLB11"), listed per button/stick
# direction under Port1. Merging would leave the old inputs bound too, so each
# template replaces every port-0 mapping of its own kind: keyboard.json the
# keyboard ones, gamepad.json the SDL (gamepad) ones.
SOH_BUTTONS = {"CRight": 1, "CLeft": 2, "CDown": 4, "CUp": 8, "R": 16, "L": 32,
               "DRight": 256, "DLeft": 512, "DDown": 1024, "DUp": 2048,
               "Start": 4096, "Z": 8192, "B": 16384, "A": 32768}
SOH_STICK = {"Left": 0, "Right": 1, "Up": 2, "Down": 3}
SOH_KINDS = {"keyboard": re.compile(r"^P0-(B\d+|S\d-D\d)-KB\d+$"),
             "gamepad": re.compile(r"^P0-(B\d+|S\d-D\d)-SDL[AB]\d+(-AD[PN])?$")}


def soh_input(kind, value):
    """(ID suffix, mapping fields, class prefix) for one template value.
    Keyboard values are scancodes; gamepad values are SDL game controller
    inputs: "B11" a button, "A4+" / "A2-" one direction of an axis."""
    if kind == "keyboard":
        return f"KB{value}", {"KeyboardScancode": value}, "KeyboardKey"
    if value.startswith("B"):
        return f"SDL{value}", {"SDLControllerButton": int(value[1:])}, "SDLButton"
    sign = value[-1]
    return (f"SDLA{value[1:-1]}-AD{'P' if sign == '+' else 'N'}",
            {"AxisDirection": 1 if sign == "+" else -1, "SDLControllerAxis": int(value[1:-1])}, "SDLAxisDirection")


def soh_wanted(template, kind):
    """{mapping ID: (Port1 table, field, mapping)} from a template."""
    keys = json.loads(template.read_text(encoding="utf-8"))
    wanted = {}
    def each(values):  # a template value is one input or a list of inputs
        return values if isinstance(values, list) else [values]

    for name, values in keys["buttons"].items():
        bitmask = SOH_BUTTONS[name]
        for value in each(values):
            suffix, fields, prefix = soh_input(kind, value)
            wanted[f"P0-B{bitmask}-{suffix}"] = ("Buttons", f"{bitmask}ButtonMappingIds", {
                "Bitmask": bitmask, "ButtonMappingClass": f"{prefix}ToButtonMapping", **fields})
    for name, values in keys["stick"].items():
        direction = SOH_STICK[name]
        for value in each(values):
            suffix, fields, prefix = soh_input(kind, value)
            wanted[f"P0-S0-D{direction}-{suffix}"] = ("LeftStick", f"{name}AxisDirectionMappingIds", {
                "AxisDirectionMappingClass": f"{prefix}ToAxisDirectionMapping", "Direction": direction,
                "Stick": 0, **fields})
    return wanted


def soh_controllers(data):
    return data.setdefault("CVars", {}).setdefault("gSettings", {}).setdefault("Controllers", {})


def overlay_soh(kind):
    def apply(template, destination):
        data = json.loads(destination.read_text(encoding="utf-8")) if destination.exists() else {}
        controllers = soh_controllers(data)
        maps = {"Buttons": controllers.setdefault("ButtonMappings", {}),
                "LeftStick": controllers.setdefault("AxisDirectionMappings", {})}
        port = controllers.setdefault("Port1", {})
        port["HasConfig"] = 1
        stick_defaults = {"DeadzonePercentage": 20, "NotchSnapAngle": 0, "SensitivityPercentage": 100}
        tables = {"Buttons": port.setdefault("Buttons", {}),
                  "LeftStick": port.setdefault("LeftStick", dict(stick_defaults)),
                  "RightStick": port.setdefault("RightStick", dict(stick_defaults))}
        owned = SOH_KINDS[kind]
        for mapping in maps.values():
            for mapping_id in [k for k in mapping if owned.match(k)]:
                del mapping[mapping_id]
        for table in tables.values():
            for field, ids in list(table.items()):
                if field.endswith("MappingIds") and isinstance(ids, str):
                    table[field] = "".join(f"{i}," for i in ids.split(",") if i and not owned.match(i))
        for mapping_id, (table, field, mapping) in soh_wanted(template, kind).items():
            maps[table][mapping_id] = mapping
            tables[table][field] = tables[table].get(field, "") + f"{mapping_id},"
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(data, indent=4) + "\n", encoding="utf-8")

    def mismatches(template, destination):
        data = json.loads(destination.read_text(encoding="utf-8")) if destination.exists() else {}
        controllers = soh_controllers(data)
        actual = {k for k in (*controllers.get("ButtonMappings", {}), *controllers.get("AxisDirectionMappings", {}))
                  if SOH_KINDS[kind].match(k)}
        wanted = set(soh_wanted(template, kind))
        yield from (f"missing {k}" for k in sorted(wanted - actual))
        yield from (f"extra {k}" for k in sorted(actual - wanted))

    return apply, mismatches


HANDLERS = {
    "ini": (overlay_ini, ini_mismatches),
    "json": (overlay_json, json_mismatches),
    "file": (copy_file, file_mismatches),
    "soh-keyboard": overlay_soh("keyboard"),
    "soh-gamepad": overlay_soh("gamepad"),
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
    # Without this file Flycast maps the pad from SDL: ABXY by label instead
    # of position and the D-pad on the D-pad.
    ("flycast/mappings/SDL_D2K Controls.cfg", config_home / "flycast/mappings/SDL_D2K Controls.cfg", "file"),
    ("azahar/qt-config.ini", home / ".var/app/org.azahar_emu.Azahar/config/azahar-emu/qt-config.ini", "ini"),
    ("ppsspp/ppsspp.ini", ppsspp_system / "ppsspp.ini", "ini"),
    ("ppsspp/controls.ini", ppsspp_system / "controls.ini", "ini"),
    ("mupen64plus/mupen64plus.cfg", config_home / "mupen64plus/mupen64plus.cfg", "ini"),
    ("shipwright/shipofharkinian.json", soh_settings, "json"),
    ("shipwright/keyboard.json", soh_settings, "soh-keyboard"),
    ("shipwright/gamepad.json", soh_settings, "soh-gamepad"),
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
