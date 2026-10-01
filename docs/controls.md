# D2K controls (keyboard, mouse, touch)

One control scheme for every console, for a French AZERTY keyboard with a
number pad. The numpad forms the DS button diamond. **Nintendo consoles are
mapped by label**, like the DS: A is always numpad 6, B numpad 2, X numpad 8
and Y numpad 4, whatever the button's place on the GameCube or N64 pad, so
"A" is the same key on every Nintendo console (and the D2K menu's A). The
PlayStation and Dreamcast are mapped **by position**: each gets whichever
button sits at that place on its own pad.

```text
  numpad        DS / 3DS     GameCube      N64           PlayStation    Dreamcast
  7  8  9      L   X   R    L   X   R    L   -   R     L1  △  R1     LT  Y  RT
  4     6      Y       A    Y       A    -       A     □       ○    X       B
  1  2  3      ZL  B  ZR    -   B   Z    Z   B   -     L2  ✕  R2     -   A   -
```

| Key | DS / 3DS | PS1 / PSP | Dreamcast | GameCube | N64 / Ocarina of Time |
| --- | --- | --- | --- | --- | --- |
| Arrows | D-pad | D-pad | **Analog stick** | Main stick | Stick |
| Numpad 8 (top) | X | Triangle | Y | X | – |
| Numpad 4 (left) | Y | Square | X | Y | – |
| Numpad 6 (right) | A | Circle | B | A | A |
| Numpad 2 (bottom) | B | Cross | A | B | B |
| Numpad 7 / 9 | L / R | L1 / R1 (PSP: L / R) | L / R triggers | L / R | L / R |
| Numpad 1 / 3 | 3DS ZL / ZR | PS1 L2 / R2 | – | – / Z | Z / – |
| Enter | Start | Start | Start | Start | Start |
| Backspace | Select | Select | – | – | – |
| I J K L | 3DS circle pad | Analog stick | **D-pad** | C-stick | C-buttons |
| T F G H | 3DS C-stick | – | – | D-pad | D-pad |
| Mouse, touch screen | DS / 3DS touch screen (lower panel) | – | – | – | – |
| Super+Esc | Leave the game (all consoles) | | | | |

## Menus (Pegasus)

The D2K menu uses the same positions: D-pad or left stick to move, A to
select, B to go back. The touch screen keeps working alongside.

| Control | Keys | Console carousel | Game grid | Music |
| --- | --- | --- | --- | --- |
| D-pad / left stick | Arrows / I J K L | Previous / next console | Move the selection | ↑↓ one track, ←→ four tracks |
| A | Numpad 6 (also Enter) | Open the console | Launch the game | Play the track, or pause / resume the playing one |
| B | Numpad 2 (also Escape) | – | Back to the carousel | Back to the carousel |
| – | Page Up / Page Down | – | Previous / next page | – |

The keys are handled in `theme.qml` (`handleKey`), from both windows, because a
tap gives the lower window keyboard focus. Numpad keys never move the
selection. Pegasus' own accept and cancel bindings (gamepad A / B) also work.

Emulator extras kept from their defaults: Flycast Tab (menu), Space
(fast-forward), F12 (screenshot).

**The numpad always sends digits.** Otherwise, with Num Lock off, it sends arrow
codes and several emulators read numpad 8/4/6/2 as the D-pad.
`configure-desktop.sh` adds the XKB option `numpad:mac` to
`~/.config/labwc/environment` (numpad = digits whatever Num Lock says) and also
sets Num Lock on. Both apply at the next login or reboot.

## Where each binding lives

The scheme is applied by `scripts/linux/configure-emulators.sh` from the overlays
in `docs/emulator-configs/linux/`. Emulators disagree on how they name keys:
some store the character a key produces (so AZERTY letters are what you see on
the keycap), others store the physical key position (named after the QWERTY
keycap in that position).

| Emulator | Overlay | Key encoding |
| --- | --- | --- |
| melonDS (DS) | `melonds/keyboard.toml` → `melonDS.toml [Instance0.Keyboard]` | Qt key code; numpad keys carry `Qt::KeypadModifier` (numpad 8 = `0x20000038`) |
| Azahar (3DS) | `azahar/qt-config.ini [Controls]` | Qt key code without modifier (numpad 8 = `56`); every key needs `\default=false` or Azahar ignores it |
| DuckStation (PS1) | `duckstation/settings.ini [Pad1]` | Physical position: `Keyboard/Numpad8`, `Keyboard/UpArrow`, `Keyboard/I` |
| PPSSPP (PSP) | `ppsspp/controls.ini` | `1-<Android keycode>`: numpad 1…9 = 145…153, Enter 66, Backspace 67 |
| Flycast (Dreamcast) | `flycast/mappings/SDL_Keyboard.cfg` (whole file) | SDL scancode (position): numpad 1…9 = 89…97 |
| Dolphin (GameCube) | `dolphin/GCPadNew.ini` | X11 base keysym: numpad 8 = `KP_Up`, 7 = `KP_Home`, 3 = `KP_Next` (independent of Num Lock) |
| Mupen64Plus (N64) | `mupen64plus/mupen64plus.cfg [Input-SDL-Control1]` | SDL 1.2 keysym: numpad 1…9 = 257…265, arrows 273–276 |
| Ship of Harkinian | `shipwright/keyboard.json` (rewrites the port-1 keyboard mappings) | PC scancode: numpad 7/8/9 = 71/72/73, arrows = 0x100 + code |

To change a key: edit the overlay, run `./scripts/linux/configure-emulators.sh`
on the Pi (with the emulator closed, since most save their config on exit),
then `--check`. Keep this table and the overlays in sync.
