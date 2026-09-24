#!/usr/bin/env bash
# Installs D2K on Raspberry Pi OS 64-bit (Trixie/Labwc). Safe to re-run: every
# step skips work that is already done. See AGENTS.md and
# docs/raspberry-pi-struggles.md for why each piece is installed this way.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

pegasus_config="$config_home/pegasus-frontend"
melonds_config="$config_home/melonDS/melonDS.toml"

pegasus_commit=83fd27f40b1535c8479321ce03490e515bcf0d15
flycast_commit=869038f40ac8cddc7741c3a35d545de057cc0dd5
melonds_url=https://github.com/melonDS-emu/melonDS/releases/download/1.1/melonDS-1.1-appimage-aarch64.zip
melonds_sha256=c537ae018d6dcedfe9da0317a1d5c0163e69201e23abfa163fa2a63e437ace09
duckstation_url=https://github.com/stenzek/duckstation/releases/download/latest/DuckStation-arm64.AppImage
duckstation_sha256=d67758c25fe3772558662e39bb508620c997cc6cd3d66ecca835e754923f158a
# Mupen64Plus "nightly-build" commits, built natively for the Pi's ARM64 dynarec.
mupen_components=(
    mupen64plus-core=b20b27ebf9e5b099a978e86dba609111dc98c837
    mupen64plus-ui-console=c8ac4862a019d7885b24927d9b4db5dd3e42a528
    mupen64plus-video-rice=f0a7b9f391b0e9bc14962b114f7da1ba553060be
    mupen64plus-audio-sdl=2faed1c7e62c5f292948e7cd2398c184970cf794
    mupen64plus-input-sdl=842c39e89749aa3a8d02202b2afddd20b29cdfdb
    mupen64plus-rsp-hle=8a7a472a7172eb2c8725b305eae26818ed7b51a2
)
# Ship of Harkinian (Ocarina of Time only): a Raspberry Pi AppImage build that
# is not an official HarbourMasters release, so it is supplied as a local zip.
soh_zip="$cache_dir/downloads/soh-raspberry-pi-0.0.2.zip"
soh_sha256=7f0536118d06381e6dfd9cf7324fba5226085e8860b37665e2044d72ec1b1a6d
ocarina_rom="$library_dir/n64/games/ocarina-of-time/rom.z64"

refresh_melonds=false
while (($#)); do
    case $1 in
        --refresh-melonds-config) refresh_melonds=true ;;
        --soh-zip) soh_zip=${2:?--soh-zip needs a path}; shift ;;
        *) echo "Usage: $0 [--refresh-melonds-config] [--soh-zip PATH]" >&2; exit 2 ;;
    esac
    shift
done

step() { printf '\n==> %s\n' "$*"; }

check_host() {
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
}

install_packages() {
    step 'System packages'
    sudo apt-get update
    sudo apt-get install -y \
        git curl unzip build-essential cmake pkg-config python3 libcurl4-openssl-dev \
        qtbase5-dev qtdeclarative5-dev qtdeclarative5-dev-tools \
        qttools5-dev qttools5-dev-tools qtmultimedia5-dev libqt5svg5-dev \
        libqt5sql5-sqlite libsdl2-dev \
        qml-module-qtquick2 qml-module-qtquick-window2 qml-module-qtmultimedia qml-module-qtgraphicaleffects \
        libgstreamer1.0-0 libfontconfig1 libssl3t64 libzstd1 \
        libpng-dev libfreetype-dev zlib1g-dev libsamplerate0-dev libspeexdsp-dev libgl-dev libglu1-mesa-dev \
        mpd mpc xdotool wmctrl xwayland x11-xserver-utils kanshi flatpak dolphin-emu \
        pipewire-pulse pipewire-alsa wireplumber pulseaudio-utils
}

# Downloads url to a temp file, checks it, and hands the path to a callback.
fetch_checked() {  # url sha256 callback
    local dir
    dir=$(mktemp -d)
    trap 'rm -rf "$dir"' RETURN
    curl -fL --retry 3 -o "$dir/download" "$1"
    printf '%s  %s\n' "$2" "$dir/download" | sha256sum --check -
    "$3" "$dir"
}

