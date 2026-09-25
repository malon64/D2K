"""Generate D2K_V1.sch, the V1 bench interconnect schematic (EAGLE 9 / Fusion Electronics).

Sheet 1 - Pi 5 on the mains (27 W USB-C PSU), Waveshare 5inch HDMI LCD (H)
          upper screen, Waveshare 4-DSI-TOUCH-A lower touch screen, Active
          Cooler. Each cable is one straight wire per conductor between the two
          connectors facing each other, with the cable named above it.
Sheet 2 - Controls: ESP32-S3-Zero as USB HID gamepad (cable W7 to the Pi),
          15 buttons (6x6 tact switches on the breadboard), 2 Circle Pads.
Sheet 3 - Audio: Waveshare WM8960 Audio Board on the Pi's I2C1 + I2S pins,
          two 8 ohm speakers.
Nets are named <cable>_<signal> for cables and by function elsewhere
(BTN_A, LSTICK_X, I2S_BCLK...); grounds merge into GND, the Pi rails into
3V3 / 5V. Sheets connect through net names (labels).

The library is embedded from gen_d2k_lbr.py. Run with any Python 3:
    python gen_d2k_v1_sch.py   (writes D2K_V1.sch next to it)
Then upload with fusion/scripts/electronics_v1/60_upload_v1_schematic.py.
"""

from pathlib import Path
from xml.sax.saxutils import escape

import gen_d2k_lbr as lib

G = lib.GRID
GAP = 20 * G          # wire length between facing pins: room for the cable caption
STACK = 4 * G         # vertical space between stacked gates
fmt = lib.fmt

PARTS = {  # part: (deviceset, value)
    "PS1": ("PSU_USBC_27W", "RPi 27W USB-C PSU"),
    "U1": ("RASPBERRY_PI_5", "Raspberry Pi 5"),
    "M1": ("RPI5_ACTIVE_COOLER", "Active Cooler SC1148"),
    "LCD1": ("WAVESHARE_5IN_HDMI_LCD_H", "5inch HDMI LCD (H) - upper"),
    "LCD2": ("WAVESHARE_4_DSI_TOUCH_A", "4-DSI-TOUCH-A - lower touch"),
    "U2": ("ESP32_S3_ZERO", "ESP32-S3-Zero - USB HID"),
    "JS1": ("CIRCLE_PAD_N3DSXL", "Circle Pad LEFT (move)"),
    "JS2": ("CIRCLE_PAD_N3DSXL", "Circle Pad RIGHT (C-stick)"),
    "U3": ("WM8960_AUDIO_BOARD", "WM8960 Audio Board"),
    "LS1": ("SPEAKER_8R_2W", "Speaker LEFT"),
    "LS2": ("SPEAKER_8R_2W", "Speaker RIGHT"),
}

# ESP32-S3-Zero pin plan. Circle Pads on ADC1 (GPIO1-4). Buttons on the header
# pins first, then the solder pads. Kept free on purpose: GPIO10 (ADC1, battery
# voltage later), GPIO40-42 (lid Hall sensor, vibration, Pi power control),
# GPIO43/44 (UART0: system link to the Pi later). GPIO45 is a strapping pin.
BUTTONS = [  # (switch, net, ESP32 gate, ESP32 pin)
    ("SW1", "BTN_DPAD_UP", "MAIN", "GPIO5"), ("SW2", "BTN_DPAD_DOWN", "MAIN", "GPIO6"),
    ("SW3", "BTN_DPAD_LEFT", "MAIN", "GPIO7"), ("SW4", "BTN_DPAD_RIGHT", "MAIN", "GPIO8"),
    ("SW5", "BTN_A", "MAIN", "GPIO9"), ("SW6", "BTN_B", "MAIN", "GPIO11"),
    ("SW7", "BTN_X", "MAIN", "GPIO12"), ("SW8", "BTN_Y", "MAIN", "GPIO13"),
    ("SW9", "BTN_START", "PADS", "GPIO14"), ("SW10", "BTN_SELECT", "PADS", "GPIO15"),
    ("SW11", "BTN_HOME", "PADS", "GPIO16"), ("SW12", "BTN_L1", "PADS", "GPIO17"),
    ("SW13", "BTN_R1", "PADS", "GPIO18"), ("SW14", "BTN_L2", "PADS", "GPIO38"),
    ("SW15", "BTN_R2", "PADS", "GPIO39"),
]
STICKS = [("JS1", "LSTICK", "GPIO1", "GPIO2"), ("JS2", "RSTICK", "GPIO3", "GPIO4")]
PARTS.update({sw: ("TACT_SWITCH_6X6", net) for sw, net, _, _ in BUTTONS})
RESERVED = {"GPIO10": "free: ADC1 for battery voltage", "GPIO40": "free: lid Hall sensor",
            "GPIO41": "free: vibration PWM", "GPIO42": "free: Pi power control",
            "GPIO43_TX": "free: UART to Pi (later)", "GPIO44_RX": "free: UART to Pi (later)",
            "GPIO45": "avoid: strapping pin"}

