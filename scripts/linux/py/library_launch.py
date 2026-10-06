#!/usr/bin/env python3
"""Rewrites each collection's metadata.pegasus.txt in the Pi's library copy to
launch games through launch-emulator.sh (called by install.sh).

Usage: library_launch.py LIBRARY_DIR LAUNCHER
"""
import pathlib
import sys

library = pathlib.Path(sys.argv[1])
launcher = sys.argv[2]
consoles = {"nds": "ds", "dreamcast": "dreamcast", "psx": "ps1",
            "n64": "n64", "gc": "gamecube", "n3ds": "3ds", "psp": "psp"}

for path in library.glob("*/metadata.pegasus.txt"):
    lines = path.read_text(encoding="utf-8").splitlines()
    shortname = next((line.partition(":")[2].strip() for line in lines
                      if line.startswith("shortname:")), "")
    console = consoles.get(shortname)
    if not console:
        continue
    lines = [line for line in lines if not line.startswith(("launch:", "workdir:"))]
    for index, line in enumerate(lines):
        if line.startswith("shortname:"):
            lines[index + 1:index + 1] = [
                f'launch: "{launcher}" {console} "{{file.path}}"',
                f"workdir: {path.parent}",
            ]
            break
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    if any(line.lstrip().startswith("launch: powershell.exe") for line in lines):
        raise SystemExit(f"Windows launch command remains in {path}")
