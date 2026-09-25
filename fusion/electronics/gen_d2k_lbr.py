"""Generate D2K.lbr, the EAGLE 9 / Fusion Electronics library of the D2K V1 modules.

The V1 electronics are off-the-shelf modules wired with cables, so every
device here is symbol-only (no package): the schematic documents which
connector pin goes where. Mechanical volumes live in the Fusion design
D2K_Electronics_V1. Add packages only when a custom carrier PCB is drawn.

Run with any Python 3:  python gen_d2k_lbr.py  (writes D2K.lbr next to it)
"""

import math
from pathlib import Path
from xml.sax.saxutils import escape

GRID = 2.54  # 0.1 inch, EAGLE's default schematic grid

# ---------------------------------------------------------------- pinouts ---
# Each connector: list of (connector pin number, signal name, EAGLE direction).
# Signal names are shared between both ends of a cable so nets read the same.
# List order is the symbol's row order: both ends of a cable use the same
# order so the schematic draws each cable as straight wires.

MICRO_HDMI_D = [  # HDMI type D receptacle (Raspberry Pi 5 HDMI0/HDMI1), rows in type A order
    (3, "TMDS_D2+", "pas"), (4, "TMDS_D2_SH", "pas"), (5, "TMDS_D2-", "pas"),
    (6, "TMDS_D1+", "pas"), (7, "TMDS_D1_SH", "pas"), (8, "TMDS_D1-", "pas"),
    (9, "TMDS_D0+", "pas"), (10, "TMDS_D0_SH", "pas"), (11, "TMDS_D0-", "pas"),
    (12, "TMDS_CLK+", "pas"), (13, "TMDS_CLK_SH", "pas"), (14, "TMDS_CLK-", "pas"),
    (15, "CEC", "pas"), (2, "UTILITY", "pas"), (17, "DDC_SCL", "pas"),
    (18, "DDC_SDA", "pas"), (16, "DDC_GND", "pas"), (19, "+5V", "pas"),
    (1, "HPD", "pas"),
]

HDMI_A = [  # HDMI type A receptacle (Waveshare 5inch HDMI LCD (H) "Display")
    (1, "TMDS_D2+", "pas"), (2, "TMDS_D2_SH", "pas"), (3, "TMDS_D2-", "pas"),
    (4, "TMDS_D1+", "pas"), (5, "TMDS_D1_SH", "pas"), (6, "TMDS_D1-", "pas"),
    (7, "TMDS_D0+", "pas"), (8, "TMDS_D0_SH", "pas"), (9, "TMDS_D0-", "pas"),
    (10, "TMDS_CLK+", "pas"), (11, "TMDS_CLK_SH", "pas"), (12, "TMDS_CLK-", "pas"),
    (13, "CEC", "pas"), (14, "UTILITY", "pas"), (15, "DDC_SCL", "pas"),
    (16, "DDC_SDA", "pas"), (17, "DDC_GND", "pas"), (18, "+5V", "pas"),
    (19, "HPD", "pas"),
]

# Raspberry Pi 22-pin 0.5 mm MIPI connector (Pi 5 CAM/DISP0-1, Waveshare
# 4-DSI-TOUCH-A). The "reverse" FFC keeps pin n on pin n.
MIPI_22 = [
    (1, "GND@1", "pwr"), (2, "D0_N", "pas"), (3, "D0_P", "pas"), (4, "GND@2", "pwr"),
    (5, "D1_N", "pas"), (6, "D1_P", "pas"), (7, "GND@3", "pwr"),
    (8, "CLK_N", "pas"), (9, "CLK_P", "pas"), (10, "GND@4", "pwr"),
    (11, "D2_N", "pas"), (12, "D2_P", "pas"), (13, "GND@5", "pwr"),
    (14, "D3_N", "pas"), (15, "D3_P", "pas"), (16, "GND@6", "pwr"),
    (17, "IO0", "pas"), (18, "IO1", "pas"), (19, "GND@7", "pwr"),
    (20, "SCL", "pas"), (21, "SDA", "pas"), (22, "3V3", "pwr"),
]

