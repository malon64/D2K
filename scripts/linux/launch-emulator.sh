#!/usr/bin/env bash
# Starts one game for Pegasus, places its windows on the D2K panels, and
# returns to the menu when the emulator exits or a Home request arrives.
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
console=${1:-}
rom=${2:-}
log_path="$state_dir/launch-${console:-unknown}.log"
mpd_script="$linux_dir/mpd.sh"
soh_dir="$software_dir/shipwright"
mupen_dir="$software_dir/mupen64plus"
emulator_pid=
cmd=()
program=
flatpak_app=
stop_pattern=

log() { mkdir -p "$state_dir"; printf '%(%FT%T%z)T  %s\n' -1 "$*" >> "$log_path"; }

# Ocarina of Time runs natively in Ship of Harkinian, which the installer
# links to the library ROM as oot.z64. Every other N64 game uses Mupen64Plus:
# ares renders black on the Pi's V3DV driver (docs/raspberry-pi-struggles.md).
is_ocarina() {
    [[ -x $soh_dir/soh-raspberry-pi.AppImage && -e $soh_dir/oot.z64 ]] &&
        [[ $(realpath -- "$1") == $(realpath -- "$soh_dir/oot.z64") ]]
}

# Sets cmd (the full command line), program (what must be installed),
# flatpak_app (for Flatpak emulators) and stop_pattern (extra processes that
# must be terminated on a Home request).
build_command() {
    local console=$1 rom=$2
    cmd=() program= flatpak_app= stop_pattern=
    case $console in
        # The stylesheet collapses melonDS's menu bar in both of its windows.
        ds) program="$software_dir/melonds/AppRun"
            cmd=(env QT_QPA_PLATFORM=xcb "$program" -stylesheet "$linux_dir/melonds.qss" "$rom") ;;
        dreamcast) program="$software_dir/flycast/bin/flycast"
            cmd=(env SDL_VIDEODRIVER=x11 "$program" "$rom") ;;
        ps1) program="$software_dir/duckstation/AppRun"
            cmd=(env QT_QPA_PLATFORM=xcb "$program" -batch -fastboot -- "$rom") ;;
        gamecube) program=$(command -v dolphin-emu || echo /usr/games/dolphin-emu)
            cmd=(env QT_QPA_PLATFORM=xcb "$program" --batch --exec "$rom") ;;
        n64)
            if is_ocarina "$rom"; then
                # SoH reads oot.o2r and its settings from its own directory.
                # Its bundled SDL would open the HDMI ALSA device PipeWire
                # already holds, so audio goes through the PulseAudio API.
                program="$soh_dir/soh-raspberry-pi.AppImage"
                cmd=(env -C "$soh_dir" SDL_VIDEODRIVER=x11 SDL_AUDIODRIVER=pulseaudio "$program")
            else
                # Plugins are named explicitly: Mupen64Plus saves command-line
                # plugin choices into its config, so a stray test run with
                # --audio dummy would otherwise silence every later game.
                program="$mupen_dir/bin/mupen64plus"
                cmd=(env LD_LIBRARY_PATH="$mupen_dir/lib" SDL_VIDEODRIVER=x11 "$program"
                     --corelib "$mupen_dir/lib/libmupen64plus.so.2"
                     --plugindir "$mupen_dir/lib/mupen64plus" --datadir "$mupen_dir/share/mupen64plus"
                     --gfx mupen64plus-video-rice.so --audio mupen64plus-audio-sdl.so
                     --input mupen64plus-input-sdl.so --rsp mupen64plus-rsp-hle.so
                     --windowed --resolution 800x600 "$rom")
            fi ;;
        3ds) flatpak_app=org.azahar_emu.Azahar program=flatpak
            stop_pattern='/app/bin/azahar-launcher|(^|/)azahar( |$)'
            cmd=(flatpak run --socket=x11 --nosocket=wayland --env=QT_QPA_PLATFORM=xcb "$flatpak_app" "$rom") ;;
        psp) flatpak_app=org.ppsspp.PPSSPP program=flatpak
            stop_pattern=PPSSPPSDL
            cmd=(flatpak run --socket=x11 --nosocket=wayland --env=SDL_VIDEODRIVER=x11 "$flatpak_app" "$rom") ;;
        *) return 1 ;;
    esac
}

emulator_installed() {
    if [[ -n $flatpak_app ]]; then
        flatpak info "$flatpak_app" >/dev/null 2>&1
    else
        [[ -x $program ]]
    fi
}

# melonDS rewrites its config on exit, so D2K's required values are restored
# before every launch.
patch_melonds() {
    python3 - "$config_home/melonDS/melonDS.toml" <<'PY'
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
PY
}

