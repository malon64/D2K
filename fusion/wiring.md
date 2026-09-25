# V1 wiring

Scope: Raspberry Pi 5 + Active Cooler, Waveshare 5inch HDMI LCD (H) (upper
screen), Waveshare 4-DSI-TOUCH-A (lower touch screen), Raspberry Pi 27 W USB-C
supply on the mains (sheet 1); the ESP32-S3-Zero controls on the breadboard
(sheet 2); the WM8960 audio board and two speakers (sheet 3). The schematic is
the Fusion Electronics design `D2K_V1` (source `electronics/D2K_V1.sch`), with
the same W1–W9 references; pinouts are in `electronics/gen_d2k_lbr.py`.
Parts: PS1 supply, U1 Pi 5, LCD1 5in, LCD2 4in, M1 cooler, U2 ESP32-S3-Zero,
SW1–SW15 buttons, JS1/JS2 Circle Pads, U3 WM8960 board, LS1/LS2 speakers.

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

## Controls: ESP32-S3-Zero (sheet 2)

| # | From | To | Cable | Carries |
| --- | --- | --- | --- | --- |
| W7 | Pi 5 `USB2_1` (the other USB 2.0 port) | ESP32-S3-Zero USB-C | USB-A to USB-C **data** cable | USB HID gamepad + the ESP32's 5 V |

The ESP32-S3-Zero straddles the breadboard's centre channel (rows 15.24 mm
apart). Each button is a 6×6 tact switch between its GPIO and GND, read
active-low with the ESP32's internal pull-up (no resistor). The Circle Pads
take 3.3 V from the ESP32's `3V3` pin.

| Function | ESP32 pin | Where on the board | Function | ESP32 pin | Where |
| --- | --- | --- | --- | --- | --- |
| LSTICK_X | GPIO1 (ADC1_CH0) | L4 | BTN_A | GPIO9 | R7 |
| LSTICK_Y | GPIO2 (ADC1_CH1) | L5 | BTN_B | GPIO11 | R5 |
| RSTICK_X | GPIO3 (ADC1_CH2) | L6 | BTN_X | GPIO12 | R4 |
| RSTICK_Y | GPIO4 (ADC1_CH3) | L7 | BTN_Y | GPIO13 | R3 |
| BTN_DPAD_UP | GPIO5 | L8 | BTN_START | GPIO14 | front pad |
| BTN_DPAD_DOWN | GPIO6 | L9 | BTN_SELECT | GPIO15 | front pad |
| BTN_DPAD_LEFT | GPIO7 | R9 | BTN_HOME | GPIO16 | front pad |
| BTN_DPAD_RIGHT | GPIO8 | R8 | BTN_L1 / R1 | GPIO17 / GPIO18 | back pads |
| Circle Pads VCC | 3V3 | L3 | BTN_L2 / R2 | GPIO38 / GPIO39 | back pads |
| GND (all) | GND | L2 | | | |

Kept free for later: GPIO10 (ADC1, battery voltage), GPIO40 (lid Hall
sensor), GPIO41 (vibration PWM), GPIO42 (Pi power control), GPIO43/44 (UART0:
system link to the Pi). Avoid GPIO45 (strapping). On the board: GPIO21 RGB LED,
GPIO0 BOOT, GPIO19/20 USB. L1–L9 / R1–R9 count from the USB-C end.

## Audio: WM8960 board and speakers (sheet 3)

| # | Pi 5 GPIO header pin | WM8960 board header P2 pin | Signal |
| --- | --- | --- | --- |
| W8 | 1 (3V3) | 1 (VCC) | 3.3 V: logic, codec **and speaker amplifier** |
| W8 | 9 (GND) | 3 (GND) | Ground |
| W8 | 3 (GPIO2, SDA1) | 7 (SDA) | I²C data (codec at 0x1A) |
| W8 | 5 (GPIO3, SCL1) | 5 (SCL) | I²C clock |
| W8 | 12 (GPIO18, PCM_CLK) | 9 (CLK) | I²S bit clock |
| W8 | 35 (GPIO19, PCM_FS) | 11 (WS) | I²S frame clock (L/R) |
| W8 | 40 (GPIO21, PCM_DOUT) | 13 (TXSDA) | Playback data, Pi → codec DAC |
| W8 | 38 (GPIO20, PCM_DIN) | 14 (RXSDA) | Recording data, codec ADC → Pi (on-board MEMS mic) |
| W9 | — | SPK J1: 1 LP, 2 LN | Left speaker (LS1) + / − |
| W9 | — | SPK J1: 4 RP, 3 RN | Right speaker (LS2) + / − |

Header pins 2/4, 10/12 duplicate 1/3, 9/11 on the board; 6 and 8 are not
connected; 15/16 export MCLK through jumper P1: leave it open (the codec uses
its own 24 MHz crystal, the Pi has no MCLK pin). W8 is eight female-female
jumper wires. The speakers' PH1.25 plugs do not fit the board's 4-pin SPK
header: crimp a matching 4-pin plug or use an adapter. Linux: the WM8960
overlay (`dtoverlay=wm8960-soundcard`, to confirm on the Pi), then MPD and the
emulators on the new ALSA card.

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
9. **The ESP32-S3 is 3.3 V only.** Buttons switch to GND, never to 5 V; feed
   the Circle Pads from the ESP32's 3V3 pin (its ADC reads up to ~3.1 V).
10. **Circle Pad pinout is not verified.** Identify VCC, GND, X and Y with a
    multimeter before connecting; a 4-contact flex breakout is needed to reach
    the module's flex on the breadboard.
11. **The WM8960 board's speaker amplifier runs from the Pi's 3V3 pin.** It
    is limited to ~0.4 W per channel at 3.3 V, and loud audio draws current
    from the Pi's 3.3 V rail: measure it (M10) and keep the volume moderate
    until then. Do not connect the board's VCC to 5 V (it is a 3.3 V board).
12. **WM8960 header pins 5/7:** the schematic netlist gives 5 = SCL, 7 = SDA;
    read the silkscreen before wiring. A swap does no damage but the codec
    will not answer on I²C.
13. **Never connect a speaker wire to GND:** the WM8960 speaker outputs are
    bridged (LP/LN, RP/RN); each speaker goes between its P and N pins only,
    and the two channels must not share a wire.
