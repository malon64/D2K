# Raspberry Pi 5 deployment notes

Problems met while bringing D2K up on a Raspberry Pi 5 (Raspberry Pi OS 64-bit,
Trixie, Labwc) and how each was solved. General Linux notes live in
[`linux-struggles.md`](linux-struggles.md); the current hardware and access
details are in [`AGENTS.md`](../AGENTS.md).

## Displays

### Two HDMI panels: order comes from the desktop layout

The Pi drives two outputs. Current wiring: the Waveshare 5-inch HDMI touch LCD
on HDMI0 (DRM `HDMI-A-1`, lower panel) and a Samsung LS27R75 desk monitor on
HDMI1 (`HDMI-A-2`, upper panel); earlier a Samsung TV was the upper panel on
HDMI0. HDMI0 is always `HDMI-A-1`, HDMI1 `HDMI-A-2`. After rewiring, the old
kanshi profile no longer matches, so the monitors come up with swapped modes
(the Waveshare at 1080p, the monitor at 800x480) until `configure-desktop.sh`
is updated and re-run. D2K has an upper panel
and a lower touch panel; both the theme and `launch-emulator.sh` order the
outputs **top to bottom by their desktop position**, never by connector or by
Qt's screen list (Qt lists the primary output first, which is arbitrary).

So swapping which screen is "top" is only a layout change. The layout is a
kanshi profile written by `scripts/linux/configure-desktop.sh`: upper output at
`0,0`, lower output centred below it. Change `D2K_UPPER_OUTPUT` /
`D2K_LOWER_OUTPUT` (and their modes) there and re-run the script, then restart
D2K so its windows go fullscreen on the new outputs.

### Waveshare picture offset/cropped: use CVT timing

With the EDID's preferred 800x480 timing (33.9 MHz), the Waveshare scaler shows
the picture shifted. Waveshare's own setup uses `hdmi_cvt 800 480 60 6`; on the
Pi 5 (KMS) the equivalent is a CVT custom mode, which kanshi applies:

```text
output HDMI-A-1 mode --custom 800x480@60Hz position 560,1080
```

`hdmi_cvt`/`hdmi_group` lines in `config.txt` are ignored under KMS.

### Waveshare dark with only its LEDs lit: it is not powered

HDMI's 5 V pin only powers the LEDs and the EDID chip, so the Pi detects the
screen and sends it a picture while the backlight stays off. The panel is
powered through its **micro-USB Touch** port, which must go to a Pi USB port
with a data cable (that port is also the touch controller; a charge-only cable
powers it but loses touch). Video still needs HDMI; the Pi 5 cannot send video
over USB. When connected, `lsusb` shows `0eef:0005 D-WAV Scientific ...
WS170120`.

### Windows pushed down 62 px after a mode change

When an output mode changes (kanshi reload, hot-plug), Labwc re-places ordinary
windows around the desktop panel: Pegasus moved to `y=62` and shrank, showing
the wallpaper above it. D2K therefore makes both theme windows fullscreen
(`Window.FullScreen` in `theme.qml`) and the launcher makes emulator windows
fullscreen with `wmctrl -b add,fullscreen`. Labwc keeps fullscreen windows
covering exactly their output, above the taskbar.

### 16:9 TV and 5:3 panels

Panel content is 800x480. On the 1920x1080 TV the theme scales it to 1800x1080
and centres it (letterbox) instead of stretching or cropping it.

## Touch

The Waveshare touch controller is a USB touchscreen (`WaveShare WS170120`).
Without a mapping, libinput spreads touches over the whole combined desktop.
`configure-desktop.sh` adds Labwc entries mapping it to the lower panel:

```xml
<touch deviceName="WaveShare WS170120" mapToOutput="HDMI-A-1" mouseEmulation="yes" />
```

Both `WaveShare WS170120` and `WaveShare WS170120 (USB 1-1)` are listed because
tools reported the device under both names. `mouseEmulation` is what the
Pegasus theme and melonDS expect.

## Audio

### Keep sound on one HDMI port

The Pi 5 has one ALSA card per HDMI port: `vc4-hdmi-0` is
`alsa_card.platform-107c701400.hdmi` (HDMI0), `vc4-hdmi-1` is
`...107c706400.hdmi` (HDMI1). `configure-desktop.sh` installs a WirePlumber rule
disabling the card of the port that must stay silent, so PipeWire has a single
sink. Check with `pactl list short sinks` and `pactl get-default-sink`.

