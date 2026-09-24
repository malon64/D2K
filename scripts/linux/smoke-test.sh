#!/usr/bin/env bash
# Checks the Linux deployment without opening Pegasus.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

for script in "$linux_dir"/*.sh; do
    bash -n "$script"
done
"$linux_dir/telemetry.sh" --self-test
"$linux_dir/launch-emulator.sh" --self-test
"$linux_dir/configure-emulators.sh" --self-test
"$linux_dir/configure-emulators.sh" --check
"$linux_dir/configure-desktop.sh" --check
# The MPD smoke test stops MPD when it finishes, which would silence a running
# D2K menu.
if pgrep -u "$(id -u)" -x pegasus-fe >/dev/null; then
    echo 'MPD smoke test skipped: D2K is running.'
else
    "$linux_dir/mpd.sh" SmokeTest
fi