GPIO_40 = [
    (1, "3V3@1", "pwr"), (2, "5V@1", "pwr"), (3, "GPIO2_SDA1", "io"), (4, "5V@2", "pwr"),
    (5, "GPIO3_SCL1", "io"), (6, "GND@1", "pwr"), (7, "GPIO4", "io"), (8, "GPIO14_TXD", "io"),
    (9, "GND@2", "pwr"), (10, "GPIO15_RXD", "io"), (11, "GPIO17", "io"), (12, "GPIO18_PCM_CLK", "io"),
    (13, "GPIO27", "io"), (14, "GND@3", "pwr"), (15, "GPIO22", "io"), (16, "GPIO23", "io"),
    (17, "3V3@2", "pwr"), (18, "GPIO24", "io"), (19, "GPIO10_MOSI", "io"), (20, "GND@4", "pwr"),
    (21, "GPIO9_MISO", "io"), (22, "GPIO25", "io"), (23, "GPIO11_SCLK", "io"), (24, "GPIO8_CE0", "io"),
    (25, "GND@5", "pwr"), (26, "GPIO7_CE1", "io"), (27, "ID_SD", "io"), (28, "ID_SC", "io"),
    (29, "GPIO5", "io"), (30, "GND@6", "pwr"), (31, "GPIO6", "io"), (32, "GPIO12", "io"),
    (33, "GPIO13", "io"), (34, "GND@7", "pwr"), (35, "GPIO19_PCM_FS", "io"), (36, "GPIO16", "io"),
    (37, "GPIO26", "io"), (38, "GPIO20_PCM_DIN", "io"), (39, "GND@8", "pwr"), (40, "GPIO21_PCM_DOUT", "io"),
]

USB2_A = [(1, "VBUS", "pas"), (2, "D-", "pas"), (3, "D+", "pas"), (4, "GND", "pas")]
USB3_A = USB2_A + [(5, "SSRX-", "pas"), (6, "SSRX+", "pas"), (7, "GND_DRAIN", "pas"),
                   (8, "SSTX-", "pas"), (9, "SSTX+", "pas")]
USB_C_SINK = [("A4", "VBUS", "pas"), ("A5", "CC1", "pas"), ("A1", "GND", "pas"),  # VBUS also A9/B4/B9,
              ("B5", "CC2", "pas")]                                                  # GND also A12/B1/B12
MICRO_B = [(1, "VBUS", "pas"), (2, "D-", "pas"), (3, "D+", "pas"), (5, "GND", "pas"), (4, "ID", "pas")]
MICRO_B_POWER = [(1, "VBUS", "pas"), (5, "GND", "pas")]
FAN_4 = [(1, "5V", "pas"), (2, "PWM", "pas"), (3, "GND", "pas"), (4, "TACH", "pas")]

# Waveshare ESP32-S3-Zero (ESP32-S3FH4R2): castellated rows 15.24 mm apart,
# numbered L1-L9 / R1-R9 from the USB-C end. The 5V/3V3 pins are NOT named
# like the Pi rails so EAGLE does not merge them into the Pi's 5V/3V3 nets.
ESP32_S3_ZERO_MAIN = [
    ("L1", "5V_IN", "pas"), ("L2", "GND@1", "pwr"), ("L3", "3V3_OUT", "pas"),
    ("L4", "GPIO1", "io"), ("L5", "GPIO2", "io"), ("L6", "GPIO3", "io"),
    ("L7", "GPIO4", "io"), ("L8", "GPIO5", "io"), ("L9", "GPIO6", "io"),
    ("R1", "GPIO43_TX", "io"), ("R2", "GPIO44_RX", "io"), ("R3", "GPIO13", "io"),
    ("R4", "GPIO12", "io"), ("R5", "GPIO11", "io"), ("R6", "GPIO10", "io"),
    ("R7", "GPIO9", "io"), ("R8", "GPIO8", "io"), ("R9", "GPIO7", "io"),
]
# Solder pads (no header): three on the front next to R9, eight on the back.
ESP32_S3_ZERO_PADS = [
    ("F", "GPIO14", "io"), ("F", "GPIO15", "io"), ("F", "GPIO16", "io"),
    ("B", "GPIO17", "io"), ("B", "GPIO18", "io"), ("B", "GPIO38", "io"), ("B", "GPIO39", "io"),
    ("B", "GPIO40", "io"), ("B", "GPIO41", "io"), ("B", "GPIO42", "io"), ("B", "GPIO45", "io"),
]
USB_C_DEVICE = [("A4", "VBUS", "pas"), ("A7", "D-", "pas"), ("A6", "D+", "pas"), ("A1", "GND", "pas")]

