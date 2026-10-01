# Pegasus theme development

The D2K theme source is `pegasus/themes/d2k/`. It is developed on Windows,
where Pegasus runs as a design preview, and deployed to the Pi by
`scripts/linux/install.sh`.

## Windows preview

Create a directory junction at Scoop's `pegasus/current/config/themes/d2k`
pointing at the theme source, so edits are visible to Pegasus without copying
files (the README has the commands). Pegasus runs in portable mode and stores
generated configuration under Scoop's ignored installation.

The two panels are separate windows at their native 800×480: the upper visual
panel (Waveshare 5" HDMI) and the lower touch panel (Waveshare 4-DSI-TOUCH-A
rotated to landscape), so what you read on the desktop is what the device
shows. The preview stacks them centred like the clamshell and needs a desktop
at least 1050px tall. `theme.qml` computes that layout from the primary screen
and `scripts/windows/launch-emulator.ps1 -Console ds` repeats the same
formula, so the two must be edited together.

With D2K selected, press `F5` in Pegasus after editing QML to reload the
theme. Check Pegasus' `lastrun.log` if a QML change does not load.

### DS games in the preview

Only the DS collection has a working emulator on Windows; the other
collections' metadata carries a header comment saying so. melonDS 1.1 uses two
independent windows: Window 0 is top-only (`ScreenSizing = 4`) and Window 1
bottom-only (`ScreenSizing = 5`). The tracked reference is
`pegasus/melonds/melonDS.dual-screen.toml`: copy its Window 0 and Window 1
settings into the active `melonDS.toml`, open a game, arrange the two windows
over the panels, and close melonDS normally from its primary window to save
the machine-local geometry. Do not commit that geometry, and do not close
Window 1 by itself: melonDS records it as disabled for the next launch.

`launch-emulator.ps1 -Console ds` re-enables Window 1 before every game,
removes melonDS' title bars and menus, and frames the two game windows on
exactly the same 800×480 rectangles as the Pegasus panels (both files derive
the layout from the same constants). At 800×480 melonDS letterboxes the DS's
4:3 output to 640×480 with 80px side bands, the target rendering on the lower
panel. Close a game in the preview with **Alt+F4**, or with the Home seam
below.

## Coordinates

Each panel is authored at a literal 800×480 with absolute integer coordinates
and scaled by `width / 800` from `Item.TopLeft`, so an 800×480 Figma frame maps
1:1 onto QML coordinates; at native size that scale is exactly 1. On a screen
of another shape the panel is scaled and centred, never stretched.

## Theme structure

`theme.qml` owns all navigation state and both windows; the panels are passive
and report user intent back through signals. `navState` moves through
`boot` → `consoles` → `games` (or `music`), and `TopPanel.qml` /
`TouchPanel.qml` are routers that load the matching screen.

| File | Role |
| --- | --- |
| `D2KTheme.qml` | Palette, type scale, fonts, console order and asset lookup |
| `TopPanel.qml` / `TouchPanel.qml` | Per-screen routers driven by `navState` |
| `TopConsole.qml` / `TopGame.qml` / `TopMusic.qml` | Upper "technical notice" showcase |
| `TouchConsoleSelector.qml` / `TouchGameLibrary.qml` / `TouchMusicLibrary.qml` | Lower interactive surface |
| `GameTile.qml`, `CoverArt.qml`, `ControlButton.qml`, `BootScreen.qml` | Shared pieces |

The token file is `D2KTheme.qml`, not `Theme.qml`: Windows filesystems are
case-insensitive, so `Theme.qml` and the `theme.qml` entry point would be the
same file.

