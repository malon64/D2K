# Emulator configuration templates

These are the D2K display overlays for the Windows emulators. Start each
emulator once, then merge the matching template into its generated config.
They deliberately exclude BIOS locations, game folders, controllers, analytics
IDs, recent games, and saved desktop positions.

Both launchers set the final D2K window rectangles. Linux uses native Debian
packages for ares and Dolphin, ARM64 AppImages for melonDS and DuckStation,
and ARM64 Flathub packages for Flycast and Azahar. The Linux installer merges
the display overlays into each Pi-local configuration. DuckStation is the
exception: it preserves Alex's setup and changes only its 800×480 window size.

| Emulator | Template |
| --- | --- |
| melonDS | `windows/melonds/melonDS.toml` |
| Flycast | `windows/flycast/emu.cfg` |
| DuckStation | `windows/duckstation/settings.ini` |
| ares | `windows/ares/settings.bml` |
| Dolphin | `windows/dolphin/Dolphin.ini` |
| Azahar | `windows/azahar/qt-config.ini` |
