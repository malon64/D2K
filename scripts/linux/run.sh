#!/usr/bin/env bash
set -euo pipefail

pegasus="$HOME/.local/opt/d2k/pegasus/bin/pegasus-fe"
if [[ ! -x $pegasus ]]; then
    echo 'Pegasus is missing. Run scripts/linux/install.sh first.' >&2
    exit 1
fi

exec "$pegasus"
