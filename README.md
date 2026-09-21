# D2K

Pegasus Frontend theme development for an eventual ROCK 4D ARM64 Linux device
with an 800×480 Waveshare display.

## Windows setup

1. Install Pegasus with Scoop:

   ```powershell
   scoop bucket add games
   scoop install pegasus
   ```

2. From the repository root, link the tracked D2K theme into Scoop's Pegasus
   configuration directory:

   ```powershell
   .\scripts\windows\setup.ps1
   ```

3. Launch Pegasus in documented portable mode:

   ```powershell
   .\scripts\windows\run.ps1
   ```

The setup creates a directory junction from Scoop's Pegasus theme directory to
this repository, then writes its `settings.txt` on first run with D2K selected
and fullscreen off.

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
the theme. Details and the future Linux ARM64 handoff are in
[docs/pegasus-development.md](docs/pegasus-development.md).

## Nintendo DS smoke test

`setup.ps1` points Pegasus at `library/consoles/ds` through
`config/game_dirs.txt`, which indexes the full 19-game DS library with its
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
pegasus/metadata/nds/ Linux handoff metadata template
scripts/windows/     Windows setup and run scripts
scripts/linux/       Reserved for Linux ARM64 scripts
docs/                Development notes
```
