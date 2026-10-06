"""Generate breadboard_v1.html: the bench wiring guide for D2K V1.

- Breadboard view (2D) of the controls: ESP32-S3-Zero straddling an MB-102
  breadboard, 15 tact switches, 2 Circle Pads, every jumper routed so that no
  two button wires cross, with hole coordinates (column 1-63, row a-j).
- Pi GPIO header view: the WM8960 audio board jumpers (W8) and the 4in DSI
  power lead (W5).
- A wire checklist for each view.
The pin plan comes from gen_d2k_v1_sch.py (BUTTONS, STICKS) and the ESP32 pin
order from gen_d2k_lbr.py, so the page always matches the D2K_V1 schematic.

Run with any Python 3:  python gen_breadboard.py  (writes breadboard_v1.html)
The output is an HTML fragment (title + style + content) as the Artifact
publisher expects; it also opens directly in a browser.
"""

from pathlib import Path
from xml.sax.saxutils import escape

import gen_d2k_lbr as lib
import gen_d2k_v1_sch as sch

# ------------------------------------------------------------ board geometry --
P = 16                     # px per 2.54 mm hole pitch
X0 = 150                   # x of column 1 (room for the USB label)
COLS = 63                  # MB-102: 63 columns, rows a-e / f-j, 4 power rails
LANE = 11                  # spacing of wire lanes above/below the board
N_TOP, N_BOT = 9, 6           # header row d wires above, row h wires below


def cx(col):
    return X0 + (col - 1) * P


Y_TOP_PLUS = 34 + N_TOP * LANE + 18
Y_TOP_MINUS = Y_TOP_PLUS + P
ROW_Y = {r: Y_TOP_PLUS + (3 + i) * P for i, r in enumerate("abcde")}
ROW_Y.update({r: Y_TOP_PLUS + (10 + i) * P for i, r in enumerate("fghij")})
Y_BOT_MINUS = Y_TOP_PLUS + 16 * P
Y_BOT_PLUS = Y_TOP_PLUS + 17 * P
RAIL_COLS = [c for g in range(10) for c in range(3 + 6 * g, 8 + 6 * g)]   # 5-hole groups


def top_lane(k):
    return Y_TOP_PLUS - 16 - (k - 1) * LANE


def bot_lane(k):
    return Y_BOT_PLUS + 16 + (k - 1) * LANE


Y_BLOCKS = bot_lane(N_BOT) + 26

# Wire colours (suggested jumper colours on the bench).
COL = {"gnd": "#23272e", "v33": "#d1343b", "dpad": "#d9a300", "face": "#2e9e5b",
       "sys": "#7b5cc4", "shoulder": "#e0761f", "stick": "#2479b8", "usb": "#6b7785"}
GROUP = {"BTN_DPAD_UP": "dpad", "BTN_DPAD_DOWN": "dpad", "BTN_DPAD_LEFT": "dpad", "BTN_DPAD_RIGHT": "dpad",
         "BTN_A": "face", "BTN_B": "face", "BTN_X": "face", "BTN_Y": "face",
         "BTN_START": "sys", "BTN_SELECT": "sys", "BTN_HOME": "sys",
         "BTN_L1": "shoulder", "BTN_R1": "shoulder", "BTN_L2": "shoulder", "BTN_R2": "shoulder"}
SHORT = {"BTN_DPAD_UP": "UP", "BTN_DPAD_DOWN": "DOWN", "BTN_DPAD_LEFT": "LEFT", "BTN_DPAD_RIGHT": "RIGHT",
         "BTN_A": "A", "BTN_B": "B", "BTN_X": "X", "BTN_Y": "Y", "BTN_START": "START",
         "BTN_SELECT": "SELECT", "BTN_HOME": "HOME", "BTN_L1": "L1", "BTN_R1": "R1",
         "BTN_L2": "L2", "BTN_R2": "R2"}
# Switch slot = left column of the 6x6 switch straddling the centre channel
# (its pins sit in e/f of columns N and N+2). Groups: D-pad, face, system, shoulders.
SLOT = {"BTN_DPAD_DOWN": 15, "BTN_DPAD_UP": 18, "BTN_DPAD_LEFT": 21, "BTN_DPAD_RIGHT": 24,
        "BTN_A": 28, "BTN_B": 31, "BTN_X": 34, "BTN_Y": 37,
        "BTN_SELECT": 41, "BTN_START": 44, "BTN_HOME": 47,
        "BTN_L1": 51, "BTN_R1": 54, "BTN_L2": 57, "BTN_R2": 60}

# ESP32-S3-Zero straddles the channel, USB-C off the left end of the board:
# header row R (R1..R9) in row d, row L (L1..L9) in row h, columns 2..10.
ESP_COL0 = 2
ESP_HOLE = {}
for i, (num, name, _) in enumerate(lib.ESP32_S3_ZERO_MAIN):
    if num.startswith("L"):
        ESP_HOLE[name] = ("h", ESP_COL0 + i)
    else:
        ESP_HOLE[name] = ("d", ESP_COL0 + i - 9)
PIN_LABEL = {"5V_IN": "5V", "GND@1": "G", "3V3_OUT": "3V3", "GPIO43_TX": "TX", "GPIO44_RX": "RX"}


