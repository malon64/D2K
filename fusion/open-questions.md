# Open questions and missing data

Close an item by writing the answer, the date and where it was applied (script,
model, doc), then move it to **Resolved** at the bottom.

## Missing data (measure on the real parts)

| ID | Item | Why it matters | How to get it | Model value now |
| --- | --- | --- | --- | --- |
| M1 | 5in (H) total thickness and layer stack | Upper shell height | Calipers: glass to the tallest rear part (HDMI A socket) | ~13.6 mm est. |
| M2 | 5in (H) mounting hole diameter and tab thickness | Screw size and bosses in the upper shell | Calipers | ø3.2, 1.6 mm est. |
| M3 | 5in (H) port positions and heights, **especially the HDMI ↔ Touch micro-USB centre distance** | Plug clearance; the straight HDMI (17.3 mm) and micro B (17 mm) flat adapters collide if the pitch is < 17.2 mm | Calipers from the glass edge, centre to centre | Scaled from the drawing: ~17 mm |
| M4 | 4in DSI boss heights (corner / inner) and adapter board height | Stack height, Pi standoff length | Calipers once received | 2.1 / 5.0 / 3.0 mm est. |
| M5 | 4in DSI power connector type and lead length | Power harness | Inspect when received | 2-pin, length unknown |
| M6 | Active Cooler height above the Pi PCB | Lower stack and airflow | Calipers once fitted | 13.3 fins / 15.3 pins est. |
| M7 | Pi 5 connector heights (USB stack, RJ45, micro-HDMI) | Lower stack; USB-A/RJ45 may be the tallest parts | Calipers or the official STEP in Fusion | 15.6 / 13.5 / 3.4 mm est. |
| M8 | Current draw: 4in backlight at full brightness, 5in at full brightness, Pi under emulation | Power budget for the future battery | USB power meter on the bench | 180 mA / 400 mA typical only |
| M9 | Real bench cables: plug overmold W × H × L outside the port, cable diameter, tightest comfortable bend radius (HDMI, USB-A/micro-B, PSU USB-C), FFC length/width, 4in lead length | Stock-cable keep-outs in `Cables_V1_stock`, baseline for the compaction | Calipers + bend the cable by hand around a round object | Typical values (constraints.md table) |

## Open questions

| ID | Question | Notes |
| --- | --- | --- |
| Q1 | Which Pi 5 22-pin connector is DISP1? | Model assumes the one nearer the micro-HDMI ports. Read the silkscreen. |
| Q2 | Exact `config.txt` lines for the 4in on DSI1 vs DSI0 on Pi 5 | Waveshare's guide lists `vc4-kms-dsi-waveshare-panel-v2,4_0_inch_a` with `,dsi0` for DSI0; confirm the DSI1 line on the Pi and record it in `docs/raspberry-pi-struggles.md`. |
| Q3 | Wayland output name of the DSI panel (`DSI-1` or `DSI-2`) | Needed for `D2K_LOWER_OUTPUT` in `configure-desktop.sh`. Check `wlr-randr` once connected. |
| Q4 | Pi 5 fan header pin order and 22-pin IO0/IO1 roles | Library uses the generic Raspberry Pi pinout; only matters if something other than the stock cooler/panel is wired. |
| Q5 | 5in (H) speaker header pinout | Not published. Relevant if the 5in's own HDMI-audio amplifier is used for speakers instead of the WM8960. |
| Q6 | Pi orientation on the 4in back: as Waveshare shows, or turned 180° | 180° points the micro-HDMI and USB-C at the hinge; check FFC reach and adapter position. See constraints. |
| Q7 | Keep the Pi on the screen back, or mount it separately in the lower shell? | The screen-back stack is ~28 mm; see constraints. |
| Q8 | HDMI through the hinge: flat HDMI flex/cable part, and right-angle adapters at both ends | Notion P1 purchase; defines the upper shell edge space. |
| Q9 | Which USB-C supply is used on the bench (official 27 W or other)? | A non-5 A supply caps USB at 600 mA. |
| Q11 | Does the 5in (H) run reliably from the Touch port alone (no DC), with the backlight at full brightness? | Bench powers it that way today; confirm there is no brownout. |
| Q12 | Console width and thickness? | Not fixed (user): an output of the electronics optimisation and placement. Notion pages disagree (~140–160 vs ~180–190 mm). With the 108.3 mm 4in plus D-pad/Circle Pad (~26 mm) and walls on each side, the controls need ≳ 170 mm if they sit beside the screen. Check with the 1:1 mock-up. |
| Q13 | Keep the Pi 5 USB-A/RJ45 connectors in the console, remove them, or move to a Compute Module 5 later? | They set the lower stack height (15.6 / 13.5 mm). See roadmap step 4. |
| Q14 | Which right-angle micro HDMI bend (Adafruit 3557 R or 3558 L) sends the ribbon towards the Pi's component side? | Depends on the Pi 5 receptacle keying; buy both or check with the board in hand. |
| Q15 | Ribbons behind the boards (+2–3 mm thickness) or beside them (+width)? | Decide in the layout study with the shell width. |
| Q16 | Do the Adafruit ribbons survive the hinge? | Cycle-test in the printed hinge prototype (thousands of openings, R ≥ 6 mm wrap). Fallback: custom dynamic-flex PCB with the same 20-pin ends. |
| Q17 | How many ribbon conductors carry VBUS/GND in the Adafruit USB adapters, and is it enough for the 5in (~400 mA, more at full backlight)? | Check the adapter schematics/continuity; otherwise feed the 5in from a separate power pair through the power/audio passage. |

## Resolved

| ID | Answer | Date | Applied in |
| --- | --- | --- | --- |
| R1 | The upper screen is the **5inch HDMI LCD (H)** (USB touch, audio jack), not another 5in variant. | 2026-09-25 | parts.md, `30_part_waveshare_5in_hdmi_h.py` |
| R2 | V1 electronics scope = Pi 5 + both Waveshare screens on mains power; ESP32, audio and battery later. | 2026-09-25 | decisions.md |
| R3 | (was Q10) Point the phase 1 layout at the light models? Obsolete: the user removed `D2K_phase1`. | 2026-09-25 | decisions.md |
| R4 | 4in power lead pins: pin 4 (5V) + pin 6 (GND). | 2026-09-25 | wiring.md, `D2K_V1` |