# Waveshare WM8960 Audio Board header P2 (8x2), from the board schematic
# netlist: 5 = SCL, 7 = SDA (check the silkscreen), 13 = DAC data in
# (silkscreen TXSDA), 14 = ADC data out (RXSDA), 15/16 = MCLK via jumper P1.
WM8960_HEADER = [
    (1, "VCC@1", "pas"), (2, "VCC@2", "pas"), (3, "GND@1", "pas"), (4, "GND@2", "pas"),
    (5, "SCL", "pas"), (6, "NC@6", "nc"), (7, "SDA", "pas"), (8, "NC@8", "nc"),
    (9, "CLK@9", "pas"), (10, "CLK@10", "pas"), (11, "WS@11", "pas"), (12, "WS@12", "pas"),
    (13, "TXSDA_DAC_IN", "pas"), (14, "RXSDA_ADC_OUT", "pas"), (15, "MCLK_RX", "pas"), (16, "MCLK_TX", "pas"),
]
WM8960_SPK = [(1, "LP", "pas"), (2, "LN", "pas"), (3, "RN", "pas"), (4, "RP", "pas")]

# ---------------------------------------------------------------- devices ---
# gates: (gate name, symbol name, symbol title, pin list, pins side)

WS4_URL = "https://www.waveshare.com/4-dsi-touch-a.htm"
WS5_URL = "https://www.waveshare.com/wiki/5inch_HDMI_LCD_(H)"
PI5_URL = "https://datasheets.raspberrypi.com/rpi5/raspberry-pi-5-mechanical-drawing.pdf"

