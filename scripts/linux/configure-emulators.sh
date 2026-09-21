#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

if [[ $# -gt 1 || ${1:-} == --help ]]; then
    echo "Usage: $0 [--check]" >&2
    exit 2
fi

python3 - "$repo_root" "$config_home" "$HOME" "${1:-}" <<'PY'
import configparser
import pathlib
import re
import sys

repo, config_home, home, mode = map(pathlib.Path, sys.argv[1:4]) + (sys.argv[4],)
templates = repo / "docs/emulator-configs/windows"

def ini(path):
    config = configparser.RawConfigParser(interpolation=None)
    config.optionxform = str
    if path.exists():
        config.read(path, encoding="utf-8")
    return config

def merge_ini(template, destination):
    config, overlay = ini(destination), ini(template)
    for section in overlay.sections():
        if not config.has_section(section):
            config.add_section(section)
        for key, value in overlay.items(section):
            config.set(section, key, value)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("w", encoding="utf-8") as file:
        config.write(file, space_around_delimiters=True)

def set_ini_values(path, section, values):
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True) if path.exists() else []
    out, current, seen = [], None, set()
    for line in lines:
        match = re.match(r"^\[([^]]+)\]", line)
        if match:
            if current == section:
                for key, value in values.items():
                    if key not in seen:
                        out.append(f"{key} = {value}\n")
            current, seen = match.group(1), set()
        key = next((key for key in values if current == section and re.match(rf"^{re.escape(key)}\s*=", line)), None)
        if key:
            out.append(f"{key} = {values[key]}\n")
            seen.add(key)
        else:
            out.append(line)
    if current == section:
        for key, value in values.items():
            if key not in seen:
                out.append(f"{key} = {value}\n")
    elif not any(re.match(rf"^\[{re.escape(section)}\]", line) for line in lines):
        out += [f"[{section}]\n"] + [f"{key} = {value}\n" for key, value in values.items()]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(out), encoding="utf-8")

def set_bml_values(path, section, values):
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True) if path.exists() else []
    out, current, seen = [], None, set()
    for line in lines:
        header = re.match(r"^([^\s][^:]*)$", line.rstrip())
        if header:
            if current == section:
                for key, value in values.items():
                    if key not in seen:
                        out.append(f"  {key}: {value}\n")
            current, seen = header.group(1), set()
        key = next((key for key in values if current == section and re.match(rf"^  {re.escape(key)}:", line)), None)
        if key:
            out.append(f"  {key}: {values[key]}\n")
            seen.add(key)
        else:
            out.append(line)
    if current == section:
        for key, value in values.items():
            if key not in seen:
                out.append(f"  {key}: {value}\n")
    elif not any(line.rstrip() == section for line in lines):
        out += [f"{section}\n"] + [f"  {key}: {value}\n" for key, value in values.items()]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(out), encoding="utf-8")

targets = {
    "dolphin": config_home / "dolphin-emu/Dolphin.ini",
    "duckstation": home / ".local/share/duckstation/settings.ini",
    "flycast": home / ".var/app/org.flycast.Flycast/config/flycast/emu.cfg",
    "azahar": home / ".var/app/org.azahar_emu.Azahar/config/azahar-emu/qt-config.ini",
    "ares": home / ".local/share/ares/settings.bml",
}

if mode == "--check":
    for name, path in targets.items():
        if not path.is_file():
            raise SystemExit(f"Missing {name} configuration: {path}")
    duckstation = ini(targets["duckstation"])
    assert duckstation.get("UI", "DisplayWindowWidth") == "800"
    assert duckstation.get("UI", "DisplayWindowHeight") == "480"
    for name, template in (("dolphin", "dolphin/Dolphin.ini"), ("flycast", "flycast/emu.cfg"), ("azahar", "azahar/qt-config.ini")):
        actual, expected = ini(targets[name]), ini(templates / template)
        for section in expected.sections():
            for key, value in expected.items(section):
                assert actual.get(section, key) == value, f"{name}: {section}.{key}"
    ares = targets["ares"].read_text(encoding="utf-8")
    for line in ("  Exclusive: false", "  AspectCorrection: false", "  AdaptiveSizing: false", "  AutoCentering: true", "  ShowStatusBar: false"):
        assert line in ares, f"ares: {line}"
    print("Emulator configuration check passed.")
    raise SystemExit(0)

# DuckStation is user-configured on the Pi: D2K owns only its launch-window size.
set_ini_values(targets["duckstation"], "UI", {"DisplayWindowWidth": "800", "DisplayWindowHeight": "480"})
merge_ini(templates / "dolphin/Dolphin.ini", targets["dolphin"])
merge_ini(templates / "flycast/emu.cfg", targets["flycast"])
merge_ini(templates / "azahar/qt-config.ini", targets["azahar"])

# ares 143+ renamed the Windows template's display keys; these are the direct
# semantic equivalents. Window placement is handled by launch-emulator.sh.
set_bml_values(targets["ares"], "Video", {
    "Exclusive": "false", "AspectCorrection": "false", "AdaptiveSizing": "false", "AutoCentering": "true",
})
set_bml_values(targets["ares"], "General", {"ShowStatusBar": "false"})
print("Emulator display configuration applied.")
PY