Whether a screen takes audio is in its ELD (`cat /proc/asound/card*/eld#0`):
`sad_count 0` means no audio formats. The LS27R75 desk monitor has none, so
with it the sound goes to HDMI0 instead. **The Waveshare accepts HDMI audio
and plays it on its 3.5 mm jack**, so a headset plugged into the Waveshare is
the audio output. (With the TV earlier, the Waveshare card was the one
disabled.) PipeWire only offers an `hdmi-stereo` profile for a port whose
screen advertises audio.

### Emulators that bypass PipeWire

- Ship of Harkinian's bundled SDL opens the HDMI device directly through ALSA,
  which PipeWire already holds (`ALSA: Couldn't open audio device: Unknown
  error 524`). SoH then switches its own audio backend to `null` in
  `shipofharkinian.json`. The launcher sets `SDL_AUDIODRIVER=pulseaudio`, and
  the SoH overlay keeps `Window/AudioBackend` at `sdl`.
- Mupen64Plus **saves command-line plugin choices into its config**. A single
  test run with `--audio dummy` left every later game silent. The launcher now
  names all four plugins explicitly and the overlay pins them too.

## Performance and heat

The Pi 5 has no fan out of the box and throttles under emulation (seen at
84.5 °C with the ARM clock capped at 1.5 GHz instead of 2.4 GHz). Fit the
official Active Cooler. Check live, not only historical, throttling:

```bash
vcgencmd measure_temp
vcgencmd measure_clock arm
vcgencmd get_throttled   # low bits = throttled now, high bits = happened earlier
```

To tell an emulator's speed problem from a stall, compare its CPU use with its
main thread's wait channel (`cat /proc/<pid>/wchan`): `hrtimer_nanosleep`
means its own speed limiter is sleeping, i.e. it is not CPU bound.

## Per-emulator notes

### DS (melonDS)

- **Tiny DS screens in the corner.** melonDS snaps its windows back to native
  256x192 shortly after boot. The launcher keeps re-checking placement for the
  whole session (every tick for 30 s, then every 2 s) and makes the windows
  fullscreen, so melonDS cannot shrink them.
- **Low frame rate.** melonDS's ARM64 JIT was disabled: 40/60 fps at ~1.8
  cores. With `[JIT] Enable = true` it holds 60/60 at ~0.8 of a core. The
  launcher forces it before every launch because melonDS rewrites its TOML.
- **Menu bar.** melonDS hides its menu bar only in its own fullscreen mode,
  which `--fullscreen` applies to the first window only, and synthetic F11
  presses do not reach its hotkeys. The launcher passes the Qt option
  `-stylesheet scripts/linux/melonds.qss`, which collapses `QMenuBar` in every
  window.
- **Exiting.** Alt+F4 on melonDS's second window only hides that window. Use
  the Super+Esc Home key (below).

### GameCube (Dolphin)

`GFX FIFO: Unknown Opcode` warnings, then a hang: Dual Core without GPU sync
desyncs on the Pi. The Dolphin overlay sets `[Core] SyncGPU = True`, which keeps
most of the Dual Core speed. If a specific game still desyncs, disable Dual Core
for that game only.

### N64: Ship of Harkinian for Ocarina of Time, Mupen64Plus for the rest

- **ares** renders N64 black on V3DV: its paraLLEl-RDP Vulkan renderer loads
  ROMs but draws nothing, including with the small-integer, subgroup and
  ubershader fallbacks. The Pi's Xwayland V3D path also only exposes OpenGL
  3.1 (ares defaults to 3.2). Debian's `ares` package has no N64 core at all.
  ares is no longer installed on the Pi.
