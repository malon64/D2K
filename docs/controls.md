# D2K controls (keyboard, gamepad, touch)

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
| Super+Esc (pad: Home) | Leave the game (all consoles) | | | | |

## D2K Controls gamepad (ESP32-S3)

The console's own buttons are a USB HID gamepad, "D2K Controls" (ESP32-S3,
`firmware/esp32-controls/`, SDL GUID `03007f933a3000000110000011010000`). It
sends A/B/X/Y **by label** (A = `BTN_A`), the D-pad as a hat, L1/R1 as
buttons 6/7, L2/R2 as buttons 8/9 plus the Z/RZ trigger axes, Select 10,
Start 11. **Home is not a gamepad button**: the same USB device also has a
keyboard interface, and Home types Super+Esc on it, so it leaves the game
exactly like the keyboard shortcut, in every emulator, without any binding
(and no emulator can open its own menu on a Guide button). SDL recognises the pad as a game controller with an automatic
mapping. It drives the same functions as the keyboard scheme above, and the
keyboard keeps working, except in Azahar.

| Pad | DS | 3DS (Azahar) | PS1 / PSP | Dreamcast | GameCube | N64 |
| --- | --- | --- | --- | --- | --- | --- |
| D-pad | D-pad | D-pad | D-pad | Analog stick | Main stick | Stick |
| A (right) / B (bottom) | A / B | A / B | Circle / Cross | B / A | A / B | A / B |
| X (top) / Y (left) | X / Y | X / Y | Triangle / Square | Y / X | X / Y | – |
| L1 / R1 | L / R | L / R | L1 / R1 (PSP L / R) | L / R triggers | L / R | L / R |
| L2 / R2 | – | ZL / ZR | PS1 L2 / R2 | L / R triggers | – / Z | Z / – |
| Start / Select | Start / Select | Start / Select | Start / Select | Start / Flycast menu | Start | Start |

- **Azahar keeps one binding per button**, so its buttons are on the pad and
  the numpad no longer drives 3DS buttons (the circle pad / C-stick keys stay).
- The D-pad drives the GameCube and N64 sticks until the Circle Pads are
  fitted; N64 C-buttons are keyboard-only for now (I J K L).
- Flycast's default pad mapping comes from SDL: ABXY by label and the D-pad
  on the D-pad. D2K replaces it with `flycast/mappings/SDL_D2K Controls.cfg`;
  Select still opens Flycast's menu (useful, like Tab on the keyboard).
- Ship of Harkinian's default pad mapping put the D-pad on the N64 D-pad
  (Ocarina's menus and movement need the stick) and R on R2.
  `shipwright/gamepad.json` replaces its SDL mappings: the D-pad and the left
  stick drive the stick, R1 = R, L2 = Z, C-buttons on the right stick.

## Menus (Pegasus)

The D2K menu uses the same keys: D-pad or left stick to move, A to
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

**The numpad always sends digits.** With Num Lock off it sends `KP_Up/…` and
Qt emulators read numpad 8/4/6/2 as the D-pad (DS face buttons dead, arrows
fine). Turning Num Lock on was not enough: Labwc (keyboard LED,
`/sys/class/leds/*numlock*`) and Xwayland (`xset q`) were seen reporting
opposite states, and one press of Num Lock broke it again. So
`configure-desktop.sh` adds the XKB option `numpad:mac` to
`~/.config/labwc/environment` (`XKB_DEFAULT_OPTIONS`; numpad = digits whatever
Num Lock says) and also sets Num Lock on. Labwc reads that file at login, not
on `labwc --reconfigure`; after a reboot, `xmodmap -pke | grep "keycode  80 "`
on `:0` no longer lists `KP_Up`. `xdotool` key presses go through X's own lock
state, so test numpad bindings on the real keyboard.

## Where each binding lives

The scheme is applied by `scripts/linux/configure-emulators.sh` from the overlays
in `docs/emulator-configs/linux/`. Emulators disagree on how they name keys:
some store the character a key produces (so AZERTY letters are what you see on
the keycap), others store the physical key position (named after the QWERTY
keycap in that position).

| Emulator | Overlay | Key encoding |
| --- | --- | --- |
| melonDS (DS) | `melonds/keyboard.toml` → `melonDS.toml [Instance0.Keyboard]` and `[Instance0.Joystick]` | Qt key code; numpad keys carry `Qt::KeypadModifier` (numpad 8 = `0x20000038`). Pad: SDL button number, hat = `0x100` + direction (up 257, right 258, down 260, left 264) |
| Azahar (3DS) | `azahar/qt-config.ini [Controls]` | Qt key code without modifier (numpad 8 = `56`); every key needs `\default=false` or Azahar ignores it. Pad: `button:N,engine:sdl,guid:…,port:0`, hat `direction:up,…,hat:0` |
| DuckStation (PS1) | `duckstation/settings.ini [Pad1]` | Physical position: `Keyboard/Numpad8`, `Keyboard/UpArrow`, `Keyboard/I`. Pad: a second line per button, `SDL-0/A`, `SDL-0/DPadUp`, `SDL-0/+LeftTrigger` |
| PPSSPP (PSP) | `ppsspp/controls.ini` | `1-<Android keycode>`: numpad 1…9 = 145…153, Enter 66, Backspace 67. Pad: `10-<code>`, SDL a/b/x/y = 189/190/191/188, Back 196, Start 197, L1/R1 194/195 |
| Flycast (Dreamcast) | `flycast/mappings/SDL_Keyboard.cfg` and `SDL_D2K Controls.cfg` (whole files) | SDL scancode (position): numpad 1…9 = 89…97. Pad: raw SDL button number, hat = `(hat + 1) << 8` + direction (up 256, down 257, left 258, right 259) |
| Dolphin (GameCube) | `dolphin/GCPadNew.ini` | X11 base keysym: numpad 8 = `KP_Up`, 7 = `KP_Home`, 3 = `KP_Next` (independent of Num Lock). Pad: OR-ed in with a device-qualified input, `` `KP_Right` \| `SDL/0/D2K Controls:Button S` `` |
| Mupen64Plus (N64) | `mupen64plus/mupen64plus.cfg [Input-SDL-Control1]` | SDL 1.2 keysym: numpad 1…9 = 257…265, arrows 273–276. Pad: `device = 0`, then `button(N)` / `hat(0 Left Right)` after the key in the same value |
| Ship of Harkinian | `shipwright/keyboard.json` and `gamepad.json` (each rewrites its own kind of port-1 mappings) | PC scancode: numpad 7/8/9 = 71/72/73, arrows = 0x100 + code. Pad: SDL game controller input, `B11` a button (D-pad up), `A4+` an axis direction |

To change a key: edit the overlay, run `./scripts/linux/configure-emulators.sh`
on the Pi (with the emulator closed, since most save their config on exit),
then `--check`. Keep this table and the overlays in sync.

Emulator defaults hid conflicts with this scheme, all overridden by the
overlays: PPSSPP bound Rewind to Backspace (Select here), DuckStation and
Mupen64Plus defaulted to WASD/IJKL, and Ship of Harkinian put the C-buttons
on the arrows and the stick on WASD. Per-emulator control problems (melonDS
with no keys, Mupen64Plus' automatic mode, Ship of Harkinian's mapping IDs,
Dolphin ignoring keys after a fast boot) are in [`emulators.md`](emulators.md).