class Svg:
    def __init__(self):
        self.parts = []

    def add(self, s):
        self.parts.append(s)

    def rect(self, x, y, w, h, fill, rx=0, stroke="none", sw=1, extra=""):
        self.add(f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{rx}" fill="{fill}" '
                 f'stroke="{stroke}" stroke-width="{sw}"{extra}/>')

    def circle(self, x, y, r, fill, stroke="none", sw=1):
        self.add(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')

    def text(self, x, y, s, size=10, fill="#3c4450", anchor="middle", weight=400, cls="", family="mono"):
        fam = "var(--mono)" if family == "mono" else "var(--body)"   # CSS vars need style=, not attributes
        klass = f' class="{cls}"' if cls else ""
        self.add(f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" fill="{fill}" text-anchor="{anchor}" '
                 f'font-weight="{weight}" style="font-family:{fam}"{klass}>{escape(s)}</text>')

    def wire(self, pts, color, dashed=False, width=2.6, title=""):
        d = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts)
        dash = ' stroke-dasharray="5 3"' if dashed else ""
        t = f"<title>{escape(title)}</title>" if title else ""
        self.add(f'<path d="{d}" fill="none" stroke="#ffffff" stroke-width="{width + 2}" stroke-linejoin="round" '
                 f'stroke-linecap="round" opacity="0.85"/>')
        self.add(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="round" '
                 f'stroke-linecap="round"{dash}>{t}</path>')
        for x, y in (pts[0], pts[-1]):
            self.circle(x, y, 2.6, color, "#ffffff", 1)


def hole(row, col):
    return cx(col), ROW_Y[row]


def rail_y(which):
    return {"top+": Y_TOP_PLUS, "top-": Y_TOP_MINUS, "bot-": Y_BOT_MINUS, "bot+": Y_BOT_PLUS}[which]


def nearest_rail(col, rises=()):
    """Nearest rail hole whose jumper from `col` does not pass over a wire rising at `rises`."""
    ok = [c for c in RAIL_COLS if not any(min(c, col) <= x <= max(c, col) for x in rises)]
    return min(ok, key=lambda c: (abs(c - col), c))


