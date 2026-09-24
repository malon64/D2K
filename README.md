# D2K

Pegasus Frontend theme for a Raspberry Pi 5 running Raspberry Pi OS 64-bit,
with two 800×480 displays.

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
