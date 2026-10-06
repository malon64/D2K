#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
pegasus="$software_dir/pegasus/bin/pegasus-fe"
theme_settings="$config_home/pegasus-frontend/theme_settings/d2k.json"
mpd_script="$linux_dir/mpd.sh"
source "$linux_dir/telemetry.sh"

if [[ ! -x $pegasus ]]; then
    echo 'Pegasus is missing. Run scripts/linux/install.sh first.' >&2
    exit 1
fi

# Prefer Labwc's Xwayland display: the theme places its two panel windows by
# absolute position, which native Wayland clients cannot do.
use_desktop_session
if [[ -n ${DISPLAY:-} ]]; then
    qt_platform=xcb
elif [[ -n ${WAYLAND_DISPLAY:-} && -S "${XDG_RUNTIME_DIR:-}/$WAYLAND_DISPLAY" ]]; then
    qt_platform=wayland
else
    echo 'D2K: no active graphical display was found for this user.' >&2
    exit 1
fi

clear_boot_state() {
    [[ -f $theme_settings ]] || return 0
    python3 "$linux_dir/py/theme_state.py" clear "$theme_settings"
}

pegasus_pid=
cleanup() {
    if [[ -n $pegasus_pid ]] && kill -0 "$pegasus_pid" 2>/dev/null; then
        kill -TERM "$pegasus_pid" 2>/dev/null || true
        for _ in {1..20}; do
            kill -0 "$pegasus_pid" 2>/dev/null || break
            sleep 0.1
        done
        kill -KILL "$pegasus_pid" 2>/dev/null || true
    fi
    "$mpd_script" Stop >/dev/null 2>&1 || true
}
trap cleanup EXIT
trap 'cleanup; exit 0' INT TERM

clear_boot_state
music_ready=false
music_prepared=false
last_launch=""
last_music_seq=""
last_settings=""
last_second=0
if "$mpd_script" Prepare >/dev/null 2>&1; then
    music_prepared=true
else
    echo 'D2K: menu music is unavailable.' >&2
fi

QML_XHR_ALLOW_FILE_READ=1 QT_QPA_PLATFORM="$qt_platform" "$pegasus" &
pegasus_pid=$!
sample_cpu
while kill -0 "$pegasus_pid" 2>/dev/null; do
    # Once a second: HUD telemetry, and the music player's position. Both are
    # only shown in the menu, so they pause while a game runs: each status
    # write starts mpc and python3, CPU time the emulator can use instead.
    if ((SECONDS != last_second)) && ! game_running; then
        last_second=$SECONDS
        write_system_status || true
        if [[ $music_prepared == true && $music_ready == true ]]; then
            "$mpd_script" Status >/dev/null 2>&1 || true
        fi
    fi
    [[ -f $theme_settings ]] || { sleep 0.2; continue; }
    settings=$(<"$theme_settings")
    if [[ $settings != "$last_settings" ]]; then
        last_settings=$settings
        mapfile -t theme_values < <(python3 "$linux_dir/py/theme_state.py" read "$theme_settings")
        ready=${theme_values[0]:-}
        music_launch=${theme_values[1]:-}
        music_seq=${theme_values[2]:-}
        music_action=${theme_values[3]:-}
        music_track=${theme_values[4]:-}
        if [[ $music_prepared == true && $music_ready == false && $ready == true ]]; then
            "$mpd_script" Boot >/dev/null 2>&1 || true
            music_ready=true
        fi
        if [[ $music_prepared == true && -n $music_launch && $music_launch != "$last_launch" ]]; then
            last_launch=$music_launch
            "$mpd_script" Pause >/dev/null 2>&1 || true
        fi
        if [[ $music_prepared == true && -n $music_seq && $music_seq != "$last_music_seq" ]]; then
            last_music_seq=$music_seq
            case $music_action in
                play) "$mpd_script" Play "$music_track" >/dev/null 2>&1 || true ;;
                pause) "$mpd_script" Pause >/dev/null 2>&1 || true ;;
                resume) "$mpd_script" Resume >/dev/null 2>&1 || true ;;
            esac
        fi
    fi
    sleep 0.2
done
wait "$pegasus_pid"
