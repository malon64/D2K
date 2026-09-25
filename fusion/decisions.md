# Fusion decision log

Newest first. Each entry: the decision, why, and what it affects. Project-level
decisions (compute, screens, roadmap) live in the Notion workspace; they are
repeated here only where they drive the Fusion work.

## 2026-09-25 — V1 electronics scope: Pi 5 + two Waveshare screens, mains power

- **Decision:** the V1 electronic model contains only the Raspberry Pi 5 (with
  its Active Cooler), the Waveshare 5inch HDMI LCD (H) as the upper screen and
  the Waveshare 4-DSI-TOUCH-A as the lower touch screen, powered from the mains
  through the Raspberry Pi 27 W USB-C supply.
- **Why:** the user's current milestone is dual-screen on the Pi; ESP32
  controls, WM8960 audio and the battery come next and the battery is not
  ordered yet.
- **Affects:** `D2K_Electronics_V1`, `D2K.flbr`, [wiring.md](wiring.md). ESP32,
  audio board, speakers and battery stay out until their step.

## 2026-09-25 — Electronics in separate, light Fusion files

- **Decision:** electronics live in `D2K_Electronics_V1` (3D reference models)
  and `D2K.flbr` (library), both at the D2K project root. `D2K_phase1` is not
  modified.
- **Why:** `D2K_phase1` loads ~7 GB (the official Pi 5 STEP alone has 2711
  bodies) and crashed Fusion when opened by script; the user asked for a
  separate file.
- **Affects:** later, the phase 1 layout should reference these light models
  (or copy their dimensions) instead of the heavy STEP.

## 2026-09-25 — Simplified parametric volumes instead of vendor STEP files

- **Decision:** each part is modelled as named boxes/cylinders from the
  vendor's dimension drawings (one base feature per component), not by
  importing the vendor STEP.
- **Why:** the Waveshare 5in (H) STEP is 45 MB with 14 sub-parts, the Pi 5
  STEP is heavy; the V1 layout needs outlines, mounting holes, connector
  positions and keep-outs, not detail. Simple bodies keep Fusion responsive.
- **Affects:** connector sizes and heights are approximate
  ([parts.md](parts.md) lists which numbers are measured, drawn or estimated).

## 2026-09-25 — Pi 5 modelled on the back of the 4in DSI

- **Decision:** in `D2K_Electronics_V1` the Pi sits on the 4in screen's inner
  M2.5 standoffs (58 × 49 = the Pi hole pattern), component side outward, as in
  Waveshare's assembly photo.
- **Why:** it is the vendor's intended mount and matches the plan to keep the
  Pi and the lower screen in the lower shell.
- **Open:** the Pi can also be turned 180° on the same pattern so its HDMI and
  USB-C face the hinge; see [constraints.md](constraints.md).

## 2026-09-25 — 4in DSI on the Pi 5 DSI1 connector (CAM/DISP 1)

- **Decision:** the lower screen uses the Pi's DSI1 connector with the supplied
  22-pin reverse FFC.
- **Why:** Waveshare's Pi 5 guide recommends DSI1; DSI0 stays free for a camera
  or a second DSI panel.

## 2026-09-25 — Symbol-only electronics library

- **Decision:** `D2K.lbr` devices have symbols with the real connector pinouts
  and spec attributes, but no packages (footprints).
- **Why:** V1 is off-the-shelf modules joined by cables, so there is no PCB to
  lay out. Packages (starting with the Pi 40-pin header) will be added when a
  carrier or ESP32 PCB is drawn.
- **Affects:** the V1 schematic will have no board view.

## 2026-09-25 — Library generated from code, one signal name per cable wire

- **Decision:** `gen_d2k_lbr.py` holds every pinout as data and writes the
  EAGLE XML. Both ends of a cable use the same signal names (for example
  `TMDS_D2+` on the Pi's micro-HDMI and on the screen's HDMI A).
- **Why:** the Fusion API cannot edit Electronics content; generated XML is
  reviewable in git and nets connect by name in the schematic.

## 2026-09-22 — Phase 1 layout (recorded from phase1/README.md)

- Parametric envelope layout `D2K_phase1`: lower footprint 165 × 110 mm, lower
  stack 33 mm, upper 12 mm, numbered component hierarchy (00_REFERENCE,
  01_ELECTRONICS, 02_CONTROLS, 03_D2K_CASE); Nintendo scans imported as hidden
  references; Pi 5 STEP imported as the V1 compute reference; all display,
  battery, control and cable sizes marked provisional until measured.