# ------------------------------------------------------------ breadboard view --
def breadboard():
    s = Svg()
    wires = []          # checklist rows: (group, label, from, to, colour key, note)
    width = cx(COLS) + 70
    height = Y_BLOCKS + (96 if sch.STICKS_FITTED else 34)
    # bench mat + board body
    s.rect(0, 0, width, height, "#e9eef3", rx=10)
    bx0, bx1 = cx(1) - P, cx(COLS) + P
    s.rect(bx0, Y_TOP_PLUS - 0.9 * P, bx1 - bx0, (Y_BOT_PLUS - Y_TOP_PLUS) + 1.8 * P, "#fbfbf9", rx=6,
           stroke="#c8ccd2", sw=1)
    s.rect(bx0, ROW_Y["e"] + 0.7 * P, bx1 - bx0, (ROW_Y["f"] - ROW_Y["e"]) - 1.4 * P, "#eceee9")
    # rails
    for key, color in (("top+", "#d1343b"), ("top-", "#2f6fd1"), ("bot-", "#2f6fd1"), ("bot+", "#d1343b")):
        y = rail_y(key)
        off = -0.55 * P if key in ("top+", "bot-") else 0.55 * P
        s.add(f'<line x1="{cx(2):.1f}" y1="{y + off:.1f}" x2="{cx(62):.1f}" y2="{y + off:.1f}" stroke="{color}" '
              f'stroke-width="1.4"/>')
        for c in RAIL_COLS:
            s.rect(cx(c) - 2.6, y - 2.6, 5.2, 5.2, "#b9bec6", rx=1)
        s.text(cx(1) - 2, y + 3.5, "+" if key.endswith("+") else "−", size=12, fill=color, weight=700)
    # terminal holes, row letters, column numbers
    for r, y in ROW_Y.items():
        for c in range(1, COLS + 1):
            s.rect(cx(c) - 2.6, y - 2.6, 5.2, 5.2, "#c3c8cf", rx=1)
        s.text(cx(1) - 0.75 * P, y + 3.5, r, size=9, fill="#8a929c")
        s.text(cx(COLS) + 0.75 * P, y + 3.5, r, size=9, fill="#8a929c")
    for c in [1] + list(range(5, COLS + 1, 5)):
        s.text(cx(c), ROW_Y["a"] - 0.55 * P, str(c), size=8, fill="#8a929c")
        s.text(cx(c), ROW_Y["j"] + 0.95 * P, str(c), size=8, fill="#8a929c")
    s.text(cx(COLS) + P, Y_TOP_PLUS - 0.95 * P - 5,
           "top rails: unused  ·  bottom − rail: GND bus  ·  bottom + rail: unused",
           size=9, anchor="end", fill="#6b7580", family="body")

    # --- ESP32-S3-Zero
    ex0, ex1 = cx(ESP_COL0) - 0.625 * P, cx(ESP_COL0 + 8) + 0.625 * P
    ey0, ey1 = ROW_Y["d"] - 0.6 * P, ROW_Y["h"] + 0.6 * P
    s.rect(ex0, ey0, ex1 - ex0, ey1 - ey0, "#1b3f8f", rx=3)
    ymid = (ROW_Y["e"] + ROW_Y["f"]) / 2
    s.rect(ex0 - 7, ymid - 28, 44, 56, "#b8bec6", rx=5, stroke="#8d949d")
    s.text(ex0 + 64, ymid - 6, "ESP32-S3", size=9, fill="#ffffff", weight=600, family="body")
    s.text(ex0 + 64, ymid + 6, "-Zero", size=9, fill="#ffffff", weight=600, family="body")
    s.text(ex0 + 64, ymid + 18, "U2", size=8, fill="#9fb3d9")
    for name, (row, col) in ESP_HOLE.items():
        x, y = hole(row, col)
        s.circle(x, y, 3.4, "#e0b64a", "#7a5d12", 0.8)
        label = PIN_LABEL.get(name, name.replace("GPIO", "").split("_")[0])
        s.text(x, y + (10 if row == "d" else -6), label, size=7.5, fill="#ffffff")
    s.wire([(ex0 - 7, ymid), (ex0 - 60, ymid)], COL["usb"], width=4)
    s.text(ex0 - 62, ymid - 8, "USB-C to Pi", size=9, anchor="end", fill="#3c4450", family="body")
    s.text(ex0 - 62, ymid + 5, "USB 2.0 port", size=9, anchor="end", fill="#3c4450", family="body")
    s.text(ex0 - 62, ymid + 17, "(W7)", size=9, anchor="end", fill="#6b7580")
    wires.append(("USB", "W7", "ESP32 USB-C", "Pi 5 second USB 2.0 port", "usb",
                  "USB-A to USB-C data cable: HID gamepad and the ESP32's 5 V"))

    # --- switches
    pin_of = {net: (gate, pin) for _, net, gate, pin in sch.BUTTONS}
    for net, n in SLOT.items():
        x0, x1 = cx(n) - 0.35 * P, cx(n + 2) + 0.35 * P
        y0, y1 = ROW_Y["e"] - 0.35 * P, ROW_Y["f"] + 0.35 * P
        s.rect(x0, y0, x1 - x0, y1 - y0, "#2b2f36", rx=2)
        s.circle((x0 + x1) / 2, (y0 + y1) / 2, 0.62 * P, "#50555e")
        for c in (n, n + 2):
            for r in "ef":
                s.circle(*hole(r, c), 2.2, "#c9ced5")
        s.text((x0 + x1) / 2, (y0 + y1) / 2 + 3.5, SHORT[net], size=8.5 if len(SHORT[net]) < 5 else 7,
               fill=COL[GROUP[net]] if GROUP[net] != "gnd" else "#ffffff", weight=700, family="body")

    # --- top wires: header row d -> column N top half, nested lanes
    top = sorted([net for net in SLOT if pin_of[net][0] == "MAIN" and ESP_HOLE[pin_of[net][1]][0] == "d"],
                 key=lambda net: -ESP_HOLE[pin_of[net][1]][1])
    for k, net in enumerate(top, start=1):
        pin = pin_of[net][1]
        src = ESP_HOLE[pin][1]
        n = SLOT[net]
        y = top_lane(k)
        s.wire([hole("a", src), (cx(src), y), (cx(n), y), hole("a", n)], COL[GROUP[net]], title=f"{net} {pin}")
        wires.append(("Buttons", SHORT[net], f"a{src} ({pin.split('_')[0]})", f"a{n}", GROUP[net],
                      f"{net}: signal"))
    assert all(SLOT[a] < SLOT[b] for a, b in zip(top, top[1:])), "top wires would cross"

    # --- bottom wires: header row h pins and solder-pad leads -> column N bottom half
    pads = sorted([net for net in SLOT if pin_of[net][0] == "PADS"], key=lambda net: SLOT[net])
    xv = {net: 14.0 - 0.5 * k for k, net in enumerate(pads)}            # lead drop columns
    bottom = [(xv[net], net) for net in pads]
    bottom += [(ESP_HOLE[pin_of[net][1]][1], net) for net in SLOT
               if pin_of[net][0] == "MAIN" and ESP_HOLE[pin_of[net][1]][0] == "h"]
    bottom.sort(key=lambda t: SLOT[t[1]])
    assert all(a[0] > b[0] for a, b in zip(bottom, bottom[1:])), "bottom wires would cross"
    lead_y = {net: ROW_Y["d"] + 0.3 * P + k * 0.95 * P for k, net in enumerate(sorted(pads, key=lambda n: -xv[n]))}
    for k, (x_src, net) in enumerate(bottom, start=1):
        n = SLOT[net]
        y = bot_lane(k)
        pin = pin_of[net][1]
        if net in xv:
            ly = lead_y[net]
            s.circle(ex1 - 3, ly, 2.6, "#e0b64a", "#7a5d12", 0.8)
            s.wire([(ex1 - 3, ly), (cx(x_src), ly), (cx(x_src), y), (cx(n), y), hole("j", n)], COL[GROUP[net]],
                   dashed=True, title=f"{net} {pin} (solder pad)")
            side = "front" if pin in ("GPIO14", "GPIO15", "GPIO16") else "back"
            wires.append(("Buttons", SHORT[net], f"{pin} pad ({side}), soldered lead", f"j{n}", GROUP[net],
                          f"{net}: signal, wire soldered to the pad"))
        else:
            s.wire([hole("j", x_src), (cx(x_src), y), (cx(n), y), hole("j", n)], COL[GROUP[net]],
                   title=f"{net} {pin}")
            wires.append(("Buttons", SHORT[net], f"j{x_src} ({pin})", f"j{n}", GROUP[net], f"{net}: signal"))

    # --- switch GND jumpers to the bottom - rail
    rises = set(SLOT.values())
    for net, n in SLOT.items():
        r = nearest_rail(n + 2, rises=rises)
        s.wire([hole("j", n + 2), (cx(r), Y_BOT_MINUS)], COL["gnd"], width=2.2, title=f"{net} GND")
        wires.append(("Buttons", SHORT[net] + " GND", f"j{n + 2}", f"bottom − rail, col {r}", "gnd",
                      f"{net}: the switch's other side to GND"))
    # optional bridge for boards whose rails are split in the middle
    s.add(f'<path d="M{cx(31):.1f},{Y_BOT_MINUS:.1f} Q{cx(32):.1f},{Y_BOT_MINUS + 12:.1f} {cx(33):.1f},'
          f'{Y_BOT_MINUS:.1f}" fill="none" stroke="{COL["gnd"]}" stroke-width="2" stroke-dasharray="2 3"/>')
    wires.append(("Power", "Rail bridge", "bottom − rail col 31", "bottom − rail col 33", "gnd",
                  "Only if your board's rail has a break in the middle"))

    # --- ESP32 power and the Circle Pads
    g_row, g_col = ESP_HOLE["GND@1"]
    v_row, v_col = ESP_HOLE["3V3_OUT"]
    s.wire([hole("j", g_col), (cx(g_col), Y_BOT_MINUS)], COL["gnd"], title="ESP32 GND to the GND bus")
    wires.insert(0, ("Power", "GND bus", f"j{g_col} (ESP32 GND)", f"bottom − rail, col {g_col}", "gnd",
                     "ESP32 ground to the bottom − rail: all switch GNDs return here"))
    if not sch.STICKS_FITTED:
        s.text(cx(1), Y_BLOCKS - 4, "Circle Pads: not wired yet. They will use GPIO1–4 (now L1 R1 L2 R2); "
               "the shoulder buttons move when the pads arrive.", size=9.5, anchor="start", fill="#5a3d58",
               family="body")
        return _finish(s, width, height, wires)
    blocks = [("JS1", "LEFT stick", cx(0.35), cx(6.65)), ("JS2", "RIGHT stick", cx(6.8), cx(12.6))]
    for ref, name, x0, x1 in blocks:
        s.rect(x0, Y_BLOCKS, x1 - x0, 52, "#f6f1f7", rx=6, stroke="#b58db0", sw=1.2)
        s.text((x0 + x1) / 2, Y_BLOCKS + 30, f"{ref} Circle Pad", size=9, fill="#5a3d58", weight=600, family="body")
        s.text((x0 + x1) / 2, Y_BLOCKS + 42, f"{name} · pinout TBC", size=8, fill="#7a5b77", family="body")
    stick_pins = {("JS1", "X"): sch.STICKS[0][2], ("JS1", "Y"): sch.STICKS[0][3],
                  ("JS2", "X"): sch.STICKS[1][2], ("JS2", "Y"): sch.STICKS[1][3]}
    for (ref, axis), pin in stick_pins.items():
        col = ESP_HOLE[pin][1]
        s.wire([hole("j", col), (cx(col), Y_BLOCKS)], COL["stick"], title=f"{ref} {axis} {pin}")
        s.text(cx(col), Y_BLOCKS + 12, axis, size=8, fill="#2479b8", weight=700)
        wires.append(("Circle Pads", f"{ref} {axis}", f"j{col} ({pin})", f"{ref} {axis} contact", "stick",
                      f"{'LSTICK' if ref == 'JS1' else 'RSTICK'}_{axis} on ADC1"))
    s.wire([hole("j", v_col), (cx(v_col), Y_BLOCKS)], COL["v33"], title="3V3 to JS1 VCC")
    s.text(cx(v_col), Y_BLOCKS + 12, "VCC", size=7.5, fill="#d1343b", weight=700)
    gx = cx(1.05)
    s.wire([hole("i", g_col), (gx, ROW_Y["i"]), (gx, Y_BLOCKS)], COL["gnd"], title="GND to JS1 GND")
    s.text(gx + 1, Y_BLOCKS + 12, "GND", size=7.5, fill="#23272e", weight=700)
    wires.append(("Circle Pads", "JS1 VCC", f"j{v_col} (ESP32 3V3)", "JS1 VCC contact", "v33", "3.3 V only"))
    wires.append(("Circle Pads", "JS1 GND", f"i{g_col} (ESP32 GND)", "JS1 GND contact", "gnd", ""))
    # JS2 shares JS1's supply: spliced under the blocks
    yb = Y_BLOCKS + 52
    for i, (color, label) in enumerate(((COL["v33"], "VCC"), (COL["gnd"], "GND"))):
        y = yb + 12 + i * 10
        s.wire([(cx(2.4 + i), yb), (cx(2.4 + i), y), (cx(10.5 + i), y), (cx(10.5 + i), yb)], color, width=2.2,
               title=f"JS2 {label} spliced to JS1 {label}")
        wires.append(("Circle Pads", f"JS2 {label}", f"JS1 {label}", f"JS2 {label} contact", "v33" if i == 0 else "gnd",
                      "Splice onto JS1's wire (both pads share the supply)"))
    s.text(cx(6.6), yb + 38, "JS2 VCC / GND spliced to JS1", size=8, fill="#6b7580", family="body")
    return _finish(s, width, height, wires)


