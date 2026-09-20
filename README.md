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

- Upper visual panel: 600×360 preview of an 800×480, 5-inch display.
- Lower touch panel: 480×288 preview of the same 800×480 logical layout on a
  4-inch display.

Click a game on the lower panel to update the upper preview, then click
**PLAY**. Arrow keys select a game and Enter launches it. Edit `theme.qml`,
then press `F5` to reload it. Details and the future Linux ARM64 handoff are
in [docs/pegasus-development.md](docs/pegasus-development.md).

## Nintendo DS smoke test

`setup.ps1` links `pegasus/metadata/nds/` into Scoop's Pegasus metafiles
directory. The metadata contains Windows-only entries for Zelda: Phantom
Hourglass, Mario & Luigi: Bowser's Inside Story, and Pokémon Version Diamant.
They use the configured melonDS build and ROMs in `C:\Users\alexi\Documents\NDS`.

For two-screen game output, copy the Window 0 and Window 1 settings from
`pegasus/melonds/melonDS.dual-screen.toml` to the active `melonDS.toml`, open
a game, arrange the two melonDS windows to match the upper and lower previews,
then close the primary melonDS window normally to save its local geometry. Do
not close the second window by itself, as melonDS disables it for the next run.
The Pegasus launcher re-enables it before every game launch, removes melonDS'
Windows title bars and menus, and frames the game outputs at the same 600×360
and 480×288 preview sizes. Use **Alt+F4** to close a game in this preview.

## Repository layout

```text
pegasus/themes/d2k/  D2K theme source
pegasus/metadata/nds/ Reserved for future DS metadata
scripts/windows/     Windows setup and run scripts
scripts/linux/       Reserved for Linux ARM64 scripts
docs/                Development notes
```