# Upper and lower panel rectangles as "width height left top", top to bottom.
# With two outputs they are the outputs themselves; with a single TV, two
# 800x480 panels are scaled and stacked on it as a preview.
panel_geometry() {
    local monitors width height
    monitors=$(xrandr --listmonitors 2>/dev/null | sed -nE 's/.* ([0-9]+)\/[0-9]+x([0-9]+)\/[0-9]+\+(-?[0-9]+)\+(-?[0-9]+).*/\1 \2 \3 \4/p' | sort -k4,4n -k3,3n)
    if [[ $(printf '%s\n' "$monitors" | sed '/^$/d' | wc -l) -ge 2 ]]; then
        printf '%s\n' "$monitors" | head -n 2
        return
    fi
    read -r width height < <(xdotool getdisplaygeometry)
    awk -v width="$width" -v height="$height" 'BEGIN {
        gap = 20
        scale = width / 800
        if ((height - gap) / 960 < scale) scale = (height - gap) / 960
        panel_width = int(800 * scale + .5)
        panel_height = int(480 * scale + .5)
        left = int((width - panel_width) / 2)
        top = int((height - (panel_height * 2 + gap)) / 2)
        print panel_width, panel_height, left, top
        print panel_width, panel_height, left, top + panel_height + gap
    }'
}

real_panels() {
    [[ $(xrandr --listmonitors 2>/dev/null | sed -nE 's/^Monitors: ([0-9]+).*/\1/p') -ge 2 ]]
}

# Emulators resize their own windows after boot (melonDS snaps back to its
# native 256x192), so placement is re-checked through the session and does
# nothing while a window is already in place. On real panels the window is
# made fullscreen on its output: labwc then keeps it covering that output,
# above the desktop panel. The single-TV preview only needs a plain resize.
place_window() {
    local window=$1 width=$2 height=$3 left=$4 top=$5 current
    current=$(xdotool getwindowgeometry "$window" 2>/dev/null | sed -nE 's/.*Position: (-?[0-9]+),(-?[0-9]+).*/\1 \2/p; s/.*Geometry: ([0-9]+)x([0-9]+).*/\1 \2/p' | tr '\n' ' ')
    [[ $current == "$left $top $width $height " ]] && return 0
    if real_panels && command -v wmctrl >/dev/null; then
        wmctrl -i -r "$window" -b remove,fullscreen 2>/dev/null
        xdotool windowmove "$window" "$left" "$top"
        wmctrl -i -r "$window" -b add,fullscreen 2>/dev/null
    else
        xdotool windowsize "$window" "$width" "$height"
        xdotool windowmove "$window" "$left" "$top"
    fi
    log "placed window=$window ${width}x${height} at $left,$top (was ${current% })"
}

place_on_panel() {  # window panel-number(1=upper, 2=lower)
    local width height left top
    read -r width height left top < <(panel_geometry | sed -n "${2}p")
    place_window "$1" "$width" "$height" "$left" "$top"
}

find_largest_window() {
    local candidate width height area largest= largest_area=0
    while IFS= read -r candidate; do
        read -r width height < <(xdotool getwindowgeometry "$candidate" 2>/dev/null | sed -nE 's/.*Geometry: ([0-9]+)x([0-9]+).*/\1 \2/p')
        [[ ${width:-} =~ ^[0-9]+$ && ${height:-} =~ ^[0-9]+$ ]] || continue
        area=$((width * height))
        if ((area > largest_area)); then
            largest=$candidate
            largest_area=$area
        fi
    done
    [[ -n $largest ]] && printf '%s\n' "$largest"
}

# Single-screen games go to the upper panel. Flatpak and AppImage emulators
# own their windows from a child process, so fall back to a title search.
layout_single() {
    local window title
    window=$(find_largest_window < <(xdotool search --onlyvisible --pid "$emulator_pid" 2>/dev/null || true))
    if [[ -z $window ]]; then
        case $console in
            dreamcast) title='[Ff]lycast' ;;
            n64) title='[Mm]upen64|Ship of Harkinian' ;;
            psp) title='PPSSPP' ;;
            *) return 1 ;;
        esac
        window=$(find_largest_window < <(xdotool search --onlyvisible --name "$title" 2>/dev/null || true))
    fi
    [[ -n $window ]] || return 1
    place_on_panel "$window" 1
}

# melonDS opens the DS top screen first and the touch screen second.
layout_melonds() {
    local -a windows
    mapfile -t windows < <(xdotool search --onlyvisible --pid "$emulator_pid" 2>/dev/null | sort -n)
    [[ -n ${windows[0]:-} && -n ${windows[1]:-} ]] || return 1
    place_on_panel "${windows[0]}" 1
    place_on_panel "${windows[1]}" 2
}

layout_azahar() {
    local primary secondary
    primary=$(xdotool search --onlyvisible --name 'Azahar.*([Pp]rimary|[Pp]rincip)' 2>/dev/null | head -n 1 || true)
    secondary=$(xdotool search --onlyvisible --name 'Azahar.*([Ss]econdary|[Ss]econd|[Bb]ottom)' 2>/dev/null | head -n 1 || true)
    [[ -n $primary && -n $secondary ]] || return 1
    place_on_panel "$primary" 1
    place_on_panel "$secondary" 2
}