# Pi GPIO header pins used by the WM8960 board (sheet 3), labelled on sheet 1.
PI_AUDIO_PINS = {"3V3@1": "3V3", "GPIO2_SDA1": "I2C1_SDA", "GPIO3_SCL1": "I2C1_SCL", "GND@2": "GND",
                 "GPIO18_PCM_CLK": "I2S_BCLK", "GPIO19_PCM_FS": "I2S_LRCLK",
                 "GPIO20_PCM_DIN": "I2S_DIN", "GPIO21_PCM_DOUT": "I2S_DOUT"}
WM8960_NETS = {"VCC@1": "3V3", "VCC@2": "3V3", "GND@1": "GND", "GND@2": "GND", "SCL": "I2C1_SCL",
               "SDA": "I2C1_SDA", "CLK@9": "I2S_BCLK", "CLK@10": "I2S_BCLK", "WS@11": "I2S_LRCLK",
               "WS@12": "I2S_LRCLK", "TXSDA_DAC_IN": "I2S_DOUT", "RXSDA_ADC_OUT": "I2S_DIN"}

GSYMS = lib.gate_symbols()
instances = {}       # (part, gate) -> (x, y)
inst_sheet = {}      # (part, gate) -> sheet index
sheets = []          # [{"nets": {name: [segments]}, "plain": [xml]}]
parts_used = {}      # part -> (deviceset, value)


def new_sheet():
    sheets.append({"nets": {}, "plain": []})


def cur():
    return sheets[-1]


def device_of(part):
    return PARTS[part][0]


def layout(part, gate):
    sname, title, pins, side = GSYMS[(device_of(part), gate)]
    return lib.symbol_layout(pins, side)


def place(part, gate, x, y):
    instances[(part, gate)] = (x, y)
    inst_sheet[(part, gate)] = len(sheets) - 1
    parts_used[part] = PARTS[part]
    left, right, width, rows = layout(part, gate)
    return {"x": x, "y": y, "w": width, "rows": rows, "top": y + G, "bottom": y - G * rows - G,
            "left_x": x - 5.08, "right_x": x + width + 5.08}


def pin_xy(part, gate, pin):
    x, y = instances[(part, gate)]
    left, right, width, _ = layout(part, gate)
    for i, p in enumerate(left):
        if p[1] == pin:
            return x - 5.08, y - G * (i + 1), -1
    for i, p in enumerate(right):
        if p[1] == pin:
            return x + width + 5.08, y - G * (i + 1), 1
    raise KeyError(f"{part}.{gate} has no pin {pin}")


def wire(x1, y1, x2, y2):
    return f'<wire x1="{fmt(x1)}" y1="{fmt(y1)}" x2="{fmt(x2)}" y2="{fmt(y2)}" width="0.1524" layer="91"/>'


def connect(net, a, b):
    """a, b = (part, gate, pin); both pins must sit on the same row."""
    (xa, ya, _), (xb, yb, _) = pin_xy(*a), pin_xy(*b)
    assert abs(ya - yb) < 1e-6, f"{a} and {b} are not aligned"
    seg = (f'<segment>\n<pinref part="{a[0]}" gate="{a[1]}" pin="{escape(a[2])}"/>\n'
           f'<pinref part="{b[0]}" gate="{b[1]}" pin="{escape(b[2])}"/>\n{wire(xa, ya, xb, yb)}\n</segment>')
    cur()["nets"].setdefault(net, []).append(seg)


