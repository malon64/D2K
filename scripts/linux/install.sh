#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
software_dir="$HOME/.local/opt/d2k"
source_dir="$HOME/.cache/d2k/pegasus-source"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
pegasus_config="$config_home/pegasus-frontend"
melonds_config="$config_home/melonDS/melonDS.toml"
rom_dir="$HOME/Games/NDS"
pegasus_commit=83fd27f40b1535c8479321ce03490e515bcf0d15
melonds_url=https://github.com/melonDS-emu/melonDS/releases/download/1.1/melonDS-1.1-appimage-aarch64.zip
melonds_sha256=c537ae018d6dcedfe9da0317a1d5c0163e69201e23abfa163fa2a63e437ace09

if [[ $# -gt 1 || ( $# -eq 1 && $1 != --refresh-melonds-config ) ]]; then
    echo "Usage: $0 [--refresh-melonds-config]" >&2
    exit 2
fi
if [[ $(uname -m) != aarch64 || ! -f /etc/debian_version ]]; then
    echo 'This installer requires a Debian ARM64 desktop, such as Radxa OS on ROCK 4D.' >&2
    exit 1
fi
if [[ $EUID -eq 0 ]]; then
    echo 'Run this script as your desktop user; it invokes sudo only for apt.' >&2
    exit 1
fi

sudo apt-get update
sudo apt-get install -y \
    git curl unzip build-essential cmake pkg-config \
    qtbase5-dev qtdeclarative5-dev qtdeclarative5-dev-tools \
    qttools5-dev qttools5-dev-tools qtmultimedia5-dev libqt5svg5-dev \
    libqt5sql5-sqlite libsdl2-dev \
    qml-module-qtquick2 qml-module-qtquick-window2 qml-module-qtmultimedia \
    libgstreamer1.0-0 libfontconfig1 libssl3 libzstd1

mkdir -p "$software_dir" "$pegasus_config/themes" "$pegasus_config/metafiles" \
    "$(dirname "$melonds_config")" "$rom_dir" "$(dirname "$source_dir")" \
    "$config_home/autostart"

if [[ ! -x $software_dir/pegasus/bin/pegasus-fe ]]; then
    if [[ ! -d $source_dir/.git ]]; then
        git clone --recursive https://github.com/mmatyas/pegasus-frontend.git "$source_dir"
    fi
    git -C "$source_dir" fetch origin "$pegasus_commit"
    git -C "$source_dir" checkout --detach "$pegasus_commit"
    git -C "$source_dir" submodule update --init --recursive
    cmake -S "$source_dir" -B "$source_dir/build-d2k" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$software_dir/pegasus" \
        -DPEGASUS_ENABLE_LTO=OFF
    cmake --build "$source_dir/build-d2k" --parallel 2
    cmake --install "$source_dir/build-d2k"
fi

if [[ ! -x $software_dir/melonds/AppRun ]]; then
    download_dir=$(mktemp -d)
    trap 'rm -rf "$download_dir"' EXIT
    curl -fL --retry 3 -o "$download_dir/melonds.zip" "$melonds_url"
    printf '%s  %s\n' "$melonds_sha256" "$download_dir/melonds.zip" | sha256sum --check -
    unzip -q "$download_dir/melonds.zip" -d "$download_dir"
    chmod +x "$download_dir/melonDS-aarch64.AppImage"
    (cd "$download_dir" && ./melonDS-aarch64.AppImage --appimage-extract >/dev/null)
    mv "$download_dir/squashfs-root" "$software_dir/melonds"
fi

theme_link="$pegasus_config/themes/d2k"
if [[ -e $theme_link || -L $theme_link ]]; then
    if [[ ! -L $theme_link || $(readlink -f "$theme_link") != "$repo_root/pegasus/themes/d2k" ]]; then
        echo "Existing theme at $theme_link is not this repository's D2K theme." >&2
        exit 1
    fi
else
    ln -s "$repo_root/pegasus/themes/d2k" "$theme_link"
fi

if [[ ! -e $pegasus_config/settings.txt ]]; then
    printf 'general.theme: themes/d2k\ngeneral.fullscreen: false\n' > "$pegasus_config/settings.txt"
fi

# Paths are generated for the current desktop user; the source template stays in Git.
sed -e "s|@REPO@|$repo_root|g" -e "s|@ROM_DIR@|$rom_dir|g" \
    "$repo_root/pegasus/metadata/nds/nds.hardware.pegasus.txt.in" \
    > "$pegasus_config/metafiles/d2k-nds.metadata.pegasus.txt"

if [[ ! -e $melonds_config || ${1:-} == --refresh-melonds-config ]]; then
    if [[ -e $melonds_config ]]; then
        cp -p "$melonds_config" "$melonds_config.backup.$(date +%Y%m%d%H%M%S)"
    fi
    cp "$repo_root/pegasus/melonds/melonDS.hardware.toml" "$melonds_config"
fi

cat > "$config_home/autostart/d2k.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=D2K
Exec="$repo_root/scripts/linux/run.sh"
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

echo 'D2K installed. Copy your three named ROMs into ~/Games/NDS, then run scripts/linux/run.sh from the desktop.'
