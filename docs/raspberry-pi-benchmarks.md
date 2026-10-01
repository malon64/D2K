# Raspberry Pi 5 game benchmarks

How each console's games actually run on the Pi 5, measured while playing.
Kept so the same games can be measured on the Radxa ROCK 4D (see AGENTS.md:
it replaces the Pi only if it is measurably better) and after emulator or
settings changes.

## Setup

- Raspberry Pi 5, 8 GB, Raspberry Pi OS 64-bit (Trixie), Labwc/Wayland.
- Official Active Cooler (SC1148), fan curve left at firmware defaults.
- Upper panel: desk monitor at 1920x1080; lower panel: Waveshare 5" HDMI
  800x480 (see AGENTS.md, "Current hardware wiring").
- Emulators from `scripts/linux/install.sh`, settings from
  `docs/emulator-configs/linux/`.

## Method

Measure over SSH while the game is being played, without pausing or touching
the emulator. Sample in a busy scene (racing, combat, open area), not a menu.

```bash
P=$(pgrep -x <emulator-process> | head -1)
top -H -b -d 3 -n 2 -p $P | awk '/^top -/{n++} n==2' | sed -n '7,14p'   # per-thread CPU
g=/sys/class/drm/card0/device/gpu_stats                                # V3D busy time (ns)
a=$(awk '/^render/{print $4}' $g); sleep 3; b=$(awk '/^render/{print $4}' $g)
echo "GPU render busy: $(( (b - a) / 30000000 ))%"
vcgencmd measure_clock arm; vcgencmd measure_temp; vcgencmd get_throttled
cat /sys/class/hwmon/*/fan1_input                                      # fan rpm
```

How to read it:

- **Emulation thread %CPU** is the number that matters: emulators run the
  console on one thread, so it is at its limit near 100% even when the other
  three cores are idle.
- **GPU render busy** is the share of time the V3D spent rendering over the
  sample. It includes the compositor, which scales the game windows.
- **`get_throttled`** must be `0x0`; any other value means heat or power
  limits, and the numbers are not comparable.
- Frame rate is not exposed by every emulator while it runs. When it is not,
  record the player's impression and say so; do not infer an exact FPS.
- N64 ROMs in the library are PAL (50 Hz): see AGENTS.md before calling one
  slow.

Do not run commands that start the emulator binary (such as `--version`)
during a session: some of them open a second instance on the screens.

## Results

| Date | Console | Game | Emulator, key settings | Busiest thread | Other threads | GPU busy | Temp / throttled | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-10-01 | Dreamcast | Sonic Adventure (USA, Rev A) | Flycast, defaults (OpenGL, native 640x480, threaded rendering) | 20% | main 6%, audio <1% | ~23% | 48.8 °C, fan ~2970 rpm / `0x0` | Plays well (player). Large headroom: the internal resolution could go up if a larger screen needs it |
| 2026-10-01 | DS | Mario Kart DS | melonDS, JIT on, software 3D renderer (threaded), `UseGL = false`, window through Xwayland | 77% in races, 50–59% in menus (emulation) | soft 3D 60%, main/UI 41%, Xwayland 55% | ~66% | 56.0 °C, fan ~3000 rpm / `0x0` | First session: brief sound cuts and some missed A presses in menus. After the audio fixes (DS notes): everything works well (player), 0 audio underruns |
| 2026-10-01 | PSP | Midnight Club 3: DUB Edition | PPSSPP (Flatpak), Vulkan, internal resolution 2x (960x544), 4x anisotropic, `AudioBufferSize = 256`, no extra audio buffering | 21–24% (emulation) | Vulkan render 12–18% | 48–85% depending on the scene | 51–52 °C / `0x0` | First session: pretty playable, but glitchy sound (13 underruns in 1.5 min, 2.7 ms buffer) and the game opened on the lower panel. After the audio and window fixes (PSP notes): plays well on the upper panel, 0 underruns in 2 min 40 s (player: good) |
| 2026-10-01 | PS1 | Crash Bandicoot (Europe) | DuckStation, renderer Automatic, native resolution (1x), nearest filtering, no PGXP, CPU thread on; audio Cubeb, 50 ms buffer, 20 ms output latency, time-stretch | 8% (CPU thread) | video thread 7% | ~8% | 48.8 °C / `0x0` | Very light: the lightest console measured. Placed on the upper panel automatically; audio stream 275 samples at 44.1 kHz, 0 underruns in 1 min. Smooth, no problems (player) |
| 2026-10-01 | N64 | Super Mario 64 (PAL) | Mupen64Plus, Rice video plugin (desktop GL), SDL audio, HLE RSP | 3–6% (main thread, asleep) → 12% after the fix | SDL audio 3% | ~12%, ~21 render jobs/s | 45.5 °C / `0x0` | Player: low frame rate and stuttering sound. Rice's VI/s counter showed **~40 of 50 VI/s** (80% speed) with `AUDIO_SYNC = True`, though the CPU idled. With `AUDIO_SYNC = False`: **50 VI/s**, 0 underruns (N64 notes); the player finds it smooth now. The PAL ROM still caps the game at 25 fps |

The ARM clock stayed at 2.4 GHz in the Dreamcast and DS sessions. In the PSP
sessions it varied between 1.7 and 2.4 GHz: the `ondemand` governor lowers it
when the CPU is lightly loaded.

## Notes per console

### Dreamcast

Flycast barely loads the Pi in Sonic Adventure. D2K's overlay only sets the
window options, so every renderer setting is Flycast's default.

### DS

DS is the absolute priority and the heaviest load measured so far: about
2.3 cores in total. The emulation thread is the limit to watch. Before tuning,
check:

- `[3D] Renderer = 0` (software) with `[3D.Soft] Threaded = true`: the 3D
  thread is the 60% "QThread".
