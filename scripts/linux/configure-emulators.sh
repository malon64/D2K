#!/usr/bin/env bash
# Merges the D2K overlays in docs/emulator-configs/linux/ into each emulator's
# own Linux configuration. Only the overlay's keys change, so BIOS paths,
# controllers, saves and user preferences survive. --check verifies them.
set -euo pipefail

if [[ ${1:-} == --self-test ]]; then
    test_home=$(mktemp -d)
    trap 'rm -rf "$test_home"' EXIT
    HOME="$test_home" XDG_CONFIG_HOME="$test_home/.config" "$0"
    HOME="$test_home" XDG_CONFIG_HOME="$test_home/.config" "$0" --check
    echo 'Emulator configuration self-test passed.'
    exit 0
fi
if [[ $# -gt 1 || ( $# -eq 1 && $1 != --check ) ]]; then
    echo "Usage: $0 [--check|--self-test]" >&2
    exit 2
fi

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

python3 "$linux_dir/py/configure_emulators.py" "$repo_root" "$config_home" "$HOME" "$software_dir" "${1:-}"
