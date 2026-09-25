# Fusion roadmap

What Fusion is for in D2K, and the order of the work. Status is updated as
steps finish; details of each step go to decisions / constraints / open
questions.

## Goals (user, 2026-09-25)

1. **See the wiring** before building it: the bench (breadboard) wiring of each
   step, readable as a schematic and as 3D cables.
2. **Make the electronics as small as possible.** After the breadboard
   prototype, fix the electronics and optimise the wiring, most likely with
   custom PCBs, so the electronics take as little room as possible.
3. **Design the clamshell** around the real parts: respect every constraint in
   [constraints.md](constraints.md), be ergonomic, and follow the Y2K art
   direction if possible.

Goals 2 and 3 feed each other: the art direction wants the internal
electronics visible through a translucent shell, so the wiring and PCBs must be
tidy enough to be shown, and their size sets the shell size.

## Step 1 — V1 bench: Pi 5 + two screens (now)

- [x] Light 3D models of the V1 parts (`D2K_Electronics_V1`).
- [x] Library of the V1 modules with real pinouts (`D2K.flbr`).
- [ ] V1 interconnect schematic (EAGLE `.sch` generated from
      `electronics/`, uploaded as a Fusion schematic): PSU, Pi 5, both screens,
      cooler, one net per cable wire.
- [ ] 3D cables in `D2K_Electronics_V1` with real plug bodies and bend radii:
      micro-HDMI → HDMI A, USB-A → micro-B (touch), 22-pin FFC, GPIO power lead.
      This shows how much room the stock cables take.
- [ ] Update the models with calipers measurements when the 4in arrives
      ([open-questions.md](open-questions.md) M1–M7).

## Step 2 — Controls bench: ESP32-S3-Zero on the MB-102 breadboard

- [ ] ESP32-S3-Zero in the library + pin assignment for 15 buttons, 4 Circle
      Pad axes (ADC1 pins), USB to the Pi. Check the pin count first.
- [ ] Breadboard schematic and a 3D breadboard view (MB-102, tact switches,
      jumper routes) to wire from.
- [ ] Circle Pad pinout measured (multimeter) and added to the library.

## Step 3 — Audio and power bench

- [ ] WM8960 board (I²S/I²C on the Pi header) + two 8 Ω speakers in the library
      and schematic.
- [ ] Battery, protection, USB-C charge + power-path, 5 V rail once chosen.
      Warning for the choice: a Pi 5 under emulation load plus two screens can
      draw roughly 12–20 W at peaks; from one 3.7 V cell that is 4–6 A into a
      boost converter, so the cell count and converter must be picked from
      measured current (M8).

## Step 4 — Compaction study (after the breadboard prototype works)

Candidate architecture to evaluate, in Fusion Electronics:

- **Main board** carrying the ESP32-S3 (module), the WM8960 codec (it has a
  built-in 1 W class-D speaker amplifier), charger/power-path/5 V converter,
  Hall sensor and vibration driver. It plugs onto the Pi 5 40-pin header like a
  HAT, so no wires to the header.
- **Two control boards** (left: D-pad + left Circle Pad + L1/L2 flex; right:
  ABXY + right Circle Pad + R1/R2 flex) with 3DS-style gold contact pads under
  the New 3DS XL silicone membranes. Each links to the main board by one FFC.
- **Flat cables instead of stock cables:** flat HDMI flex with right-angle
  micro-HDMI and HDMI A ends (also solves the hinge), a short internal USB link
  for the 5in touch, and a folded 22-pin DSI FFC.
- **Pi 5 height:** the USB-A stacks (15.6 mm) and the RJ45 (13.5 mm) set the
  lower stack height, and the console doesn't need them. Options: keep them;
  remove them from the board; or later move to a **Raspberry Pi Compute
  Module 5**. It has the same BCM2712 as the Pi 5, so the same software, on a
  55 × 40 mm module with a custom carrier board. The carrier is the most
  compact option but also the hardest PCB (HDMI/DSI high-speed routing, 4+
  layers).
- Fusion links each PCB's 3D board to the mechanical design, so board outlines
  can follow the shell and the shell can follow the boards.

Notion rule: no custom PCB before the first working mechanical integration.
Step 4 therefore produces the study and the board outlines. The boards
themselves come after the V0 shell.

## Step 5 — Clamshell

- [ ] New light design `D2K_Shell` driven by user parameters from
      [constraints.md](constraints.md), referencing the part models
      (not the heavy Pi STEP).
- [ ] Width decision: Notion architecture says about 140–160 mm, the mechanics
      page studies 180–190 mm, phase 1 sweeps 155–170 mm; the controls beside
      the 4in need at least ~175 mm ([open-questions.md](open-questions.md) Q12).
- [ ] 1:1 flat ergonomic mock-up of the lower half (Notion workflow step 4),
      printed and held with the real buttons and Circle Pads.
- [ ] Hinge prototype with dummy cables at real bend radii.
- [ ] Shell V0 (fit and function), then V1 with the art direction:
      translucent ice blue (#298CC8 / #91BDE2) as the main material, candy pink
      (#DABFDB) on buttons and small parts only, capsule shapes and large radii,
      glossy finish, visible internals and silver screws. Clear parts print
      best in resin (SLA); FDM PETG gives a frosted look.

Notion rule: detailed shell only after the electronics gate. The parametric
skeleton and the ergonomic mock-up can start before it.