Every choice is on the lower panel; the upper panel follows the selection. On
the console selector the side arrows change console and **SELECT CONSOLE**
opens it. In the library, touching a tile only selects the game: only
**LAUNCH** or the accept key starts a ROM. **BACK** returns to the consoles,
and the side arrows page through the 4×3 grid. The keyboard and gamepad
controls are in [`controls.md`](controls.md#menus-pegasus); keys are handled in
`theme.qml` (`handleKey`) from both windows.

`gameIndex` is the single source of truth shared by both screens.
`selectGame()` only moves the selection and never launches; only the `LAUNCH`
control or the accept key calls `launchSelectedGame()`, which takes a lock so a
double tap cannot start a ROM twice. Pagination is derived from the selection
(`pageSize` is 12, in a 4×3 grid), so the selected tile is always on the
visible page.

Imports use QtQuick, QtQuick.Window, QtMultimedia and QtGraphicalEffects; the
Linux installer supplies their matching QML modules.

## Assets

Art and fonts live in `pegasus/themes/d2k/assets/`, which must stay inside the
theme directory because that is what gets junctioned into Pegasus. Static
ornament exported from Figma is downscaled to roughly twice its on-screen size;
the full-bleed background is JPEG because it is opaque and photographic. Covers
are bound from Pegasus metadata instead, and every `Image` that shows box art
sets `sourceSize` so a 512×460 scan is not decoded at full resolution.

Fonts are the six Google families the Figma file uses (Chakra Petch, Orbitron,
Rubik Glitch, Pixelify Sans, Press Start 2P, Danfo), bundled as static TTF
instances with their OFL licences. Qt 5 does not apply variable-font axes, so
static instances are required: a variable TTF renders at its default weight.

Console artwork is looked up by a D2K console id derived from the Pegasus
`shortname` through an alias map in `D2KTheme.qml` (`nds` → `ds`, `psx` → `ps1`
and so on). Each console has two pieces, matching `console.png` and
`console-pixel.png` in `library/README.md`: `<id>-art.png` is the
high-resolution render for the upper screen and `<id>-carousel.png` the pixel
variant for the touch carousel. They are different artwork in Figma, taken from
the `Console art / selected` and `Carousel` nodes. Both are re-centred on their
own bounding box when imported, because Figma's exports carry uneven
transparent padding.

## Library layout

The private game library is under `library/consoles/` (git-ignored). Each
console owns a `metadata.pegasus.txt` file and `games/<game-id>/` folders
holding the ROM plus `cover.png`, `title.png` and `description.txt`. Pegasus
finds the consoles through `config/game_dirs.txt`: configure it manually on
Windows; the Pi installer generates it.

Each game carries `assets.boxFront` and `assets.logo` lines pointing at its
local `cover.png` and `title.png`. Without them the art on disk is invisible to
QML, because Pegasus only exposes files it was told about through metadata. The
grid tiles show the box art; the upper screen prefers the title screen and
falls back to the box art.

The launch file is detected per game, so both the `rom.<extension>` convention
and original multi-track `.cue` disc sets resolve. Windows metadata holds a
PowerShell `launch:` line; the Pi installer rewrites its copy of the library to
use the Linux launcher without changing the Windows source.

Game artwork keeps its original box-art proportion. The lower display uses
fixed square cells and must show it with `Image.PreserveAspectFit`; never crop
or stretch the source image (N64 covers are landscape).

## Launch lifecycle: the theme does not survive a game

Pegasus does not keep the theme's QML scene alive while a launched game runs.
It tears the whole scene down before starting the process (`FrontendLayer`
teardown/rebuild, visible in the binary's exported symbols: `processLaunchOk`,
`teardownComplete`, `rebuild`, `processFinished`) and only rebuilds it, cold,
from `Component.onCompleted`, once that process exits. Confirmed in
`lastrun.log`: the theme's boot log line reappears in the same second the
launched process is reported finished.

Practical consequences:

- **No code in `theme.qml` can run while a game plays.** Ending a game and
  returning to the menu is entirely the launcher's job
  (`scripts/windows/launch-emulator.ps1`, `scripts/linux/launch-emulator.sh`),
  since it is the only D2K code alive for the whole session.
- **`api.memory` is the only channel that survives.** It is written to
  `config/theme_settings/d2k.json` outside the QML engine. `theme.qml` mirrors
  `navState` into it as `d2kNav` (alongside `d2kConsole` / `d2kGame:<id>`) and
  restores from it in `Component.onCompleted`, skipping the boot screen when
  it finds one, so the menu comes back on the same game.
- **`d2kNav` must not survive a power cycle.** `run.ps1` and `run.sh` clear it
  once per launch, before starting Pegasus, so a restart always plays the boot
  screen.
- **A failure inside the launcher must never end the session early.** Its own
  lifetime is what Pegasus times the game against: if it exits before the
  emulator does, Pegasus rebuilds the menu on top of a still-running game.
  Every non-essential phase (config patching, window framing) can fail
  without ending the script, and the script always exits `0`. The Windows
  launcher logs to `%LOCALAPPDATA%\D2K\launch-ds.log`, the Linux one to
  `~/.local/state/d2k/launch-<console>.log`; look there first when a launch
  misbehaves, because Pegasus does not put the child's stderr in
  `lastrun.log`.

## Home button seam

The eventual Home button (on the ESP32, not built yet) ends a game the way the
keyboard does today: by asking the launcher to close the emulator through a
signal file. On the Pi, **Super+Esc** touches
`~/.local/state/d2k/home-request` ([`platform.md`](platform.md#leaving-a-game)).
On Windows, dropping any file at `%LOCALAPPDATA%\D2K\home-request` makes
`launch-emulator.ps1` close melonDS gracefully (falling back to a kill) within
its next poll tick; `New-Item` that path by hand to test the return path.
Either way Pegasus then rebuilds and the menu resumes on the same game.

An on-screen Home button in the side band melonDS leaves empty on the lower
screen is planned; it needs its own always-on-top overlay, since the theme does
not exist while a game runs, and is not built yet.