DEVICES = [
    {
        "name": "RASPBERRY_PI_5", "prefix": "U",
        "desc": "Raspberry Pi 5 (4/8 GB). D2K V1 compute. Board 85 x 56 mm, 4x M2.5 on 58 x 49.",
        "attrs": {
            "MANUFACTURER": "Raspberry Pi Ltd", "MPN": "Raspberry Pi 5",
            "SUPPLY": "5.1 V USB-C PD, 5 A (27 W PSU)",
            "USB_BUDGET": "1.6 A total on the 4 USB-A ports with a 5 A PSU, 600 mA otherwise",
            "DOC": PI5_URL,
            "VERIFY": "MIPI_22 IO0/IO1 roles and FAN pin order are from the generic RPi pinout, check before wiring",
        },
        "gates": [
            ("PWR", "RPI5_USBC_PWR", "USB-C power in", USB_C_SINK, "L"),
            ("HDMI0", "HDMI_D", "micro-HDMI", MICRO_HDMI_D, "R"),
            ("HDMI1", "HDMI_D", "micro-HDMI", MICRO_HDMI_D, "R"),
            ("DISP0", "MIPI_22", "CAM/DISP 22p", MIPI_22, "R"),
            ("DISP1", "MIPI_22", "CAM/DISP 22p", MIPI_22, "R"),
            ("GPIO", "RPI_GPIO_40", "40-pin header", GPIO_40, "LR"),
            ("USB2_0", "USB2_A", "USB 2.0 A", USB2_A, "R"),
            ("USB2_1", "USB2_A", "USB 2.0 A", USB2_A, "R"),
            ("USB3_0", "USB3_A", "USB 3.0 A", USB3_A, "R"),
            ("USB3_1", "USB3_A", "USB 3.0 A", USB3_A, "R"),
            ("FAN", "FAN_4", "Fan header JST-SH 4p", FAN_4, "R"),
        ],
    },
    {
        "name": "RPI5_ACTIVE_COOLER", "prefix": "M",
        "desc": "Raspberry Pi Active Cooler for Pi 5 (SC1148). 63.5 x 42.5 x 13.7 mm, blower fan, PWM + tach, 5 V from the Pi fan header.",
        "attrs": {"MANUFACTURER": "Raspberry Pi Ltd", "MPN": "SC1148", "SUPPLY": "5 V from Pi FAN header",
                  "DOC": "https://pip.raspberrypi.com/documents/RP-008188-DS-raspberry-pi-active-cooler-product-brief.pdf"},
        "gates": [("FAN", "FAN_4", "Fan lead JST-SH 4p", FAN_4, "L")],
    },
    {
        "name": "WAVESHARE_5IN_HDMI_LCD_H", "prefix": "LCD",
        "desc": "Waveshare 5inch HDMI LCD (H): 800x480 TFT, 5-point capacitive USB touch, toughened glass, "
                "RTD2660 scaler. D2K upper screen. PCB/glass 121 x 76 mm, holes 109 x 84.",
        "attrs": {
            "MANUFACTURER": "Waveshare", "MPN": "5inch HDMI LCD (H)",
            "SUPPLY": "5 V, about 400 mA, from DC micro-USB or the Touch micro-USB",
            "TOUCH": "USB HID, 5-point capacitive", "RESOLUTION": "800x480 @ 60 Hz",
            "AUDIO": "HDMI audio to 3.5 mm jack and 4-pin speaker header",
            "DOC": WS5_URL,
            "VERIFY": "Speaker header pin order not published: identify L/R before wiring speakers",
        },
        "gates": [
            ("HDMI", "HDMI_A", "HDMI type A (Display)", HDMI_A, "L"),
            ("TOUCH", "USB_MICRO_B", "micro-USB Touch", MICRO_B, "L"),
            ("DC", "USB_MICRO_B_PWR", "micro-USB DC power", MICRO_B_POWER, "L"),
            ("AUDIO", "AUDIO_JACK", "3.5 mm jack", [("T", "L", "pas"), ("R", "R", "pas"), ("S", "GND", "pas")], "L"),
            ("SPK", "SPK_HEADER_4", "Speaker header 4p", [(1, "SPK1", "pas"), (2, "SPK2", "pas"),
                                                          (3, "SPK3", "pas"), (4, "SPK4", "pas")], "L"),
        ],
    },
    {
        "name": "WAVESHARE_4_DSI_TOUCH_A", "prefix": "LCD",
        "desc": "Waveshare 4-DSI-TOUCH-A (SKU 34354): 4inch IPS 480x800 (landscape 800x480), MIPI DSI, "
                "5-point capacitive touch, optical bonding, aluminium back. D2K lower touch screen. "
                "Outline 108.3 x 65.1 x 5.8 mm, AA 86.4 x 51.84, 8x M2.5 (corners 100 x 56, Pi pattern 58 x 49).",
        "attrs": {
            "MANUFACTURER": "Waveshare", "MPN": "4-DSI-TOUCH-A", "SKU": "34354",
            "SUPPLY": "4.75-5.25 V, 180 mA typ, via 2-wire lead to Pi GPIO 5V/GND",
            "TOUCH": "Goodix, I2C 0x14 on the DSI cable I2C (i2c-10 on Pi 5)",
            "OVERLAY": "dtoverlay=vc4-kms-dsi-waveshare-panel-v2,4_0_inch_a (add ,dsi0 on DISP0)",
            "CABLE": "FFC 22-pin 0.5 mm 200 mm reverse (supplied)",
            "DOC": WS4_URL,
        },
        "gates": [
            ("DSI", "MIPI_22", "DSI 22p 0.5 mm", MIPI_22, "L"),
            ("PWR", "PWR_2", "Power 2p", [(1, "5V", "pwr"), (2, "GND", "pwr")], "L"),
        ],
    },
    {
        "name": "PSU_USBC_27W", "prefix": "PS",
        "desc": "Raspberry Pi 27 W USB-C power supply (mains). V1 bench power: 5.1 V 5 A, PD 9 V 3 A / 12 V 2.25 A / 15 V 1.8 A.",
        "attrs": {"MANUFACTURER": "Raspberry Pi Ltd", "MPN": "27W USB-C PSU", "INPUT": "100-240 V AC",
                  "OUTPUT": "5.1 V 5 A (PD)"},
        "gates": [("P", "PSU_USBC", "USB-C PSU", [("L", "AC_L", "pas"), ("N", "AC_N", "pas"),
                                                  ("A4", "VBUS", "pas"), ("A5", "CC", "pas"),
                                                  ("A1", "GND", "pas")], "LR2")],
    },
    {
        "name": "ESP32_S3_ZERO", "prefix": "U",
        "desc": "Waveshare ESP32-S3-Zero (ESP32-S3FH4R2, 4 MB flash, 2 MB PSRAM). D2K embedded controller: "
                "USB HID gamepad to the Pi. 18 x 23.5 mm, 2 x 9 castellated pins 2.54 mm pitch, rows 15.24 mm apart "
                "(fits a breadboard). On board: WS2812 on GPIO21, BOOT on GPIO0, native USB on GPIO19/20 (USB-C). "
                "GPIO33-37 used by the PSRAM. ADC1 = GPIO1-10. Strapping: GPIO0, 3, 45, 46.",
        "attrs": {
            "MANUFACTURER": "Waveshare", "MPN": "ESP32-S3-Zero",
            "SUPPLY": "5V pin / USB-C 3.7-6 V, >= 500 mA; 3V3_OUT from the on-board LDO",
            "LOGIC": "3.3 V, not 5 V tolerant",
            "DOC": "https://www.waveshare.com/wiki/ESP32-S3-Zero",
        },
        "gates": [
            ("MAIN", "ESP32_S3_ZERO", "ESP32-S3-Zero castellated", ESP32_S3_ZERO_MAIN, "S9"),
            ("PADS", "ESP32_S3_ZERO_PADS", "Solder pads F=front B=back", ESP32_S3_ZERO_PADS, "R"),
            ("USB", "USB_C_DEVICE", "USB-C (native USB)", USB_C_DEVICE, "L"),
        ],
    },
    {
        "name": "TACT_SWITCH_6X6", "prefix": "SW",
        "desc": "6 x 6 mm through-hole tact switch (bench stand-in for the New 3DS XL membrane buttons). "
                "Pins 1-2 and 3-4 are joined inside; the switch closes 1/2 to 3/4.",
        "attrs": {"MPN": "6x6 tact switch", "VERIFY": "Check which pin pairs are joined with a multimeter"},
        "gates": [("S", "TACT_SWITCH", "6x6 tact", [("1/2", "P1", "pas"), ("3/4", "P2", "pas")], "S1")],
    },
    {
        "name": "CIRCLE_PAD_N3DSXL", "prefix": "JS",
        "desc": "New 3DS XL Circle Pad module (KasynParts), 2 analog axes on a 4-contact flex. "
                "PINOUT NOT VERIFIED: identify VCC, GND, X, Y with a multimeter before wiring (Notion).",
        "attrs": {"SUPPLY": "3.3 V from the ESP32 (ADC full scale ~3.1 V at 11 dB attenuation)",
                  "VERIFY": "Pin order and supply voltage unknown; needs a 4-contact flex breakout",
                  "DOC": "https://kasynparts.com/product/original-3d-analog-joystick-module-stick-replacement-for-new-2ds-xl-new-3ds-xl-new-3ds/"},
        "gates": [("P", "CIRCLE_PAD", "Circle Pad (pinout TBC)",
                   [(1, "VCC", "pas"), (2, "X", "pas"), (3, "Y", "pas"), (4, "GND", "pas")], "R")],
    },
    {
        "name": "WM8960_AUDIO_BOARD", "prefix": "U",
        "desc": "Waveshare WM8960 Audio Board (SKU 15019): WM8960 codec, I2C control (0x1A), I2S audio, "
                "24 MHz crystal as MCLK, 1 W/ch class-D speaker outputs (8 ohm), 3.5 mm headset jack, MEMS mic. "
                "Runs from 3.3 V only: the speaker supply (SPKVDD) is the same 3.3 V rail.",
        "attrs": {
            "MANUFACTURER": "Waveshare", "MPN": "WM8960 Audio Board", "SKU": "15019",
            "SUPPLY": "3.3 V (logic, codec AND speaker amplifier)",
            "SPEAKER": "8 ohm, 1 W/ch at 5 V SPKVDD; ~0.4 W/ch at the board's 3.3 V",
            "I2C_ADDR": "0x1A",
            "DOC": "https://www.waveshare.com/wiki/WM8960_Audio_Board",
            "VERIFY": "Header pins 5/7 (SCL/SDA) from the schematic netlist: check the silkscreen",
        },
        "gates": [
            ("HDR", "WM8960_HEADER", "Header P2 8x2", WM8960_HEADER, "LR"),
            ("SPK", "WM8960_SPK", "SPK J1 4p", WM8960_SPK, "R"),
        ],
    },
    {
        "name": "SPEAKER_8R_2W", "prefix": "LS",
        "desc": "Waveshare 2030 Cavity Speaker Type B (SKU 27859): 8 ohm 2 W, 20 x 30 x 6.8 mm, "
                "2-pin PH1.25 plug on ~120 mm wires (does not mate with the WM8960 board's 4-pin SPK header).",
        "attrs": {"MANUFACTURER": "Waveshare", "MPN": "2030 Cavity Speaker Type B", "SKU": "27859",
                  "DOC": "https://www.waveshare.com/8ohm-2w-speaker-b.htm"},
        "gates": [("S", "SPEAKER", "Speaker 8R PH1.25", [(1, "SPK+", "pas"), (2, "SPK-", "pas")], "L")],
    },
]