def stub(net, a, length=3):
    """Short wire + net label on one pin, pointing away from the symbol."""
    x, y, direction = pin_xy(*a)
    x2 = x + direction * length * G
    rot = ' rot="R180"' if direction < 0 else ""
    seg = (f'<segment>\n<pinref part="{a[0]}" gate="{a[1]}" pin="{escape(a[2])}"/>\n{wire(x, y, x2, y)}\n'
           f'<label x="{fmt(x2)}" y="{fmt(y)}" size="1.778" layer="95"{rot}/>\n</segment>')
    cur()["nets"].setdefault(net, []).append(seg)


def text(x, y, s, size=1.778, layer=97, align=None):
    a = f' align="{align}"' if align else ""
    cur()["plain"].append(f'<text x="{fmt(x)}" y="{fmt(y)}" size="{size}" layer="{layer}"{a}>{escape(s)}</text>')


def note_at_pin(part, gate, pin, s):
    x, y, direction = pin_xy(part, gate, pin)
    text(x + direction * 1.5 * G, y - 0.6, s, size=1.27, align="center-left" if direction > 0 else "center-right")


def cable(ref, caption, a_part, a_gate, b_part, b_gate, net_of, rows=None):
    """Connect a's right column to b's left column row by row."""
    a_right = layout(a_part, a_gate)[1]
    b_left = layout(b_part, b_gate)[0]
    ax, ay = instances[(a_part, a_gate)]
    bx, by = instances[(b_part, b_gate)]
    shift = round((ay - by) / G)  # b rows lower than a by this many
    for i, (_, sig, _) in enumerate(a_right):
        j = i - shift
        if rows is not None and sig not in rows:
            continue
        if 0 <= j < len(b_left):
            connect(net_of(sig, b_left[j][1]), (a_part, a_gate, sig), (b_part, b_gate, b_left[j][1]))
    x_mid = (ax + layout(a_part, a_gate)[2] + 5.08 + bx - 5.08) / 2
    text(x_mid, max(ay, by) + G + 1.27, f"{ref}  {caption}", align="bottom-center")


def frame(boxes, title, subtitle, notes, margin=16 * G):
    left = min(b["left_x"] for b in boxes) - margin
    right = max(b["right_x"] for b in boxes) + margin
    top = max(b["top"] for b in boxes) + margin
    bottom = min(b["bottom"] for b in boxes) - margin - G * 2 * len(notes)
    for x1, y1, x2, y2 in [(left, top, right, top), (right, top, right, bottom),
                           (right, bottom, left, bottom), (left, bottom, left, top)]:
        cur()["plain"].append(f'<wire x1="{fmt(x1)}" y1="{fmt(y1)}" x2="{fmt(x2)}" y2="{fmt(y2)}" '
                              f'width="0.4064" layer="94"/>')
    text(left + 2 * G, top - 3 * G, title, size=3.81, layer=94)
    text(left + 2 * G, top - 5.5 * G, subtitle)
    for i, n in enumerate(notes):
        text(left + 2 * G, bottom + (2 + 2 * (len(notes) - 1 - i)) * G, n, size=1.27)


def is_ground(sig):
    base = sig.split("@")[0]
    return base in ("GND", "DDC_GND", "GND_DRAIN") or base.endswith("_SH")


