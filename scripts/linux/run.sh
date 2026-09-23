#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
pegasus="$HOME/.local/opt/d2k/pegasus/bin/pegasus-fe"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
theme_settings="$config_home/pegasus-frontend/theme_settings/d2k.json"
mpd_script="$repo_root/scripts/linux/mpd.sh"

if [[ ! -x $pegasus ]]; then
    echo 'Pegasus is missing. Run scripts/linux/install.sh first.' >&2
    exit 1
fi

clear_boot_state() {
    [[ -f $theme_settings ]] || return 0
    python3 - "$theme_settings" <<'PY'
import json
import os
import pathlib
import sys
import tempfile

path = pathlib.Path(sys.argv[1])
try:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("settings root is not an object")
    changed = any(key in data for key in ("d2kNav", "d2kMusicReady", "d2kMusicLaunch", "d2kMusicSeq", "d2kMusicAction", "d2kMusicTrack"))
    for key in ("d2kNav", "d2kMusicReady", "d2kMusicLaunch", "d2kMusicSeq", "d2kMusicAction", "d2kMusicTrack"):
        data.pop(key, None)
    if changed:
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as output:
            json.dump(data, output, separators=(",", ":"))
            output.write("\n")
            temporary = output.name
        os.replace(temporary, path)
except Exception as error:
    print(f"D2K: could not clear saved boot state: {error}", file=sys.stderr)
PY
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
last_status_second=0
if "$mpd_script" Prepare >/dev/null 2>&1; then
    music_prepared=true
else
    echo 'D2K: menu music is unavailable.' >&2
fi

QT_QPA_PLATFORM=xcb "$pegasus" &
pegasus_pid=$!
while kill -0 "$pegasus_pid" 2>/dev/null; do
    [[ -f $theme_settings ]] || { sleep 0.2; continue; }
    settings=$(<"$theme_settings")
    if [[ $settings != "$last_settings" ]]; then
        last_settings=$settings
        mapfile -t theme_values < <(python3 - "$theme_settings" <<'PY'
import json, pathlib, sys
try:
    values = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
except Exception:
    values = {}
for key in ("d2kMusicReady", "d2kMusicLaunch", "d2kMusicSeq", "d2kMusicAction", "d2kMusicTrack"):
    value = values.get(key, "")
    print("true" if value is True else "" if value is None else value)
PY
)
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
    if [[ $music_prepared == true && $music_ready == true && $SECONDS -ne $last_status_second ]]; then
        "$mpd_script" Status >/dev/null 2>&1 || true
        last_status_second=$SECONDS
    fi
    sleep 0.2
done
wait "$pegasus_pid"
