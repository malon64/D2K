# Constraints

Hard limits and known clashes that any Fusion change must respect. Numbers come
from [parts.md](parts.md); "phase 1" means the parameters in
`scripts/phase1/d2k_phase1_layout.py` / the `D2K_phase1` design.

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
- Lower-half width is being studied at about 180–190 mm (phase 1 currently
  sweeps 155–170 mm).

## Clashes found between the datasheets and the phase 1 layout (2026-09-25)

| Item | Phase 1 value | Datasheet / model | Consequence |
| --- | --- | --- | --- |
| 4in DSI module | 99 × 65 × 6 mm (`bottom_display_*`, "UNMEASURED") | **108.3 × 65.1 × 5.8 mm**, plus 2.1 mm corner bosses and 5 mm Pi standoffs at the back | Lower screen opening and bezel 9.3 mm wider than drawn. |
| 5in HDMI (H) | 124 × 77 × 7 mm (`top_display_*`, "UNMEASURED") | **121 × 76 mm** glass/PCB, **89.48 mm** tall over the mounting tabs, ~13.6 mm thick (estimated) | Upper shell must take ~14 mm + walls: `upper_case_height` 12 mm is too thin. The tabs need 89.5 mm of depth (phase 1 `top_case_depth` 94 mm leaves 2.25 mm per side). |
| Controls beside the 4in | `case_width` 165 mm | (165 − 108.3) / 2 = **28.35 mm** per side, before walls | D-pad (25 mm) and Circle Pad (26 mm) barely fit inside one 2.4 mm wall; no grip margin. Supports the Notion 180–190 mm width study. |
| Lower stack, Pi on the 4in back | `lower_case_height` 33 mm | Glass top to Pi USB-A top ≈ **28.0 mm** (5.8 screen body, 5 mm standoffs, 1.6 mm PCB, 15.6 mm USB stack); cooler push pins ≈ 27.7 mm | Leaves 5.0 mm, i.e. 0.2 mm after two 2.4 mm walls: no real clearance. Options: drop the USB-A/Ethernet height (not needed in the console), move the Pi off the screen back, or raise the stack. |

## Layout constraints from the V1 models

- **Pi on the 4in back:** the Pi's micro-HDMI and USB-C face the screen's
  lower edge (user side), while the HDMI must go up through the hinge. Turning
  the Pi 180° on the same 58 × 49 pattern points them at the hinge instead;
  the USB/Ethernet stack then faces the other side. Check FFC reach (200 mm) and
  the 4in adapter board position before choosing.
- **5in (H) ports are on its side edges:** HDMI A, Touch micro-USB, VGA and the
  audio jack are on one short edge; DC micro-USB and five OSD buttons on the
  other. A straight HDMI A plug plus cable bend adds roughly 30–40 mm beyond
  the edge; the upper shell needs a right-angle adapter or a flat HDMI flex.
- **The Active Cooler needs air:** blower fan on the Pi's component side; the
  Pi throttles without it (seen on the bench). Keep an inlet over the fan and
  an outlet past the fins.
- **4in adapter board:** it sticks out 3 mm behind the back plate, between the
  back and the Pi. The DSI connector faces the screen edge, so the FFC loops
  around the Pi's edge to reach DISP1.

## Tooling constraints (Fusion)

- `D2K_phase1` is too heavy to open or edit by script (see [README.md](README.md)).
- The Fusion API cannot create Electronics documents or schematic content;
  schematics and libraries are generated as EAGLE XML and uploaded.
- Fusion is Y-up: models built "glass up +Z" face the **Front** view.
- Units: scripts work in mm and convert to the API's cm.
