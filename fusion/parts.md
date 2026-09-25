# Part specs used in the Fusion models

Confidence tags: **[drawing]** read from the vendor's dimensioned drawing,
**[STEP]** measured from the vendor STEP, **[spec]** vendor text, **[est]**
estimated (to be measured on the real part). Coordinates are those of the
`scripts/electronics_v1/` scripts.

## Raspberry Pi 5 — compute (owned)

- Board 85 × 56 × 1.6 mm, corner radius 3 **[drawing]**.
- 4 × M2.5 holes ø2.7 at (3.5, 3.5), (61.5, 3.5), (3.5, 52.5), (61.5, 52.5):
  58 × 49 pattern **[drawing]**.
- Active Cooler holes ø3 at about (3.4, 9.5) and (61.4, 46.0) **[drawing, scaled]**.
- Edge connectors (bottom edge, x of centre): USB-C power 11.2, micro-HDMI0
  25.8, micro-HDMI1 39.2 **[drawing]**. Right edge: Ethernet centre y 10.2,
  USB stacks y 29.1 (USB 3) and 47 (USB 2); Ethernet overhangs 3 mm
  **[drawing]**. Heights: USB stack 15.6, RJ45 13.5, micro-HDMI 3.4, USB-C 3.2
  above the PCB **[est]**.
- Two 22-pin 0.5 mm MIPI connectors (CAM/DISP 0/1) at x ≈ 47–50 and 53–56,
  y ≈ 3.4–15.9 **[drawing, scaled]**; which is DISP1 is **[est]**.
- 40-pin header centred at x 32.5, y 52.5 **[drawing]**; fan header right of the
  header end **[est]**.
- Power: 5.1 V 5 A USB-C PD; USB ports 1.6 A total with a 5 A PSU **[spec]**.
- Official detailed model: Fusion `01_ELECTRONICS/Raspberry_Pi_5/rpi-5b_no_graphics`
  (from `RP-010083-CA-1-rpi-5 3D STEP`, MIT licence); bounds 88.5 × 57.63 mm,
  z 1.616–23.36 mm, 2711 bodies **[STEP]**.
- Source: <https://datasheets.raspberrypi.com/rpi5/raspberry-pi-5-mechanical-drawing.pdf>

## Raspberry Pi Active Cooler SC1148 (ordered)

- 63.5 × 42.5 mm footprint, 13.7 mm tall; fan section 30 × 30 mm; two
  spring-loaded push pins on opposite corners **[drawing]**. The base plate
  does not extend under the lower-right corner: the Pi's MIPI connectors stay
  exposed **[photo]**.
- 5 V from the Pi fan header, PWM + tach, 8000 rpm max, 1.09 CFM **[spec]**.
- Height above the Pi PCB (base on the SoC) **[est]**: top of fins 13.3 mm,
  push pins 15.3 mm.
- Source: <https://pip.raspberrypi.com/documents/RP-008188-DS-raspberry-pi-active-cooler-product-brief.pdf>

## Waveshare 4-DSI-TOUCH-A (SKU 34354) — lower touch screen (ordered)

- Outline 108.3 × 65.1 mm, active area 86.4 × 51.84 mm (centred), body 5.8 mm
  **[drawing]**.
- Back: 8 × M2.5 threads, corners on 100 × 56, inner on 58 × 49 (Pi pattern),
  inner holes 35.15 mm from the right edge in the rear view **[drawing]**.
  Boss heights: corner 2.1 mm, inner 5.0 mm **[est: drawing is ambiguous]**.
- Adapter board 14 × 40 mm, 3 mm deep, with the 22-pin DSI connector and a
  2-pin power connector (white JST) **[drawing + photo]**.
- 480 × 800 IPS (used as 800 × 480), 60 Hz, 5-point capacitive touch (Goodix,
  I²C 0x14 on the DSI cable), optical bonding, aluminium back **[spec]**.
- Supply 4.75–5.25 V, 180 mA typical **[spec]**; peak with full backlight
  unknown.
- Pi 5: FFC 22-pin 200 mm reverse to DSI1; power lead to GPIO 5 V/GND **[spec]**.
- Sources: <https://www.waveshare.com/4-dsi-touch-a.htm>,
  <https://docs.waveshare.com/4-DSI-TOUCH-A/User-Guide-Rpi>

