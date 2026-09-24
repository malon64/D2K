#!/usr/bin/env bash
# Console HUD telemetry. run.sh sources it and calls write_system_status every
# second; run it directly with --self-test to check the output.
# Writes the same file and fields as scripts/windows/run.ps1; the theme polls
# it while the console menu is up.
# shellcheck shell=bash

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    set -euo pipefail
    source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
fi
system_status_file="$repo_root/pegasus/themes/d2k/system-status.json"

# CPU use is the busy share of the jiffies since the previous sample, so the
# first call only primes the counters.
cpu_total=0
cpu_idle=0
cpu_text=--
sample_cpu() {
    local user nice system idle iowait irq softirq steal total idle_all busy
    read -r _ user nice system idle iowait irq softirq steal _ </proc/stat
    total=$((user + nice + system + idle + iowait + irq + softirq + steal))
    idle_all=$((idle + iowait))
    if ((cpu_total > 0 && total > cpu_total)); then
        # iowait can step backwards, so keep the result inside 0-100.
        busy=$((100 * (total - cpu_total - (idle_all - cpu_idle)) / (total - cpu_total)))
        cpu_text="$((busy < 0 ? 0 : busy > 100 ? 100 : busy))%"
    fi
    cpu_total=$total
    cpu_idle=$idle_all
}

# A wireless mouse or keyboard also shows up as a power_supply Battery (the Pi
# lists a Logitech hidpp_battery_0); only a supply with System scope powers the
# machine. A Pi on mains power has none and reads as a full battery.
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

# The degree sign stays a JSON escape so the file is plain ASCII.
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

write_system_status() {
    local temporary="$system_status_file.$$.tmp"
    sample_cpu
    sample_battery
    sample_temperature
    printf '{"battery":"%s","cpu":"%s","temperature":"%s","updatedAt":%s}\n' \
        "$battery_text" "$cpu_text" "$temp_text" "$(date +%s%3N)" >"$temporary"
    mv -f "$temporary" "$system_status_file"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    [[ ${1:-} == --self-test ]] || { echo "Usage: $0 --self-test" >&2; exit 2; }
    sample_cpu
    sleep 0.5
    write_system_status
    status=$(<"$system_status_file")
    pattern='^\{"battery":"[0-9]+%","cpu":"[0-9]+%","temperature":"([0-9]+\\u00b0C|--)","updatedAt":[0-9]+\}$'
    [[ $status =~ $pattern ]] || { echo "System telemetry format check failed: $status" >&2; exit 1; }
    echo "$status"
fi
