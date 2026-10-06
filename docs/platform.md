# Linux and Raspberry Pi 5 platform

How D2K runs on Linux and on the Raspberry Pi 5 (Raspberry Pi OS 64-bit,
Trixie, Labwc/Wayland), and every platform problem met so far with its fix.
Per-emulator problems are in [`emulators.md`](emulators.md), the key scheme in
[`controls.md`](controls.md), measured performance in
[`benchmarks.md`](benchmarks.md). SSH access, deploying and restarting D2K on
the Pi are in [`../AGENTS.md`](../AGENTS.md).

Sections marked **(Pi 5)** depend on the Raspberry Pi hardware or Raspberry Pi
OS; the rest applies to any Linux desktop.

## How D2K runs on Linux

### A graphical session is required

Pegasus and the emulators need the logged-in desktop. A plain SSH shell fails
with `qt.qpa.xcb: could not connect to display`. The scripts source
`scripts/linux/lib.sh` and call `use_desktop_session`, which fills in
`XDG_RUNTIME_DIR`, the D-Bus socket, `DISPLAY=:0` and `WAYLAND_DISPLAY`. A
working SSH login is still not a GUI session: check placement and sound on the
real screens.

### Everything runs on Xwayland

D2K places windows by absolute position with `xdotool` and `wmctrl`, which only
control X11 windows. Pegasus/Qt and every emulator therefore run on Xwayland
(`QT_QPA_PLATFORM=xcb`, `SDL_VIDEODRIVER=x11`, `--socket=x11` and
`--nosocket=wayland` for Flatpaks) while the desktop stays on Wayland. The
price is CPU: Xwayland used about half a core presenting melonDS's two windows
at 60 fps. The final 800x480 upper screen will cost less than today's 1080p
desk monitor (fewer pixels to scale and present). Native Wayland clients with
Labwc window rules (`MoveToOutput`, fullscreen) would remove that copy
(untested).

### Window placement

`launch-emulator.sh` finds each emulator's windows and puts them on the
panels, ordered **top to bottom by desktop position**, never by connector or
by Qt's screen list (Qt lists the primary output first, which is arbitrary).

- **Emulators resize their own windows after boot** (melonDS snaps back to
  256x192), so placement is re-checked for the whole session: every tick for
  30 s, then every 2 s, doing nothing while a window is already in place.
- **Windows are made fullscreen** (`wmctrl -b add,fullscreen`; the theme uses
  `Window.FullScreen`). When an output mode changes (kanshi reload, hot-plug),
  Labwc re-places ordinary windows around its panel: Pegasus once moved to
  `y=62` and shrank. Fullscreen windows stay on their output, above the panel.
- **Finding the window.** By process ID first; Flatpak and AppImage emulators
  own their windows from a child process, so the launcher then searches by
  window class (PPSSPP: `org.ppsspp.PPSSPP`), then by title. A title search
  alone failed for PPSSPP, which renames its window to the running game.
