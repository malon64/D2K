// D2K controls: ESP32-S3-Zero as a USB HID gamepad for the Raspberry Pi 5.
//
// Bench wiring without soldering (fusion/wiring.md, "D2K Bench Wiring" page):
// each button is a tact switch between its GPIO and GND, read with the
// internal pull-up (pressed = LOW). Keep the PINS table below in step with
// BUTTONS in fusion/electronics/gen_d2k_v1_sch.py.
//
// Build: Arduino-ESP32 core 3.x, board "ESP32S3 Dev Module",
//   USB Mode = USB-OTG (TinyUSB), USB CDC On Boot = Enabled (see README.md).
//
// Report layout (Linux maps HID gamepad buttons 1..15 to BTN_SOUTH..BTN_THUMBR):
//   ABXY are sent by POSITION, like an Xbox pad, so SDL and the emulators see
//   south / east / north / west: B (bottom) = south, A (right) = east,
//   X (top) = north, Y (left) = west. The D-pad is the hat switch.

#include "USB.h"
#include "USBHIDGamepad.h"

USBHIDGamepad Gamepad;

struct Button {
  uint8_t pin;
  int8_t hidButton;   // USBHIDGamepad BUTTON_* index, or -1 for the D-pad
  const char *name;
};

// D-pad pins (read into the hat switch).
const uint8_t PIN_UP = 8, PIN_DOWN = 7, PIN_LEFT = 9, PIN_RIGHT = 10;

const Button BUTTONS[] = {
  {11, BUTTON_B, "A"},          // A, right of the diamond -> east
  {12, BUTTON_A, "B"},          // B, bottom -> south
  {13, BUTTON_X, "X"},          // X, top -> north
  {44, BUTTON_Y, "Y"},          // Y, left -> west (RX pin)
  {6, BUTTON_START, "START"},
  {43, BUTTON_SELECT, "SELECT"},  // TX pin: driven by the boot ROM at power-up
  {5, BUTTON_MODE, "HOME"},
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
    if (s & (1u << i)) buttons |= 1u << BUTTONS[i].hidButton;
  }
  // Axes stay centred until the Circle Pads are fitted.
  Gamepad.send(0, 0, 0, 0, 0, 0, hatFrom(s), buttons);
  lastSend = millis();
}

void printState(uint32_t s) {
  Serial.print("pressed:");
  for (size_t i = 0; i < N_BUTTONS; i++) {
    if (s & (1u << i)) { Serial.print(' '); Serial.print(BUTTONS[i].name); }
  }
  const char *dirs[4] = {"UP", "DOWN", "LEFT", "RIGHT"};
  for (int k = 0; k < 4; k++) {
    if (s & (1u << (N_BUTTONS + k))) { Serial.print(' '); Serial.print(dirs[k]); }
  }
  Serial.println();
}

void setup() {
  for (size_t i = 0; i < N_BUTTONS; i++) pinMode(BUTTONS[i].pin, INPUT_PULLUP);
  const uint8_t dpad[4] = {PIN_UP, PIN_DOWN, PIN_LEFT, PIN_RIGHT};
  for (int k = 0; k < 4; k++) pinMode(dpad[k], INPUT_PULLUP);

  USB.manufacturerName("D2K");
  USB.productName("D2K Controls");
  Gamepad.begin();
  USB.begin();
  Serial.begin(115200);   // USB CDC: button log for bench checks (`cat /dev/ttyACM0`)
}

void loop() {
  uint32_t now = millis();
  uint32_t raw = readRaw();
  if (raw != lastRaw) {
    lastRaw = raw;
    rawSince = now;
  }
  if (raw != stableState && now - rawSince >= DEBOUNCE_MS) {
    stableState = raw;
    sendReport(stableState);
    printState(stableState);
  } else if (now - lastSend >= RESEND_MS) {
    sendReport(stableState);
  }
  delay(1);
}
