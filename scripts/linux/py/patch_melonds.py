#!/usr/bin/env python3
"""Restores the melonDS settings D2K needs before each launch (called by
launch-emulator.sh): melonDS rewrites its config on exit.

Usage: patch_melonds.py MELONDS_TOML
"""
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
out, section, found, enabled = [], "", False, False
for line in lines:
    match = re.match(r"^\[([^]]+)\]\s*$", line.rstrip("\r\n"))
    if match:
        if section == "Instance0.Window1" and not enabled:
            out.append("Enabled = true\n")
        section = match.group(1)
        found |= section == "Instance0.Window1"
        out.append(line)
    elif section == "Instance0.Window1" and re.match(r"^Enabled\s*=", line):
        out.append("Enabled = true\n")  # the second window is the DS touch screen
        enabled = True
    elif re.fullmatch(r"Instance0\.Window[0-3]", section) and re.match(r"^Geometry\s*=", line):
        out.append('Geometry = ""\n')  # the launcher owns window geometry
    elif section == "JIT" and re.match(r"^Enable\s*=", line):
        out.append("Enable = true\n")  # the ARM64 JIT is what holds 60 fps on the Pi
    else:
        out.append(line)
if section == "Instance0.Window1" and not enabled:
    out.append("Enabled = true\n")
if not found:
    raise ValueError("[Instance0.Window1] is missing")
path.write_text("".join(out), encoding="utf-8")
