#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! -f $1 ]]; then
    echo 'Usage: launch-melonds.sh /absolute/path/to/game.nds' >&2
    exit 1
fi

melonds="$HOME/.local/opt/d2k/melonds/AppRun"
config="${XDG_CONFIG_HOME:-$HOME/.config}/melonDS/melonDS.toml"
if [[ ! -x $melonds || ! -f $config ]]; then
    echo 'melonDS is not configured. Run scripts/linux/install.sh first.' >&2
    exit 1
fi

# melonDS saves Window1.Enabled=false when the secondary window is closed.
sed -i '/^\[Instance0\.Window1\]/,/^\[/{s/^Enabled = .*/Enabled = true/;}' "$config"
exec "$melonds" "$1"