def _finish(s, width, height, wires):
    svg = (f'<svg viewBox="0 0 {width:.0f} {height:.0f}" width="{width:.0f}" height="{height:.0f}" role="img" '
           f'aria-label="Breadboard wiring of the D2K controls" xmlns="http://www.w3.org/2000/svg">'
           + "".join(s.parts) + "</svg>")
    return svg, wires


# ------------------------------------------------------------ Pi header view --
PI_WIRES = [  # (Pi pin, destination, destination pin, colour key, signal)
    (1, "WM8960", 1, "v33", "3.3 V (VCC)"), (9, "WM8960", 3, "gnd", "GND"),
    (3, "WM8960", 7, "i2c", "I²C SDA (GPIO2)"), (5, "WM8960", 5, "i2c2", "I²C SCL (GPIO3)"),
    (12, "WM8960", 9, "i2s", "I²S bit clock (GPIO18)"), (35, "WM8960", 11, "i2s2", "I²S L/R clock (GPIO19)"),
    (40, "WM8960", 13, "dout", "Playback data out (GPIO21) → TXSDA"),
    (38, "WM8960", 14, "din", "Mic data in (GPIO20) ← RXSDA"),
    (4, "4in DSI", "red", "v5", "5 V to the 4in screen (red lead)"),
    (6, "4in DSI", "black", "gnd", "GND to the 4in screen (black lead)"),
]
PI_COL = {"v33": "#d1343b", "gnd": "#23272e", "i2c": "#1f9aa8", "i2c2": "#136f7a", "i2s": "#7b5cc4",
          "i2s2": "#5a3fa6", "dout": "#2e9e5b", "din": "#e0761f", "v5": "#b3202a"}
