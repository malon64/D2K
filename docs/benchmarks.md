# Benchmarks

How each console's games actually run, measured while playing. Kept so the
same games can be measured after emulator or settings changes, and on the
Radxa ROCK 4D, which replaces the Pi only if it is measurably better
([`../AGENTS.md`](../AGENTS.md#project-context-from-notion)). The problems and
fixes behind each verdict are in [`emulators.md`](emulators.md).

## Method

Measure over SSH while the game is being played, without pausing or touching
the emulator. Sample a busy scene (racing, combat, open area), not a menu.

```bash
P=$(pgrep -x <emulator-process> | head -1)
top -H -b -d 3 -n 2 -p $P | awk '/^top -/{n++} n==2' | sed -n '7,14p'   # per-thread CPU
g=/sys/class/drm/card0/device/gpu_stats                                # V3D busy time (ns)
a=$(awk '/^render/{print $4}' $g); sleep 3; b=$(awk '/^render/{print $4}' $g)
echo "GPU render busy: $(( (b - a) / 30000000 ))%"
pw-top -b -n 2                                                         # audio: QUANT and ERR per stream
vcgencmd measure_clock arm; vcgencmd measure_temp; vcgencmd get_throttled
cat /sys/class/hwmon/*/fan1_input                                      # fan rpm
```

How to read it:

- **Emulation thread %CPU** is the number that matters: emulators run the
  console on one thread, so it is at its limit near 100% even when the other
  cores are idle.
- **GPU render busy** is the share of time the GPU spent rendering. It
  includes the compositor, which scales the game windows.
- **Audio ERR** (underruns) should stay near 0; see
  [`platform.md`](platform.md#emulators-need-a-larger-audio-buffer).
- **`get_throttled`** must be `0x0`; otherwise heat or power limited the run
  and the numbers are not comparable.
- **Frame rate:** not every emulator shows it. Mupen64Plus does (VI/s in the
  window title with `ShowFPS`); otherwise record the player's impression and
  say so. Low CPU with a sleeping main thread is not proof of full speed.
- Do not run commands that start an emulator binary (such as `--version`)
  during a session: some open a second instance on the screens.

## Raspberry Pi 5 (October 2026)

Raspberry Pi 5, 8 GB, Raspberry Pi OS 64-bit (Trixie), Labwc, official Active
Cooler. Upper panel: desk monitor at 1920x1080; lower panel: Waveshare 5"
HDMI 800x480. Emulators and settings as described in
[`emulators.md`](emulators.md). All runs on 2026-10-01; figures are after the
fixes listed in the verdict.

| Console | Game | Busiest thread | Other threads | GPU busy | Audio | Temp, throttled | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Dreamcast | Sonic Adventure (USA, Rev A) | 20% | main 6% | ~23% | not measured | 48.8 °C, `0x0` | Plays well |
| DS | Mario Kart DS | 77% in races, 50–59% in menus (emulation) | soft 3D 60%, UI 41%, Xwayland 55% | ~66% | 0 ERR after the audio fixes (31 in 5 min before) | 56.0 °C, `0x0` | Works well |
| PSP | Midnight Club 3: DUB Edition | 21–24% (emulation) | Vulkan 12–18% | 48–85% by scene | 0 ERR after the fix (13 in 1.5 min before) | 51–52 °C, `0x0` | Plays well (window fix too) |
| PS1 | Crash Bandicoot (Europe) | 8% | video 7% | ~8% | 0 ERR | 48.8 °C, `0x0` | Smooth, lightest console |
| N64 | Super Mario 64 (PAL) | 12% (was 3–6%, asleep) | audio 3% | ~12% | 0 ERR | 45.5 °C, `0x0` | Smooth at **50.0 VI/s** after `AUDIO_SYNC = False` (~40 VI/s before) |
| N64 | Ocarina of Time (PAL), Ship of Harkinian | 16% | 2% | ~7% | 0 ERR | ~49 °C, `0x0` | Plays fine |
| GameCube | Mario Kart: Double Dash!! (USA, 60 fps) | 58% in a race (video thread) | CPU thread 35% | ~68% in a race | 0 ERR; small stutter fixed by time-stretching | 53–54 °C, `0x0` | Works after the control fixes; speed not measured |
| 3DS | Super Mario 3D Land | 40% (EmuThread), with a warm shader cache | Vulkan 37% | ~74% | 0 ERR after the fix (56 and rising before) | 55 °C, `0x0` | Smooth once the cache is warm; **black shadow columns** remain |

Notes:

- **3DS before the shader cache was warm:** two `Pipeline worker` threads at
  ~97–100% from launch, EmuThread 40% then waiting, GPU ~50%, temperature up to
  59 °C, and a freeze at 2 min 49 s.
- **ARM clock:** 2.4 GHz in the Dreamcast and DS sessions; 1.7–2.4 GHz in
  the PSP sessions, because the `ondemand` governor lowers it under light
  load.
- **Heaviest loads:** CPU, the DS emulation thread (77%); GPU, the PSP's peak
  (85%) and the 3DS (74%). Every other console has large headroom.

## Next measurements

- Repeat the same games on the ROCK 4D, with the same method, after porting
  the platform ([`platform.md`](platform.md#another-board-rock-4d)). For the
  3DS, run the same Super Mario 3D Land scene with both PanVK and the Mali
  proprietary driver and compare screenshots of the shadows.
- Repeat a console's game after any change to its emulator or settings.