extract_appimage() {  # dir-with-download destination
    chmod +x "$1/download"
    (cd "$1" && ./download --appimage-extract >/dev/null)
    mv "$1/squashfs-root" "$2"
}

install_pegasus() {
    [[ -x $software_dir/pegasus/bin/pegasus-fe ]] && return
    step 'Pegasus (source build)'
    local src="$cache_dir/pegasus-source"
    [[ -d $src/.git ]] || git clone --recursive https://github.com/mmatyas/pegasus-frontend.git "$src"
    git -C "$src" fetch origin "$pegasus_commit"
    git -C "$src" checkout --detach "$pegasus_commit"
    git -C "$src" submodule update --init --recursive
    cmake -S "$src" -B "$src/build-d2k" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$software_dir/pegasus" -DPEGASUS_ENABLE_LTO=OFF
    cmake --build "$src/build-d2k" --parallel 2
    cmake --install "$src/build-d2k"
}

install_melonds() {
    [[ -x $software_dir/melonds/AppRun ]] && return
    step 'melonDS (DS)'
    unpack_melonds() {
        unzip -q "$1/download" -d "$1"
        mv "$1/melonDS-aarch64.AppImage" "$1/download"
        extract_appimage "$1" "$software_dir/melonds"
    }
    fetch_checked "$melonds_url" "$melonds_sha256" unpack_melonds
}

install_duckstation() {
    [[ -x $software_dir/duckstation/AppRun ]] && return
    step 'DuckStation (PS1)'
    unpack_duckstation() { extract_appimage "$1" "$software_dir/duckstation"; }
    fetch_checked "$duckstation_url" "$duckstation_sha256" unpack_duckstation
}

# The Flathub ARM64 Flycast assumes 4 KiB pages and aborts on the Pi 5's
# 16 KiB kernel. Building upstream on the Pi records the actual page size.
install_flycast() {
    [[ -x $software_dir/flycast/bin/flycast ]] && return
    step 'Flycast (Dreamcast, source build)'
    local src="$cache_dir/flycast-source"
    [[ -d $src/.git ]] || git clone --recursive https://github.com/flyinghead/flycast.git "$src"
    git -C "$src" fetch --depth 1 origin "$flycast_commit"
    git -C "$src" checkout --detach "$flycast_commit"
    git -C "$src" submodule update --init --recursive
    cmake -S "$src" -B "$src/build-d2k" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$software_dir/flycast" -DUSE_BREAKPAD=OFF -DUSE_VULKAN=OFF
    cmake --build "$src/build-d2k" --parallel 2
    cmake --install "$src/build-d2k"
}

