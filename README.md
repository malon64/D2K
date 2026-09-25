# D2K

D2K is a handheld clamshell retro console inspired by the Nintendo DS/3DS and
the AYN Thor: two asymmetric screens, a 3D-printed shell, and a fully custom
Y2K-cybercore interface built as a [Pegasus Frontend](https://pegasus-frontend.org)
theme that launches standalone emulators. This repository holds the theme, the
launch/music scripts for Windows (design preview) and Linux (the device), and
the emulator configurations.

**Emulation priority:** Nintendo DS first, then PSP / Dreamcast / N64 / PS1,
then Nintendo 3DS (desired, not sized for), older consoles later through
RetroArch (optional, not a core dependency).

## Hardware

| Part | V1 target | Status |
| --- | --- | --- |
| Compute | Raspberry Pi 5, Raspberry Pi OS 64-bit (baseline) | In use |
| Compute (alternative) | Radxa ROCK 4D 6 GB (RK3576) | On order; to be benchmarked on all emulators. Likely faster, but the Pi stays the baseline unless the ROCK 4D also drives the 4" DSI touch screen (untested on it) |
| Upper screen | Waveshare 5" HDMI, 800×480 | Received |
| Lower screen | Waveshare 4-DSI-TOUCH-A, 4" touch, 480×800 used landscape | On order |
| Controls | ESP32-S3 as USB HID: D-pad, ABXY, L1/R1/L2/R2, Start/Select/Home, two New 3DS XL circle pads | On order |
| Audio | Waveshare WM8960 board (I²S) + two 8 Ω / 2 W speakers, headphone jack | On order |
| Cooling | Raspberry Pi 5 Active Cooler (SC1148) | On order |
| Power | Battery, protection, USB-C charging with power-path | To choose |

The DS image is shown at 640×480 on the lower screen (×2.5, 80 px side bands).
The ESP32-S3 also handles battery telemetry, the lid sensor, vibration and a
clean shutdown. No detailed shell design starts before the complete
electronics (screens, touch, controls, audio, power) run together on a bench.

Current bench setup (September 2026): a desk monitor stands in for the upper
screen, and the Waveshare 5" HDMI serves as the touch lower screen with its
headphone jack as audio output; controls are a USB keyboard and mouse
([docs/controls.md](docs/controls.md)). Project management, BOM and roadmap
live in the Notion workspace "Projet Hardware" (see [AGENTS.md](AGENTS.md)).

## Windows setup

Install Pegasus and MPD at the existing Scoop locations, then manually create
the configuration used by the launcher:

   ```powershell
   scoop bucket add games
   scoop install pegasus mpd
   ```

```powershell
New-Item -ItemType Junction -Path "$env:USERPROFILE\scoop\apps\pegasus\current\config\themes\d2k" -Target "$PWD\pegasus\themes\d2k"
Get-ChildItem "$PWD\library\consoles" -Directory | Where-Object { Test-Path "$($_.FullName)\metadata.pegasus.txt" } | Select-Object -Expand FullName | Set-Content "$env:USERPROFILE\scoop\apps\pegasus\current\config\game_dirs.txt"
```

Then launch the portable preview:

   ```powershell
   .\scripts\windows\run.ps1
   ```

Set the D2K theme and library directory in Pegasus if they are not already
selected. `run.ps1` keeps using the installed Scoop executable paths.

`run.ps1` starts MPD for the menu music from `library/consoles/music/playlist.m3u`
and stops it when Pegasus closes. Check the integration without opening Pegasus:

```powershell
.\scripts\windows\mpd.ps1 -Action SmokeTest
```

## Raspberry Pi 5 setup

The Pi target is current Raspberry Pi OS 64-bit (Trixie/labwc) and runs all
eight D2K collections: DS, Dreamcast, PSP, PS1, N64, GameCube, 3DS, and Music.

Copy the ignored private library one way before installing:

```bash
rsync -a --delete /path/to/D2K/library/ <pi-user>@<pi-host>:~/D2K/library/
ssh <pi-user>@<pi-host> 'cd ~/D2K && ./scripts/linux/install.sh'
```

The installer is safe to re-run. It builds the pinned Pegasus, Flycast and
Mupen64Plus revisions, installs the melonDS/DuckStation AppImages and the
Azahar/PPSSPP Flatpaks, merges the emulator overlays, configures the desktop
(screen layout, touch, HDMI audio port, Super+Esc Home key), generates Pi-local launch
metadata, and adds D2K to the graphical-session autostart. Ocarina of Time runs
in Ship of Harkinian when its Pi build is supplied as
`~/.cache/d2k/downloads/soh-raspberry-pi-0.0.2.zip` (or `--soh-zip PATH`);
otherwise it uses Mupen64Plus like the other N64 games.

| Script (`scripts/linux/`) | Purpose |
| --- | --- |
| `install.sh` | Full, idempotent install |
| `configure-desktop.sh` | Screen layout, touch mapping, HDMI audio port, Labwc rules; re-run after rewiring screens |
| `configure-emulators.sh` | Merge `docs/emulator-configs/linux/` overlays (`--check` to verify) |
| `run.sh` | Start Pegasus and the menu music (autostart) |
| `launch-emulator.sh` | Start, place and stop one game (called by Pegasus) |
| `smoke-test.sh` | Check everything without opening Pegasus |

```bash
./scripts/linux/smoke-test.sh
```

Pegasus and the emulators use Xwayland for absolute window placement while the
desktop stays on Wayland. With one TV connected, both panels are stacked on it;
with two outputs, D2K follows their top-to-bottom desktop position. Press
**Super+Esc** to leave a game. Keyboard controls (AZERTY: arrows + numpad
diamond, Enter = Start) are in [docs/controls.md](docs/controls.md).

Deployment troubleshooting is split into [general Linux notes](docs/linux-struggles.md)
and [Raspberry Pi 5 notes](docs/raspberry-pi-struggles.md). Agents working on
the Pi should start with [AGENTS.md](AGENTS.md).

## Theme development

The theme uses two Windows preview windows:

- Upper visual panel: 800×480, matching the Waveshare 5-inch HDMI display.
- Lower touch panel: 800×480, matching the Waveshare 4-DSI-TOUCH-A rotated to
  landscape.

Both windows run at the panels' native resolution rather than scaled down, so
what you read on the desktop is what the device shows. They are stacked and
centred like the clamshell, and need a desktop at least 1050px tall.

The menu runs boot → console selector → game library. Every choice is on the
lower panel; the upper panel is a non-interactive showcase that follows the
selection. On the console selector, the side arrows change console and
**SELECT CONSOLE** opens it. In the library, touching a tile only selects the
game — only **LAUNCH** or the accept key starts a ROM. **BACK** returns to the
consoles, and the side arrows page through the 4×3 grid.

Keyboard: arrows move the selection, `PageUp`/`PageDown` change page, `Enter`
accepts and `Escape` goes back. Edit any `.qml` file, then press `F5` to reload
the theme. Details and the Raspberry Pi runtime are in
[docs/pegasus-development.md](docs/pegasus-development.md).

## Nintendo DS smoke test

`game_dirs.txt` points Pegasus at `library/consoles`, which indexes the full DS library with its
cover art. The collection's metadata uses the configured melonDS build and the
ROMs stored beside each game in the library.

For two-screen game output, copy the Window 0 and Window 1 settings from
`pegasus/melonds/melonDS.dual-screen.toml` to the active `melonDS.toml`, open
a game, arrange the two melonDS windows to match the upper and lower previews,
then close the primary melonDS window normally to save its local geometry. Do
not close the second window by itself, as melonDS disables it for the next run.
The Pegasus launcher re-enables it before every game launch, removes melonDS'
Windows title bars and menus, and frames the game outputs on exactly the same
800×480 rectangles as the Pegasus panels. Use **Alt+F4** to close a game in this
preview — that is also what the eventual Home button will do internally, via a
file-drop seam described in
[docs/pegasus-development.md](docs/pegasus-development.md), until the ESP32
hardware exists.

## Repository layout

```text
pegasus/themes/d2k/  D2K theme source, with Figma assets and fonts
scripts/windows/     Windows run and music scripts
scripts/linux/       Raspberry Pi installation and runtime scripts
docs/                Development notes
```
