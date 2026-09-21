#!/usr/bin/env bash
set -uo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/d2k"
log_path="$state_dir/launch-melonds.log"
home_request="$state_dir/home-request"
melonds="$HOME/.local/opt/d2k/melonds/AppRun"
config="${XDG_CONFIG_HOME:-$HOME/.config}/melonDS/melonDS.toml"
mpd_script="$repo_root/scripts/linux/mpd.sh"

mkdir -p "$state_dir"
log() { printf '%(%FT%T%z)T  %s\n' -1 "$*" >> "$log_path"; }

patch_config() {
    python3 - "$config" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
result = []
section = ""
window1_seen = False
window1_enabled = False

for line in lines:
    match = re.match(r"^\[([^]]+)\]\s*$", line.rstrip("\r\n"))
    if match:
        if section == "Instance0.Window1" and not window1_enabled:
            result.append("Enabled = true\n")
        section = match.group(1)
        if section == "Instance0.Window1":
            window1_seen = True
        result.append(line)
        continue
    if section == "Instance0.Window1" and re.match(r"^Enabled\s*=", line):
        result.append("Enabled = true\n")
        window1_enabled = True
    elif re.fullmatch(r"Instance0\.Window[0-3]", section) and re.match(r"^Geometry\s*=", line):
        result.append('Geometry = ""\n')
    else:
        result.append(line)

if section == "Instance0.Window1" and not window1_enabled:
    result.append("Enabled = true\n")
if not window1_seen:
    raise ValueError("[Instance0.Window1] is missing")
path.write_text("".join(result), encoding="utf-8")
PY
}

layout_windows() {
    local width height panel_width panel_height left top bottom
    read -r width height < <(xdotool getdisplaygeometry)
    read -r panel_width panel_height left top bottom < <(
        awk -v width="$width" -v height="$height" 'BEGIN {
            gap = 20
            scale = width / 800
            if ((height - gap) / 960 < scale) scale = (height - gap) / 960
            panel_width = int(800 * scale + .5)
            panel_height = int(480 * scale + .5)
            left = int((width - panel_width) / 2)
            top = int((height - (panel_height * 2 + gap)) / 2)
            print panel_width, panel_height, left, top, top + panel_height + gap
        }')
    local top_window bottom_window
    top_window=$(xdotool search --onlyvisible --pid "$melonds_pid" --name '\[w1\]' 2>/dev/null | head -n 1 || true)
    bottom_window=$(xdotool search --onlyvisible --pid "$melonds_pid" --name '\[w2\]' 2>/dev/null | head -n 1 || true)
    [[ -n $top_window && -n $bottom_window ]] || return 1
    xdotool windowsize --sync "$top_window" "$panel_width" "$panel_height"
    xdotool windowmove "$top_window" "$left" "$top"
    xdotool windowsize --sync "$bottom_window" "$panel_width" "$panel_height"
    xdotool windowmove "$bottom_window" "$left" "$bottom"
    log "layout top=$top_window bottom=$bottom_window ${panel_width}x${panel_height}"
}

log "===== launch-melonds start: rom=${1:-} ====="
"$mpd_script" Pause >/dev/null 2>&1 || log 'MPD pause failed (non-fatal)'

if [[ $# -ne 1 || ! -f ${1:-} ]]; then
    log 'ROM is missing; returning to Pegasus.'
    "$mpd_script" Resume >/dev/null 2>&1 || true
    exit 0
fi
if [[ ! -x $melonds || ! -f $config ]]; then
    log 'melonDS is not configured; returning to Pegasus.'
    "$mpd_script" Resume >/dev/null 2>&1 || true
    exit 0
fi

patch_config && log 'melonDS config patched' || log 'melonDS config patch failed (non-fatal)'
export DISPLAY="${DISPLAY:-:0}"
QT_QPA_PLATFORM=xcb "$melonds" "$1" &
melonds_pid=$!
log "melonDS started: pid=$melonds_pid"

settled=false
while kill -0 "$melonds_pid" 2>/dev/null; do
    if [[ $settled == false ]] && layout_windows; then
        settled=true
    fi
    if [[ -e $home_request ]]; then
        rm -f "$home_request"
        log 'Home request detected; stopping melonDS'
        kill -TERM "$melonds_pid" 2>/dev/null || true
        for _ in {1..20}; do
            kill -0 "$melonds_pid" 2>/dev/null || break
            sleep 0.15
        done
        kill -0 "$melonds_pid" 2>/dev/null && kill -KILL "$melonds_pid" 2>/dev/null || true
    fi
    sleep 0.15
done
wait "$melonds_pid" || true
log 'melonDS exited'
"$mpd_script" Resume >/dev/null 2>&1 || log 'MPD resume failed (non-fatal)'
log '===== launch-melonds end ====='
exit 0
