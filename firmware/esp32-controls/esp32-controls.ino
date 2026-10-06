// D2K controls: ESP32-S3-Zero as a USB HID gamepad for the Raspberry Pi 5.
//
// Bench wiring without soldering (fusion/wiring.md, "D2K Bench Wiring" page):
// each button is a tact switch between its GPIO and GND, read with the
// internal pull-up (pressed = LOW). Keep the PINS table below in step with
// BUTTONS in fusion/electronics/gen_d2k_v1_sch.py.
//
// Build: Arduino-ESP32 core 3.x, board "ESP32S3 Dev Module",
//   USB Mode = USB-OTG (TinyUSB), USB CDC On Boot = Disabled (see README.md).
//   CDC on boot would start USB before setup() and keep Espressif's default
//   device name, so the log port is created here instead.
//
// Report layout (Linux maps HID gamepad buttons 1..15 to BTN_A..BTN_THUMBR):
//   ABXY are sent by LABEL (user, 2026-10-06): A = BTN_A, B = BTN_B,
//   X = BTN_X (top), Y = BTN_Y (left), so A confirms in Pegasus like on a
//   Nintendo console. Emulators are mapped explicitly. The D-pad is the hat.
//   HOME is not a gamepad button: it types Super+Esc on a second (keyboard)
//   HID interface, the Labwc shortcut that leaves the game for Pegasus. It
//   works in every emulator without binding, and no emulator opens its own
//   menu on a Guide button.

#include "USB.h"
#include "USBCDC.h"
#include "USBHIDGamepad.h"
#include "USBHIDKeyboard.h"

USBHIDGamepad Gamepad;
USBHIDKeyboard Keyboard;
USBCDC LogSerial;   // button log for bench checks (`cat /dev/ttyACM0`)

const int8_t HOME_KEYS = -2;   // hidButton value: send Super+Esc instead

struct Button {
  uint8_t pin;
  int8_t hidButton;   // USBHIDGamepad BUTTON_* index, or HOME_KEYS
  const char *name;
};

// D-pad pins (read into the hat switch).
const uint8_t PIN_UP = 8, PIN_DOWN = 7, PIN_LEFT = 9, PIN_RIGHT = 10;

const Button BUTTONS[] = {
  {11, BUTTON_A, "A"},          // A, right of the diamond
  {12, BUTTON_B, "B"},          // B, bottom
  {13, BUTTON_X, "X"},          // X, top
  {44, BUTTON_Y, "Y"},          // Y, left (RX pin)
  {6, BUTTON_START, "START"},
  {43, BUTTON_SELECT, "SELECT"},  // TX pin: driven by the boot ROM at power-up
  {5, HOME_KEYS, "HOME"},       // Super+Esc: leave the game
  {4, BUTTON_TL, "L1"},         // GPIO1-4 go to the Circle Pads later (Q22)
  {3, BUTTON_TR, "R1"},
  {2, BUTTON_TL2, "L2"},
  {1, BUTTON_TR2, "R2"},
};
const size_t N_BUTTONS = sizeof(BUTTONS) / sizeof(BUTTONS[0]);

const uint32_t DEBOUNCE_MS = 5;        // a level must hold this long to count
const uint32_t RESEND_MS = 100;        // resend the report even without change

uint32_t stableState = 0, lastRaw = 0, rawSince = 0, lastSend = 0;
uint8_t stableHat = HAT_CENTER;

// Bit layout of the raw state: bits 0..N_BUTTONS-1 buttons, then up/down/left/right.
uint32_t readRaw() {
  uint32_t s = 0;
  for (size_t i = 0; i < N_BUTTONS; i++) {
    if (digitalRead(BUTTONS[i].pin) == LOW) s |= 1u << i;
  }
  const uint8_t dpad[4] = {PIN_UP, PIN_DOWN, PIN_LEFT, PIN_RIGHT};
  for (int k = 0; k < 4; k++) {
    if (digitalRead(dpad[k]) == LOW) s |= 1u << (N_BUTTONS + k);
  }
  return s;
}