# ---------------------------------------------------------------- sheet 1 ---
def sheet_pi_screens():
    new_sheet()
    boxes = []
    psu = place("PS1", "P", 0, 0)
    pwr = place("U1", "PWR", psu["right_x"] + GAP + 5.08, 0)
    xs1 = pwr["x"]                                   # Pi column
    hdmi = place("U1", "HDMI0", xs1, pwr["bottom"] - STACK - 2 * G)
    xl1 = hdmi["right_x"] + GAP + 5.08               # screen column
    lcd_hdmi = place("LCD1", "HDMI", xl1, hdmi["y"])
    usb = place("U1", "USB2_0", xs1, hdmi["bottom"] - STACK - 2 * G)
    touch = place("LCD1", "TOUCH", xl1, usb["y"])
    audio = place("LCD1", "AUDIO", xl1, usb["bottom"] - STACK - 4 * G)
    boxes += [psu, pwr, hdmi, lcd_hdmi, usb, touch, audio]

    cable("W1", "USB-C cable (PSU captive), 5.1 V 5 A PD", "PS1", "P", "U1", "PWR",
          lambda a, b: {"VBUS": "VBUS_5V1", "CC": "USBC_CC"}.get(a, "GND"))
    stub("AC_L", ("PS1", "P", "AC_L"))
    stub("AC_N", ("PS1", "P", "AC_N"))
    text(psu["left_x"] - 3 * G, psu["top"] + 1.27, "230 V AC mains", align="bottom-center")
    cable("W2", "micro-HDMI (D) -> HDMI (A) cable: video 800x480 + HDMI audio", "U1", "HDMI0", "LCD1", "HDMI",
          lambda a, b: "GND" if is_ground(a) else f"HDMI0_{a}")
    cable("W3", "USB-A -> micro-USB DATA cable: touch (USB HID) + screen power ~400 mA", "U1", "USB2_0",
          "LCD1", "TOUCH", lambda a, b: "GND" if a == "GND" else f"USB2_0_{a}")
    for pin, net in (("L", "HEADSET_L"), ("R", "HEADSET_R"), ("GND", "HEADSET_GND")):
        stub(net, ("LCD1", "AUDIO", pin))
    text(audio["left_x"] - 3 * G, audio["top"] + 1.27, "Headset (HDMI audio, until the WM8960 works)",
         align="bottom-right")

    x2 = lcd_hdmi["right_x"] + 12 * G
    disp = place("U1", "DISP1", x2, 0)
    xl2 = disp["right_x"] + GAP + 5.08
    dsi = place("LCD2", "DSI", xl2, 0)
    gpio = place("U1", "GPIO", x2, disp["bottom"] - STACK - 2 * G)
    # 4in power lead on pin 4 (5V) and pin 6 (GND): rows 2 and 3 of the even column
    lcd_pwr = place("LCD2", "PWR", gpio["right_x"] + GAP + 5.08, gpio["y"] - G)
    fan = place("U1", "FAN", x2, gpio["bottom"] - STACK - 2 * G)
    cooler = place("M1", "FAN", fan["right_x"] + GAP + 5.08, fan["y"])
    boxes += [disp, dsi, gpio, lcd_pwr, fan, cooler]

    cable("W4", "FFC 22-pin 0.5 mm 200 mm REVERSE (supplied): DSI + touch I2C + 3V3", "U1", "DISP1", "LCD2", "DSI",
          lambda a, b: "GND" if is_ground(a) else ("3V3" if a == "3V3" else f"DSI1_{a}"))
    cable("W5", "2-wire lead: red = 5V (pin 4), black = GND (pin 6)", "U1", "GPIO", "LCD2", "PWR",
          lambda a, b: "5V" if b == "5V" else "GND", rows=("5V@2", "GND@1"))
    for pin, net in PI_AUDIO_PINS.items():           # WM8960 wiring, drawn on sheet 3
        stub(net, ("U1", "GPIO", pin))
    text(gpio["x"] + gpio["w"] / 2, gpio["bottom"] - 1.27,
         "! GPIO 5V is not fused: one pin off can kill the Pi. Power off before plugging.", align="top-center")
    text(gpio["x"] + gpio["w"] / 2, gpio["bottom"] - 3.8,
         "Labelled pins 1, 3, 5, 9, 12, 35, 38, 40: WM8960 audio board (sheet 3), W8 jumper wires.",
         size=1.27, align="top-center")
    cable("W6", "Fan lead JST-SH 4p (captive)", "U1", "FAN", "M1", "FAN",
          lambda a, b: "GND" if a == "GND" else f"FAN_{a}")

    frame(boxes, "D2K V1 - 1/3 Pi 5 and screens",
          "Raspberry Pi 5 on mains USB-C + Waveshare 5inch HDMI LCD (H) upper + Waveshare 4-DSI-TOUCH-A lower touch",
          ["Generated by fusion/electronics/gen_d2k_v1_sch.py - warnings and cable details: fusion/wiring.md",
           "Unused: Pi HDMI1, DISP0, USB3, Ethernet; 5in DC micro-USB, VGA, speaker header. "
           "Pi USB2_1: ESP32 (sheet 2)."])


