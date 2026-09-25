# V1 wiring

Scope: Raspberry Pi 5 + Active Cooler, Waveshare 5inch HDMI LCD (H) (upper
screen), Waveshare 4-DSI-TOUCH-A (lower touch screen), Raspberry Pi 27 W USB-C
supply on the mains. The schematic is the Fusion Electronics design `D2K_V1`
(source `electronics/D2K_V1.sch`), with the same W1–W6 references; pinouts are
in `electronics/gen_d2k_lbr.py`. Parts: PS1 supply, U1 Pi 5, LCD1 5in, LCD2
4in, M1 cooler.

## Connections

| # | From | To | Cable | Carries |
| --- | --- | --- | --- | --- |
| W1 | PSU 27 W USB-C | Pi 5 `PWR` (USB-C) | PSU's captive USB-C | 5.1 V 5 A with USB PD; the Pi reads the 5 A capability over CC |
| W2 | Pi 5 `HDMI0` (micro-HDMI, next to USB-C) | 5in (H) `HDMI` (type A, "Display") | micro-HDMI (D) to HDMI (A) | Video 800×480 @ 60 Hz + HDMI audio (to the 5in jack) |
| W3 | Pi 5 `USB2_0` (USB-A) | 5in (H) `TOUCH` (micro-USB "Touch") | USB-A to micro-B **data** cable | Touch (USB HID) and the screen's power, about 400 mA |
| W4 | Pi 5 `DISP1` (22-pin, CAM/DISP 1) | 4in `DSI` (22-pin) | FFC 22-pin 0.5 mm 200 mm **reverse** (supplied) | 2 or 4 DSI lanes, touch I²C (Goodix 0x14, i2c-10), 3V3 |
| W5 | Pi 5 `GPIO` pin 4 (5 V) + pin 6 (GND) | 4in `PWR` (2-pin) | Supplied 2-wire lead (red 5 V, black GND) | Backlight/panel 5 V, 180 mA typical |
| W6 | Active Cooler lead | Pi 5 `FAN` (4-pin JST-SH) | Captive fan lead | 5 V, PWM, tach |
| — | 5in (H) `AUDIO` 3.5 mm jack | Headset | — | HDMI audio (V1 sound path, as on the bench today) |

Unused in V1: Pi `HDMI1`, `DISP0`, USB3 ports, Ethernet; 5in `DC` micro-USB,
VGA mini-HDMI, speaker header.

Software side (already in `scripts/linux/configure-desktop.sh` and
[docs/raspberry-pi-struggles.md](../docs/raspberry-pi-struggles.md)):
`dtoverlay=vc4-kms-dsi-waveshare-panel-v2,4_0_inch_a` for the 4in panel, touch
mapping in Labwc, screen roles in kanshi. When the 4in is connected, the lower
output becomes the DSI connector instead of the 5in HDMI, and the 5in moves to
the upper role.

## Wiring warnings

1. **The GPIO 5 V pins are not fused.** The 4in power lead must go red → pin 4,
   black → pin 6. One pin off puts 5 V onto pin 1 (3V3) or a GPIO
   (pin 3), which can destroy the SoC. Pin 1 is at the header end farthest from
   the USB ports; pins 2/4/6 are the outer row at that end. Check with the Pi
   unplugged.
2. **Power off before plugging or unplugging the DSI FFC.** Use the 22-pin
   0.5 mm reverse cable (contacts on opposite faces at each end); Pi 4 era
   15-pin 1 mm cables do not fit the Pi 5 connector. Lift the latch, insert
   fully and square, close the latch.
3. **Check which connector is DISP1** on the board silkscreen before plugging
   (model assumption: DISP1 is the one nearer the micro-HDMI ports). If the
   panel ends up on DISP0, the overlay needs `,dsi0`.
4. **The 5in (H) must be powered from USB**, not from HDMI: the HDMI +5 V pin
   only supplies about 55 mA. Use the **Touch** port (data + power); the DC
   port is power only and gives no touch. Do not feed the DC port from another
   supply while the Touch port is also plugged in (two supplies tied together).
5. **USB power budget:** with the official 5 A PSU the Pi allows 1.6 A in total
   on its USB ports; with a 3 A supply it limits them to 600 mA and warns.
   The 5in screen (about 400 mA) fits either way, but use the 5 A PSU once more
   USB loads (ESP32, adapters) are added.
6. **HDMI port names:** HDMI0 (next to USB-C) is `HDMI-A-1` in Wayland, HDMI1
   is `HDMI-A-2`. Keep [AGENTS.md](../AGENTS.md) "Current hardware wiring" and
   `configure-desktop.sh` in step with the physical cables.
7. **Fan lead:** the Active Cooler connector is small and keyed; push it
   straight and fully down, stop on any resistance (Raspberry Pi warning). The
   cooler is not meant to be removed once clipped on.
8. **FFC and HDMI routing:** do not fold the FFC sharply over the Pi's edge;
   with the Active Cooler fitted it has to arch over the cooler to reach
   DISP1. Mounted on the 4in back, the Pi's micro-HDMI and USB-C face the lower
   edge of the screen. Leave room for the plug bodies and the cable bends: the
   3D keep-outs are in `D2K_Electronics_V1` / `Cables_V1_stock`
   ([constraints.md](constraints.md)).
