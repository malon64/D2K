# Emulators

Which emulator D2K uses for each console, the settings D2K sets and why, and
every emulator problem met so far with its fix. Measured performance is in
[`benchmarks.md`](benchmarks.md); platform problems (display, audio, heat,
GPU driver limits) are in [`platform.md`](platform.md); the key scheme is in
[`controls.md`](controls.md).

| Console | Windows (design preview) | Linux (Raspberry Pi 5) | Pi verdict |
| --- | --- | --- | --- |
| DS | melonDS | melonDS AppImage | Works well |
| PSP | PPSSPP | PPSSPP Flatpak | Plays well |
| Dreamcast | Flycast | Flycast, built from source | Plays well |
| N64 | ares | Mupen64Plus + Rice, built from source | Smooth (PAL ROMs: 25 fps) |
| N64: Ocarina of Time | ares | Ship of Harkinian AppImage | Plays fine |
| PS1 | DuckStation | DuckStation AppImage | Smooth |
| GameCube | Dolphin | Dolphin (Debian package) | Works |
| 3DS | Azahar | Azahar Flatpak | Smooth once warm; shadow bug |

## How D2K configures emulators

D2K keeps an **overlay** per emulator in `emulator-configs/windows/` and
`emulator-configs/linux/`: only the keys D2K needs (display, behaviour,
audio, the keyboard scheme). Overlays never hold BIOS locations, game folders,
controllers, analytics IDs, recent games or saved window positions; the
launchers set the final window rectangles themselves.

On Linux, `scripts/linux/configure-emulators.sh` sets each overlay key in the
emulator's own config file, in place, keeping comments, and `--check` reports
any drift. It reads configs with its own line-based reader because melonDS's
TOML (top-level keys, multi-line arrays) is not INI. Comment lines in overlays
are ignored. melonDS is the exception: `install.sh` copies its TOML whole and
the launcher patches it before every launch, because melonDS rewrites it on
exit.

**Emulators write their own settings back.** Change a config only with the
emulator closed, then run `configure-emulators.sh` and `--check`. When a
setting "comes back", look for the emulator writing it before blaming the
overlay:

- melonDS rewrites its TOML on exit.
- Mupen64Plus saves command-line plugin choices.
- Ship of Harkinian saves `AudioBackend: null` after an audio failure.
- Azahar rewrites `key\default=true` whenever a value equals its default (the
  check ignores `\default` keys), and **ignores a value while its `\default`
  flag is `true`**, so every overlay key sets `key\default=false`.
- Undo test changes: a temporary setting left in a live config survives.

## DS (melonDS)

melonDS AppImage with two windows (upper screen, lower touch screen), JIT on,
software 3D renderer (threaded). Overlay: `melonds/melonDS.toml` and
`melonds/keyboard.toml`.