# N64 except Ocarina of Time. ares renders black on V3DV and RMG stalls; this
# native core + Rice build is the one that plays on the Pi.
install_mupen64plus() {
    [[ -x $software_dir/mupen64plus/bin/mupen64plus ]] && return
    step 'Mupen64Plus (N64, source build)'
    local src="$cache_dir/mupen64plus" entry name commit
    local -a make_args=(PREFIX="$software_dir/mupen64plus" APIDIR="$src/mupen64plus-core/src/api" LDCONFIG=true)
    for entry in "${mupen_components[@]}"; do
        name=${entry%%=*} commit=${entry#*=}
        [[ -d $src/$name/.git ]] || git clone "https://github.com/mupen64plus/$name.git" "$src/$name"
        git -C "$src/$name" fetch origin "$commit"
        git -C "$src/$name" checkout --detach "$commit"
    done
    for entry in "${mupen_components[@]}"; do
        name=${entry%%=*}
        make -C "$src/$name/projects/unix" all "${make_args[@]}" -j2
        make -C "$src/$name/projects/unix" install "${make_args[@]}"
    done
}

# Ocarina of Time runs natively (and far better than emulated) in Ship of
# Harkinian. SoH extracts oot.o2r from the linked ROM on its first launch.
install_ship_of_harkinian() {
    local dir="$software_dir/shipwright"
    if [[ ! -x $dir/soh-raspberry-pi.AppImage ]]; then
        if [[ ! -f $soh_zip ]]; then
            echo "Ship of Harkinian skipped: $soh_zip not found (Ocarina of Time will use Mupen64Plus)."
            return
        fi
        step 'Ship of Harkinian (Ocarina of Time)'
        printf '%s  %s\n' "$soh_sha256" "$soh_zip" | sha256sum --check -
        mkdir -p "$dir"
        unzip -qo "$soh_zip" -d "$dir"
        chmod +x "$dir/soh-raspberry-pi.AppImage"
    fi
    [[ -f $ocarina_rom ]] && ln -sfn "$ocarina_rom" "$dir/oot.z64"
    return 0
}

install_flatpaks() {
    step 'Flatpak emulators (3DS, PSP)'
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install --user -y flathub org.azahar_emu.Azahar org.ppsspp.PPSSPP
}

setup_pegasus() {
    step 'Pegasus theme and library'
    mkdir -p "$pegasus_config/themes"
    local theme_link="$pegasus_config/themes/d2k"
    if [[ -e $theme_link || -L $theme_link ]]; then
        if [[ ! -L $theme_link || $(readlink -f "$theme_link") != "$repo_root/pegasus/themes/d2k" ]]; then
            echo "Existing theme at $theme_link is not this repository's D2K theme." >&2
            exit 1
        fi
    else
        ln -s "$repo_root/pegasus/themes/d2k" "$theme_link"
    fi

    local -a console_dirs
    mapfile -t console_dirs < <(find "$library_dir" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/metadata.pegasus.txt' \; -print | sort)
    if ((${#console_dirs[@]} == 0)); then
        echo "No Pegasus collection metadata found under $library_dir." >&2
        exit 1
    fi
    printf '%s\n' "${console_dirs[@]}" > "$pegasus_config/game_dirs.txt"
    [[ -e $pegasus_config/settings.txt ]] ||
        printf 'general.theme: themes/d2k\ngeneral.fullscreen: false\n' > "$pegasus_config/settings.txt"

    # The private library is copied one-way to the Pi, so it can hold Linux
    # launch commands without altering the Windows source library.
    python3 - "$library_dir" "$linux_dir/launch-emulator.sh" <<'PY'
import pathlib
import sys

library = pathlib.Path(sys.argv[1])
launcher = sys.argv[2]
consoles = {"nds": "ds", "dreamcast": "dreamcast", "psx": "ps1",
            "n64": "n64", "gc": "gamecube", "n3ds": "3ds", "psp": "psp"}

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
    if any(line.lstrip().startswith("launch: powershell.exe") for line in lines):
        raise SystemExit(f"Windows launch command remains in {path}")
PY
    echo "${#console_dirs[@]} collections registered."
}

setup_emulator_configs() {
    step 'Emulator configuration'
    mkdir -p "$(dirname "$melonds_config")"
    if [[ ! -e $melonds_config || $refresh_melonds == true ]]; then
        [[ -e $melonds_config ]] && cp -p "$melonds_config" "$melonds_config.backup.$(date +%Y%m%d%H%M%S)"
        cp "$repo_root/docs/emulator-configs/linux/melonds/melonDS.toml" "$melonds_config"
    fi
    "$linux_dir/configure-emulators.sh"
}

setup_autostart() {
    step 'Autostart'
    mkdir -p "$config_home/autostart"
    cat > "$config_home/autostart/d2k.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=D2K
Exec=$linux_dir/run.sh
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
}

check_host
install_packages
mkdir -p "$software_dir" "$cache_dir"
install_pegasus
install_melonds
install_duckstation
install_flycast
install_mupen64plus
install_ship_of_harkinian
install_flatpaks
setup_pegasus
setup_emulator_configs
step 'Desktop (screens, touch, audio, Home key)'
"$linux_dir/configure-desktop.sh"
setup_autostart
echo
echo 'D2K installed. Run scripts/linux/smoke-test.sh before opening D2K.'
