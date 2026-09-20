# Pegasus development

The D2K theme source is `pegasus/themes/d2k/`. On Windows, `setup.ps1` creates
a directory junction at Scoop's `pegasus/current/config/themes/d2k`, so source
edits are visible to Pegasus without copying files. Pegasus runs in portable
mode and stores generated configuration under Scoop's ignored installation.

`theme.qml` uses 800×480 as the logical design baseline for two independent
windows. The upper 5-inch visual panel previews at 600×360; the lower 4-inch
touch panel previews at 480×288. The lower panel selects one of the three
configured Nintendo DS games with mouse clicks, and Play launches it. Arrow
keys select a game and Enter launches it.

The metadata is `pegasus/metadata/nds/nds.metadata.pegasus.txt`. It points to
the current Windows melonDS and three ROM paths, so it must be replaced with
Linux ARM64 paths during the device handoff.

## Library layout

The intended portable game library is under `library/consoles/`. Each console
owns its renders, a `metadata.pegasus.txt` file, and `games/<game-id>/` folders
containing a local `rom.<extension>` and optional `cover.png`. The first
migrated library is `library/consoles/ds/`; its ROMs remain Git-ignored.

The existing `pegasus/metadata/nds/` metadata stays in place for the current
Windows preview. Switch Pegasus' game directory to `library/consoles/ds` only
when the collection-based D2K navigation is implemented, so the same NDS games
are not indexed twice.

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
for the next launch. `scripts/windows/launch-melonds.ps1` restores its enabled
setting before Pegasus starts a game. It also displays the top and bottom game
windows without Windows chrome at 600×360 and 480×288, matching the Pegasus
preview frames. Close a game with Alt+F4. Do not commit that geometry.

On Linux ARM64, install a compatible Pegasus build separately, copy the
`pegasus/themes/d2k/` directory to its Pegasus themes directory, choose D2K in
Settings, and map the upper and lower windows to their physical outputs. Keep
the logical layout at 800×480 while validating the lower display's rotation.

With D2K selected, press `F5` in Pegasus after editing QML to reload the theme.
Check Pegasus' `lastrun.log` if a QML change does not load.
