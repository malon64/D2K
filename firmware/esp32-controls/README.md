# ESP32-S3 controls firmware

Turns the Waveshare ESP32-S3-Zero into a USB HID gamepad ("D2K Controls")
for the Raspberry Pi 5: 15 buttons wired to GND on the header GPIOs (bench
plan without soldering, see `fusion/wiring.md` and the "D2K Bench Wiring"
page). The D-pad is the hat switch; ABXY are sent by label (A = BTN_A,
B = BTN_B, X = BTN_X, Y = BTN_Y), so A confirms in Pegasus. HOME is sent as
Super+Esc on a second, keyboard HID interface: Labwc's "leave the game"
shortcut. The Circle Pad axes stay centred until the pads are fitted.

A USB serial port comes up next to the gamepad and prints every change
(`pressed: A L1 UP`), which is the quickest bench check.

## Build and flash from the Pi (the ESP32 is plugged into it)

```bash
# once: arduino-cli and the ESP32 core (in ~/.local/bin, ~1 GB download)
curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | BINDIR=~/.local/bin sh
arduino-cli config init
arduino-cli config add board_manager.additional_urls https://espressif.github.io/arduino-esp32/package_esp32_index.json
arduino-cli core update-index && arduino-cli core install esp32:esp32

# build + upload (USB-OTG/TinyUSB for HID; the sketch creates its own log port)
cd ~/D2K/firmware/esp32-controls
FQBN='esp32:esp32:esp32s3:USBMode=default,CDCOnBoot=default'
arduino-cli compile --fqbn "$FQBN" .
arduino-cli upload --fqbn "$FQBN" -p /dev/ttyACM0 .
```

If the upload says "Failed to connect ... No serial data received", the running
sketch did not accept esptool's reset: `stty -F /dev/ttyACM0 1200` reboots it
into download mode (the port comes back as "USB JTAG/serial debug unit"),
then upload again. Last resort (crashed sketch): hold **BOOT**, plug the
USB-C in, release, upload.

## Check it

```bash
lsusb | grep -i d2k            # "D2K Controls"
cat /dev/ttyACM0               # press buttons: one line per change
evtest                         # pick "D2K Controls": BTN_A.., ABS_HAT0X/Y
```

## Troubleshooting

- **Nothing in `lsusb`, LED blinking:** the board has power but no data:
  use a USB-C cable with data wires.
- **A button always reads pressed:** its switch is turned so both wires sit
  on joined legs; rotate the switch 90° in the breadboard.
- **Do not hold SELECT while the board powers up:** it is on the TX pin,
  which the boot ROM drives.
