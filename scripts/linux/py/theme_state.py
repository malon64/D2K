#!/usr/bin/env python3
"""Reads and clears the D2K values the theme saves in Pegasus' theme settings
(called by run.sh).

Usage:
  theme_state.py clear SETTINGS  drop the saved boot and music state
  theme_state.py read SETTINGS   print the music values, one per line
"""
import json
import os
import pathlib
import sys
import tempfile

MUSIC_KEYS = ("d2kMusicReady", "d2kMusicLaunch", "d2kMusicSeq", "d2kMusicAction", "d2kMusicTrack")
BOOT_KEYS = ("d2kNav",) + MUSIC_KEYS


def clear(path):
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise ValueError("settings root is not an object")
        changed = any(key in data for key in BOOT_KEYS)
        for key in BOOT_KEYS:
            data.pop(key, None)
        if changed:
            with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as output:
                json.dump(data, output, separators=(",", ":"))
                output.write("\n")
                temporary = output.name
            os.replace(temporary, path)
    except Exception as error:
        print(f"D2K: could not clear saved boot state: {error}", file=sys.stderr)


def read(path):
    try:
        values = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        values = {}
    for key in MUSIC_KEYS:
        value = values.get(key, "")
        print("true" if value is True else "" if value is None else value)


if __name__ == "__main__":
    mode, settings = sys.argv[1:]
    {"clear": clear, "read": read}[mode](pathlib.Path(settings))