# --------------------------------------------------------------- XML output --


def fmt(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


def symbol_layout(pins, side):
    """Split pins into left/right columns and size the box.

    Pin connection points: left pins at (-5.08, -GRID*(i+1)), right pins at
    (width + 5.08, -GRID*(i+1)), relative to the symbol origin.
    """
    if side == "LR":  # split evenly (40-pin header: odd pins left, even right)
        left = [p for p in pins if int(p[0]) % 2 == 1]
        right = [p for p in pins if int(p[0]) % 2 == 0]
    elif side == "LR2":  # PSU: mains in on the left, USB-C out on the right
        left, right = pins[:2], pins[2:]
    elif side.startswith("S"):  # "S<n>": first n pins on the left, the rest on the right
        n = int(side[1:])
        left, right = pins[:n], pins[n:]
    elif side == "L":
        left, right = pins, []
    else:
        left, right = [], pins
    # Pin names are drawn inside the box (~1.6 mm per character at the default size)
    longest = max(len(p[1].split("@")[0]) for p in pins)
    sides = 2 if left and right else 1
    width = GRID * max(8, math.ceil((longest * sides * 1.6 + 6) / GRID))
    return left, right, width, max(len(left), len(right))


def symbol_xml(name, title, pins, side):
    left, right, width, rows = symbol_layout(pins, side)
    top, bottom = GRID, -GRID * rows - GRID
    out = [f'<symbol name="{name}">']
    for x1, y1, x2, y2 in [(0, top, width, top), (width, top, width, bottom),
                           (width, bottom, 0, bottom), (0, bottom, 0, top)]:
        out.append(f'<wire x1="{fmt(x1)}" y1="{fmt(y1)}" x2="{fmt(x2)}" y2="{fmt(y2)}" width="0.254" layer="94"/>')
    out.append(f'<text x="0" y="{fmt(top + 1.27)}" size="1.778" layer="95">&gt;NAME</text>')
    out.append(f'<text x="0" y="{fmt(bottom - 2.54)}" size="1.778" layer="96">&gt;VALUE</text>')
    out.append(f'<text x="{fmt(width / 2)}" y="{fmt(top - 1.9)}" size="1.27" layer="97" align="center">{escape(title)}</text>')
    # Symbol-only devices have no pads, so the connector pin number is drawn
    # as text on each pin line: that is what the bench wiring is done by.
    for i, (num, sig, d) in enumerate(left):
        y = -GRID * (i + 1)
        out.append(f'<pin name="{escape(sig)}" x="{fmt(-5.08)}" y="{fmt(y)}" length="middle" direction="{d}"/>')
        out.append(f'<text x="-2.54" y="{fmt(y + 0.3)}" size="1.016" layer="97" align="bottom-center">{escape(str(num))}</text>')
    for i, (num, sig, d) in enumerate(right):
        y = -GRID * (i + 1)
        out.append(f'<pin name="{escape(sig)}" x="{fmt(width + 5.08)}" y="{fmt(y)}" length="middle" direction="{d}" rot="R180"/>')
        out.append(f'<text x="{fmt(width + 2.54)}" y="{fmt(y + 0.3)}" size="1.016" layer="97" align="bottom-center">{escape(str(num))}</text>')
    out.append("</symbol>")
    return "\n".join(out)


def pin_table(gates):
    rows = []
    for gname, _, title, pins, _ in gates:
        pinstr = ", ".join(f"{n}={s.split('@')[0]}" for n, s, _ in pins)
        rows.append(f"<b>{escape(gname)}</b> ({escape(title)}): {escape(pinstr)}")
    return "<br>".join(rows)


def gate_symbols():
    """Map (device, gate) -> (symbol name, title, pins, side).

    The same connector drawn facing the other way (Pi end vs screen end) gets
    its own symbol, suffixed with its side.
    """
    seen, out = {}, {}
    for dev in DEVICES:
        for gname, sname, title, pins, side in dev["gates"]:
            if seen.get(sname, side) != side:
                sname = f"{sname}_{side}"
            seen.setdefault(sname, side)
            out[(dev["name"], gname)] = (sname, title, pins, side)
    return out


LAYERS_XML = "\n".join(  # Pins (93) hidden: its direction markers clutter the connector rows
    f'<layer number="{n}" name="{nm}" color="{c}" fill="1" visible="{"no" if n == 93 else "yes"}" active="yes"/>'
    for n, nm, c in [(91, "Nets", 2), (92, "Busses", 1), (93, "Pins", 2), (94, "Symbols", 4),
                     (95, "Names", 7), (96, "Values", 7), (97, "Info", 7), (98, "Guide", 6)])

HEADER_XML = (
    '<?xml version="1.0" encoding="utf-8"?>\n<!DOCTYPE eagle SYSTEM "eagle.dtd">\n'
    '<eagle version="9.6.2">\n<drawing>\n<settings>\n<setting alwaysvectorfont="no"/>\n'
    '<setting verticaltext="up"/>\n</settings>\n'
    '<grid distance="0.1" unitdist="inch" unit="inch" style="lines" multiple="1" display="no" '
    'altdistance="0.01" altunitdist="inch" altunit="inch"/>\n'
    f"<layers>\n{LAYERS_XML}\n</layers>\n")


def library_xml(name=None):
    """The <library> element; name is set when embedded in a schematic."""
    gsyms = gate_symbols()
    symbols, done = [], set()
    for sname, title, pins, side in gsyms.values():
        if sname not in done:
            done.add(sname)
            symbols.append(symbol_xml(sname, title, pins, side))
    devicesets = []
    for dev in DEVICES:
        gates_xml = []
        for gi, (gname, *_rest) in enumerate(dev["gates"]):
            sname = gsyms[(dev["name"], gname)][0]
            gates_xml.append(f'<gate name="{gname}" symbol="{sname}" x="{fmt(gi * 50.8)}" y="0" addlevel="next"/>')
        attrs = "".join(f'<attribute name="{k}" value="{escape(v, {chr(34): "&quot;"})}"/>'
                        for k, v in dev["attrs"].items())
        desc = escape(f"<b>{dev['desc']}</b><br><br>Connector pin = signal:<br>") + escape(pin_table(dev["gates"]))
        devicesets.append(
            f'<deviceset name="{dev["name"]}" prefix="{dev["prefix"]}" uservalue="yes">\n'
            f"<description>{desc}</description>\n"
            f"<gates>\n" + "\n".join(gates_xml) + "\n</gates>\n"
            f'<devices>\n<device name="">\n<technologies>\n<technology name="">{attrs}</technology>\n'
            f"</technologies>\n</device>\n</devices>\n</deviceset>"
        )
    lib_desc = escape("<b>D2K V1 modules</b><br>Raspberry Pi 5, Active Cooler, Waveshare 5inch HDMI LCD (H), "
                      "Waveshare 4-DSI-TOUCH-A, 27 W USB-C PSU, ESP32-S3-Zero, 6x6 tact switch, New 3DS XL "
                      "Circle Pad, WM8960 Audio Board, 8 ohm speaker. Symbol-only devices for the system "
                      "interconnect schematic. Generated by gen_d2k_lbr.py.")
    open_tag = f'<library name="{name}">' if name else "<library>"
    return (
        f"{open_tag}\n<description>{lib_desc}</description>\n"
        "<packages>\n</packages>\n<symbols>\n" + "\n".join(symbols) + "\n</symbols>\n"
        "<devicesets>\n" + "\n".join(devicesets) + "\n</devicesets>\n</library>\n"
    )


def build():
    return HEADER_XML + library_xml() + "</drawing>\n</eagle>\n"


if __name__ == "__main__":
    out = Path(__file__).with_name("D2K.lbr")
    out.write_text(build(), encoding="utf-8")
    print(f"wrote {out}")
