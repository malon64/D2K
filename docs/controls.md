# D2K controls (keyboard, mouse, touch)

One control scheme for every console, for a French AZERTY keyboard with a
number pad. Buttons are mapped **by position**: the numpad forms the DS button
diamond, and each console gets whichever button sits at that position on its
own pad.

```text
  numpad        DS / 3DS     PlayStation    Dreamcast     GameCube
  7  8  9      L   X   R    L1  △  R1     LT  Y  RT     L  Y  R
  4     6      Y       A    □       ○    X       B     B     X
  1  2  3      ZL  B  ZR    L2  ✕  R2     -   A   -     -  A  Z
```

| Key | DS / 3DS | PS1 / PSP | Dreamcast | GameCube | N64 / Ocarina of Time |
| --- | --- | --- | --- | --- | --- |
| Arrows | D-pad | D-pad | D-pad | Main stick | Stick |
| Numpad 8 (top) | X | Triangle | Y | Y | – |
| Numpad 4 (left) | Y | Square | X | B | B |
| Numpad 6 (right) | A | Circle | B | X | – |
| Numpad 2 (bottom) | B | Cross | A | A | A |
| Numpad 7 / 9 | L / R | L1 / R1 (PSP: L / R) | L / R triggers | L / R | L / R |
| Numpad 1 / 3 | 3DS ZL / ZR | PS1 L2 / R2 | – | – / Z | Z / – |
| Enter | Start | Start | Start | Start | Start |
| Backspace | Select | Select | – | – | – |
| I J K L | 3DS circle pad | Analog stick | Analog stick | C-stick | C-buttons |
| T F G H | 3DS C-stick | – | – | D-pad | D-pad |
| Mouse, touch screen | DS / 3DS touch screen (lower panel) | – | – | – | – |
| Super+Esc | Leave the game (all consoles) | | | | |

Menus: arrows, Enter and the touch screen drive the Pegasus menu.

Emulator extras kept from their defaults: Flycast Tab (menu), Space
(fast-forward), F12 (screenshot).

**Num Lock must be on.** With it off, the numpad sends arrow codes and several
emulators read numpad 8/4/6/2 as the D-pad. `configure-desktop.sh` sets
`<numlock>on</numlock>` in Labwc, which applies at login; if the numpad ever
behaves like arrows, press Num Lock.

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
