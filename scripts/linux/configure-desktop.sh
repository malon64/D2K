#!/usr/bin/env bash
# Configures the Raspberry Pi OS (Labwc) desktop for the D2K panels:
#   - screen layout: upper panel above, lower touch panel centred below (kanshi)
#   - touch input mapped to the lower panel only (Labwc)
#   - sound pinned to one HDMI port (WirePlumber), melonDS and PPSSPP audio
#     buffer floor (pipewire-pulse)
#   - melonDS without title bars, Super+Esc as the keyboard Home button, and
#     the numpad always sending digits (the face-button diamond, docs/controls.md)
# Safe to re-run; re-run it after rewiring the screens. --check verifies it.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Current wiring (see AGENTS.md): Waveshare 5" HDMI touch LCD on HDMI0
# (HDMI-A-1) is the upper panel, the Waveshare 4-DSI-TOUCH-A on the DISP 1
# connector (DSI-2, overlay in config.txt) is the lower touch panel. The 5"
# scaler needs CVT timing (Waveshare's hdmi_cvt 800 480 60 6); its EDID timing
# leaves the picture offset. The DSI panel is 480x800 portrait and is turned to
# landscape by the output transform; Labwc rotates touches mapped to it too.
upper_output=${D2K_UPPER_OUTPUT:-HDMI-A-1}
upper_mode=${D2K_UPPER_MODE:---custom 800x480@60Hz}
lower_output=${D2K_LOWER_OUTPUT:-DSI-2}
lower_mode=${D2K_LOWER_MODE:-480x800}
lower_transform=${D2K_LOWER_TRANSFORM:-270}
touch_output=${D2K_TOUCH_OUTPUT:-$lower_output}
# Touch device=output. The DSI panel's Goodix controller is the menu. The 5"
# panel's USB touch (libinput has reported it under both names) stays on its
# own screen so it cannot reach the menu.
touch_maps=("Goodix Capacitive TouchScreen=$touch_output"
            "WaveShare WS170120=$upper_output"
            "WaveShare WS170120 (USB 1-1)=$upper_output")
# Audio device to disable so PipeWire keeps sound on the other HDMI port. The
# Waveshare 5" accepts HDMI audio and plays it on its 3.5 mm jack; the DSI panel
# has no audio. HDMI1 is 107c706400, HDMI0 is 107c701400.
muted_audio_card=${D2K_MUTED_AUDIO_CARD:-alsa_card.platform-107c706400.hdmi}

kanshi_config="$config_home/kanshi/config"
labwc_config="$config_home/labwc/rc.xml"
wireplumber_rule="$config_home/wireplumber/wireplumber.conf.d/50-d2k-audio.conf"
pulse_rule="$config_home/pipewire/pipewire-pulse.conf.d/50-d2k-emulator-audio.conf"
old_pulse_rule="$config_home/pipewire/pipewire-pulse.conf.d/50-d2k-melonds.conf"
marker='# Managed by D2K scripts/linux/configure-desktop.sh'

