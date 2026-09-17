# Pegasus development

The D2K theme source is `pegasus/themes/d2k/`. On Windows, `setup.ps1` creates
a directory junction at Scoop's `pegasus/current/config/themes/d2k`, so source
edits are visible to Pegasus without copying files. Pegasus runs in portable
mode and stores generated configuration under Scoop's ignored installation.

`theme.qml` uses 800×480 as its design baseline. It has a single temporary DS
smoke-test launch action: press Enter to launch the only configured game. It
does not provide a game list, navigation, final styling, animation, or
dual-screen support.

The smoke-test metadata is `pegasus/metadata/nds/nds.metadata.pegasus.txt`.
It points to the current Windows melonDS and ROM paths, so it must be replaced
with Linux ARM64 paths during the device handoff.

On Linux ARM64, install a compatible Pegasus build separately, copy the
`pegasus/themes/d2k/` directory to its Pegasus themes directory, choose D2K in
Settings, and develop against an 800×480 display. Add DS metadata later under
`pegasus/metadata/nds/`.

With D2K selected, press `F5` in Pegasus after editing QML to reload the theme.
Check Pegasus' `lastrun.log` if a QML change does not load.
