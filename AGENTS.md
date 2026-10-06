# AGENTS.md

Context for coding agents working on D2K. Read this first, then the linked docs.

## What D2K is

D2K is a dual-screen retro console: a [Pegasus Frontend](https://pegasus-frontend.org)
theme (`pegasus/themes/d2k/`) plus launch scripts, targeting a **Raspberry Pi 5**
running Raspberry Pi OS 64-bit (Trixie, Labwc/Wayland). The theme has two
800x480 panels:

- **Upper panel**: non-interactive showcase (console art, game art, telemetry).
- **Lower panel**: the touch menu (console selector, game grid, music player).

Collections: DS, Dreamcast, PS1, PSP, N64, GameCube, 3DS, and Music (MPD).
The theme and the Windows scripts are developed on a Windows PC; the Pi is the
real device.

## Project context (from Notion)

The source of truth for goals, BOM and roadmap is the Notion workspace
**Projet Hardware** (French):
<https://app.notion.com/p/Projet-Hardware-3ddfe42f978d80ae9757dfcd926d5619>,
with sub-pages *Architecture & décisions*, *Hardware BOM*, *Software & UI*,
*Mécanique & boîtier*, *Music & MPD*, *Direction artistique* and a
*Roadmap & Tasks* database. Read it when a task touches hardware or priorities.
Summary as of 24 September 2026:

- **Product:** handheld clamshell console (DS/3DS and AYN Thor inspired),
  3D-printed shell, Y2K cybercore art direction shared by UI and shell. The
  user should never see a Linux desktop, a terminal or emulator menus.
- **Emulation priority:** DS (absolute) → PSP / Dreamcast / N64 / PS1 → 3DS
  (secondary) → older consoles via RetroArch later (optional; Pegasus launches
  standalone emulators, RetroArch is not a core dependency).
- **Compute:** Raspberry Pi 5 is the V1 baseline: it has the better hardware
  support, including documented support for the Waveshare 4" DSI touch screen.
  A **Radxa ROCK 4D 6 GB (RK3576)** is on order and will be benchmarked on all
  emulators; it should be faster, but it is **not a certain replacement**: the
  4" DSI screen is untested on it. It replaces the Pi only if the HDMI + DSI
  screens, touch and dual-screen melonDS work without custom driver work and
  performance is measurably better.
- **Hardware parts and their status** are in the README's Hardware table. The
  final lower screen is a Waveshare 4-DSI-TOUCH-A over DSI (overlay
  `vc4-kms-dsi-waveshare-panel-v2,4_0_inch_a`). The ESP32-S3 gamepad's left
  circle pad is movement, the right one the C-stick / N64 C-buttons / PS1
  right stick (no L3/R3); until it exists, the keyboard scheme in
  `docs/controls.md` stands in.
- **Roadmap:** software on Pi (mostly done) → two physical screens on Pi (now)
  → ROCK 4D test → ESP32 controls → audio → power → full bench "electronics
  gate" → mechanical prototype → V1 integration. No detailed shell before the
  electronics gate.

## Repository map

| Path | Contents |
| --- | --- |
| `pegasus/themes/d2k/` | The QML theme. `theme.qml` owns the two windows and screen placement. |
| `scripts/windows/` | Windows preview: `run.ps1`, `launch-emulator.ps1`, `mpd.ps1`. |
| `scripts/linux/` | Pi/Linux: `install.sh`, `configure-desktop.sh`, `configure-emulators.sh`, `run.sh`, `launch-emulator.sh`, `mpd.sh`, `telemetry.sh` (HUD battery, CPU, temperature), `smoke-test.sh`, shared `lib.sh`. |
| `docs/emulator-configs/{windows,linux}/` | Per-emulator config overlays (only the keys D2K needs). |
| `docs/platform.md` | How D2K runs on Linux and the Pi 5 (windows, displays, touch, audio, heat, GPU driver limits) and every platform problem with its fix; what to check on another board (ROCK 4D). **Read before changing Pi behaviour.** |
| `docs/emulators.md` | Emulator per console, its settings, every emulator problem with its fix. **Read before changing an emulator or its overlay.** |
| `docs/benchmarks.md` | Measured performance per console and the method; repeat it after changes and on any new board. |
| `docs/controls.md` | The keyboard/menu/touch control scheme and where each emulator stores it. |
| `docs/theme.md` | Theme development, the Windows preview, the launch lifecycle. |
| `library/` | **Private, git-ignored** ROMs, art and metadata. Never commit it. |
| `firmware/esp32-controls/` | ESP32-S3-Zero USB HID gamepad firmware (Arduino-ESP32, TinyUSB); build and flash from the Pi with `arduino-cli`, see its README. Pin table must match `fusion/electronics/gen_d2k_v1_sch.py`. |
| `fusion/` | Autodesk Fusion work (Fusion project **D2K**): build scripts run through the Fusion MCP, the generated electronics library, and the decision / open-question / wiring / constraint docs. **Read `fusion/README.md` before touching Fusion** (one small script at a time: heavy designs and uploads stall it). |

## Raspberry Pi access

- SSH: `ssh alex@192.168.1.66` over **Ethernet** (gigabit, the default route
  since October 2026); the Wi-Fi address `192.168.1.16` also exists but its
  signal is weak and SSH on it can time out. Key authentication from the
  Windows PC; user `alex` has passwordless `sudo`. Both addresses are DHCP
  and have changed before: if SSH times out, scan the LAN for port 22 and
  confirm with `hostname` (`raspberry`). Use `-o ConnectTimeout=30`.
- Repository on the Pi: `~/D2K` (git clone of `origin`; `library/` is synced
  one way from Windows with `rsync`, see README).
- Installed software: `~/.local/opt/d2k/` (pegasus, melonds, duckstation,
  flycast, mupen64plus, shipwright). Flatpaks (user): Azahar, PPSSPP. Dolphin
  comes from Debian.
- Build sources and downloads: `~/.cache/d2k/` (the Ship of Harkinian zip lives
  in `~/.cache/d2k/downloads/`; it is not downloadable from an official source).
- Runtime state: `~/.local/state/d2k/` (`launch-<console>.log`, `home-request`, `game-running`,
  `mpd/`).
- Pi-local config written by the scripts: `~/.config/kanshi/config` (screen
  layout), `~/.config/labwc/rc.xml` (touch mapping, melonDS rule, Super+Esc),
  `~/.config/wireplumber/wireplumber.conf.d/50-d2k-audio.conf` (sound on one HDMI port),
  `~/.config/pipewire/pipewire-pulse.conf.d/50-d2k-emulator-audio.conf` (melonDS / PPSSPP / Azahar audio buffer floor),
  `~/.config/autostart/d2k.desktop`.

## Current hardware wiring

| Role | Device | Connection | Desktop output |
| --- | --- | --- | --- |
| Upper panel + sound | Waveshare 5" HDMI LCD, 800x480; HDMI audio comes out of its 3.5 mm jack (headset) | HDMI0 for video and audio, micro-USB **Touch** port to a Pi USB port for power (its touch is mapped to this screen) | `HDMI-A-1`, position `0,0`, CVT mode |
| Lower touch panel | Waveshare 4-DSI-TOUCH-A, 480x800 portrait panel, Goodix touch | DSI ribbon to the **DISP 1** connector, 5V/GND from the GPIO header; `dtoverlay=vc4-kms-dsi-waveshare-panel-v2,4_0_inch_a` in `/boot/firmware/config.txt` | `DSI-2`, position `0,480`, transform `270` |

Earlier the upper panel was a Samsung desk monitor on HDMI1 and the 5" was the
lower touch panel; the wiring and the screens change, so check `wlr-randr`
before assuming these names.

The official Active Cooler is fitted (hwmon `pwmfan`, `fan1_input` = RPM); its
cable must be plugged in before boot ([docs/platform.md](docs/platform.md#heat-and-cooling-pi-5)).
Screen roles are set in `configure-desktop.sh` (`D2K_UPPER_OUTPUT`,
`D2K_LOWER_OUTPUT`, modes, touch device); the theme and launcher follow the
top-to-bottom desktop layout automatically.

## Working on the Pi remotely

SSH is not the desktop session. Export the session variables first (or source
`scripts/linux/lib.sh` and call `use_desktop_session`):

```bash
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-0 DISPLAY=:0
wlr-randr                                            # outputs and positions
grim -o HDMI-A-1 /tmp/upper.png; grim -o DSI-2 /tmp/lower.png       # screenshots (scp them back to look)
xdotool search --onlyvisible --name . getwindowname %@
pactl list short sinks; pactl get-default-sink       # audio
vcgencmd measure_temp; vcgencmd get_throttled        # heat
```

- **Start D2K from SSH** fully detached, or it dies with the SSH session:
  `cd ~/D2K && setsid nohup ./scripts/linux/run.sh > /tmp/d2k-run.log 2>&1 < /dev/null &`
  (normally it starts from the Labwc autostart entry).
- **Stop D2K**: `pkill -TERM -f '[s]cripts/linux/run.sh'` (its cleanup kills
  Pegasus and stops MPD). Pegasus catches SIGTERM and keeps running, so
  `pkill -x pegasus-fe` alone does nothing. Wait until `run.sh` itself has
  exited, not just Pegasus, before starting a new copy: its cleanup stops MPD
  *after* Pegasus is gone, and once landed on the new copy's MPD (no menu
  music). Stop and start in separate SSH commands, so the start command's
  `./scripts/linux/run.sh` text cannot match the `pkill -f`.
- **Restarting `pipewire-pulse`** (done by `configure-desktop.sh` when the
  emulator audio rule changes) drops MPD's output; restart D2K afterwards.
- **Launch a game for testing**:
  `./scripts/linux/launch-emulator.sh <ds|dreamcast|ps1|psp|n64|gamecube|3ds> "$PWD/library/consoles/<console>/games/<game>/rom.<ext>"`
- **Leave a game**: `touch ~/.local/state/d2k/home-request` (what Super+Esc does).
  The launcher stops the emulator's whole process group and resumes the music.
- The user may be looking at or playing on the screens. Say before you launch,
  close or restart anything, and do not close a game they are playing.

## Deploying and testing changes

1. Edit in the Windows working copy, commit and push.
2. On the Pi: `cd ~/D2K && git pull` (or copy single files: `scp` to a temp
   name, then `mv` over the old file; see traps below).
3. Re-run what changed: `./scripts/linux/install.sh` (idempotent, skips built
   software), or just `configure-desktop.sh` / `configure-emulators.sh`.
4. `./scripts/linux/smoke-test.sh` (self-tests, config checks, MPD test).
5. Verify on the real screens: screenshots with `grim`, window geometry with
   `xdotool`, sound with `pactl list sink-inputs`, and the launch log.

## Traps that already cost time

- `pkill -f PATTERN` / `pgrep -f` over SSH also match the SSH command line that
  contains PATTERN, killing your own shell. Use `pgrep -x NAME`, or a pattern
  like `[p]egasus` that does not match its own text, and keep the plain text
  (e.g. `./scripts/linux/run.sh`) out of that same SSH command.
- Overwriting a running bash script in place corrupts the running copy (bash
  reads scripts while executing). `run.sh` and `launch-emulator.sh` are usually
  running: write a new file and `mv` it into place.
- Emulators write their own settings back (melonDS, Mupen64Plus, Ship of
  Harkinian, Azahar): change configs with the emulator closed, and undo test
  changes ([docs/emulators.md](docs/emulators.md#how-d2k-configures-emulators)).
- Do not run an emulator binary with flags like `--version` on the Pi: Flycast
  opened a second instance on the screens that way.
- Alt+F4 can close Pegasus itself; use Super+Esc / `home-request`.
- A sleeping main thread at low CPU is not proof of full speed (Mupen64Plus'
  audio sync held Mario 64 at ~40 of 50 VI/s that way). Measure the frame
  rate where the emulator shows it, and remember the N64 ROMs are PAL (25 fps
  in Mario 64 is the original speed).
- ares renders N64 black on the Pi and was removed; do not reintroduce it
  there. Windows still uses ares.

## Conventions

- Match the surrounding style: bash with `set -euo pipefail`, small functions,
  comments that explain *why* (usually a Pi quirk, with a pointer to the docs).
- Record every new problem and its fix once, where it belongs:
  `docs/platform.md` (Linux, Pi, another board), `docs/emulators.md` (an
  emulator), `docs/controls.md` (keys). Measurements go into
  `docs/benchmarks.md`, linking to the fix instead of retelling it.
- Emulator config changes go into the overlays in `docs/emulator-configs/`,
  never only into the Pi's live files.
