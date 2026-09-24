# Linux deployment notes

Issues found while porting D2K from Windows that apply to any Linux desktop.
Raspberry Pi-specific problems live in
[`raspberry-pi-struggles.md`](raspberry-pi-struggles.md).

## Launch from a graphical session

Pegasus and the emulators need the active graphical display. Running
`scripts/linux/run.sh` in a plain SSH shell without the session environment
fails with `qt.qpa.xcb: could not connect to display`. The scripts source
`scripts/linux/lib.sh` and call `use_desktop_session`, which fills in
`XDG_RUNTIME_DIR`, the D-Bus socket, `DISPLAY=:0` and `WAYLAND_DISPLAY` for the
logged-in desktop user. A successful SSH login is still not a GUI session:
validate placement and sound on the real screens.

## Keep the UI on Xwayland

D2K places windows by absolute position with `xdotool` and `wmctrl`, which
control X11 windows. Pegasus/Qt and every emulator therefore run on Xwayland
(`QT_QPA_PLATFORM=xcb`, `SDL_VIDEODRIVER=x11`, `--socket=x11` and
`--nosocket=wayland` for Flatpaks). Moving an emulator to native Wayland removes
the window-placement seam.

## Emulators fight the launcher for their window size

Several emulators resize their own windows after boot (melonDS returns to its
native size). `launch-emulator.sh` re-checks placement for the whole session
and does nothing while a window is already in place. On a two-output desktop
the windows are made fullscreen with `wmctrl -b add,fullscreen`, because
compositors re-place ordinary windows when an output changes.

## Emulators spawn the real game as a child

`flatpak run` and AppImage runtimes are wrappers: the visible emulator is a
child that can outlive them. The launcher starts each emulator with `setsid`
and watches and stops the **whole process group**; for Flatpaks it also checks
`flatpak ps --columns=application` and finishes with `flatpak kill <app-id>`.
Do not add `--user` to `flatpak ps` or `flatpak kill`; the installed Flatpak
version rejects it.

## Keep configuration templates platform-specific

Windows configuration files are references, not Linux deployment files.
Linux overlays live in `docs/emulator-configs/linux/`, and
`scripts/linux/configure-emulators.sh` sets only the overlay's keys in each
emulator's own configuration (in place, keeping comments), preserving BIOS
paths, game paths, controllers, saves and preferences. `--check` reports any
drift. melonDS is the exception: it rewrites its TOML on exit, so the launcher
patches the values D2K needs before every launch.

## Settings that emulators persist on their own

Some emulators write command-line or fallback choices back into their config:
Mupen64Plus saves plugin choices, Ship of Harkinian saves `AudioBackend: null`
after an audio failure, and Azahar rewrites `\default` flags. When a setting
"comes back", look for the emulator writing it before blaming the overlay.

## Useful checks

```bash
./scripts/linux/smoke-test.sh                    # everything below, without opening Pegasus
./scripts/linux/launch-emulator.sh --self-test
./scripts/linux/configure-emulators.sh --check
./scripts/linux/configure-desktop.sh --check
flatpak ps --columns=application
```
