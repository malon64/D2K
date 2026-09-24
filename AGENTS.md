# AGENTS.md

Context for coding agents working on D2K. Read this first, then the linked docs.

## What D2K is

D2K is a dual-screen retro console: a [Pegasus Frontend](https://pegasus-frontend.org)
theme (`pegasus/themes/d2k/`) plus launch scripts, targeting a **Raspberry Pi 5**
running Raspberry Pi OS 64-bit (Trixie, Labwc/Wayland). The theme has two
800x480 panels:

- **Upper panel**: non-interactive showcase (console art, game art, telemetry).
- **Lower panel**: the touch menu (console selector, game grid, music player).

Collections: DS, Dreamcast, PS1, PSP, N64, GameCube, 3DS, and Music (MPD).
The theme and the Windows scripts are developed on a Windows PC; the Pi is the
real device.

## Repository map

| Path | Contents |
| --- | --- |
| `pegasus/themes/d2k/` | The QML theme. `theme.qml` owns the two windows and screen placement. |
| `scripts/windows/` | Windows preview: `run.ps1`, `launch-emulator.ps1`, `mpd.ps1`. |
| `scripts/linux/` | Pi/Linux: `install.sh`, `configure-desktop.sh`, `configure-emulators.sh`, `run.sh`, `launch-emulator.sh`, `mpd.sh`, `telemetry.sh` (HUD battery, CPU, temperature), `smoke-test.sh`, shared `lib.sh`. |
| `docs/emulator-configs/{windows,linux}/` | Per-emulator config overlays (only the keys D2K needs). |
| `docs/raspberry-pi-struggles.md` | Every Pi problem met so far and its fix. **Read before changing Pi behaviour.** |
| `docs/linux-struggles.md` | Linux-generic porting notes. |
| `docs/pegasus-development.md` | Theme development notes. |
| `library/` | **Private, git-ignored** ROMs, art and metadata. Never commit it. |

## Raspberry Pi access

- SSH: `ssh alex@192.168.1.66` (key authentication from the Windows PC; user
  `alex` has passwordless `sudo`).
- Repository on the Pi: `~/D2K` (git clone of `origin`; `library/` is synced
  one way from Windows with `rsync`, see README).
- Installed software: `~/.local/opt/d2k/` (pegasus, melonds, duckstation,
  flycast, mupen64plus, shipwright). Flatpaks (user): Azahar, PPSSPP. Dolphin
  comes from Debian.
- Build sources and downloads: `~/.cache/d2k/` (the Ship of Harkinian zip lives
  in `~/.cache/d2k/downloads/`; it is not downloadable from an official source).
- Runtime state: `~/.local/state/d2k/` (`launch-<console>.log`, `home-request`,
  `mpd/`).
- Pi-local config written by the scripts: `~/.config/kanshi/config` (screen
  layout), `~/.config/labwc/rc.xml` (touch mapping, melonDS rule, Super+Esc),
  `~/.config/wireplumber/wireplumber.conf.d/50-d2k-audio.conf` (TV audio),
  `~/.config/autostart/d2k.desktop`.

## Current hardware wiring

| Role | Device | Connection | Desktop output |
| --- | --- | --- | --- |
| Upper panel + sound | Samsung TV, 1920x1080 | HDMI0 | `HDMI-A-1`, position `0,0` |
| Lower touch panel | Waveshare 5" HDMI LCD, 800x480 | HDMI1 for video, micro-USB **Touch** port to a Pi USB port for power + touch | `HDMI-A-2`, position `560,1080`, CVT mode |

The Pi has no fan yet and throttles under load; an Active Cooler is recommended.
Screen roles are set in `configure-desktop.sh` (`D2K_UPPER_OUTPUT`,
`D2K_LOWER_OUTPUT`, modes, touch device); the theme and launcher follow the
top-to-bottom desktop layout automatically. Emulator choice per console is in
`docs/emulator-configs/README.md`.

## Working on the Pi remotely

SSH is not the desktop session. Export the session variables first (or source
`scripts/linux/lib.sh` and call `use_desktop_session`):

```bash
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-0 DISPLAY=:0
wlr-randr                                            # outputs and positions
grim -o HDMI-A-1 /tmp/upper.png; grim -o HDMI-A-2 /tmp/lower.png   # screenshots (scp them back to look)
xdotool search --onlyvisible --name . getwindowname %@
pactl list short sinks; pactl get-default-sink       # audio
vcgencmd measure_temp; vcgencmd get_throttled        # heat
```

- **Start D2K from SSH** fully detached, or it dies with the SSH session:
  `cd ~/D2K && setsid nohup ./scripts/linux/run.sh > /tmp/d2k-run.log 2>&1 < /dev/null &`
  (normally it starts from the Labwc autostart entry).
- **Stop D2K**: `pkill -TERM -f '[s]cripts/linux/run.sh'` (its cleanup kills
  Pegasus and stops MPD). Pegasus catches SIGTERM and keeps running, so
  `pkill -x pegasus-fe` alone does nothing; check `pgrep -x pegasus-fe` before
  starting a new copy.
- **Launch a game for testing**:
  `./scripts/linux/launch-emulator.sh <ds|dreamcast|ps1|psp|n64|gamecube|3ds> "$PWD/library/consoles/<console>/games/<game>/rom.<ext>"`
- **Leave a game**: `touch ~/.local/state/d2k/home-request` (what Super+Esc does).
  The launcher stops the emulator's whole process group and resumes the music.
- The user may be looking at or playing on the screens. Say before you launch,
  close or restart anything, and do not close a game they are playing.

## Deploying and testing changes

1. Edit in the Windows working copy, commit and push.
2. On the Pi: `cd ~/D2K && git pull` (or copy single files: `scp` to a temp
   name, then `mv` over the old file; see traps below).
3. Re-run what changed: `./scripts/linux/install.sh` (idempotent, skips built
   software), or just `configure-desktop.sh` / `configure-emulators.sh`.
4. `./scripts/linux/smoke-test.sh` (self-tests, config checks, MPD test).
5. Verify on the real screens: screenshots with `grim`, window geometry with
   `xdotool`, sound with `pactl list sink-inputs`, and the launch log.

## Traps that already cost time

- `pkill -f PATTERN` / `pgrep -f` over SSH also match the SSH command line that
  contains PATTERN, killing your own shell. Use `pgrep -x NAME`, or a pattern
  like `[p]egasus` that does not match its own text, and keep the plain text
  (e.g. `./scripts/linux/run.sh`) out of that same SSH command.
- Overwriting a running bash script in place corrupts the running copy (bash
  reads scripts while executing). `run.sh` and `launch-emulator.sh` are usually
  running: write a new file and `mv` it into place.
- Emulators persist settings on their own: Mupen64Plus saves command-line plugin
  choices (a test with `--audio dummy` silenced every later game), Ship of
  Harkinian writes `AudioBackend: null` after an audio error, melonDS rewrites
  its TOML on exit, Azahar rewrites `\default` flags. Undo test changes.
- Alt+F4 can close Pegasus itself; use Super+Esc / `home-request`.
- All N64 ROMs in the library are PAL (50 Hz): a "low frame rate" there can be
  the original game speed, not the Pi. Check the emulator's CPU use and whether
  its main thread sleeps in its speed limiter before tuning.
- ares renders N64 black on the Pi and was removed; do not reintroduce it
  there. Windows still uses ares.

## Conventions

- Match the surrounding style: bash with `set -euo pipefail`, small functions,
  comments that explain *why* (usually a Pi quirk, with a pointer to the docs).
- Record every new Pi problem and its fix in `docs/raspberry-pi-struggles.md`.
- Emulator config changes go into the overlays in `docs/emulator-configs/`,
  never only into the Pi's live files.
