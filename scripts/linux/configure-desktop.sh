#!/usr/bin/env bash
# Configures the Raspberry Pi OS (Labwc) desktop for the D2K panels:
#   - screen layout: upper panel above, lower touch panel centred below (kanshi)
#   - touch input mapped to the lower panel only (Labwc)
#   - sound pinned to one HDMI port (WirePlumber)
#   - melonDS without title bars, Super+Esc as the keyboard Home button, and
#     the numpad always sending digits (the face-button diamond, docs/controls.md)
# Safe to re-run; re-run it after rewiring the screens. --check verifies it.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Current wiring (see AGENTS.md): Waveshare 5" HDMI touch LCD on HDMI0
# (HDMI-A-1) is the lower panel, the Samsung LS27R75 desk monitor on HDMI1
# (HDMI-A-2) is the upper panel. The Waveshare scaler needs CVT timing
# (Waveshare's hdmi_cvt 800 480 60 6); its EDID timing leaves the picture
# offset. The desk monitor runs at 1080p rather than its native 1440p to keep
# the GPU load of scaling emulator output down.
upper_output=${D2K_UPPER_OUTPUT:-HDMI-A-2}
upper_mode=${D2K_UPPER_MODE:-1920x1080}
lower_output=${D2K_LOWER_OUTPUT:-HDMI-A-1}
lower_mode=${D2K_LOWER_MODE:---custom 800x480@60Hz}
touch_output=${D2K_TOUCH_OUTPUT:-$lower_output}
# libinput has reported this panel under both names.
touch_devices=("WaveShare WS170120" "WaveShare WS170120 (USB 1-1)")
# Audio device to disable so PipeWire keeps sound on the other HDMI port. The
# desk monitor has no speakers (its ELD lists no audio formats); the Waveshare
# accepts HDMI audio and plays it on its 3.5 mm jack. HDMI1 is
# 107c706400, HDMI0 is 107c701400.
muted_audio_card=${D2K_MUTED_AUDIO_CARD:-alsa_card.platform-107c706400.hdmi}

kanshi_config="$config_home/kanshi/config"
labwc_config="$config_home/labwc/rc.xml"
wireplumber_rule="$config_home/wireplumber/wireplumber.conf.d/50-d2k-audio.conf"
marker='# Managed by D2K scripts/linux/configure-desktop.sh'

size_of() { [[ $1 =~ ([0-9]+)x([0-9]+) ]] && echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"; }
read -r upper_width upper_height < <(size_of "$upper_mode")
read -r lower_width _ < <(size_of "$lower_mode")
lower_x=$(((upper_width - lower_width) / 2))

kanshi_text="$marker
profile d2k {
    output $upper_output mode $upper_mode position 0,0
    output $lower_output mode $lower_mode position $lower_x,$upper_height
}"

wireplumber_text="$marker
monitor.alsa.rules = [
  {
    matches = [ { device.name = \"$muted_audio_card\" } ]
    actions = { update-props = { device.disabled = true } }
  }
]"

# Labwc's rc.xml belongs to the desktop user, so D2K only inserts its entries.
labwc_edit() {  # apply|check
    if [[ ! -f $labwc_config ]]; then
        [[ $1 == apply && -f /etc/xdg/labwc/rc.xml ]] || return 1
        mkdir -p "$(dirname "$labwc_config")"
        cp /etc/xdg/labwc/rc.xml "$labwc_config"
    fi
    python3 - "$1" "$labwc_config" "$home_request" "$touch_output" "${touch_devices[@]}" <<'PY'
import pathlib
import re
import sys

mode, path, home_request, touch_output, *devices = sys.argv[1:]
path = pathlib.Path(path)
text = original = path.read_text(encoding="utf-8")
# A panel's touch mapping must point at its current output: drop any mapping
# of these devices to another output (left over from earlier wiring).
stale = re.compile(r'^\s*<touch deviceName="(%s)" mapToOutput="(?!%s")[^"]*"[^>]*/>\n'
                   % ("|".join(map(re.escape, devices)), re.escape(touch_output)), re.M)
if stale.search(text):
    if mode == "check":
        sys.exit(1)
    text = stale.sub("", text)
# The numpad is the controller's face-button diamond (docs/controls.md). With
# Num Lock off, numpad 8/4/6/2 arrive as KP_Up/Left/Right/Down and Qt emulators
# read them as the arrow keys, which are the D-pad.
if "<numlock>on</numlock>" not in text:
    if mode == "check":
        sys.exit(1)
    text, count = re.subn(r"<numlock>\s*\w*\s*</numlock>", "<numlock>on</numlock>", text)
    if not count:
        text = text.replace("<keyboard>", "<keyboard>\n    <numlock>on</numlock>", 1)
entries = [
    ("  </windowRules>", '    <windowRule title="*melonDS*" serverDecoration="no" />\n'),
    ("  </keyboard>", '    <keybind key="W-Escape">\n'
                      '      <action name="Execute">\n'
                      f'        <command>touch "{home_request}"</command>\n'
                      '      </action>\n'
                      '    </keybind>\n'),
] + [("</openbox_config>", f'  <touch deviceName="{device}" mapToOutput="{touch_output}" mouseEmulation="yes" />\n')
     for device in devices]
missing = [(anchor, entry) for anchor, entry in entries if entry.strip().splitlines()[0] not in text]
if mode == "check":
    sys.exit(1 if missing else 0)
for anchor, entry in missing:
    if anchor not in text:
        sys.exit(f"{path}: cannot find {anchor.strip()}")
    text = text.replace(anchor, entry + anchor, 1)
if text != original:
    path.write_text(text, encoding="utf-8")
PY
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
echo "Desktop configured: $upper_output above $lower_output, touch on $touch_output, audio device $muted_audio_card disabled."