- The GPU load is mostly the compositor and Xwayland scaling the window to
  640x480 (x2.5), not melonDS rendering.
- melonDS's OpenGL renderer (`Renderer = 1`, `[Screen] UseGL = true`) could
  move work from the CPU to the V3D. It has not been tested on the Pi.

**Sound cutting out (2026-10-01, Mario Kart DS).** `pw-top` counted 31
underruns (`ERR`) on the melonDS stream and the HDMI sink in 5 minutes of
play, in bursts (none during a quiet 20 s window). PipeWire's default buffer
is 1024 samples, but melonDS's SDL stream pulls the graph down to 256 samples
(5.3 ms at 48 kHz), so any short stall in the emulator or the compositor is
an audible gap. Fix applied the same day: `launch-emulator.sh` starts melonDS
with `PULSE_LATENCY_MSEC=40` and `PIPEWIRE_LATENCY=2048/48000` (~40 ms, on
whichever audio API SDL uses). The player heard a clear improvement, but
`pw-top` showed why it was not complete: melonDS goes through the PulseAudio
API, 40 ms became a 480-sample request, PipeWire rounded the graph down to
256 again, and melonDS still logged ~6–10 underruns a minute. Second fix:
`configure-desktop.sh` adds a `pipewire-pulse` rule
(`50-d2k-emulator-audio.conf`, `pulse.min.quantum = 1024/48000`) so the graph runs
at 1024 samples (21 ms) while melonDS plays. To verify: during a DS game,
`pw-top` shows QUANT 1024 on the HDMI sink and the melonDS `ERR` count stays
near 0. Verified the same day on Mario Kart DS: QUANT 1024 on both the sink
and melonDS, 0 underruns after 1.5 minutes of play.

**A button sometimes not recognised in the game menus.** Seen in the first
session only; after the audio fixes the player reported every press working.
Probably the same stalls: melonDS samples the keys once per emulated frame, so
a very short tap during a stall can be missed. If it comes back, watch the raw
key events while pressing numpad 6 (`sudo libinput debug-events | grep KP6`):
one `pressed` per tap means the keyboard is fine and the emulator lost it.

**Background work during a game.** `run.sh` kept its once-a-second loop
running while a game played: HUD telemetry and `mpd.sh Status`, which starts
`mpc` and a fresh `python3` to write `mpd-status.json`, all unread until the
menu comes back (python seen in 4 of 50 samples). Fixed the same day: the
launcher writes its PID to `~/.local/state/d2k/game-running` and `run.sh`
skips that work while the PID is alive.

### PSP

PPSSPP is GPU-bound on the Pi, not CPU-bound: in Midnight Club 3 the V3D was
48–85% busy depending on the scene, while the emulation thread used 21–24% of
a core. The levers are
`InternalResolution` (2 = 960x544, already above the 800x480 panel) and
`AnisotropyLevel` (4); lowering either should free GPU time if a game slows
down.

PPSSPP's audio runs with the smallest buffer seen so far (118 samples at
44.1 kHz, 2.7 ms: `AudioBufferSize = 256`, `ExtraAudioBuffering = False`)
and underran ~9 times a minute. The player heard no cuts but glitchy sound at
times: with `FillAudioGaps = True`, PPSSPP patches each gap instead of going
silent. Fix applied the same day, both halves of the melonDS one:
`ExtraAudioBuffering = True` in `docs/emulator-configs/linux/ppsspp/ppsspp.ini`,
and PPSSPP added to the `pipewire-pulse` rule (`50-d2k-emulator-audio.conf`),
matched by its Flatpak id (`pipewire.access.portal.app_id`) because its
stream carries no application name. Verified the same day: `pw-top` showed
QUANT 941 on `PPSSPPSDL` (the 1024/48000 floor expressed at 44.1 kHz, 21 ms)
and 0 underruns after 2 min 40 s, and the player confirmed the sound is good.

The game also opened on the lower panel: PPSSPP retitles its window to the
running game, so the launcher's title search missed it. The launcher now
finds it by window class (see `docs/raspberry-pi-struggles.md`).

### PS1

DuckStation barely loads the Pi in Crash Bandicoot: 8% of a core and 8% of
the GPU at native resolution. There is room to raise `ResolutionScale` or
turn on PGXP (less wobbly 3D) if a sharper picture is wanted; measure again
after either. Its audio needs no D2K fix: DuckStation keeps its own 50 ms
buffer, so its small PipeWire stream (275 samples) did not underrun.

### N64

Mupen64Plus needs little CPU in Super Mario 64, but the first measurement
was misleading: the main thread used 3–6% of a core and was always asleep
(`hrtimer_nanosleep`), which looked like a speed limiter waiting for the next
frame. The player saw a low frame rate and heard stuttering sound, and Rice's
counter (`[Video-Rice] ShowFPS = True` puts VI/s in the window title) showed
~40 VI/s instead of 50. The sleep was the SDL audio plugin's `AUDIO_SYNC`:
it paces the emulator on its own audio buffer (target 2048 + 1024 samples),
which fought PipeWire's 256-sample graph. The overlay now sets
`[Audio-SDL] AUDIO_SYNC = False`, so the core's VI limiter paces the game:
50.0 VI/s, 12% CPU, 0 underruns over 20 s.

Measure VI/s, not just CPU, before calling an N64 game fast or slow. The PAL
ROMs still make the game run at 25 fps, as on a PAL console; NTSC ROMs would
give 30 fps and the original speed. Ship of Harkinian (Ocarina of Time) is a native port, not emulation,
and still needs its own measurement.

## To measure

Ship of Harkinian (Ocarina of Time),
GameCube (Dolphin) and 3DS (Azahar) have no measurement yet. Favour the
heaviest game of each library.
