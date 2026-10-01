# D2K

D2K is a handheld clamshell retro console inspired by the Nintendo DS/3DS and
the AYN Thor: two asymmetric screens, a 3D-printed shell, and a fully custom
Y2K-cybercore interface built as a [Pegasus Frontend](https://pegasus-frontend.org)
theme that launches standalone emulators. This repository holds the theme, the
launch and music scripts for Windows (design preview) and Linux (the device),
the emulator configurations, and the Fusion work for the shell.

**Emulation priority:** Nintendo DS first, then PSP / Dreamcast / N64 / PS1,
then Nintendo 3DS (secondary), older consoles later through RetroArch
(optional, not a core dependency). Every console in the library plays
correctly on the Raspberry Pi 5 except one open 3DS rendering bug
([docs/benchmarks.md](docs/benchmarks.md)).

## Hardware

| Part | V1 target | Status (October 2026) |
| --- | --- | --- |
| Compute | Raspberry Pi 5, Raspberry Pi OS 64-bit | In use; the V1 baseline |
| Compute (alternative) | Radxa ROCK 4D 6 GB (RK3576) | On order; replaces the Pi only if both screens and touch work without custom driver work and it is measurably faster |
| Upper screen | Waveshare 5" HDMI, 800×480 | Received; on the bench it is the lower touch screen |
| Lower screen | Waveshare 4-DSI-TOUCH-A, 4" touch, 480×800 used landscape | On order |
| Controls | ESP32-S3 as USB HID: D-pad, ABXY, L1/R1/L2/R2, Start/Select/Home, two New 3DS XL circle pads | On order; a keyboard stands in ([docs/controls.md](docs/controls.md)) |
| Audio | Waveshare WM8960 board (I²S), two 8 Ω / 2 W speakers, headphone jack | On order; today the Waveshare 5" jack |
| Cooling | Raspberry Pi 5 Active Cooler (SC1148) | Fitted |
| Power | Battery, protection, USB-C charging with power-path | To choose |

The DS image is shown at 640×480 on the lower screen (×2.5, 80 px side bands).
The ESP32-S3 also handles battery telemetry, the lid sensor, vibration and a
clean shutdown. No detailed shell design starts before the complete
electronics run together on a bench. Today's bench uses a desk monitor as the
upper screen. Project management, BOM and roadmap live in the Notion
workspace "Projet Hardware" (see [AGENTS.md](AGENTS.md)).

## Raspberry Pi 5 setup

The Pi runs Raspberry Pi OS 64-bit (Trixie, Labwc) and all eight D2K
collections: DS, Dreamcast, PSP, PS1, N64, GameCube, 3DS and Music. Copy the
git-ignored private library one way, then install:

```bash
rsync -a --delete /path/to/D2K/library/ <pi-user>@<pi-host>:~/D2K/library/
ssh <pi-user>@<pi-host> 'cd ~/D2K && ./scripts/linux/install.sh'
```

The installer is safe to re-run. It builds the pinned Pegasus, Flycast and
Mupen64Plus revisions, installs the melonDS and DuckStation AppImages and the
Azahar and PPSSPP Flatpaks, applies the emulator overlays, configures the
desktop (screen layout, touch, audio, Super+Esc Home key), generates Pi-local
launch metadata, and adds D2K to the session autostart. Ocarina of Time runs in
Ship of Harkinian when its Pi build is supplied as
`~/.cache/d2k/downloads/soh-raspberry-pi-0.0.2.zip` (or `--soh-zip PATH`);
otherwise it uses Mupen64Plus like the other N64 games.

| Script (`scripts/linux/`) | Purpose |
| --- | --- |
| `install.sh` | Full, idempotent install |
| `configure-desktop.sh` | Screen layout, touch mapping, audio, Labwc rules; re-run after rewiring screens |
| `configure-emulators.sh` | Apply the `docs/emulator-configs/linux/` overlays (`--check` to verify) |
| `run.sh` | Start Pegasus and the menu music (autostart) |
| `launch-emulator.sh` | Start, place and stop one game (called by Pegasus) |
| `smoke-test.sh` | Check everything without opening Pegasus |

Press **Super+Esc** to leave a game.

## Windows preview

Install Pegasus and MPD with Scoop, link the theme and point Pegasus at the
library:

```powershell
scoop bucket add games
scoop install pegasus mpd
New-Item -ItemType Junction -Path "$env:USERPROFILE\scoop\apps\pegasus\current\config\themes\d2k" -Target "$PWD\pegasus\themes\d2k"
Get-ChildItem "$PWD\library\consoles" -Directory | Where-Object { Test-Path "$($_.FullName)\metadata.pegasus.txt" } | Select-Object -Expand FullName | Set-Content "$env:USERPROFILE\scoop\apps\pegasus\current\config\game_dirs.txt"
.\scripts\windows\run.ps1
```

Select the D2K theme in Pegasus if it is not already. `run.ps1` starts MPD for
the menu music from `library/consoles/music/playlist.m3u` and stops it when
Pegasus closes (`.\scripts\windows\mpd.ps1 -Action SmokeTest` checks it
without Pegasus). Only DS games run in the preview; see
[docs/theme.md](docs/theme.md).

## Documentation

| Document | Contents |
| --- | --- |
| [AGENTS.md](AGENTS.md) | Start here for agents: Pi access, deploying, restarting D2K, traps, conventions |
| [docs/platform.md](docs/platform.md) | How D2K runs on Linux and the Pi 5: windows, displays, touch, audio, heat, GPU limits, other boards |
| [docs/emulators.md](docs/emulators.md) | Emulator per console, its settings, every problem met and its fix |
| [docs/benchmarks.md](docs/benchmarks.md) | Measured performance per console, and how to measure |
| [docs/controls.md](docs/controls.md) | Keyboard, menu and touch controls, and where each emulator stores them |
| [docs/theme.md](docs/theme.md) | Pegasus theme development, the Windows preview, the launch lifecycle |
| [fusion/README.md](fusion/README.md) | Autodesk Fusion work for the shell and the electronics |

## Repository layout

```text
pegasus/themes/d2k/          D2K theme source, with Figma assets and fonts
scripts/windows/             Windows preview: run, launch and music scripts
scripts/linux/               Raspberry Pi installation and runtime scripts
docs/                        Documentation (see the table above)
docs/emulator-configs/       Per-emulator config overlays, Windows and Linux
fusion/                      Autodesk Fusion scripts and design records
library/                     Private, git-ignored ROMs, art and metadata
```
