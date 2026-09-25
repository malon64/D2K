"""Generate D2K_V1.sch, the V1 bench interconnect schematic (EAGLE 9 / Fusion Electronics).

V1 = Raspberry Pi 5 on the mains (27 W USB-C PSU), Waveshare 5inch HDMI LCD (H)
as the upper screen, Waveshare 4-DSI-TOUCH-A as the lower touch screen, and
the Pi Active Cooler. Each cable is drawn as one straight wire per conductor
between the two connector symbols facing each other, with the cable named
above it. Net names are <cable>_<signal>; grounds merge into GND.

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
}

GSYMS = lib.gate_symbols()
instances = {}   # (part, gate) -> (x, y)
nets = {}        # net name -> list of segment xml strings
plain = []       # free texts and frame wires


def layout(part, gate):
    sname, title, pins, side = GSYMS[(PARTS[part][0], gate)]
    return lib.symbol_layout(pins, side)


def place(part, gate, x, y):
    instances[(part, gate)] = (x, y)
    left, right, width, rows = layout(part, gate)
    return {"x": x, "y": y, "w": width, "rows": rows, "top": y + G, "bottom": y - G * rows - G,
            "left_x": x - 5.08, "right_x": x + width + 5.08}


def pin_xy(part, gate, pin):
    x, y = instances[(part, gate)]
    left, right, width, _ = layout(part, gate)
    for i, p in enumerate(left):
        if p[1] == pin:
            return x - 5.08, y - G * (i + 1)
    for i, p in enumerate(right):
        if p[1] == pin:
            return x + width + 5.08, y - G * (i + 1)
    raise KeyError(f"{part}.{gate} has no pin {pin}")


def wire(x1, y1, x2, y2):
    return f'<wire x1="{fmt(x1)}" y1="{fmt(y1)}" x2="{fmt(x2)}" y2="{fmt(y2)}" width="0.1524" layer="91"/>'


def connect(net, a, b):
    """a, b = (part, gate, pin); both pins must sit on the same row."""
    (xa, ya), (xb, yb) = pin_xy(*a), pin_xy(*b)
    assert abs(ya - yb) < 1e-6, f"{a} and {b} are not aligned"
    seg = (f'<segment>\n<pinref part="{a[0]}" gate="{a[1]}" pin="{escape(a[2])}"/>\n'
           f'<pinref part="{b[0]}" gate="{b[1]}" pin="{escape(b[2])}"/>\n{wire(xa, ya, xb, yb)}\n</segment>')
    nets.setdefault(net, []).append(seg)


def stub(net, a, direction):
    """Short wire + net label on one pin (direction -1 = to the left)."""
    x, y = pin_xy(*a)
    x2 = x + direction * 3 * G
    rot = ' rot="R180"' if direction < 0 else ""
    seg = (f'<segment>\n<pinref part="{a[0]}" gate="{a[1]}" pin="{escape(a[2])}"/>\n{wire(x, y, x2, y)}\n'
           f'<label x="{fmt(x2)}" y="{fmt(y)}" size="1.778" layer="95"{rot}/>\n</segment>')
    nets.setdefault(net, []).append(seg)


def text(x, y, s, size=1.778, layer=97, align=None):
    a = f' align="{align}"' if align else ""
    plain.append(f'<text x="{fmt(x)}" y="{fmt(y)}" size="{size}" layer="{layer}"{a}>{escape(s)}</text>')


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


def is_ground(sig):
    base = sig.split("@")[0]
    return base in ("GND", "DDC_GND", "GND_DRAIN") or base.endswith("_SH")


def build():
    # ------------------------------------------------ column 1: PSU, HDMI, USB
    psu = place("PS1", "P", 0, 0)
    pwr = place("U1", "PWR", psu["right_x"] + GAP + 5.08, 0)
    xs1 = pwr["x"]                                   # Pi column
    hdmi = place("U1", "HDMI0", xs1, pwr["bottom"] - STACK - 2 * G)
    xl1 = hdmi["right_x"] + GAP + 5.08               # screen column
    place("LCD1", "HDMI", xl1, hdmi["y"])
    usb = place("U1", "USB2_0", xs1, hdmi["bottom"] - STACK - 2 * G)
    place("LCD1", "TOUCH", xl1, usb["y"])
    audio = place("LCD1", "AUDIO", xl1, usb["bottom"] - STACK - 4 * G)

    # W1 mains PSU -> Pi USB-C
    cable("W1", "USB-C cable (PSU captive), 5.1 V 5 A PD",
          "PS1", "P", "U1", "PWR",
          lambda a, b: {"VBUS": "VBUS_5V1", "CC": "USBC_CC"}.get(a, "GND"))
    stub("AC_L", ("PS1", "P", "AC_L"), -1)
    stub("AC_N", ("PS1", "P", "AC_N"), -1)
    text(psu["left_x"] - 3 * G, psu["top"] + 1.27, "230 V AC mains", align="bottom-center")

    # W2 micro-HDMI -> HDMI A
    cable("W2", "micro-HDMI (D) -> HDMI (A) cable: video 800x480 + HDMI audio",
          "U1", "HDMI0", "LCD1", "HDMI",
          lambda a, b: "GND" if is_ground(a) else f"HDMI0_{a}")
    # W3 USB-A -> micro-B Touch
    cable("W3", "USB-A -> micro-USB DATA cable: touch (USB HID) + screen power ~400 mA",
          "U1", "USB2_0", "LCD1", "TOUCH",
          lambda a, b: "GND" if a == "GND" else f"USB2_0_{a}")
    for pin, net in (("L", "HEADSET_L"), ("R", "HEADSET_R"), ("GND", "HEADSET_GND")):
        stub(net, ("LCD1", "AUDIO", pin), -1)
    text(audio["left_x"] - 3 * G, audio["top"] + 1.27, "Headset (V1 sound = HDMI audio)", align="bottom-right")

    # ---------------------------------------------- column 2: DSI, power, fan
    x2 = place("LCD1", "HDMI", xl1, hdmi["y"])["right_x"] + 12 * G
    disp = place("U1", "DISP1", x2, 0)
    xl2 = disp["right_x"] + GAP + 5.08
    place("LCD2", "DSI", xl2, 0)
    gpio = place("U1", "GPIO", x2, disp["bottom"] - STACK - 2 * G)
    # 4in power lead on pin 4 (5V) and pin 6 (GND): rows 2 and 3 of the even column
    place("LCD2", "PWR", gpio["right_x"] + GAP + 5.08, gpio["y"] - G)
    fan = place("U1", "FAN", x2, gpio["bottom"] - STACK - 2 * G)
    place("M1", "FAN", fan["right_x"] + GAP + 5.08, fan["y"])

    cable("W4", "FFC 22-pin 0.5 mm 200 mm REVERSE (supplied): DSI + touch I2C + 3V3",
          "U1", "DISP1", "LCD2", "DSI",
          lambda a, b: "GND" if is_ground(a) else ("3V3" if a == "3V3" else f"DSI1_{a}"))
    cable("W5", "2-wire lead: red = 5V (pin 4), black = GND (pin 6)",
          "U1", "GPIO", "LCD2", "PWR",
          lambda a, b: "5V" if b == "5V" else "GND", rows=("5V@2", "GND@1"))
    text(gpio["right_x"] + GAP / 2 + 5.08, gpio["bottom"] - 1.27,
         "! GPIO 5V is not fused: one pin off can kill the Pi. Power off before plugging.",
         layer=97, align="top-center")
    cable("W6", "Fan lead JST-SH 4p (captive)", "U1", "FAN", "M1", "FAN",
          lambda a, b: "GND" if a == "GND" else f"FAN_{a}")

    # ------------------------------------------------------ title and frame
    right = place("M1", "FAN", fan["right_x"] + GAP + 5.08, fan["y"])["right_x"] + 8 * G
    right = max(right, xl2 + 60)
    left, top = psu["left_x"] - 16 * G, 16 * G
    bottom = min(audio["bottom"], fan["bottom"]) - 12 * G
    for x1, y1, x2_, y2 in [(left, top, right, top), (right, top, right, bottom),
                            (right, bottom, left, bottom), (left, bottom, left, top)]:
        plain.append(f'<wire x1="{fmt(x1)}" y1="{fmt(y1)}" x2="{fmt(x2_)}" y2="{fmt(y2)}" width="0.4064" layer="94"/>')
    text(left + 2 * G, top - 3 * G, "D2K V1 - bench interconnect", size=3.81, layer=94)
    text(left + 2 * G, top - 5.5 * G,
         "Raspberry Pi 5 on mains USB-C + Waveshare 5inch HDMI LCD (H) upper + Waveshare 4-DSI-TOUCH-A lower touch",
         size=1.778, layer=97)
    text(left + 2 * G, bottom + 4 * G,
         "Generated by fusion/electronics/gen_d2k_v1_sch.py - warnings and cable details: fusion/wiring.md",
         size=1.27, layer=97)
    text(left + 2 * G, bottom + 2 * G,
         "Unused: Pi HDMI1, DISP0, USB2_1, USB3, Ethernet; 5in DC micro-USB, VGA, speaker header.",
         size=1.27, layer=97)

    parts_xml = "\n".join(f'<part name="{p}" library="D2K" deviceset="{ds}" device="" value="{escape(v)}"/>'
                          for p, (ds, v) in PARTS.items())
    inst_xml = "\n".join(f'<instance part="{p}" gate="{g}" x="{fmt(x)}" y="{fmt(y)}"/>'
                         for (p, g), (x, y) in instances.items())
    nets_xml = "\n".join(f'<net name="{escape(n)}" class="0">\n' + "\n".join(segs) + "\n</net>"
                         for n, segs in nets.items())
    return (
        lib.HEADER_XML
        + '<schematic xreflabel="%F%N/%S.%C%R" xrefpart="/%S.%C%R">\n'
        + "<libraries>\n" + lib.library_xml("D2K") + "</libraries>\n"
        + "<attributes>\n</attributes>\n<variantdefs>\n</variantdefs>\n"
        + '<classes>\n<class number="0" name="default" width="0" drill="0">\n</class>\n</classes>\n'
        + f"<parts>\n{parts_xml}\n</parts>\n"
        + "<sheets>\n<sheet>\n<plain>\n" + "\n".join(plain) + "\n</plain>\n"
        + f"<instances>\n{inst_xml}\n</instances>\n<busses>\n</busses>\n<nets>\n{nets_xml}\n</nets>\n"
        + "</sheet>\n</sheets>\n</schematic>\n</drawing>\n</eagle>\n"
    )


if __name__ == "__main__":
    out = Path(__file__).with_name("D2K_V1.sch")
    out.write_text(build(), encoding="utf-8")
    print(f"wrote {out}: {len(instances)} gate instances, {len(nets)} nets")
