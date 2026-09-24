#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
pegasus="$software_dir/pegasus/bin/pegasus-fe"
theme_settings="$config_home/pegasus-frontend/theme_settings/d2k.json"
mpd_script="$linux_dir/mpd.sh"
system_status_file="$repo_root/pegasus/themes/d2k/system-status.json"

# CPU use is the busy share of the jiffies since the previous sample, so the
# first call only primes the counters.
cpu_total=0
cpu_idle=0
cpu_text=--
sample_cpu() {
    local user nice system idle iowait irq softirq steal total idle_all
    read -r _ user nice system idle iowait irq softirq steal _ </proc/stat
    total=$((user + nice + system + idle + iowait + irq + softirq + steal))
    idle_all=$((idle + iowait))
    if ((cpu_total > 0 && total > cpu_total)); then
        # iowait can step backwards, so keep the result inside 0-100.
        local busy=$((100 * (total - cpu_total - (idle_all - cpu_idle)) / (total - cpu_total)))
        cpu_text="$((busy < 0 ? 0 : busy > 100 ? 100 : busy))%"
    fi
    cpu_total=$total
    cpu_idle=$idle_all
}

# A wireless mouse or keyboard also shows up as a power_supply Battery (the Pi
# lists a Logitech hidpp_battery_0); only a supply with System scope powers the
# machine. A Pi on mains power has none and reads as a full battery.
battery_text=100%
sample_battery() {
    local supply
    battery_text=100%
    for supply in /sys/class/power_supply/*; do
        [[ -r $supply/type && -r $supply/capacity && $(<"$supply/type") == Battery ]] || continue
        [[ $(cat "$supply/scope" 2>/dev/null || true) == Device ]] && continue
        battery_text="$(<"$supply/capacity")%"
        return 0
    done
}

temp_text=--
sample_temperature() {
    local zone millidegrees
    temp_text=--
    for zone in /sys/class/thermal/thermal_zone*; do
        [[ -r $zone/type && -r $zone/temp ]] || continue
        case $(<"$zone/type") in
            cpu-thermal | x86_pkg_temp)
                millidegrees=$(<"$zone/temp")
                temp_text="$(((millidegrees + 500) / 1000))\\u00b0C"
                return 0
                ;;
        esac
    done
}

# Same file and fields as scripts/windows/run.ps1; the theme polls it while the
# console menu is up.
write_system_status() {
    local temporary="$system_status_file.$$.tmp"
    sample_cpu
    sample_battery
    sample_temperature
    printf '{"battery":"%s","cpu":"%s","temperature":"%s","updatedAt":%s}\n' \
        "$battery_text" "$cpu_text" "$temp_text" "$(date +%s%3N)" >"$temporary"
    mv -f "$temporary" "$system_status_file"
}

if [[ ${1:-} == --self-test ]]; then
    sample_cpu
    sleep 0.5
    write_system_status
    status=$(<"$system_status_file")
    pattern='^\{"battery":"([0-9]+%|--)","cpu":"([0-9]+%|--)","temperature":"([0-9]+\\u00b0C|--)","updatedAt":[0-9]+\}$'
    [[ $status =~ $pattern && $cpu_text != -- ]] || { echo "System telemetry format check failed: $status" >&2; exit 1; }
    echo "$status"
    exit 0
fi

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
last_system_second=0
sample_cpu
if "$mpd_script" Prepare >/dev/null 2>&1; then
    music_prepared=true
else
    echo 'D2K: menu music is unavailable.' >&2
fi

QML_XHR_ALLOW_FILE_READ=1 QT_QPA_PLATFORM="$qt_platform" "$pegasus" &
pegasus_pid=$!
while kill -0 "$pegasus_pid" 2>/dev/null; do
    if ((SECONDS != last_system_second)); then
        write_system_status || true
        last_system_second=$SECONDS
    fi
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