## Waveshare 5inch HDMI LCD (H) — upper screen (on the bench)

- Identified from the drawing: "USB Touch", audio jack, HDMI "Display" port
  and micro-USB "Touch" port match the bench unit.
- Glass/PCB 121 × 76 mm; mounting tabs make it 89.48 mm tall; 4 holes on
  109 × 84 mm, tab outer width 115 mm **[drawing]**; PCBA 121 × 89.5 mm
  **[STEP]**. Hole diameter 3.2 mm **[est]**.
- Panel active area 108 × 64.8 mm (standard 5in 800 × 480 TFT) **[est]**.
- Stack: glass 1.0 + LCD 3.5 + spacer 1.5 + PCB 1.6 + parts up to 6.0 behind
  = **~13.6 mm [est]**.
- Rear-view port positions (x from the left edge in the drawing; the front
  view is mirrored): audio jack y ≈ 64, Touch micro-USB y ≈ 50, HDMI A
  y ≈ 33, VGA mini-HDMI y ≈ 13 on one edge; DC micro-USB y ≈ 10 and five OSD
  buttons on the other; 4-pin speaker header near the top **[drawing, scaled]**.
- 5 V, about 400 mA **[spec]**; capacitive USB HID touch; HDMI audio to the
  jack and the 4-pin speaker header **[spec]**.
- Vendor STEP: `5inch HDMI LCD (H)_3D Drawing.zip` (45 MB, 14 parts), not
  imported (see decisions).
- Sources: <https://www.waveshare.com/wiki/5inch_HDMI_LCD_(H)>,
  <https://www.waveshare.com/5inch-hdmi-lcd-h.htm>

## Flat cables — proposed order (Adafruit DIY USB/HDMI cable parts)

One system for both cables: small plug adapters with a flex-cable clip, joined
by a 20-pin FPC ribbon (10 mm wide). Adafruit tested it with a Raspberry Pi at
1080p; it is not shielded and less durable than a moulded cable (fine for
800 × 480 and USB 2.0 touch inside a case). Sold by Adafruit and resellers
(The Pi Hut, Kubii, Mouser, Digi-Key).

| Qty | Part | Adafruit ID | Size **[spec]** | Where |
| --- | --- | --- | --- | --- |
| 1 (+1) | Right Angle micro HDMI plug, R bend / L bend | 3557 / 3558 | 17.5 × 15 × 14.5 mm | Pi HDMI0. The ribbon must leave towards the Pi component side (back); which bend does that depends on the port keying: buy both, or check with the Pi in hand. |
| 1 | Straight HDMI plug adapter | 3548 | 27.5 × 17.3 × 5 mm | 5in HDMI "Display" port |
| 1 | Straight USB Type A plug | 4109 | 30 × 17 × 5 mm | Pi USB 2.0 port (no right-angle USB A in the range) |
| 1 | Straight micro B plug | 4106 | 23 × 17 × 3 mm | 5in Touch port. **Collides with the HDMI adapter if the ports are < 17.2 mm apart (M3).** Fallback: Right Angle micro B Up/Down 4104/4105 (PCB 17 × 13.3 × 3.6 + 11 mm plug; adds depth behind the 5in). |
| 2 | 20-pin FPC ribbon, 10 mm wide | 3560 (10 cm), 3561 (20 cm), 3562 (30 cm), 3563 (50 cm) | 10 mm wide | Bench route needs ~24 cm (HDMI) and ~30 cm (USB) including the clips: 30 cm or 50 cm. The final console route will be shorter; lengths are cheap to re-buy. |

Pre-made alternative for W3: one-piece "FPV flat FPC" cables, micro USB 90°
to USB A male (15/20/50 cm, sold as *Permanent* / fpv-solution); thinner at the
micro B end but the angle orientation must match the port.

## Raspberry Pi 27 W USB-C PSU — V1 bench supply (assumed)

- 5.1 V 5 A, PD 9 V 3 A / 12 V 2.25 A / 15 V 1.8 A **[spec]**. Assumed
  official unit; confirm which supply is actually used.