uint8_t hatFrom(uint32_t s) {
  bool up = s & (1u << N_BUTTONS), down = s & (1u << (N_BUTTONS + 1));
  bool left = s & (1u << (N_BUTTONS + 2)), right = s & (1u << (N_BUTTONS + 3));
  if (up && down) up = down = false;        // a worn D-pad must not report both
  if (left && right) left = right = false;
  if (up && right) return HAT_UP_RIGHT;
  if (up && left) return HAT_UP_LEFT;
  if (down && right) return HAT_DOWN_RIGHT;
  if (down && left) return HAT_DOWN_LEFT;
  if (up) return HAT_UP;
  if (down) return HAT_DOWN;
  if (left) return HAT_LEFT;
  if (right) return HAT_RIGHT;
  return HAT_CENTER;
}

void sendReport(uint32_t s) {
  uint32_t buttons = 0;
  for (size_t i = 0; i < N_BUTTONS; i++) {
    if ((s & (1u << i)) && BUTTONS[i].hidButton >= 0) buttons |= 1u << BUTTONS[i].hidButton;
  }
  // SDL's automatic gamepad mapping reads the triggers from the Z / RZ axes
  // (lefttrigger:a2, righttrigger:a5), so L2/R2 also swing those axes from
  // released (-127) to pressed (+127); raw-joystick emulators use buttons 8/9.
  // The sticks stay centred until the Circle Pads are fitted.
  int8_t l2 = (buttons & (1u << BUTTON_TL2)) ? 127 : -127;
  int8_t r2 = (buttons & (1u << BUTTON_TR2)) ? 127 : -127;
  Gamepad.send(0, 0, l2, r2, 0, 0, hatFrom(s), buttons);
  lastSend = millis();
}

// Holds Super+Esc while HOME is held, like the real key combination.
void updateHomeKeys(uint32_t before, uint32_t after) {
  for (size_t i = 0; i < N_BUTTONS; i++) {
    if (BUTTONS[i].hidButton != HOME_KEYS) continue;
    bool was = before & (1u << i), is = after & (1u << i);
    if (is && !was) {
      Keyboard.press(KEY_LEFT_GUI);
      Keyboard.press(KEY_ESC);
    } else if (was && !is) {
      Keyboard.releaseAll();
    }
  }
}

void printState(uint32_t s) {
  LogSerial.print("pressed:");
  for (size_t i = 0; i < N_BUTTONS; i++) {
    if (s & (1u << i)) { LogSerial.print(' '); LogSerial.print(BUTTONS[i].name); }
  }
  const char *dirs[4] = {"UP", "DOWN", "LEFT", "RIGHT"};
  for (int k = 0; k < 4; k++) {
    if (s & (1u << (N_BUTTONS + k))) { LogSerial.print(' '); LogSerial.print(dirs[k]); }
  }
  LogSerial.println();
}

void setup() {
  for (size_t i = 0; i < N_BUTTONS; i++) pinMode(BUTTONS[i].pin, INPUT_PULLUP);
  const uint8_t dpad[4] = {PIN_UP, PIN_DOWN, PIN_LEFT, PIN_RIGHT};
  for (int k = 0; k < 4; k++) pinMode(dpad[k], INPUT_PULLUP);

  USB.manufacturerName("D2K");
  USB.productName("D2K Controls");
  Gamepad.begin();
  Keyboard.begin();
  LogSerial.begin(115200);
  USB.begin();
}

void loop() {
  uint32_t now = millis();
  uint32_t raw = readRaw();
  if (raw != lastRaw) {
    lastRaw = raw;
    rawSince = now;
  }
  if (raw != stableState && now - rawSince >= DEBOUNCE_MS) {
    updateHomeKeys(stableState, raw);
    stableState = raw;
    sendReport(stableState);
    printState(stableState);
  } else if (now - lastSend >= RESEND_MS) {
    sendReport(stableState);
  }
  delay(1);
}