- **Keyboard focus** is given once, to the upper window, so keys do not keep
  going to Pegasus. Dolphin needs more than that (see
  [`emulators.md`](emulators.md#gamecube-dolphin)).

### The real game runs as a child process

`flatpak run` and AppImage runtimes are wrappers: the visible emulator is a
child that can outlive them. The launcher starts each emulator with `setsid`
and watches and stops the **whole process group**, checking the main PID first
(right after `setsid ... &` the group may not exist yet; reading that as
"exited" once skipped all placement). For Flatpaks it also checks
`flatpak ps --columns=application` and finishes with `flatpak kill <app-id>`.
Do not add `--user` to `flatpak ps` or `flatpak kill`: the installed Flatpak
rejects it. The emulator's output goes to `~/.local/state/d2k/<console>-emulator.log`,
not to Pegasus: chatty emulators (Azahar) stalled on Pegasus' pipe.

### Leaving a game

The Home key is **Super+Esc**: a Labwc keybind that touches
`~/.local/state/d2k/home-request`. `launch-emulator.sh` polls for it, stops the
emulator's process group and returns to Pegasus. Do not use Alt+F4: it can
close Pegasus itself, and on melonDS's second window it only hides that
window. DuckStation and Dolphin are configured to close without a confirmation
dialog, which otherwise opened behind the fullscreen game.

### While a game runs

Pegasus tears its QML scene down for the whole game (see
[`theme.md`](theme.md#launch-lifecycle-the-theme-does-not-survive-a-game)).
`run.sh` keeps running: it writes HUD telemetry and the music status once a
second. During a game the launcher writes its PID to
`~/.local/state/d2k/game-running`, and `run.sh` skips that work while the PID is
alive: each status write started `mpc` and a fresh `python3`, unread until the
menu came back.

### Menu music (MPD)

- `mpc play N` is 1-based while MPD's protocol `play N` is 0-based. `mpd.sh`
  resolves a track's queue position with `awk` and must print `NR`, not
  `NR - 1` (the off-by-one played the track before the one selected). The
  Windows script talks to MPD directly and is 0-based.
- Restarting `pipewire-pulse` (done by `configure-desktop.sh` when the emulator
  audio rule changes) disconnects MPD (`mpd.log`: `Failed to play on "D2K"
  (pulse): disconnected`). Restart D2K afterwards, waiting for the old `run.sh`
  to exit, not just Pegasus: its cleanup runs `mpd.sh Stop` after Pegasus
  exits and once stopped the MPD the new `run.sh` had just started.

### HUD telemetry

`run.sh` writes `pegasus/themes/d2k/system-status.json` every second through
`telemetry.sh`, like the Windows `run.ps1`: CPU use from `/proc/stat` deltas and
temperature from the `cpu-thermal` zone. Power supplies with `scope` `Device`
are skipped: the wireless Logitech receiver appears as
`/sys/class/power_supply/hidpp_battery_0` (type `Battery`), and the HUD must not
show a mouse's charge as the console's. With no System battery the console is
on mains power and BATTERY reads `100%`.

## Displays (Pi 5)

### Panel roles come from the desktop layout

HDMI0 is always DRM `HDMI-A-1` and HDMI1 `HDMI-A-2`; a panel on the **DISP 1**
connector is `DSI-2` (on a second DRM card, `card2`). The layout is a kanshi
profile written by `configure-desktop.sh`: upper output at `0,0`, lower output
centred below it. To swap which screen is "top", change `D2K_UPPER_OUTPUT` /
`D2K_LOWER_OUTPUT` (and their modes, `D2K_LOWER_TRANSFORM`), re-run the script
and restart D2K. After rewiring without doing this, the old profile no longer
matches and Labwc places the outputs side by side, so the theme puts its
panels on the wrong screens. The current wiring is in
[`../AGENTS.md`](../AGENTS.md#current-hardware-wiring).

### Waveshare 4-DSI-TOUCH-A: overlay, then rotate

The DSI panel needs its overlay in `/boot/firmware/config.txt` (under `[all]`)
and a reboot; without it the Pi shows no DSI output at all:

```ini
dtoverlay=vc4-kms-dsi-waveshare-panel-v2,4_0_inch_a
```

That is for the DISP 1 connector; on DISP 0 append `,dsi0`. Which connector is
used cannot be probed before the overlay is loaded (the connectors' I²C buses
only appear with it), so try one and check `dmesg | grep -i waveshare` and
`/sys/class/drm/card*-DSI-*/status`. When it works the kernel reports
`dsi panel: waveshare,4.0-dsi-touch-a`, the touch controller appears as
`Goodix Capacitive TouchScreen` (I²C `11-005d`) and the backlight as
`/sys/class/backlight/11-0045`. The panel is 480x800 portrait: kanshi turns it
to landscape with `transform 270` (90 left it upside down in the bench
mounting).

### Waveshare 5" HDMI picture offset: use CVT timing

With the EDID's preferred 800x480 timing (33.9 MHz) the Waveshare scaler shifts
the picture. Waveshare's setup uses `hdmi_cvt 800 480 60 6`; under KMS the
equivalent is a CVT custom mode applied by kanshi
(`output HDMI-A-1 mode --custom 800x480@60Hz position 0,0`).
`hdmi_cvt` / `hdmi_group` lines in `config.txt` are ignored under KMS.

### Waveshare dark with only its LEDs lit: it is not powered

HDMI's 5 V pin only powers the LEDs and the EDID chip, so the Pi detects the
screen and sends it a picture while the backlight stays off. The panel is
powered through its **micro-USB Touch** port, which must go to a Pi USB port
with a data cable (it is also the touch controller; a charge-only cable powers
it but loses touch). When connected, `lsusb` shows
`0eef:0005 D-WAV Scientific ... WS170120`.

### A 16:9 screen, or a single screen

Panel content is 800x480. On a 1920x1080 screen the theme scales it to
1800x1080 and centres it instead of stretching or cropping it. With only one
output connected, both panels are stacked on it, scaled to fit.

## Touch (Pi 5)

Without a mapping, libinput spreads touches over the whole desktop.
`configure-desktop.sh` maps each touchscreen to its own output in Labwc's
`rc.xml`; Labwc also applies that output's transform, so the rotated DSI
panel needs no calibration matrix:

```xml
<touch deviceName="Goodix Capacitive TouchScreen" mapToOutput="DSI-2" mouseEmulation="yes" />
<touch deviceName="WaveShare WS170120" mapToOutput="HDMI-A-1" mouseEmulation="yes" />
```

The DSI panel's Goodix controller is the menu. Raspberry Pi OS's default
`rc.xml` already lists `11-005d Goodix Capacitive TouchScreen`, but libinput
names the device without the bus prefix, so D2K adds its own entry. The 5"
HDMI panel's USB touch (`WaveShare WS170120`, also reported as
`WaveShare WS170120 (USB 1-1)`) stays mapped to its own screen so a touch
there cannot reach the menu. `mouseEmulation` is what the theme and melonDS
expect. A tap gives the lower window keyboard focus, which is why the theme
handles keys in both windows ([`controls.md`](controls.md#menus-pegasus)).

## Audio (Pi 5)

### Sound on one HDMI port

The Pi 5 has one ALSA card per HDMI port: `vc4-hdmi-0` is
`alsa_card.platform-107c701400.hdmi` (HDMI0), `vc4-hdmi-1` is
`...107c706400.hdmi` (HDMI1). `configure-desktop.sh` installs a WirePlumber rule
(`50-d2k-audio.conf`) disabling the card of the port that must stay silent, so
PipeWire has a single sink (`pactl list short sinks`, `pactl get-default-sink`).
Whether a screen takes audio is in its ELD (`cat /proc/asound/card*/eld#0`):
`sad_count 0` means none. The desk monitor had none; **the Waveshare 5" plays
HDMI audio on its 3.5 mm jack**, so a headset there is today's audio output.

### Emulators need a larger audio buffer

Several emulators asked PipeWire for tiny buffers (melonDS 256 samples, PPSSPP
118, Azahar 204: 2.7–5.3 ms), so any short stall in the emulator or the
compositor became an audible gap. `configure-desktop.sh` writes a
`pipewire-pulse` rule (`50-d2k-emulator-audio.conf`) giving them a floor of
`pulse.min.quantum = 1024/48000` (21 ms), matched by `application.name` for
melonDS and by Flatpak id (`pipewire.access.portal.app_id`) for PPSSPP and
Azahar, whose streams carry no application name. PipeWire rounds a requested
quantum down to a power of two, so an environment variable alone
(`PULSE_LATENCY_MSEC=40` became 480 samples, then 256) was not enough.

To check an emulator's audio during play: `pw-top -b -n 2` shows each stream's
QUANT and ERR (underruns). ERR should stay near 0. An emulator can also stutter
with no PipeWire underruns when its own mixer runs dry (Dolphin, Mupen64Plus):
see [`emulators.md`](emulators.md).

### Emulators that bypass or break PipeWire

- Ship of Harkinian's bundled SDL opens the HDMI device directly through ALSA,
  which PipeWire already holds (`ALSA: Couldn't open audio device: Unknown
  error 524`), and SoH then saves `AudioBackend: null`. The launcher sets
  `SDL_AUDIODRIVER=pulseaudio` and the overlay keeps the backend at `sdl`.
- Mupen64Plus saves command-line plugin choices: one test with `--audio dummy`
  silenced every later game. The launcher names all four plugins and the
  overlay pins them.

## Heat and cooling (Pi 5)

A bare Pi 5 throttles under emulation (84.5 °C with the ARM clock capped at
1.5 GHz instead of 2.4 GHz), so the official Active Cooler is fitted. Check
live, not only historical, throttling:

```bash
vcgencmd measure_temp
vcgencmd measure_clock arm
vcgencmd get_throttled   # low bits = throttled now, high bits = happened earlier
cat /sys/class/hwmon/*/fan1_input
```

**Plug the cooler in before boot.** Connected with the Pi running, it was not
detected: no `pwmfan` hwmon, `pwm_fan` not loaded, and
`/proc/device-tree/cooling_fan/status` read `disabled`. The firmware enables
that node only if it finds a fan at boot. After a reboot: status `okay`,
about 2,860 RPM at 51 °C. `dtparam=cooling_fan=on` would force it but would
hide a badly seated connector.

With the cooler, every console stayed between 45 and 59 °C with no
throttling ([`benchmarks.md`](benchmarks.md)). Without it, Mario Kart DS went
from 54 °C idle to 76 °C in 60 s.

## Graphics driver limits (Pi 5)

The Pi 5's GPU is a V3D 7.1 driven by Mesa (V3D for OpenGL, V3DV for Vulkan).
These limits explain several emulator choices and are the first things to
compare on another board:

| Limit | Consequence |
| --- | --- |
| Desktop OpenGL 3.1 through Xwayland (OpenGL ES 3.1 natively) | melonDS's GL renderer needs 3.2 and ares 3.2; Azahar's GL renderer needs 4.3 and is not even built into its ARM64 Flatpak |
| V3DV compiles Vulkan pipelines slowly | 3DS freezes until the driver's shader cache is warm |
| 3DS shadows drawn as black columns under V3DV | Azahar's only open bug on the Pi; not fixable by settings |
| ares' Vulkan N64 renderer draws nothing on V3DV | N64 uses Mupen64Plus and Ship of Harkinian |
| 16 KiB kernel pages | The Flathub ARM64 Flycast aborts; Flycast is built from source |

Details are in each console's section of [`emulators.md`](emulators.md).

## Another board (ROCK 4D)

The Linux scripts target Raspberry Pi OS. These parts are Pi-specific and need
checking on another board: `vcgencmd` (heat, clock, HUD telemetry), HDMI
output names and ALSA card names in `configure-desktop.sh`, the Labwc/kanshi
desktop, the 16 KiB page-size Flycast build, the GPU driver limits above, and
the Ship of Harkinian `soh-raspberry-pi` build. Keep the generic parts
(launcher, overlays, controls) board-independent and record what differs in a
new section of this file. Repeat the measurements in
[`benchmarks.md`](benchmarks.md#next-measurements) on the new board.

## Useful checks

```bash
./scripts/linux/smoke-test.sh                    # everything below, without opening Pegasus
./scripts/linux/launch-emulator.sh --self-test
./scripts/linux/configure-emulators.sh --check
./scripts/linux/configure-desktop.sh --check
flatpak ps --columns=application
```