PI_NAMES = {n: name for n, name, _ in lib.GPIO_40}


def pi_header():
    s = Svg()
    pp = 22                                      # header drawn at a larger pitch
    x0, y_even, y_odd = 70, 120, 120 + pp
    width, height = x0 + 20 * pp + 250, 380

    def pin_xy(n):
        return x0 + ((n + 1) // 2 - 1) * pp, (y_odd if n % 2 else y_even)

    s.rect(0, 0, width, height, "#e9eef3", rx=10)
    s.rect(x0 - 16, y_even - 16, 20 * pp + 10, 2 * pp + 10, "#1e2a24", rx=4)
    used = {w[0]: w for w in PI_WIRES}
    for n in range(1, 41):
        x, y = pin_xy(n)
        c = PI_COL[used[n][3]] if n in used else "#9aa1a8"
        s.rect(x - 5, y - 5, 10, 10, "#d8b75a" if n in used else "#6e757c", rx=1.5)
        if n in used:
            s.rect(x - 7, y - 7, 14, 14, "none", rx=2, stroke=c, sw=2)
        s.text(x, (y_even - 10) if n % 2 == 0 else (y_odd + 18), str(n), size=8, fill="#3c4450")
    s.text(x0 - 30, y_odd + 4, "odd", size=8, fill="#6b7580", anchor="end", family="body")
    s.text(x0 - 30, y_even + 4, "even", size=8, fill="#6b7580", anchor="end", family="body")
    s.text(x0 + 10 * pp, 40, "Raspberry Pi 5 GPIO header, seen from the component side (pin 1 end away from the USB ports)",
           size=10, fill="#3c4450", family="body")
    # 4in DSI lead block above
    bx = x0 + pp * 2.5
    s.rect(bx - 30, 52, 110, 26, "#f4f6f8", rx=5, stroke="#8a96a3")
    s.text(bx + 25, 69, "4in DSI power (W5)", size=9, fill="#3c4450", family="body")
    for n, tx, ty in ((4, bx - 12, 100), (6, bx + 40, 92)):   # red to the left terminal, black to the right
        x, y = pin_xy(n)
        s.wire([(x, y - 7), (x, ty), (tx, ty), (tx, 78)], PI_COL[used[n][3]])
    # WM8960 header below
    wx0, wy_odd, wy_even = x0 + 3 * pp, 300, 300 + pp
    s.rect(wx0 - 16, wy_odd - 16, 8 * pp + 10, 2 * pp + 10, "#1b3f8f", rx=4)
    s.text(wx0 + 8 * pp + 10, wy_odd + 8, "WM8960 Audio Board header P2 (U3)", size=10, fill="#3c4450",
           anchor="start", family="body")
    s.text(wx0 + 8 * pp + 10, wy_odd + 22, "pins 2, 4, 10, 12 repeat 1, 3, 9, 11 · 6, 8 not connected",
           size=8.5, fill="#6b7580", anchor="start", family="body")

    def wm_xy(n):
        return wx0 + ((n + 1) // 2 - 1) * pp, (wy_odd if n % 2 else wy_even)

    wm_used = {w[2] for w in PI_WIRES if w[1] == "WM8960"}
    for n in range(1, 17):
        x, y = wm_xy(n)
        s.rect(x - 5, y - 5, 10, 10, "#d8b75a" if n in wm_used else "#6e757c", rx=1.5)
        s.text(x, (wy_odd - 20) if n % 2 else (wy_even + 26), str(n), size=8, fill="#3c4450")
    # jumpers: Pi odd/even pin -> lane -> WM8960 pin (lanes ordered by source x)
    audio = sorted([w for w in PI_WIRES if w[1] == "WM8960"], key=lambda w: pin_xy(w[0])[0])
    for k, (pn, _, wn, ck, _) in enumerate(audio):
        px, py = pin_xy(pn)
        wx, wy = wm_xy(wn)
        lane = 185 + k * 11
        start = (px, py + 7) if pn % 2 else (px + 7, py)
        pts = [start]
        if pn % 2 == 0:                          # even-row pin: step out sideways past the odd row
            pts += [(px + 7, py), (px + 9, py), (px + 9, lane)]
        else:
            pts.append((px, lane))
        end_y = wy - 7 if wn % 2 else wy + 7
        if wn % 2 == 0:
            pts += [(wx - 9, lane), (wx - 9, wy), (wx - 7, wy)]
        else:
            pts += [(wx, lane), (wx, end_y)]
        s.wire(pts, PI_COL[ck], title=f"Pi {pn} to WM8960 {wn}")
    svg = (f'<svg viewBox="0 0 {width} {height}" width="{width}" height="{height}" role="img" '
           f'aria-label="Pi GPIO header jumpers to the WM8960 board and the 4in screen" '
           f'xmlns="http://www.w3.org/2000/svg">' + "".join(s.parts) + "</svg>")
    rows = [("Audio (W8)" if d == "WM8960" else "4in screen (W5)", f"Pi pin {pn}",
             f"{PI_NAMES[pn].split('@')[0]}", f"WM8960 pin {dn}" if d == "WM8960" else f"4in lead, {dn}",
             ck, sig) for pn, d, dn, ck, sig in PI_WIRES]
    return svg, rows


# ------------------------------------------------------------ page --
CSS = """
:root{--ground:#f4f6f9;--panel:#ffffff;--ink:#16202b;--muted:#5a6675;--line:#d8dee6;--accent:#298cc8;
--accent-ink:#1d5da7;--pink:#dabfdb;--mat:#e9eef3;--ok:#2e9e5b;--chip-edge:rgba(0,0,0,.18);
--display:"Chakra Petch",ui-sans-serif,system-ui,sans-serif;--body:"Atkinson Hyperlegible",ui-sans-serif,system-ui,sans-serif;
--mono:"JetBrains Mono",ui-monospace,SFMono-Regular,Menlo,monospace}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--ground:#0e141b;--panel:#151d26;--ink:#e4ebf3;
--muted:#9aa7b6;--line:#26313d;--accent:#5db3e6;--accent-ink:#8cc9ee;--ok:#57c283;--chip-edge:rgba(255,255,255,.55);color-scheme:dark}}
:root[data-theme="dark"]{--ground:#0e141b;--panel:#151d26;--ink:#e4ebf3;--muted:#9aa7b6;--line:#26313d;
--accent:#5db3e6;--accent-ink:#8cc9ee;--ok:#57c283;--chip-edge:rgba(255,255,255,.55);color-scheme:dark}
body{background:var(--ground);color:var(--ink);font-family:var(--body);font-size:15px;line-height:1.55}
.wrap{max-width:1180px;margin:0 auto;padding-inline:20px;padding-block:28px 64px;display:grid;gap:40px}
header{display:grid;gap:8px;max-width:72ch}
.eyebrow{font-family:var(--mono);font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--accent-ink)}
h1{font-family:var(--display);font-weight:600;font-size:clamp(28px,4vw,40px);line-height:1.1;margin:0;text-wrap:balance}
h2{font-family:var(--display);font-weight:600;font-size:22px;margin:0;text-wrap:balance}
p{margin:0}.lede{color:var(--muted);font-size:16px}
section{display:grid;gap:14px}
.figure{background:var(--mat);border:1px solid var(--line);border-radius:12px;overflow-x:auto;padding:8px}
.figure svg{display:block;max-width:none}
.legend{display:flex;flex-wrap:wrap;gap:8px 16px;font-size:13px;color:var(--muted)}
.legend span{display:inline-flex;align-items:center;gap:6px}
.sw{width:22px;height:5px;border-radius:3px;display:inline-block;box-shadow:0 0 0 1px var(--chip-edge)}
.sw.dash{background:repeating-linear-gradient(90deg,var(--c) 0 6px,transparent 6px 9px)!important}
.notes{display:grid;gap:6px;margin:0;padding-left:18px;color:var(--ink);max-width:80ch}
.notes li::marker{color:var(--accent)}
.bar{display:flex;flex-wrap:wrap;align-items:center;justify-content:space-between;gap:12px}
.progress{font-family:var(--mono);font-size:13px;color:var(--muted);font-variant-numeric:tabular-nums}
.progress b{color:var(--ok)}
button.reset{font:inherit;font-size:13px;background:transparent;color:var(--accent-ink);border:1px solid var(--line);
border-radius:6px;padding:4px 10px;cursor:pointer}
button.reset:focus-visible,input:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
.tablewrap{overflow-x:auto;border:1px solid var(--line);border-radius:10px;background:var(--panel)}
table{border-collapse:collapse;width:100%;font-size:14px;min-width:720px}
th,td{text-align:left;padding:7px 10px;border-bottom:1px solid var(--line);vertical-align:top}
thead th{font-size:12px;letter-spacing:.06em;text-transform:uppercase;color:var(--muted);font-weight:600}
tr.group td{background:var(--ground);font-family:var(--display);font-weight:600;color:var(--accent-ink)}
td.hole{font-family:var(--mono);font-size:13px;white-space:nowrap;font-variant-numeric:tabular-nums}
td.note{color:var(--muted)}
tr.done td:not(:first-child){opacity:.5}
tr.done td.hole{text-decoration:line-through}
input[type=checkbox]{width:17px;height:17px;accent-color:var(--ok);cursor:pointer}
.chip{display:inline-block;width:12px;height:12px;border-radius:3px;vertical-align:-1px;margin-right:6px;
border:1px solid var(--chip-edge)}
.warn{display:grid;gap:10px;margin:0;padding:0;list-style:none;max-width:84ch}
.warn li{padding:10px 14px;border-left:3px solid var(--pink);background:var(--panel);border-radius:0 8px 8px 0}
.warn b{color:var(--ink)}
footer{color:var(--muted);font-size:13px;max-width:80ch}
code{font-family:var(--mono);font-size:.92em}
@media (max-width:640px){.wrap{padding-inline:16px}}
"""

JS = """
(function(){
  var KEY='d2k-bench-wiring-v1';
  var done={};
  try{done=JSON.parse(localStorage.getItem(KEY)||'{}')||{};}catch(e){done={};}
  var boxes=[].slice.call(document.querySelectorAll('input[data-wire]'));
  function paint(){
    var n=0;
    boxes.forEach(function(b){var on=!!done[b.id];b.checked=on;b.closest('tr').classList.toggle('done',on);if(on)n++;});
    document.querySelectorAll('[data-progress]').forEach(function(el){
      var scope=el.getAttribute('data-progress');
      var set=boxes.filter(function(b){return b.dataset.wire===scope;});
      var k=set.filter(function(b){return done[b.id];}).length;
      el.innerHTML='<b>'+k+'</b> / '+set.length+' wires placed';
    });
  }
  function save(){try{localStorage.setItem(KEY,JSON.stringify(done));}catch(e){}}
  boxes.forEach(function(b){b.addEventListener('change',function(){done[b.id]=b.checked;save();paint();});});
  document.querySelectorAll('button.reset').forEach(function(btn){
    btn.addEventListener('click',function(){
      var scope=btn.getAttribute('data-scope');
      boxes.forEach(function(b){if(b.dataset.wire===scope)delete done[b.id];});save();paint();});
  });
  paint();
})();
"""


def table(rows, scope, colours):
    out = ['<div class="tablewrap"><table><thead><tr><th scope="col">Done</th><th scope="col">Wire</th>'
           '<th scope="col">From</th><th scope="col">To</th><th scope="col">Signal / note</th></tr></thead><tbody>']
    group = None
    for i, (g, label, a, b, ck, note) in enumerate(rows):
        if g != group:
            out.append(f'<tr class="group"><td colspan="5">{escape(g)}</td></tr>')
            group = g
        wid = f"{scope}-{i:02d}"
        out.append(f'<tr><td><input type="checkbox" id="{wid}" data-wire="{scope}" aria-label="{escape(label)} placed">'
                   f'</td><td><span class="chip" style="background:{colours[ck]}"></span>{escape(label)}</td>'
                   f'<td class="hole">{escape(a)}</td><td class="hole">{escape(b)}</td>'
                   f'<td class="note">{escape(note)}</td></tr>')
    out.append("</tbody></table></div>")
    return "".join(out)


def page():
    bb_svg, bb_rows = breadboard()
    pi_svg, pi_rows = pi_header()
    order = {"Power": 0, "USB": 1, "Circle Pads": 2, "Buttons": 3}
    slot_order = [SHORT[n] for n in sorted(SLOT, key=SLOT.get)]
    def key(r):  # groups in order; each button's signal then its GND
        if r[0] != "Buttons":
            return (order[r[0]], 0, 0)
        name = r[1].split()[0]
        return (order[r[0]], slot_order.index(name), r[1].endswith("GND"))
    bb_rows = sorted(bb_rows, key=key)
    pi_rows = [(g, label, a, b, ck, note) for g, a, label, b, ck, note in pi_rows]
    items = [(COL["dpad"], "D-pad", False), (COL["face"], "A B X Y", False),
             (COL["sys"], "Select Start Home", False), (COL["shoulder"], "L1 R1 L2 R2", False),
             (COL["gnd"], "GND", False)]
    if sch.STICKS_FITTED:
        items += [(COL["stick"], "Circle Pad axes", False), (COL["v33"], "3.3 V", False)]
    if any(g == "PADS" for _, _, g, _ in sch.BUTTONS):
        items.append((COL["sys"], "wire soldered to a pad", True))
    legend = "".join(
        f'<span><i class="sw{" dash" if dash else ""}" style="background:{c};--c:{c}"></i>{escape(t)}</span>'
        for c, t, dash in items)
    return f"""<title>D2K Bench Wiring</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible:wght@400;700&family=Chakra+Petch:wght@500;600&family=JetBrains+Mono:wght@400;600&display=swap">
<style>{CSS}</style>
<main class="wrap">
<header>
<p class="eyebrow">D2K V1 · bench step 2 · controls and audio</p>
<h1>Bench wiring</h1>
<p class="lede">The ESP32-S3-Zero and the 15 buttons on an MB-102 breadboard, no soldering, then the
jumpers from the Pi's GPIO header to the WM8960 audio board and the 4-inch screen. Same pin plan as the
<code>D2K_V1</code> schematic in Fusion. Hole names are column 1–63 and row a–j.</p>
</header>

<section id="breadboard" aria-labelledby="h-bb">
<h2 id="h-bb">Breadboard: controls</h2>
<div class="figure">{bb_svg}</div>
<div class="legend">{legend}</div>
<ul class="notes">
<li><b>Reading a hole name:</b> <code>a22</code> is column 22, row a. The five holes of one column in the same
half (a–e, or f–j) are joined inside the board, so a wire can go in any free hole of that group.</li>
<li>The ESP32-S3-Zero sits across the centre channel: its TX/RX/13…7 pin row in row d and its 5V/GND/3V3/1…6
row in row h, columns 2–10, USB-C off the left edge. Every wire starts in a free hole next to a pin
(row a above, row j below) and ends in a free hole of a switch column.</li>
<li>Each 6×6 switch straddles the channel with its legs in rows e and f of two columns. One column takes the
GPIO wire, the other a short black wire to the GND rail. The ESP32's internal pull-ups do the rest: no
resistors. If a button reads as always pressed, turn the switch 90°.</li>
<li>No two button wires cross. The dotted link on the GND rail is only needed if your board's rail is split
in the middle. Hover or long-press a wire to see its name.</li>
</ul>
</section>

<section id="wire-list" aria-labelledby="h-list">
<div class="bar"><h2 id="h-list">Breadboard wire list</h2>
<span class="progress" data-progress="bb"></span>
<button class="reset" type="button" data-scope="bb">Clear ticks</button></div>
{table(bb_rows, "bb", {**COL})}
</section>

<section id="pi-header" aria-labelledby="h-pi">
<h2 id="h-pi">Pi GPIO header: audio board and 4-inch screen</h2>
<div class="figure">{pi_svg}</div>
<div class="bar"><span class="progress" data-progress="pi"></span>
<button class="reset" type="button" data-scope="pi">Clear ticks</button></div>
{table(pi_rows, "pi", PI_COL)}
</section>

<section id="checks" aria-labelledby="h-checks">
<h2 id="h-checks">Before you power up</h2>
<ul class="warn">
<li><b>Do not hold SELECT while the ESP32 powers up.</b> It is wired to the TX pin, which the chip drives during
boot. (The firmware turns TX into a normal input afterwards.)</li>
<li><b>Circle Pads later:</b> measure their pinout first (VCC, GND, X, Y are not verified) and feed them 3.3 V,
never 5 V. They will take GPIO1–4, so L1 R1 L2 R2 move then.</li>
<li><b>Nothing on the ESP32 sees 5 V.</b> Its pins are 3.3 V only; leave its 5V pin empty, the USB-C powers it.</li>
<li><b>The 4-inch lead is red on pin 4, black on pin 6.</b> The Pi's 5 V pins are not fused.</li>
<li><b>WM8960 header pins 5 and 7</b> are SCL and SDA per its schematic: check the silkscreen. Its speaker
amplifier runs from the Pi's 3.3 V pin, so keep the volume moderate until its current is measured.</li>
<li><b>Speakers:</b> each one between its P and N pins only (bridged outputs), never to GND. Their PH1.25 plugs
need a 4-pin adapter or a recrimp for the board's SPK connector.</li>
<li><b>Power off the Pi</b> before plugging the DSI ribbon or the GPIO jumpers.</li>
</ul>
</section>

<footer>Generated by <code>fusion/electronics/gen_breadboard.py</code> from the D2K_V1 pin plan. Rails differ
between MB-102 boards: use the rail printed with the blue (−) line for GND. Ticks are saved in this browser
only.</footer>
</main>
<script>{JS}</script>
"""


if __name__ == "__main__":
    out = Path(__file__).with_name("breadboard_v1.html")
    out.write_text(page(), encoding="utf-8")
    print(f"wrote {out}")