- **Tiny DS screens in the corner.** melonDS snaps its windows back to
  256x192 shortly after boot; the launcher keeps re-placing them fullscreen
  ([`platform.md`](platform.md#window-placement)).
- **Low frame rate: JIT.** melonDS's ARM64 JIT was off: 40/60 fps at ~1.8
  cores. With `[JIT] Enable = true` it holds 60/60 at ~0.8 of a core. The
  launcher forces it before every launch because melonDS rewrites its TOML.
- **Menu bar.** melonDS hides its menu bar only in its own fullscreen mode,
  which `--fullscreen` applies to the first window only, and synthetic F11
  presses do not reach its hotkeys. The launcher passes the Qt option
  `-stylesheet scripts/linux/melonds.qss`, which collapses `QMenuBar` in every
  window.
- **No keys at all.** Every `[Instance0.Keyboard]` entry was `-1`, so games
  only reacted to touch. The keys now come from `melonds/keyboard.toml`.
- **Sound cutting out.** melonDS's SDL stream pulled PipeWire down to 256
  samples and underran ~6 times a minute. Fixed in two steps: the launcher
  sets `PULSE_LATENCY_MSEC=40` and `PIPEWIRE_LATENCY=2048/48000` (a clear
  improvement, but PipeWire still rounded to 256), then the `pipewire-pulse`
  floor of 1024 samples ([`platform.md`](platform.md#emulators-need-a-larger-audio-buffer)).
  Verified: 0 underruns.
- **A button sometimes missed in menus.** Seen in the first session only,
  before the audio fixes. melonDS samples keys once per emulated frame, so a
  very short tap during a stall can be missed. If it returns, watch the raw
  events (`sudo libinput debug-events | grep KP6`): one `pressed` per tap means
  the keyboard is fine and the emulator lost it.
- **OpenGL renderer rejected.** `[Screen] UseGL = true` fails on its own
  (`Failed to create OpenGL context`: V3D exposes OpenGL 3.1, melonDS wants
  3.2). With `MESA_GL_VERSION_OVERRIDE=3.3 MESA_GLSL_VERSION_OVERRIDE=330` it
  renders, but melonDS (~1.0 core) and Xwayland (~0.55) use no less CPU. Kept
  `UseGL = false`.

The DS is the heaviest CPU load measured: about 2.3 cores in total, with the
emulation thread at up to 77% of a core. That thread is the limit to watch.
Its GPU load (~66%) is mostly the compositor and Xwayland scaling the windows
(640x480 on the lower panel, x2.5), not melonDS rendering.

## PSP (PPSSPP)

PPSSPP Flatpak, Vulkan, internal resolution 2x (960x544, already above the
800x480 panel), 4x anisotropic filtering. Overlay: `ppsspp/ppsspp.ini`,
`ppsspp/controls.ini`.

- **Game on the lower panel.** PPSSPP renames its window to the running game
  (`ULES00108 : Midnight Club 3: DUB Edition`), so the launcher's title search
  missed it and placement timed out. The launcher now finds it by window class
  `org.ppsspp.PPSSPP`.
- **Glitchy sound.** PPSSPP ran at 118 samples (2.7 ms: `AudioBufferSize =
  256`) and underran ~9 times a minute; `FillAudioGaps = True` turned each gap
  into a glitch rather than silence. Fixed with `[Sound] ExtraAudioBuffering =
  True` plus the `pipewire-pulse` floor. Verified: QUANT 941 at 44.1 kHz
  (21 ms), 0 underruns.
- `controls.ini` starts with a UTF-8 BOM, which hid its first section header
  from the overlay reader (it would have appended a second
  `[ControlMapping]`); the reader keeps the BOM out of the parse.

PPSSPP is GPU-bound on the Pi (V3D 48–85% busy, emulation thread ~24%). If a
game slows down, lower `InternalResolution` or `AnisotropyLevel` first.

## Dreamcast (Flycast)

Flycast built from the pinned source in `~/.local/opt/d2k/flycast`, run with
`SDL_VIDEODRIVER=x11`, renderer settings at Flycast's defaults (OpenGL, native
640x480). Overlay: `flycast/emu.cfg`, `flycast/mappings/SDL_Keyboard.cfg`,
`flycast/mappings/SDL_D2K Controls.cfg`.

- The Flathub ARM64 Flycast aborts on the Pi 5's 16 KiB-page kernel, hence the
  source build.
- The overlay leaves window size to the launcher: Flycast saves the size the
  launcher gave its window on exit, so a fixed size would always drift.
- With no mapping file for a pad, Flycast builds one from SDL's game
  controller mapping: ABXY by label (wrong for the Dreamcast, mapped by
  position), the D-pad on the D-pad, and Select (SDL "back") on Flycast's
  own menu. It keeps that default in memory without saving it, so the D2K
  pad file is written whole; Flycast looks it up by the pad's name. It keeps
  Select on the menu, which is useful in game (like Tab).
- Extras kept from Flycast's defaults: Tab (menu), Space (fast-forward), F12
  (screenshot).

Flycast barely loads the Pi (busiest thread 20%, GPU 23%): the internal
resolution could go up for a larger screen.

## N64 (Mupen64Plus, Ship of Harkinian)

Ocarina of Time runs natively in Ship of Harkinian; every other N64 game uses
Mupen64Plus with the Rice video plugin. **All N64 ROMs in the library are PAL**
(50 Hz): Super Mario 64 runs at 25 fps and ~17% slower than NTSC, as on a PAL
console. NTSC ROMs are the real fix for that.

### Emulators tried and removed

- **ares** renders N64 black on V3DV: its paraLLEl-RDP Vulkan renderer loads
  ROMs but draws nothing, including with the small-integer, subgroup and
  ubershader fallbacks, and its OpenGL path wants 3.2 (the Pi offers 3.1).
  Debian's `ares` package has no N64 core. Removed from the Pi; Windows still
  uses ares (it can show an inset N64 viewport inside its window there).
- **RMG** (Mupen64Plus + GLideN64) displays correctly but stalls heavily.
  Removed.

### Mupen64Plus

Native build of the `nightly-build` commits pinned in `install.sh`. Overlay:
`mupen64plus/mupen64plus.cfg`.

- **Measure VI/s, not CPU.** With `[Video-Rice] ShowFPS = True` the window title
  shows VI/s (50 = full PAL speed); undo it afterwards. A main thread asleep at
  low CPU is not proof of full speed.
- **Slow with stuttering sound: `AUDIO_SYNC`.** Super Mario 64 ran at ~40 of
  50 VI/s while the main thread used 3–6% and slept in `hrtimer_nanosleep`:
  the SDL audio plugin paced the emulator on its own buffer (target 2048 +
  1024 samples), which fought PipeWire's 256-sample graph. `[Audio-SDL]
  AUDIO_SYNC = False` lets the core's VI limiter pace the game: 50.0 VI/s, 12%
  CPU, 0 underruns.
- **Silent games:** it saves command-line plugin choices, so the launcher names
  all four plugins and the overlay pins them. Vsync and fullscreen stay off;
  the launcher places the window. It needs `--datadir` (ROM database and OSD
  font), otherwise it exits right after starting.
- **Blue textures (red/blue swapped) came from a Rice build with
  `USE_GLES=1`.** Mupen64Plus creates a desktop OpenGL context, but a GLES
  build only uploads BGRA textures when `GL_EXT_texture_format_BGRA8888`
  exists, which a desktop context never reports. Build Rice without
  `USE_GLES` (the installer does; `ldd` must show `libGL`, not `libGLESv2`).
- **Only Start worked on the keyboard:** `[Input-SDL-Control1] mode = 2`
  (automatic) replaces the keyboard bindings with defaults (WASD/IJKL); the
  overlay sets `mode = 0` (manual).
- Rice has texture inaccuracies (e.g. Super Mario 64's file-select icons) and
  renders the PAL Ocarina of Time framebuffer incorrectly, one reason Ocarina
  of Time uses Ship of Harkinian.

### Ship of Harkinian (Ocarina of Time)

The working build is `soh-raspberry-pi.AppImage` from
`soh-raspberry-pi-0.0.2.zip`, not an official HarbourMasters release: the
installer checks its SHA-256 and takes it from `~/.cache/d2k/downloads/` or
`--soh-zip`. Overlay: `shipwright/shipofharkinian.json`,
`shipwright/keyboard.json`.

- SoH reads `oot.o2r` and its settings from its own directory, so the launcher
  starts it there; `install.sh` links `oot.z64` to the library ROM and SoH
  extracts `oot.o2r` on first launch. It supports Ocarina of Time only.
- Building it from source needs `-DUSE_OPENGLES=ON` and throttles above two
  build jobs.
- Its keyboard mapping IDs contain the key (`P0-B32768-KB80`), so a merge
  would leave old keys bound; `configure-emulators.sh` replaces all port-1
  keyboard mappings. Its default put the C-buttons on the arrows and the stick
  on WASD.
- SoH's own fullscreen (`Window.Fullscreen.Enabled`) is off: SDL puts it
  on X display 0, which Xwayland made the lower DSI panel, and it snapped back
  there each time the launcher moved it up (the game flickered on both
  panels). Windowed, the launcher makes it fullscreen on the upper panel
  like every other single-screen emulator.
- Audio: see [`platform.md`](platform.md#emulators-that-bypass-or-break-pipewire).
- `LowResMode = 1` renders 4:3 at N64 resolution (pillarboxed on 16:9);
  `InterpolationFPS = 20` is the original rate, and the Pi has room for 30 or
  60.

## PS1 (DuckStation)

DuckStation AppImage, native resolution, its own 50 ms audio buffer with
time-stretching. Overlay: `duckstation/settings.ini`.

- **Alt+F4 seemed ignored:** `ConfirmPowerOff = true` opened a dialog behind
  the fullscreen game. The overlay sets it to `false`.
- DuckStation renders in a separate window (`RenderToSeparateWindow`) and
  hides its main window while running.

The lightest console measured (8% CPU, 8% GPU): `ResolutionScale` or PGXP could
go up if a sharper or steadier picture is wanted.

## GameCube (Dolphin)

Dolphin from Debian, JIT ARM64, dual core, OpenGL. Overlay:
`dolphin/Dolphin.ini`, `dolphin/GCPadNew.ini`.

- **Hang after `GFX FIFO: Unknown Opcode`:** dual core without GPU sync desyncs
  on the Pi. `[Core] SyncGPU = True` keeps most of the dual-core speed. If a
  game still desyncs, disable dual core for that game only.
- **Every key ignored after a fast boot.** With warm caches Dolphin booted in
  about a second and the launcher focused its render window at once. X
  reported it active, but Dolphin's own focus tracking missed it and it read
  no keys, Start included; re-activating did not help. `[Input]
  BackgroundInput = True` makes it read keys regardless.
- **A little sound stutter** with no PipeWire underruns: Dolphin's mixer ran
  dry on short speed dips. `[DSP] AudioStretch = True`.
- **Stop without confirmation:** `[Interface] ConfirmStop = False`.
- Keys are named by base X keysym (`KP_Up` for numpad 8, whatever Num Lock
  says).

## 3DS (Azahar)

Azahar Flatpak, Vulkan, 1x resolution, SPIR-V shader generation, hardware
vertex shading, asynchronous shader compilation, disk shader cache. Overlay:
`azahar/qt-config.ini`. The Pi's heaviest console; on Super Mario 3D Land it
runs smoothly once warm, with one open bug.

- **Freezes: Vulkan pipeline compilation.** Two `Pipeline worker` threads at
  100% while `EmuThread` waits on a futex: V3DV builds pipelines slowly and
  the game blocks until each exists. The Mesa shader cache
  (`~/.var/app/org.azahar_emu.Azahar/cache/mesa_shader_cache`) makes a game
  smooth after a few sessions; new levels and games compile again.
- **Black shadow columns (open).** Every object casts a solid black column down
  to the ground: the game's shadow pass is drawn instead of darkening the
  floor. Azahar logs `VK_EXT_fragment_shader_interlock unavailable`, but it
  does not need that extension: without it, its shader generator updates the
  shadow buffer with an `imageAtomicCompSwap` loop, and V3DV reports
  `fragmentStoresAndAtomics`. So that fallback, or V3DV's storage-image
  atomics, is the likely failure. Mesa implements the interlock extension only
  in anv, radv, lavapipe and venus, so PanVK (ROCK 4D) would use the same
  fallback. Settings tried, all reverted:
  - `spirv_shader_gen=false` (GLSL generation): the game sat on its title
    screen for over 4 minutes, both pipeline workers at 100%.
  - `use_hw_shader=false` (software vertex shading): spikes unchanged, so not
    vertex precision. It removed pipeline compiling entirely but put
    `EmuThread` at 99% with a lower frame rate.
  - OpenGL (`graphics_api=1` plus `MESA_GL_VERSION_OVERRIDE=4.3`): the ARM64
    Flatpak has no OpenGL renderer compiled in ("Unknown or unsupported
    graphics API 1, falling back to available default"); using it would mean
    building Azahar from source.
  - Software renderer (`graphics_api=0`): four `SwRenderer` threads (~2.5
    cores), far lower frame rate, both 3DS screens drawn in each window.
- **Sound breaks.** The output ran at 204 samples and underran; Azahar also
  opened the microphone (`input_type=0`, Auto). Azahar joined the
  `pipewire-pulse` floor and `[Audio] input_type=1` (Null) closes the
  microphone. Verified: 699 samples at Azahar's rate (21 ms), 0 underruns.
- Changing `graphics_api` needs `graphics_api\default=false`, and Azahar
  closed first.
- Azahar rewrites its analog-stick bindings in its own notation (a per-key
  prefix list); the overlay stores that notation so `--check` stays clean.
- Text entry and choice screens open an Azahar dialog and pause the game until
  answered. A title screen waiting for input looks frozen: compare frames
  only after pressing a button.
- One launch after a screen swap showed a black upper window; relaunching
  fixed it. If it recurs, check whether emulation is stalled (identical
  frames, no CPU drop) before changing settings.

Alternatives: the Citra forks (AzaharPlus and others) share Azahar's renderer
and its problems; Panda3DS is the only independent 3DS emulator and has no
known ARM64 Linux build. On another board, run the same Super Mario 3D Land
scene and compare screenshots (on Rockchip, with both PanVK and the Mali
proprietary driver).