size_of() { [[ $1 =~ ([0-9]+)x([0-9]+) ]] && echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"; }
read -r upper_width upper_height < <(size_of "$upper_mode")
read -r lower_width lower_height < <(size_of "$lower_mode")
# A 90/270 transform swaps the panel's width and height on the desktop.
[[ $lower_transform == *90 || $lower_transform == *270 ]] && lower_width=$lower_height
lower_x=$(((upper_width - lower_width) / 2))

kanshi_text="$marker
profile d2k {
    output $upper_output mode $upper_mode position 0,0
    output $lower_output mode $lower_mode transform $lower_transform position $lower_x,$upper_height
}"

wireplumber_text="$marker
monitor.alsa.rules = [
  {
    matches = [ { device.name = \"$muted_audio_card\" } ]
    actions = { update-props = { device.disabled = true } }
  }
]"

# melonDS's audio arrives through the PulseAudio API. Even with
# PULSE_LATENCY_MSEC (launch-emulator.sh) it asks for 480 samples, which
# PipeWire rounds down to a 256-sample (5 ms) graph, and Mario Kart DS still
# underran ~6 times a minute (docs/platform.md). A 1024-sample
# floor gives it 21 ms of margin. PPSSPP (Flatpak, matched by its app id)
# ran at 118 samples (2.7 ms) and its sound glitched the same way, and
# Azahar (Flatpak too) underran at 204 samples in Super Mario 3D Land.
pulse_text="$marker
pulse.rules = [
  {
    matches = [
      { application.name = \"melonDS\" }
      { application.process.binary = \"melonDS\" }
      { pipewire.access.portal.app_id = \"org.ppsspp.PPSSPP\" }
      { pipewire.access.portal.app_id = \"org.azahar_emu.Azahar\" }
    ]
    actions = { update-props = { pulse.min.quantum = 1024/48000 } }
  }
]"

# Labwc's rc.xml belongs to the desktop user, so D2K only inserts its entries.
labwc_edit() {  # apply|check
    if [[ ! -f $labwc_config ]]; then
        [[ $1 == apply && -f /etc/xdg/labwc/rc.xml ]] || return 1
        mkdir -p "$(dirname "$labwc_config")"
        cp /etc/xdg/labwc/rc.xml "$labwc_config"
    fi
    python3 "$linux_dir/py/labwc_rc.py" "$1" "$labwc_config" "$home_request" "${touch_maps[@]}"
}

# Writes a D2K-owned file, keeping a backup of any file D2K did not write.
write_managed() {  # path text -> returns 0 when the file changed
    local path=$1 text=$2
    [[ -f $path && $(<"$path") == "$text" ]] && return 1
    mkdir -p "$(dirname "$path")"
    if [[ -f $path ]] && ! grep -qF "$marker" "$path"; then
        cp -p "$path" "$path.backup.$(date +%Y%m%d%H%M%S)"
    fi
    printf '%s\n' "$text" > "$path"
}

# The numpad is the face-button diamond, so it must always send digits. Num Lock
# alone is not reliable: Labwc and Xwayland have disagreed about its state, and
# with it off Qt emulators read numpad 8/4/6/2 as arrows. The XKB option
# numpad:mac makes the numpad send digits regardless of Num Lock. Labwc reads
# this file at login, so the option applies after the next login or reboot.
labwc_environment="$config_home/labwc/environment"
numpad_option=numpad:mac
xkb_options_edit() {  # apply|check
    local current
    current=$(sed -n 's/^XKB_DEFAULT_OPTIONS=//p' "$labwc_environment" 2>/dev/null | tail -n 1)
    [[ ,$current, == *,$numpad_option,* ]] && return 0
    [[ $1 == check ]] && return 1
    mkdir -p "$(dirname "$labwc_environment")"
    touch "$labwc_environment"
    sed -i '/^XKB_DEFAULT_OPTIONS=/d' "$labwc_environment"
    echo "XKB_DEFAULT_OPTIONS=${current:+$current,}$numpad_option" >> "$labwc_environment"
}

if [[ ${1:-} == --check ]]; then
    status=0
    xkb_options_edit check || { echo "XKB option $numpad_option missing: $labwc_environment" >&2; status=1; }
    [[ -f $kanshi_config && $(<"$kanshi_config") == "$kanshi_text" ]] || { echo "Screen layout differs: $kanshi_config" >&2; status=1; }
    [[ -f $wireplumber_rule && $(<"$wireplumber_rule") == "$wireplumber_text" ]] || { echo "Audio rule differs: $wireplumber_rule" >&2; status=1; }
    [[ -f $pulse_rule && $(<"$pulse_rule") == "$pulse_text" ]] || { echo "Emulator audio rule differs: $pulse_rule" >&2; status=1; }
    labwc_edit check || { echo "Labwc entries missing: $labwc_config" >&2; status=1; }
    ((status == 0)) && echo 'Desktop configuration check passed.'
    exit "$status"
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--check]" >&2
    exit 2
fi

use_desktop_session
if write_managed "$kanshi_config" "$kanshi_text"; then
    pkill -HUP -u "$(id -u)" -x kanshi 2>/dev/null || true
fi
if labwc_edit apply; then
    labwc_pid=$(pgrep -u "$(id -u)" -x labwc | head -n 1 || true)
    [[ -n $labwc_pid ]] && LABWC_PID="$labwc_pid" labwc --reconfigure 2>/dev/null || true
fi
xkb_options_edit apply
if write_managed "$wireplumber_rule" "$wireplumber_text"; then
    systemctl --user restart wireplumber 2>/dev/null || true
fi
# pipewire-pulse reads its rules only at start. Restarting it drops every
# PulseAudio client (Pegasus' sounds, MPD), so restart D2K afterwards.
pulse_changed=false
write_managed "$pulse_rule" "$pulse_text" && pulse_changed=true
# Earlier name of the same rule, from when it only covered melonDS.
if [[ -f $old_pulse_rule ]] && grep -qF "$marker" "$old_pulse_rule"; then
    rm -f "$old_pulse_rule"
    pulse_changed=true
fi
if [[ $pulse_changed == true ]]; then
    systemctl --user restart pipewire-pulse 2>/dev/null || true
fi
echo "Desktop configured: $upper_output above $lower_output, touch on $touch_output, audio device $muted_audio_card disabled."
