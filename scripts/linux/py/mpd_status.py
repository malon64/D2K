#!/usr/bin/env python3
"""Writes the music status file the theme polls (called by mpd.sh), atomically.

Usage: mpd_status.py STATUS_FILE STATE FILE TITLE ARTIST POSITION_S DURATION_S
"""
import json, os, pathlib, sys, tempfile, time
path = pathlib.Path(sys.argv[1])
data = dict(zip(("state", "file", "title", "artist", "positionMs", "durationMs"), sys.argv[2:]))
data["positionMs"] = int(data["positionMs"]) * 1000
data["durationMs"] = int(data["durationMs"]) * 1000
data["updatedAt"] = int(time.time() * 1000)
with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as output:
    json.dump(data, output, separators=(",", ":"))
    output.write("\n")
    temporary = output.name
os.replace(temporary, path)
