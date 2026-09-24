# Emulator configuration templates

Windows and Linux have separate D2K overlays. Each holds only the display and
behaviour keys D2K needs; they deliberately exclude BIOS locations, game
folders, controllers, analytics IDs, recent games and saved window positions.
Both launchers set the final window rectangles themselves.

On Linux, `scripts/linux/configure-emulators.sh` sets the `linux/` overlays'
keys in each emulator's own configuration (`--check` verifies them). melonDS
is copied whole by `install.sh` and patched before every launch, because it
rewrites its TOML on exit.

| Console | Windows | Linux (Raspberry Pi) |
| --- | --- | --- |
| DS | melonDS: `windows/melonds/melonDS.toml` | melonDS AppImage: `linux/melonds/melonDS.toml` |
| Dreamcast | Flycast: `windows/flycast/emu.cfg` | Flycast, native build: `linux/flycast/emu.cfg` |
| PS1 | DuckStation: `windows/duckstation/settings.ini` | DuckStation AppImage: `linux/duckstation/settings.ini` |
| PSP | PPSSPP: `windows/ppsspp/ppsspp.ini` | PPSSPP Flatpak: `linux/ppsspp/ppsspp.ini` |
| GameCube | Dolphin: `windows/dolphin/Dolphin.ini` | Dolphin (Debian): `linux/dolphin/Dolphin.ini` |
| 3DS | Azahar: `windows/azahar/qt-config.ini` | Azahar Flatpak: `linux/azahar/qt-config.ini` |
| N64 | ares: `windows/ares/settings.bml` | Mupen64Plus + Rice, native build: `linux/mupen64plus/mupen64plus.cfg` |
| N64: Ocarina of Time | ares | Ship of Harkinian AppImage: `linux/shipwright/shipofharkinian.json` |

## Linux notes

- **ares is not used on Linux.** On the Pi's V3DV driver it renders N64 black.
  Mupen64Plus plays the N64 library and Ship of Harkinian runs Ocarina of Time
  natively. See [`../raspberry-pi-struggles.md`](../raspberry-pi-struggles.md).
- **Mupen64Plus** pins its four plugins because it saves command-line plugin
  choices into this file. Vsync and fullscreen stay off; the launcher places the
  window.
- **Ship of Harkinian** keeps `Window/AudioBackend` at `sdl`: after an ALSA
  failure SoH writes `null` there and stays silent.
- **Dolphin** sets `[Core] SyncGPU = True`: Dual Core without GPU sync desyncs
  on the Pi (`GFX FIFO: Unknown Opcode`).
- **PPSSPP and Azahar** select Vulkan, the working Pi V3D backend on Xwayland.
- **Azahar** rewrites `key\default` flags whenever a value equals its default;
  the check ignores them.

## Windows known limitation

On the Windows desktop preview, ares can still display an inset N64 viewport
inside its correctly sized window.
