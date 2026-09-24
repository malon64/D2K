# Shared paths and helpers for the D2K Linux scripts. Source it; do not run it.
# shellcheck shell=bash

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
linux_dir="$repo_root/scripts/linux"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/d2k"
software_dir="$HOME/.local/opt/d2k"
cache_dir="$HOME/.cache/d2k"
library_dir="$repo_root/library/consoles"
home_request="$state_dir/home-request"

# Scripts started over SSH, from Pegasus, or from autostart all need the
# logged-in desktop's session bus and Labwc's Xwayland display. D2K keeps its
# windows on Xwayland because xdotool/wmctrl place them by absolute position.
use_desktop_session() {
    local runtime="/run/user/$(id -u)" socket
    if [[ -z ${XDG_RUNTIME_DIR:-} && -d $runtime ]]; then
        export XDG_RUNTIME_DIR="$runtime"
    fi
    if [[ -z ${DBUS_SESSION_BUS_ADDRESS:-} && -S "${XDG_RUNTIME_DIR:-}/bus" ]]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
    fi
    if [[ -z ${DISPLAY:-} && -S /tmp/.X11-unix/X0 ]]; then
        export DISPLAY=:0
    fi
    if [[ -z ${WAYLAND_DISPLAY:-} && -n ${XDG_RUNTIME_DIR:-} ]]; then
        socket=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -type s -name 'wayland-*' -printf '%f\n' 2>/dev/null | sort | head -n 1)
        [[ -n $socket ]] && export WAYLAND_DISPLAY="$socket"
    fi
    return 0
}