layout() {
    case $console in
        ds) layout_melonds ;;
        3ds) layout_azahar ;;
        *) layout_single ;;
    esac
}

flatpak_running() {
    flatpak ps --columns=application 2>/dev/null | grep -Fxq "$1"
}

# The emulator runs in its own process group (setsid below), so the whole
# group counts: AppImage runtimes and flatpak wrappers start the real game as
# a child that can outlive the process the launcher started.
emulator_running() {
    kill -0 -- "-$emulator_pid" 2>/dev/null && return 0
    [[ -n $flatpak_app ]] && flatpak_running "$flatpak_app"
}

stop_emulator() {
    local -a pids
    [[ -n $stop_pattern ]] && pkill -TERM -u "$(id -u)" -f "$stop_pattern" 2>/dev/null
    kill -TERM -- "-$emulator_pid" 2>/dev/null
    for _ in {1..20}; do
        emulator_running || break
        sleep 0.15
    done
    if [[ -n $stop_pattern ]]; then
        mapfile -t pids < <(pgrep -u "$(id -u)" -f "$stop_pattern" 2>/dev/null)
        ((${#pids[@]})) && kill -KILL "${pids[@]}" 2>/dev/null
    fi
    kill -KILL -- "-$emulator_pid" 2>/dev/null
    [[ -n $flatpak_app ]] && flatpak kill "$flatpak_app" >/dev/null 2>&1
    return 0
}

if [[ $console == --self-test ]]; then
    build_command ds '/tmp/Test DS.nds'
    [[ ${cmd[3]} == -stylesheet && ${cmd[-1]} == '/tmp/Test DS.nds' ]]
    build_command dreamcast '/tmp/Test Dreamcast.cdi'
    [[ ${cmd[-1]} == '/tmp/Test Dreamcast.cdi' ]]
    build_command ps1 '/tmp/Test Disc.cue'
    [[ ${cmd[*]:3} == '-batch -fastboot -- /tmp/Test Disc.cue' ]]
    build_command n64 '/tmp/Test Game.z64'
    [[ $program == */mupen64plus && ${cmd[-1]} == '/tmp/Test Game.z64' && " ${cmd[*]} " == *' --audio mupen64plus-audio-sdl.so '* ]]
    build_command gamecube '/tmp/Test Game.iso'
    [[ ${cmd[*]:3} == '--batch --exec /tmp/Test Game.iso' ]]
    build_command 3ds '/tmp/Test 3DS.3ds'
    [[ $flatpak_app == org.azahar_emu.Azahar && ${cmd[-1]} == '/tmp/Test 3DS.3ds' ]]
    build_command psp '/tmp/Test Game.iso'
    [[ $flatpak_app == org.ppsspp.PPSSPP && ${cmd[-1]} == '/tmp/Test Game.iso' ]]
    ! build_command n64x /tmp/x
    echo 'launch-emulator self-test passed.'
    exit 0
fi

if [[ $# -ne 2 || ! $console =~ ^(ds|dreamcast|ps1|n64|gamecube|3ds|psp)$ ]]; then
    echo "Usage: $0 {ds|dreamcast|ps1|n64|gamecube|3ds|psp} /absolute/path/to/rom" >&2
    exit 2
fi

log "===== launch-$console start: rom=$rom ====="
"$mpd_script" Pause >/dev/null 2>&1 || log 'MPD pause failed (non-fatal)'
return_to_menu() {
    "$mpd_script" Resume >/dev/null 2>&1 || log 'MPD resume failed (non-fatal)'
    log "===== launch-$console end ====="
    exit 0
}
if [[ ! -f $rom ]]; then
    log 'ROM is missing; returning to Pegasus.'
    return_to_menu
fi
build_command "$console" "$rom"
if ! emulator_installed; then
    log "$console emulator is not installed ($program); returning to Pegasus."
    return_to_menu
fi
if [[ $console == ds ]]; then
    patch_melonds && log 'melonDS config patched' || log 'melonDS config patch failed (non-fatal)'
fi

rm -f "$home_request"
use_desktop_session
export DISPLAY="${DISPLAY:-:0}"
setsid "${cmd[@]}" &
emulator_pid=$!
log "$console started: pid=$emulator_pid program=$program"

placed=false
layout_deadline=$((SECONDS + 30))
next_layout=0
layout_warning=false
while emulator_running; do
    # Every tick while the emulator boots, then every 2 s for the session.
    if ((SECONDS <= layout_deadline || SECONDS >= next_layout)); then
        layout && placed=true
        next_layout=$((SECONDS + 2))
    fi
    if [[ $placed == false && $SECONDS -gt $layout_deadline && $layout_warning == false ]]; then
        log 'Window placement timed out after 30 seconds; emulator remains usable.'
        layout_warning=true
    fi
    if [[ -e $home_request ]]; then
        rm -f "$home_request"
        log 'Home request detected; stopping emulator'
        stop_emulator
    fi
    sleep 0.2
done
wait "$emulator_pid" 2>/dev/null
log "$console exited"
return_to_menu
