#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
software_dir="$HOME/.local/opt/d2k"
source_dir="$HOME/.cache/d2k/pegasus-source"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
pegasus_config="$config_home/pegasus-frontend"
melonds_config="$config_home/melonDS/melonDS.toml"
library_dir="$repo_root/library/consoles"
pegasus_commit=83fd27f40b1535c8479321ce03490e515bcf0d15
melonds_url=https://github.com/melonDS-emu/melonDS/releases/download/1.1/melonDS-1.1-appimage-aarch64.zip
melonds_sha256=c537ae018d6dcedfe9da0317a1d5c0163e69201e23abfa163fa2a63e437ace09
duckstation_url=https://github.com/stenzek/duckstation/releases/download/latest/DuckStation-arm64.AppImage
duckstation_sha256=d67758c25fe3772558662e39bb508620c997cc6cd3d66ecca835e754923f158a

if [[ $# -gt 1 || ( $# -eq 1 && $1 != --refresh-melonds-config ) ]]; then
    echo "Usage: $0 [--refresh-melonds-config]" >&2
    exit 2
fi
if [[ $(uname -m) != aarch64 || ! -f /etc/debian_version ]]; then
    echo 'This installer requires a Debian ARM64 desktop, such as Raspberry Pi OS 64-bit.' >&2
    exit 1
fi
if [[ $EUID -eq 0 ]]; then
    echo 'Run this script as your desktop user; it invokes sudo only for apt.' >&2
    exit 1
fi
if [[ ! -d $library_dir ]]; then
    echo "D2K library is missing at $library_dir. Sync library/ from the Windows workspace first." >&2
    exit 1
fi

sudo apt-get update
sudo apt-get install -y \
    git curl unzip build-essential cmake pkg-config python3 \
    qtbase5-dev qtdeclarative5-dev qtdeclarative5-dev-tools \
    qttools5-dev qttools5-dev-tools qtmultimedia5-dev libqt5svg5-dev \
    libqt5sql5-sqlite libsdl2-dev \
    qml-module-qtquick2 qml-module-qtquick-window2 qml-module-qtmultimedia qml-module-qtgraphicaleffects \
    libgstreamer1.0-0 libfontconfig1 libssl3 libzstd1 \
    mpd mpc xdotool xwayland flatpak ares dolphin-emu \
    pipewire-pulse pipewire-alsa wireplumber pulseaudio-utils

mkdir -p "$software_dir" "$pegasus_config/themes" "$pegasus_config/metafiles" \
    "$(dirname "$melonds_config")" "$config_home/autostart" "$HOME/.cache/d2k"

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
    (
        trap 'rm -rf "$download_dir"' EXIT
        curl -fL --retry 3 -o "$download_dir/melonds.zip" "$melonds_url"
        printf '%s  %s\n' "$melonds_sha256" "$download_dir/melonds.zip" | sha256sum --check -
        unzip -q "$download_dir/melonds.zip" -d "$download_dir"
        chmod +x "$download_dir/melonDS-aarch64.AppImage"
        (cd "$download_dir" && ./melonDS-aarch64.AppImage --appimage-extract >/dev/null)
        mv "$download_dir/squashfs-root" "$software_dir/melonds"
    )
fi

if [[ ! -x $software_dir/duckstation/AppRun ]]; then
    download_dir=$(mktemp -d)
    (
        trap 'rm -rf "$download_dir"' EXIT
        curl -fL --retry 3 -o "$download_dir/duckstation.AppImage" "$duckstation_url"
        printf '%s  %s\n' "$duckstation_sha256" "$download_dir/duckstation.AppImage" | sha256sum --check -
        chmod +x "$download_dir/duckstation.AppImage"
        (cd "$download_dir" && ./duckstation.AppImage --appimage-extract >/dev/null)
        mv "$download_dir/squashfs-root" "$software_dir/duckstation"
    )
fi

flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user -y flathub org.flycast.Flycast org.azahar_emu.Azahar

theme_link="$pegasus_config/themes/d2k"
if [[ -e $theme_link || -L $theme_link ]]; then
    if [[ ! -L $theme_link || $(readlink -f "$theme_link") != "$repo_root/pegasus/themes/d2k" ]]; then
        echo "Existing theme at $theme_link is not this repository's D2K theme." >&2
        exit 1
    fi
else
    ln -s "$repo_root/pegasus/themes/d2k" "$theme_link"
fi

mapfile -t console_dirs < <(find "$library_dir" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/metadata.pegasus.txt' \; -print | sort)
if (( ${#console_dirs[@]} == 0 )); then
    echo "No Pegasus collection metadata found under $library_dir." >&2
    exit 1
fi
printf '%s\n' "${console_dirs[@]}" > "$pegasus_config/game_dirs.txt"

# The private library is copied one-way to the Pi, so it can hold Linux launch
# commands without altering the Windows source library.
python3 - "$library_dir" "$repo_root/scripts/linux/launch-emulator.sh" <<'PY'
import pathlib
import sys

library = pathlib.Path(sys.argv[1])
launcher = sys.argv[2]
consoles = {"nds": "ds", "dreamcast": "dreamcast", "psx": "ps1",
            "n64": "n64", "gc": "gamecube", "n3ds": "3ds"}

for path in library.glob("*/metadata.pegasus.txt"):
    lines = path.read_text(encoding="utf-8").splitlines()
    shortname = next((line.partition(":")[2].strip() for line in lines
                      if line.startswith("shortname:")), "")
    console = consoles.get(shortname)
    if not console:
        continue
    lines = [line for line in lines if not line.startswith(("launch:", "workdir:"))]
    for index, line in enumerate(lines):
        if line.startswith("shortname:"):
            lines[index + 1:index + 1] = [
                f'launch: "{launcher}" {console} "{{file.path}}"',
                f"workdir: {path.parent}",
            ]
            break
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

# The old three-game template is superseded by the synced, full library.
rm -f "$pegasus_config/metafiles/d2k-nds.metadata.pegasus.txt"

if [[ ! -e $pegasus_config/settings.txt ]]; then
    printf 'general.theme: themes/d2k\ngeneral.fullscreen: false\n' > "$pegasus_config/settings.txt"
fi

if [[ ! -e $melonds_config || ${1:-} == --refresh-melonds-config ]]; then
    if [[ -e $melonds_config ]]; then
        cp -p "$melonds_config" "$melonds_config.backup.$(date +%Y%m%d%H%M%S)"
    fi
    cp "$repo_root/docs/emulator-configs/windows/melonds/melonDS.toml" "$melonds_config"
fi
"$repo_root/scripts/linux/configure-emulators.sh"

cat > "$config_home/autostart/d2k.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=D2K
Exec=$repo_root/scripts/linux/run.sh
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

echo "D2K installed with ${#console_dirs[@]} collections. Run scripts/linux/smoke-test.sh before opening D2K."
