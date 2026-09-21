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
    changed = any(key in data for key in ("d2kNav", "d2kMusicReady", "d2kMusicLaunch"))
    for key in ("d2kNav", "d2kMusicReady", "d2kMusicLaunch"):
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

theme_value() {
    [[ -f $theme_settings ]] || return 0
    python3 - "$theme_settings" "$1" <<'PY'
import json
import pathlib
import sys
try:
    value = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")).get(sys.argv[2])
    print("true" if value is True else "" if value is None else value)
except Exception:
    pass
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
last_launch=$(theme_value d2kMusicLaunch)
"$mpd_script" Prepare >/dev/null 2>&1 || echo 'D2K: menu music is unavailable.' >&2

"$pegasus" &
pegasus_pid=$!
while kill -0 "$pegasus_pid" 2>/dev/null; do
    if [[ $music_ready == false && $(theme_value d2kMusicReady) == true ]]; then
        "$mpd_script" Boot >/dev/null 2>&1 || true
        music_ready=true
    fi
    music_launch=$(theme_value d2kMusicLaunch)
    if [[ -n $music_launch && $music_launch != "$last_launch" ]]; then
        last_launch=$music_launch
        "$mpd_script" Pause >/dev/null 2>&1 || true
    fi
    sleep 0.1
done
wait "$pegasus_pid"