- **RMG** (Mupen64Plus + GLideN64) displays correctly but stalls heavily. Removed.
- **Mupen64Plus + Rice** (native build of the `nightly-build` commits pinned in
  `install.sh`) plays the other N64 games with little CPU. Rice has texture
  inaccuracies (e.g. Super Mario 64's file-select icons) and renders the PAL
  Ocarina of Time framebuffer incorrectly. It needs `--datadir` (ROM database
  and OSD font), otherwise it exits right after starting.
- **Ship of Harkinian** runs Ocarina of Time natively. The working build is
  `soh-raspberry-pi.AppImage` from `soh-raspberry-pi-0.0.2.zip` (not an
  official HarbourMasters release; the installer checks its SHA-256 and takes
  it from `~/.cache/d2k/downloads/` or `--soh-zip`). Building SoH from source
  needs `-DUSE_OPENGLES=ON` and hits thermal throttling above two jobs. SoH
  reads `oot.o2r` and its settings from its own directory, so the launcher
  starts it there; `install.sh` links `oot.z64` to the library ROM and SoH
  extracts `oot.o2r` from it on first launch. SoH supports Ocarina of Time only.
- **All six library ROMs are PAL.** PAL N64 games run at 50 Hz (Super Mario 64
  at 25 fps) and much of the library plays ~17 % slower than NTSC, which feels
  like a low frame rate on a 60 Hz TV even when the emulator is at full speed.
  NTSC ROMs are the real fix.

### 3DS (Azahar)

- Azahar is the heaviest target: about two full cores and the Pi reached 85 °C.
  Use the overlay's Vulkan backend, `resolution_factor=1` and asynchronous
  shader compilation.
- The first launch after the screen swap showed a black upper window; three
  relaunches rendered correctly. If it recurs, check whether the emulation is
  stalled (identical frames, no CPU drop) before changing settings.
- A title screen waiting for input looks frozen: compare frames only after
  pressing a button.
- Azahar rewrites `key\default=true` whenever a value equals its default, so
  `configure-emulators.sh --check` ignores `\default` keys.

### Dreamcast (Flycast)

The Flathub ARM64 Flycast aborts on the Pi 5's 16 KiB-page kernel. The
installer builds the pinned Flycast source natively in
`~/.local/opt/d2k/flycast` and it runs with `SDL_VIDEODRIVER=x11`.

## Leaving a game

The keyboard Home button is **Super+Esc**: a Labwc keybind that touches
`~/.local/state/d2k/home-request`. `launch-emulator.sh` polls for it, stops the
emulator's whole process group (AppImages and Flatpaks start the real game as a
child that can outlive the process the launcher started), and returns to
Pegasus. Do not use Alt+F4: it can close Pegasus itself.

## Menu music

`mpc play N` is 1-based while MPD's protocol `play N` is 0-based. The Linux
`mpd.sh` resolves a track's queue position with `awk` and passes it to `mpc`,
so it must print `NR`, not `NR - 1`; the off-by-one played the track before the
one selected. The Windows script talks to MPD directly and is 0-based.

## Console HUD telemetry

`run.sh` writes `pegasus/themes/d2k/system-status.json` every second through
`telemetry.sh`, like the Windows `run.ps1`: CPU use from `/proc/stat` deltas
and temperature from the `cpu-thermal` zone. The Pi on mains power has no battery, but the wireless
Logitech receiver shows up as `/sys/class/power_supply/hidpp_battery_0`
(type `Battery`); it has `scope` `Device`, and the HUD must not show a
mouse's charge as the console's, so such supplies are skipped. With no
System battery, the Pi is on mains power and BATTERY reads `100%`.

## Remote diagnosis

SSH is not the Labwc session. Scripts that need the desktop source
`scripts/linux/lib.sh` and call `use_desktop_session` (`XDG_RUNTIME_DIR`,
D-Bus, `DISPLAY=:0`, `WAYLAND_DISPLAY`). Useful commands over SSH:

```bash
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-0 DISPLAY=:0
wlr-randr                                   # outputs, modes, positions
grim -o HDMI-A-1 /tmp/top.png                # screenshot one output
xdotool search --onlyvisible --name . getwindowname %@
tail ~/.local/state/d2k/launch-*.log         # launcher log per console
```

Two traps when scripting over SSH: `pkill -f PATTERN` also matches the SSH
command line that contains PATTERN (kill your own shell), and overwriting a
running bash script in place corrupts it, because bash reads scripts while
executing them. Deploy by writing a new file and `mv` it over the old one.

Pegasus catches SIGTERM and does not exit, so `pkill -x pegasus-fe` leaves it
running, and starting `run.sh` again then gives two menus (and the old
`run.sh` stops MPD under the new one when it finally exits). Stop D2K through
`run.sh` instead: `pkill -TERM -f '[s]cripts/linux/run.sh'`; its cleanup sends
SIGKILL to Pegasus after two seconds.