# ---------------------------------------------------------------- sheet 2 ---
def sheet_controls():
    new_sheet()
    boxes = []
    esp = place("U2", "MAIN", 0, 0)
    pads = place("U2", "PADS", esp["right_x"] - 5.08 - layout("U2", "PADS")[2], esp["bottom"] - STACK - 6 * G)
    usb_esp = place("U2", "USB", 0, esp["top"] + 14 * G)
    pi_usb = place("U1", "USB2_1", usb_esp["left_x"] - GAP - 5.08 - layout("U1", "USB2_1")[2], usb_esp["y"])
    boxes += [esp, pads, usb_esp, pi_usb]
    cable("W7", "USB-A -> USB-C DATA cable: HID gamepad + ESP32 power", "U1", "USB2_1", "U2", "USB",
          lambda a, b: "GND" if a == "GND" else f"USB2_1_{a}")

    stub("ESP_3V3", ("U2", "MAIN", "3V3_OUT"))
    stub("GND", ("U2", "MAIN", "GND@1"))
    note_at_pin("U2", "MAIN", "5V_IN", "= USB-C VBUS on board")
    for part, net, x_pin, y_pin in STICKS:
        stub(net + "_X", ("U2", "MAIN", x_pin))
        stub(net + "_Y", ("U2", "MAIN", y_pin))
    for sw, net, gate, pin in BUTTONS:
        stub(net, ("U2", gate, pin), length=4)
    for pin, why in RESERVED.items():
        gate = "PADS" if pin in ("GPIO40", "GPIO41", "GPIO42", "GPIO45") else "MAIN"
        note_at_pin("U2", gate, pin, why)

    # Buttons: two columns, each switch GPIO label on the left pin, GND on the right.
    col_x = [esp["left_x"] - 46 * G, esp["right_x"] + 34 * G]
    y0 = esp["top"] + 6 * G
    for i, (sw, net, gate, pin) in enumerate(BUTTONS):
        col, row = (0, i) if i < 8 else (1, i - 8)
        b = place(sw, "S", col_x[col], y0 - row * 6 * G)
        boxes.append(b)
        stub(net, (sw, "S", "P1"), length=4)
        stub("GND", (sw, "S", "P2"))
    text(col_x[0] + 4 * G, y0 + 4 * G, "Face buttons, D-pad (6x6 tact on the breadboard)", size=1.778,
         align="bottom-center")
    text(col_x[1] + 4 * G, y0 + 4 * G, "Start/Select/Home, shoulders", size=1.778, align="bottom-center")

    # Circle Pads below the left button column.
    jy = y0 - 8 * 6 * G - 4 * G
    for k, (part, net, x_pin, y_pin) in enumerate(STICKS):
        js = place(part, "P", col_x[0] + k * 34 * G, jy)
        boxes.append(js)
        stub("ESP_3V3", (part, "P", "VCC"))
        stub(net + "_X", (part, "P", "X"))
        stub(net + "_Y", (part, "P", "Y"))
        stub("GND", (part, "P", "GND"))
    text(col_x[0], jy - 8 * G, "! Circle Pad pinout NOT verified: measure VCC/GND/X/Y before wiring. "
         "Feed 3.3 V (ESP_3V3), never 5 V.", size=1.27)

    frame(boxes, "D2K V1 - 2/3 Controls (ESP32-S3-Zero USB HID)",
          "15 buttons active-low to GND (internal pull-ups), 2 Circle Pads on ADC1, USB to the Pi",
          ["Header pins L1-L9 / R1-R9 sit on the breadboard; GPIO14-18, 38, 39 are solder pads (F front, B back).",
           "6x6 tact switch: pins 1-2 and 3-4 are joined inside - wire diagonally (1 to GPIO, 4 to GND).",
           "ESP32 is 3.3 V only (not 5 V tolerant). GPIO3 (RSTICK_X) is a strapping pin: fine as analog input.",
           "Kept free: GPIO10 (ADC battery), GPIO40-42 (Hall, vibration, Pi power), GPIO43/44 (UART to Pi)."])


