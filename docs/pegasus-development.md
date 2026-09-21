# Pegasus development

The D2K theme source is `pegasus/themes/d2k/`. On Windows, `setup.ps1` creates
a directory junction at Scoop's `pegasus/current/config/themes/d2k`, so source
edits are visible to Pegasus without copying files. Pegasus runs in portable
mode and stores generated configuration under Scoop's ignored installation.

`theme.qml` uses 800×480 as the logical design baseline for two independent
windows, which is also their native size: a Waveshare 5-inch HDMI panel on top
and a Waveshare 4-DSI-TOUCH-A rotated to landscape below. The Windows preview
runs both at 800×480 so legibility matches the device. Each panel is authored at
a literal 800×480 with absolute integer coordinates and then scaled by
`width / 800` from `Item.TopLeft`, so an 800×480 Figma frame maps 1:1 onto QML
coordinates; at native size that scale is exactly 1.

The preview stacks the two windows centred like the clamshell. `theme.qml`
computes the layout from the primary screen and
`scripts/windows/launch-emulator.ps1 -Console ds` repeats the same formula, so the two must
be edited together. It needs a desktop at least 1050px tall.

## Theme structure

`theme.qml` owns all navigation state and both windows; the panels are passive
and report user intent back through signals. `navState` moves through
`boot` → `consoles` → `games`, and `TopPanel.qml` / `TouchPanel.qml` are routers
that load the matching screen.

| File | Role |
| --- | --- |
| `D2KTheme.qml` | Palette, type scale, fonts, console order and asset lookup |
| `TopPanel.qml` / `TouchPanel.qml` | Per-screen routers driven by `navState` |
| `TopConsole.qml` / `TopGame.qml` | Upper "technical notice" showcase |
| `TouchConsoleSelector.qml` / `TouchGameLibrary.qml` | Lower interactive surface |
| `GameTile.qml`, `CoverArt.qml`, `ControlButton.qml`, `BootScreen.qml` | Shared pieces |

The token file is `D2KTheme.qml`, not `Theme.qml`: Windows filesystems are
case-insensitive, so `Theme.qml` and the `theme.qml` entry point are the same
file and would overwrite each other.

`selectedGameIndex` is the single source of truth shared by both screens.
`selectGame()` only moves the selection and never launches; only the `LAUNCH`
control or the accept key calls `launchSelectedGame()`, which takes a lock so a
double tap cannot start a ROM twice. Pagination is derived from the selection
(`pageSize` is 12, in a 4×3 grid), so the selected tile is always on the visible
page.

Imports are limited to `QtQuick 2.0` and `QtQuick.Window 2.15`, both already
covered by the packages `scripts/linux/install.sh` installs. Keep it that way —
anything else (notably `QtGraphicalEffects`) needs a matching apt package added
there, and will otherwise fail only once it reaches the device.

## Assets

Art and fonts live in `pegasus/themes/d2k/assets/`, which must stay inside the
theme directory because that is what gets junctioned into Pegasus. Static
ornament exported from Figma is downscaled to roughly twice its on-screen size;
the full-bleed background is JPEG because it is opaque and photographic. Covers
are bound from Pegasus metadata instead, and every `Image` that shows box art
sets `sourceSize` so a 512×460 scan is not decoded at full resolution.

Fonts are the seven Google families the Figma file uses (Chakra Petch, Orbitron,
Rubik Glitch, Pixelify Sans, Press Start 2P, Bungee Shade, Danfo), bundled as
static TTF instances with their OFL licences. Qt 5 does not apply variable-font
axes, so static instances are required — a variable TTF renders at its default
weight instead of the designed one.

Console artwork is looked up by a D2K console id derived from the Pegasus
`shortname` through an alias map in `D2KTheme.qml` (`nds` → `ds`, `psx` → `ps1`
and so on). Each console has two pieces, matching `console.png` and
`console-pixel.png` in `library/README.md`: `<id>-art.png` is the
high-resolution render for the upper screen and `<id>-carousel.png` the pixel
variant for the touch carousel. They are different artwork in Figma, taken from
the `Console art / selected` and `Carousel` nodes respectively. Both are
re-centred on their own bounding box when imported, because Figma's exports
carry uneven transparent padding.

## Library layout

The portable game library is under `library/consoles/`. Each console owns a
`metadata.pegasus.txt` file and `games/<game-id>/` folders holding the ROM plus
`cover.png`, `title.png` and `description.txt`. ROMs remain Git-ignored.

Collection-based navigation now exists, so that switch has been made:
`setup.ps1` writes `config/game_dirs.txt` listing every console directory that
has a metadata file, and removes the old `config/metafiles` junction. Indexing
both would list the same Nintendo DS games twice. `pegasus/metadata/nds/` is
kept only as the Linux handoff template and is no longer read on Windows.

Each game carries `assets.boxFront` and `assets.logo` lines pointing at its
local `cover.png` and `title.png`. Without them the art on disk is invisible to
QML, because Pegasus only exposes files it was told about through metadata. The
grid tiles show the box art; the upper screen prefers the title screen and
falls back to the box art.

