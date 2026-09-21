#!/usr/bin/env bash
set -euo pipefail

action=${1:-}
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
music_dir="$repo_root/library/consoles/music"
playlist="$music_dir/playlist.m3u"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/d2k/mpd"
config="$state_dir/mpd.conf"
pid_file="$state_dir/mpd.pid"
port=6600

mpc_cmd() { mpc --host 127.0.0.1 --port "$port" "$@"; }

d2k_pid() {
    if [[ -f $pid_file ]] && kill -0 "$(<"$pid_file")" 2>/dev/null; then
        cat "$pid_file"
        return 0
    fi
    pgrep -f "mpd $config" | head -n 1 || true
}

tracks() {
    [[ -f $playlist ]] || { echo "D2K playlist is missing: $playlist" >&2; return 1; }
    local track
    while IFS= read -r track || [[ -n $track ]]; do
        [[ -z $track || $track == \#* ]] && continue
        [[ $track != /* && $track != *..* && -f $music_dir/$track ]] || {
            echo "Invalid D2K playlist entry: $track" >&2
            return 1
        }
        [[ -s $music_dir/$track ]] && printf '%s\n' "$track"
    done < "$playlist"
}

fade() {
    local target=$1 current step volume
    current=$(mpc_cmd volume | sed -n 's/^volume: \([0-9][0-9]*\)%.*/\1/p')
    [[ $current =~ ^[0-9]+$ ]] || current=100
    for step in 1 2 3 4 5; do
        volume=$((current + (target - current) * step / 5))
        mpc_cmd volume "$volume" >/dev/null
        sleep 0.12
    done
}

start() {
    command -v mpd >/dev/null && command -v mpc >/dev/null || {
        echo 'MPD is missing. Run scripts/linux/install.sh first.' >&2
        return 1
    }
    mkdir -p "$state_dir"
    local existing_pid
    existing_pid=$(d2k_pid)
    if [[ -n $existing_pid ]]; then
        printf '%s\n' "$existing_pid" > "$pid_file"
        return 0
    fi
    rm -f "$pid_file"
    if mpc_cmd status >/dev/null 2>&1; then
        echo "MPD port $port is already in use." >&2
        return 1
    fi
    cat > "$config" <<EOF
music_directory "$music_dir"
playlist_directory "$state_dir/playlists"
db_file "$state_dir/database"
state_file "$state_dir/state"
pid_file "$pid_file"
log_file "$state_dir/mpd.log"
bind_to_address "127.0.0.1"
port "$port"
zeroconf_enabled "no"
audio_output {
    type "pulse"
    name "D2K"
    mixer_type "software"
}
EOF
    mkdir -p "$state_dir/playlists"
    mpd "$config"
    for _ in {1..50}; do
        mpc_cmd status >/dev/null 2>&1 && return 0
        sleep 0.1
    done
    echo 'D2K MPD did not become ready.' >&2
    return 1
}

queue() {
    local track count=0
    # MPD's first database scan is asynchronous. Waiting here prevents the
    # first launch from trying to add tracks before they exist in its database.
    mpc_cmd --wait update >/dev/null
    mpc_cmd clear >/dev/null
    while IFS= read -r track; do
        mpc_cmd add "$track" >/dev/null
        ((count += 1))
    done < <(tracks)
    (( count > 0 )) || { echo 'D2K playlist has no playable tracks.' >&2; return 1; }
    mpc_cmd random on >/dev/null
    mpc_cmd repeat on >/dev/null
    mpc_cmd crossfade 5 >/dev/null
    mpc_cmd volume 0 >/dev/null
    mpc_cmd play >/dev/null
}

stop() {
    local existing_pid
    existing_pid=$(d2k_pid)
    if [[ -n $existing_pid ]] && kill -0 "$existing_pid" 2>/dev/null; then
        fade 0 || true
        mpc_cmd stop >/dev/null 2>&1 || true
        kill -TERM "$existing_pid" 2>/dev/null || true
        for _ in {1..20}; do
            kill -0 "$existing_pid" 2>/dev/null || break
            sleep 0.1
        done
        kill -KILL "$existing_pid" 2>/dev/null || true
    fi
    rm -f "$pid_file"
}

case $action in
    Prepare) start && queue && mpc_cmd pause >/dev/null ;;
    Boot) mpc_cmd pause >/dev/null && fade 100 ;;
    Start) start && queue && fade 100 ;;
    Pause) fade 0 && mpc_cmd pause >/dev/null ;;
    Resume) mpc_cmd pause >/dev/null && fade 100 ;;
    Stop) stop ;;
    SmokeTest)
        trap stop EXIT
        start
        queue
        fade 100
        [[ $(mpc_cmd playlist | wc -l) -gt 0 ]]
        mpc_cmd status | grep -q '\[playing\]'
        echo 'MPD smoke test passed.'
        ;;
    *) echo "Usage: $0 {Prepare|Boot|Start|Pause|Resume|Stop|SmokeTest}" >&2; exit 2 ;;
esac
