# Constraints

Hard limits that any Fusion change must respect. Numbers come from
[parts.md](parts.md). **The shell has no fixed size** (user, 2026-09-25): its
dimensions follow from how the electronics are optimised and placed. The
sizes below are minimums set by the parts, not targets.

## Project rules (from Notion, *Projet Hardware*)

- No detailed shell before the **electronics gate** (everything working on the
  bench: screens, touch, ESP32 controls, audio, power). Model real, measured
  parts only; catalogue sizes are not enough (connectors, cables and bend radii
  are part of the envelope).
- Heavy parts in the lower shell (Pi, battery, ESP32, power, amplifier,
  controls); the upper shell carries the 5in screen, the speakers and wiring
  only.
- Hinge: two separate passages, **HDMI alone on one side**, screen power +
  four speaker wires on the other; service loop, no sharp folds. A generic FFC
  is not an HDMI cable: use a cable/flex made for HDMI.
- Notion gives no single width (architecture page ~140–160 mm, mechanics page
  ~180–190 mm); it is now an output of the layout, checked with a 1:1 mock-up.

## Minimum envelopes set by the parts (2026-09-25)

| Item | Datasheet / model | Consequence for the shell |
| --- | --- | --- |
| 4in DSI module | **108.3 × 65.1 × 5.8 mm**, plus 2.1 mm corner bosses and 5 mm Pi standoffs at the back | Lower screen opening at least 108.3 × 65.1 plus clearance. |
| 5in HDMI (H) | **121 × 76 mm** glass/PCB, **89.48 mm** tall over the mounting tabs, ~13.6 mm thick (estimated) | Upper half at least ~14 mm + walls thick and ~90 mm deep, or cut/replace the tabs. |
| Controls beside the 4in | D-pad 25 mm, Circle Pad 26 mm, wall 2.4 mm (provisional) | Needs roughly (26 + 2.4 + clearance) ≈ 31 mm per side: lower half ≳ 170 mm wide with the controls beside the screen. |
| Lower stack, Pi on the 4in back | Glass top to Pi USB-A top ≈ **28.0 mm** (5.8 screen body, 5 mm standoffs, 1.6 mm PCB, 15.6 mm USB stack); cooler push pins ≈ 27.7 mm | ~33 mm lower half with walls. The USB-A/RJ45 stacks are the tallest parts and unused in the console: removing them, or moving the Pi off the screen back, is the first thickness saving. |
| Legacy phase 1 layout (removed 2026-09-25) | Its placeholders were 99 × 65 × 6 (4in) and 124 × 77 × 7 (5in) | Do not reuse those numbers. |

## Layout constraints from the V1 models

- **Pi on the 4in back:** the Pi's micro-HDMI and USB-C face the screen's
  lower edge (user side), while the HDMI must go up through the hinge. Turning
  the Pi 180° on the same 58 × 49 pattern points them at the hinge instead;
  the USB/Ethernet stack then faces the other side. Check FFC reach (200 mm) and
  the 4in adapter board position before choosing.
- **5in (H) ports are on its side edges:** HDMI A, Touch micro-USB, VGA and the
  audio jack are on one short edge; DC micro-USB and five OSD buttons on the
  other. With stock cables the HDMI A plug and its bend reach ~79 mm past that
  edge (table below): the upper shell needs a right-angle adapter or a flat
  HDMI flex.
- **The Active Cooler needs air:** blower fan on the Pi's component side; the
  Pi throttles without it (seen on the bench). Keep an inlet over the fan and
  an outlet past the fins.
- **4in adapter board:** it sticks out 3 mm behind the back plate, between the
  back and the Pi. The DSI connector faces the screen edge, so the FFC loops
  around the Pi's edge to reach DISP1.
- **FFC vs Active Cooler:** with the cooler fitted, the supplied 22-pin FFC
  cannot reach DISP1 along the board (the cooler covers the path from the
  Pi's SD-card edge); it has to arch over the cooler's push pins (Z ≈ −22.5
  in the model), which sets the top of the lower stack. A shorter FFC entering
  DISP1 from the HDMI side, or turning the Pi, may avoid that.
- **The 4in power connector sits under the Pi**, in the 2 mm left between the
  adapter board and the Pi PCB; the 2-wire lead leaves past the Pi's GPIO edge.

## Stock-cable keep-outs (V1 bench cables, 2026-09-25)

Modelled in `D2K_Electronics_V1` / `Cables_V1_stock` by
`scripts/electronics_v1/70_cables_v1_stock.py`: plug overmold outside the port,
then the cable turning 90° at its minimum bend radius. Plug sizes, diameters
and radii are **typical values** until the real cables are measured
([open-questions.md](open-questions.md) M9). This is the baseline the
compaction work has to beat.

| Cable end | Plug outside the port (W × H × L) | Cable Ø / min bend R | Reach beyond the part edge |
| --- | --- | --- | --- |
| W2 HDMI A on the 5in | 21 × 11 × 38 mm | 6 / 30 mm | **~79 mm** past the 5in side edge |
| W2 micro-HDMI on the Pi | 11 × 6.5 × 20 mm | 6 / 30 mm | **~61 mm** past the 4in lower edge, together with W1 |
| W1 USB-C (PSU) on the Pi | 12.5 × 6.5 × 22 mm | 4.5 / 25 mm | turns backwards (−Z): lower stack depth |
| W3 USB-A on the Pi | 16 × 8 × 30 mm | 4 / 20 mm | **~50 mm** past the 4in side edge |
| W3 micro-USB on the 5in Touch port | 11 × 6.5 × 20 mm | 4 / 20 mm | ~40 mm past the 5in side edge |
| W4 FFC 22-pin | 12 × 0.3 mm flat | folds | arches over the cooler: stack ≈ 28.3 mm |
| W5 Dupont on GPIO 4/6 | 5.1 × 2.5 × 14 mm | 2.5 bundle / 3 mm | 14 mm tall on top of the header |

The bare parts measure 108.3 × 65.1 × 28.1 mm (4in + Pi) and
124.8 × 89.5 × 13.6 mm (5in). With stock cables, their ends alone push the
footprint to roughly 176 × 154 mm around the lower pair and 202 mm wide at the
upper screen. Right-angle adapters, flat HDMI flex, a direct USB link and a
short FFC are the obvious first savings (roadmap step 4).

## Tooling constraints (Fusion)

- Keep Fusion designs light; heavy STEP-based designs froze Fusion (see [README.md](README.md)).
- The Fusion API cannot create Electronics documents or schematic content;
  schematics and libraries are generated as EAGLE XML and uploaded.
- Fusion is Y-up: models built "glass up +Z" face the **Front** view.
- Units: scripts work in mm and convert to the API's cm.