# ---------------------------------------------------------------- sheet 3 ---
def sheet_audio():
    new_sheet()
    boxes = []
    hdr = place("U3", "HDR", 0, 0)
    spk = place("U3", "SPK", hdr["x"], hdr["bottom"] - STACK - 6 * G)
    ls1 = place("LS1", "S", spk["right_x"] + 30 * G, spk["y"] + 2 * G)
    ls2 = place("LS2", "S", spk["right_x"] + 30 * G, spk["y"] - 6 * G)
    boxes += [hdr, spk, ls1, ls2]
    for pin, net in WM8960_NETS.items():
        stub(net, ("U3", "HDR", pin))
    note_at_pin("U3", "HDR", "MCLK_RX", "open: MCLK = on-board 24 MHz")
    note_at_pin("U3", "HDR", "MCLK_TX", "open")
    for pin, net in (("LP", "SPK_LP"), ("LN", "SPK_LN"), ("RN", "SPK_RN"), ("RP", "SPK_RP")):
        stub(net, ("U3", "SPK", pin), length=4)
    for part, p, n in (("LS1", "SPK_LP", "SPK_LN"), ("LS2", "SPK_RP", "SPK_RN")):
        stub(p, (part, "S", "SPK+"), length=4)
        stub(n, (part, "S", "SPK-"), length=4)
    text(hdr["x"] + hdr["w"] / 2, hdr["top"] + 3 * G,
         "W8  8 jumper wires from the Pi GPIO header (sheet 1): 3V3 pin 1, SDA 3, SCL 5, GND 9, "
         "BCLK 12, LRCLK 35, DIN 38, DOUT 40", align="bottom-center")
    text(ls1["x"], ls1["top"] + 3 * G, "W9  speaker leads (PH1.25 plugs: need a 4-pin adapter / recrimp)",
         align="bottom-center")

    frame(boxes, "D2K V1 - 3/3 Audio (WM8960 + 2 speakers)",
          "Pi 5 I2S (GPIO18-21) + I2C1 (GPIO2/3) -> Waveshare WM8960 Audio Board -> two 8 ohm 2 W speakers",
          ["The board runs from the Pi 3V3 rail, including its speaker amplifier (SPKVDD): ~0.4 W/ch max, "
           "measure the current.",
           "Header pins 5/7 = SCL/SDA per the schematic netlist: check the board silkscreen before wiring.",
           "Linux: WM8960 overlay (dtoverlay=wm8960-soundcard, to confirm on the Pi); codec I2C address 0x1A.",
           "Speakers go in the upper half: 4 wires through the hinge, power/audio side (fusion/constraints.md)."])


def build():
    sheet_pi_screens()
    sheet_controls()
    sheet_audio()
    parts_xml = "\n".join(f'<part name="{p}" library="D2K" deviceset="{ds}" device="" value="{escape(v)}"/>'
                          for p, (ds, v) in parts_used.items())
    sheets_xml = []
    for idx, sh in enumerate(sheets):
        inst_xml = "\n".join(f'<instance part="{p}" gate="{g}" x="{fmt(x)}" y="{fmt(y)}"/>'
                             for (p, g), (x, y) in instances.items() if inst_sheet[(p, g)] == idx)
        nets_xml = "\n".join(f'<net name="{escape(n)}" class="0">\n' + "\n".join(segs) + "\n</net>"
                             for n, segs in sh["nets"].items())
        sheets_xml.append("<sheet>\n<plain>\n" + "\n".join(sh["plain"]) + "\n</plain>\n"
                          f"<instances>\n{inst_xml}\n</instances>\n<busses>\n</busses>\n"
                          f"<nets>\n{nets_xml}\n</nets>\n</sheet>")
    return (
        lib.HEADER_XML
        + '<schematic xreflabel="%F%N/%S.%C%R" xrefpart="/%S.%C%R">\n'
        + "<libraries>\n" + lib.library_xml("D2K") + "</libraries>\n"
        + "<attributes>\n</attributes>\n<variantdefs>\n</variantdefs>\n"
        + '<classes>\n<class number="0" name="default" width="0" drill="0">\n</class>\n</classes>\n'
        + f"<parts>\n{parts_xml}\n</parts>\n"
        + "<sheets>\n" + "\n".join(sheets_xml) + "\n</sheets>\n</schematic>\n</drawing>\n</eagle>\n"
    )


if __name__ == "__main__":
    out = Path(__file__).with_name("D2K_V1.sch")
    out.write_text(build(), encoding="utf-8")
    nets = {n for sh in sheets for n in sh["nets"]}
    print(f"wrote {out}: {len(sheets)} sheets, {len(parts_used)} parts, {len(instances)} gate instances, "
          f"{len(nets)} nets")
