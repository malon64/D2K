#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
for script in "$repo_root"/scripts/linux/*.sh; do
    bash -n "$script"
done
"$repo_root/scripts/linux/mpd.sh" SmokeTest