The launch file is detected per game, so both the `rom.<extension>` convention
and original multi-track `.cue` disc sets resolve. Only the DS collection has a
working emulator on Windows; the others carry a header comment saying so.

That metadata file holds a Windows `launch:` line, so the Linux install path
still uses the `.in` template under `pegasus/metadata/nds/`. One metadata file
cannot serve both platforms; reconcile this during the device handoff.

Game artwork keeps its original box-art proportion. The lower display uses
fixed square cells and must show it with `Image.PreserveAspectFit`; never crop
or stretch the source image. This accommodates landscape artwork such as N64
covers as well as portrait cases.

melonDS 1.1 uses two independent windows for this preview: Window 0 is
top-only (`ScreenSizing = 4`) and Window 1 is bottom-only
(`ScreenSizing = 5`). The tracked reference is
`pegasus/melonds/melonDS.dual-screen.toml`. Apply those sections to the active
Windows configuration at
`C:\Users\alexi\Documents\NDS\melonDS-1.1-windows-x86_64\melonDS.toml`, then
arrange the two windows and close melonDS normally to save machine-local
geometry. Do not close Window 1 by itself: melonDS records that as disabled
for the next launch. `scripts/windows/launch-emulator.ps1 -Console ds` restores its enabled
setting before Pegasus starts a game. It also displays the top and bottom game
windows without Windows chrome, on exactly the same 800×480 rectangles as the
Pegasus panels: both files derive the layout from the same constants, so the
emulator lands where the menu was. At 800×480 melonDS letterboxes the DS's 4:3
output to 640×480 with 80px side bands, which is the target rendering on the
lower panel. Close a game with Alt+F4. Do not commit that geometry.

On Linux ARM64, install a compatible Pegasus build separately, copy the
`pegasus/themes/d2k/` directory to its Pegasus themes directory, choose D2K in
Settings, and map the upper and lower windows to their physical outputs. Keep
the logical layout at 800×480 while validating the lower display's rotation.

With D2K selected, press `F5` in Pegasus after editing QML to reload the theme.
Check Pegasus' `lastrun.log` if a QML change does not load.

## Launch lifecycle: the theme does not survive a game

Pegasus does not keep the theme's QML scene alive while a launched game runs.
It tears the whole scene down before starting the process (`FrontendLayer`
teardown/rebuild, visible in the binary's exported symbols:
`processLaunchOk`, `teardownComplete`, `rebuild`, `processFinished`) and only
rebuilds it — cold, from `Component.onCompleted` again — once that process
exits. This was confirmed by tracing `lastrun.log`: the theme's boot log line
reappears in the same second the launched process is reported finished.

Practical consequences:

- **No code in `theme.qml` can run while a game plays.** There is nothing to
  hide, nothing to restore, and no signal to listen for — the theme instance
  is simply gone. Ending a game and returning to the menu is entirely
  `scripts/windows/launch-emulator.ps1 -Console ds`'s job, since it is the only D2K code
  alive for the whole session.
- **`api.memory` is the only channel that survives.** It is written to
  `config/theme_settings/d2k.json` outside the QML engine, so it is how state
  crosses the teardown/rebuild boundary. `theme.qml` mirrors `navState` into
  it as `d2kNav` (alongside the existing `d2kConsole` / `d2kGame:<id>` keys)
  and restores from it in `Component.onCompleted`, skipping the boot screen
  when it finds one — that is what makes the menu come back on the same game
  instead of replaying boot → consoles.
- **`d2kNav` must not survive an actual power cycle.** `scripts/windows/run.ps1`
  clears it once per launch, before starting Pegasus, so "shut down and
  restart the console" always plays the boot screen. A future Linux startup
  script needs the same clear (or an equivalent full-state reset) — it is
  presently Windows-only.
- **A failure inside `launch-emulator.ps1 -Console ds` must never end the session early.**
  Its own lifetime is what Pegasus is timing the game against: if it exits
  before melonDS does, Pegasus treats the game as over and rebuilds the menu
  on top of a still-running emulator. Every non-essential phase (config
  patching, window framing) is wrapped so it can fail without ending the
  script, and the script always exits `0`. It logs its own run to
  `%LOCALAPPDATA%\D2K\launch-ds.log`, which is the place to look first
  when a launch misbehaves — Pegasus forwards the child process's stderr to
  its own console rather than into `lastrun.log`, so that log is otherwise
  the only record.

## Home button seam

There is no hardware yet, so ending a game today is `Alt+F4`, same as
before. The eventual Home button (ESP32, not yet built) is expected to end
the game the same way anything else would: by asking
`launch-emulator.ps1 -Console ds` to close melonDS. The seam for that is a signal file —
dropping any file at `%LOCALAPPDATA%\D2K\home-request` makes the script close
melonDS gracefully (falling back to a kill) within its next poll tick, after
which Pegasus rebuilds and the menu resumes on the same game. This can be
exercised by hand today (`New-Item` that path while a game is running) to
test the return path without waiting on hardware. The planned first version
is an on-screen button in the side band melonDS leaves empty on the lower
screen (its DS output is letterboxed to 640×480 inside the 800×480 window);
that still needs its own always-on-top overlay, since the theme does not
exist while a game runs, and is not built yet.
