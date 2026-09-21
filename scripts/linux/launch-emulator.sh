#!/usr/bin/env bash
set -uo pipefail

console=${1:-}
rom=${2:-}
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/d2k"
log_path="$state_dir/launch-${console:-unknown}.log"
home_request="$state_dir/home-request"
software_dir="$HOME/.local/opt/d2k"
mpd_script="$repo_root/scripts/linux/mpd.sh"
emulator_pid=
args=()

mkdir -p "$state_dir"
log() { printf '%(%FT%T%z)T  %s\n' -1 "$*" >> "$log_path"; }

emulator_args() {
    case $1 in
        ds|dreamcast|3ds) args=("$2") ;;
        ps1) args=(-batch -fastboot -- "$2") ;;
        n64) args=(--system "Nintendo 64" --no-file-prompt "$2") ;;
        gamecube) args=(--batch --exec "$2") ;;
    esac
}

patch_melonds() {
    local config="${XDG_CONFIG_HOME:-$HOME/.config}/melonDS/melonDS.toml"
    python3 - "$config" <<'PY'
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
        out.append("Enabled = true\n")
        enabled = True
    elif re.fullmatch(r"Instance0\.Window[0-3]", section) and re.match(r"^Geometry\s*=", line):
        out.append('Geometry = ""\n')
    else:
        out.append(line)
if section == "Instance0.Window1" and not enabled:
    out.append("Enabled = true\n")
if not found:
    raise ValueError("[Instance0.Window1] is missing")
path.write_text("".join(out), encoding="utf-8")
PY
}

panel_geometry() {
    local width height
    read -r width height < <(xdotool getdisplaygeometry)
    awk -v width="$width" -v height="$height" 'BEGIN {
        gap = 20
        scale = width / 800
        if ((height - gap) / 960 < scale) scale = (height - gap) / 960
        panel_width = int(800 * scale + .5)
        panel_height = int(480 * scale + .5)
        left = int((width - panel_width) / 2)
        top = int((height - (panel_height * 2 + gap)) / 2)
        print panel_width, panel_height, left, top, top + panel_height + gap
    }'
}

layout_single() {
    local panel_width panel_height left top bottom window
    read -r panel_width panel_height left top bottom < <(panel_geometry)
    window=$(xdotool search --onlyvisible --pid "$emulator_pid" 2>/dev/null | head -n 1 || true)
    if [[ -z $window && $console == dreamcast ]]; then
        window=$(xdotool search --onlyvisible --name '[Ff]lycast' 2>/dev/null | head -n 1 || true)
    elif [[ -z $window && $console == 3ds ]]; then
        window=$(xdotool search --onlyvisible --name '[Aa]zahar' 2>/dev/null | head -n 1 || true)
    fi
    [[ -n $window ]] || return 1
    xdotool windowsize --sync "$window" "$panel_width" "$panel_height"
    xdotool windowmove "$window" "$left" "$top"
    log "layout window=$window ${panel_width}x${panel_height} at $left,$top"
}

layout_melonds() {
    local panel_width panel_height left top bottom upper lower
    read -r panel_width panel_height left top bottom < <(panel_geometry)
    upper=$(xdotool search --onlyvisible --pid "$emulator_pid" --name '\[w1\]' 2>/dev/null | head -n 1 || true)
    lower=$(xdotool search --onlyvisible --pid "$emulator_pid" --name '\[w2\]' 2>/dev/null | head -n 1 || true)
    [[ -n $upper && -n $lower ]] || return 1
    xdotool windowsize --sync "$upper" "$panel_width" "$panel_height"
    xdotool windowmove "$upper" "$left" "$top"
    xdotool windowsize --sync "$lower" "$panel_width" "$panel_height"
    xdotool windowmove "$lower" "$left" "$bottom"
    log "layout upper=$upper lower=$lower ${panel_width}x${panel_height}"
}

emulator_command() {
    case $console in
        ds) printf '%s\n' "$software_dir/melonds/AppRun" ;;
        dreamcast) printf '%s\n' flatpak ;;
        ps1) printf '%s\n' "$software_dir/duckstation/AppRun" ;;
        n64) command -v ares ;;
        gamecube) command -v dolphin-emu ;;
        3ds) printf '%s\n' flatpak ;;
        *) return 1 ;;
    esac
}

stop_emulator() {
    case $console in
        dreamcast) flatpak kill --user org.flycast.Flycast >/dev/null 2>&1 || true ;;
        3ds) flatpak kill --user org.azahar_emu.Azahar >/dev/null 2>&1 || true ;;
        *) kill -TERM "$emulator_pid" 2>/dev/null || true ;;
    esac
    for _ in {1..20}; do
        kill -0 "$emulator_pid" 2>/dev/null || break
        sleep 0.15
    done
    kill -0 "$emulator_pid" 2>/dev/null && kill -KILL "$emulator_pid" 2>/dev/null || true
}

if [[ $console == --self-test ]]; then
    emulator_args ps1 '/tmp/Test Disc.cue'
    [[ ${args[*]} == '-batch -fastboot -- /tmp/Test Disc.cue' ]]
    emulator_args n64 /tmp/Test.z64
    [[ ${args[0]} == --system && ${args[1]} == 'Nintendo 64' ]]
    echo 'launch-emulator self-test passed.'
    exit 0
fi

if [[ $# -ne 2 || ! $console =~ ^(ds|dreamcast|ps1|n64|gamecube|3ds)$ ]]; then
    echo "Usage: $0 {ds|dreamcast|ps1|n64|gamecube|3ds} /absolute/path/to/rom" >&2
    exit 2
fi

log "===== launch-$console start: rom=$rom ====="
"$mpd_script" Pause >/dev/null 2>&1 || log 'MPD pause failed (non-fatal)'
if [[ ! -f $rom ]]; then
    log 'ROM is missing; returning to Pegasus.'
    "$mpd_script" Resume >/dev/null 2>&1 || true
    exit 0
fi

emulator=$(emulator_command 2>/dev/null || true)
if [[ -z $emulator || ( $console != dreamcast && $console != 3ds && ! -x $emulator ) ]]; then
    log "$console emulator is not installed; returning to Pegasus."
    "$mpd_script" Resume >/dev/null 2>&1 || true
    exit 0
fi
if [[ $console == ds ]]; then
    patch_melonds && log 'melonDS config patched' || log 'melonDS config patch failed (non-fatal)'
fi

emulator_args "$console" "$rom"
export DISPLAY="${DISPLAY:-:0}"
case $console in
    dreamcast) flatpak run org.flycast.Flycast "${args[@]}" & ;;
    3ds) flatpak run org.azahar_emu.Azahar "${args[@]}" & ;;
    *) QT_QPA_PLATFORM=xcb "$emulator" "${args[@]}" & ;;
esac
emulator_pid=$!
log "$console started: pid=$emulator_pid"

settled=false
while kill -0 "$emulator_pid" 2>/dev/null; do
    if [[ $settled == false ]]; then
        if [[ $console == ds ]]; then
            layout_melonds && settled=true
        else
            layout_single && settled=true
        fi
    fi
    if [[ -e $home_request ]]; then
        rm -f "$home_request"
        log 'Home request detected; stopping emulator'
        stop_emulator
    fi
    sleep 0.15
done
wait "$emulator_pid" || true
log "$console exited"
"$mpd_script" Resume >/dev/null 2>&1 || log 'MPD resume failed (non-fatal)'
log "===== launch-$console end ====="
exit 0
