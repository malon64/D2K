#!/usr/bin/env python3
"""Inserts D2K's entries into Labwc's rc.xml (called by configure-desktop.sh):
touch-to-output mappings, Num Lock on, the melonDS window rule and Super+Esc.

Usage: labwc_rc.py apply|check RC_XML HOME_REQUEST [DEVICE=OUTPUT ...]
In check mode the exit status is 1 when an entry is missing.
"""
import pathlib
import re
import sys

mode, path, home_request, *maps = sys.argv[1:]
maps = [entry.rsplit("=", 1) for entry in maps]
path = pathlib.Path(path)
text = original = path.read_text(encoding="utf-8")
# A panel's touch mapping must point at its current output: drop any mapping
# of these devices to another output (left over from earlier wiring).
for device, output in maps:
    stale = re.compile(r'^\s*<touch deviceName="%s" mapToOutput="(?!%s")[^"]*"[^>]*/>\n'
                       % (re.escape(device), re.escape(output)), re.M)
    if stale.search(text):
        if mode == "check":
            sys.exit(1)
        text = stale.sub("", text)
# The numpad is the controller's face-button diamond (docs/controls.md). With
# Num Lock off, numpad 8/4/6/2 arrive as KP_Up/Left/Right/Down and Qt emulators
# read them as the arrow keys, which are the D-pad.
if "<numlock>on</numlock>" not in text:
    if mode == "check":
        sys.exit(1)
    text, count = re.subn(r"<numlock>\s*\w*\s*</numlock>", "<numlock>on</numlock>", text)
    if not count:
        text = text.replace("<keyboard>", "<keyboard>\n    <numlock>on</numlock>", 1)
entries = [
    ("  </windowRules>", '    <windowRule title="*melonDS*" serverDecoration="no" />\n'),
    ("  </keyboard>", '    <keybind key="W-Escape">\n'
                      '      <action name="Execute">\n'
                      f'        <command>touch "{home_request}"</command>\n'
                      '      </action>\n'
                      '    </keybind>\n'),
] + [("</openbox_config>", f'  <touch deviceName="{device}" mapToOutput="{output}" mouseEmulation="yes" />\n')
     for device, output in maps]
missing = [(anchor, entry) for anchor, entry in entries if entry.strip().splitlines()[0] not in text]
if mode == "check":
    sys.exit(1 if missing else 0)
for anchor, entry in missing:
    if anchor not in text:
        sys.exit(f"{path}: cannot find {anchor.strip()}")
    text = text.replace(anchor, entry + anchor, 1)
if text != original:
    path.write_text(text, encoding="utf-8")
