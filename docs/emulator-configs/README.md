# Emulator configuration templates

These are the D2K display overlays for the Windows emulators. Start each
emulator once, then merge the matching template into its generated config.
They deliberately exclude BIOS locations, game folders, controllers, analytics
IDs, recent games, and saved desktop positions.

The Windows launcher still sets the final 800x480 D2K window rectangles. The
templates provide the emulator-side defaults and are the portable reference for
a later Linux setup; config locations vary by package and platform.

| Emulator | Template |
| --- | --- |
| melonDS | `windows/melonds/melonDS.toml` |
| Flycast | `windows/flycast/emu.cfg` |
| DuckStation | `windows/duckstation/settings.ini` |
| ares | `windows/ares/settings.bml` |
| Dolphin | `windows/dolphin/Dolphin.ini` |
| Azahar | `windows/azahar/qt-config.ini` |
