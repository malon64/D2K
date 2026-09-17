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
and fullscreen off. The theme is designed against an 800×480 baseline; resize
the Pegasus window to that size when checking it locally.

## Theme development

The minimal theme is in `pegasus/themes/d2k/` and displays:

```text
D2K
PEGASUS DEV
800 × 480
```

In Pegasus, open Settings and select **D2K** if it is not already active. Edit
`theme.qml`, then press `F5` to reload it. Details and the future Linux ARM64
handoff are in [docs/pegasus-development.md](docs/pegasus-development.md).

## Nintendo DS smoke test

`setup.ps1` links `pegasus/metadata/nds/` into Scoop's Pegasus metafiles
directory. It contains one Windows-only smoke test entry for the configured
melonDS build and Pokémon Version Diamant in `C:\Users\alexi\Documents\NDS`.
Start Pegasus, then press **Enter** on the D2K screen to launch it.

## Repository layout

```text
pegasus/themes/d2k/  D2K theme source
pegasus/metadata/nds/ Reserved for future DS metadata
scripts/windows/     Windows setup and run scripts
scripts/linux/       Reserved for Linux ARM64 scripts
docs/                Development notes
```
