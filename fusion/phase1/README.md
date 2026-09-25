# D2K mechanical source assets

`local/` contains local copies and working derivatives of hardware and reference
models supplied for the Fusion layout. It is ignored by Git because the meshes
are large and their redistribution terms are not established.

The layout scripts live in `fusion/`. Original files supplied by the user are
in `C:/Users/alexi/Downloads/`:

- `OG 3DS.rar` — four STL reference pieces.
- `OG DS.rar` — six STL scan pieces.
- `RP-010083-CA-1-rpi-5 3D STEP - No Graphics small file.zip` — Raspberry Pi 5 STEP and license.
- `ESP32-S3-DevKitC-1_Reference_Design.zip` — board design package; no STEP model.
- `Radxa_ROCK_4D_3D_v1_11_20250328.stp` — future comparison only; not the V1 fit target.

Reference mesh geometry is for proportions and hinge study only. Keep imported
references in `00_REFERENCE`; do not modify their source meshes. The Pi 5 STEP
is the V1 compute reference. Display, battery, control, and cable dimensions
remain provisional until measured from actual hardware.

## Phase 1 build order

Run `d2k_phase1_layout.py` through the Fusion MCP script executor to create or
refresh the parametric envelopes. `d2k_restructure.py` migrates an older
un-numbered D2K layout to the numbered hierarchy and is only needed for that
migration. `prepare_reference_assets.py` prepares local, reduced-poly Nintendo
scan proxies; then `import_nintendo_references.py` and `import_pi5_step.py`
import the supplied assets into the active Fusion design. The import scripts
expect their extracted inputs under `fusion/assets/local/`.

## Current fit assumptions and checks

- Lower footprint: 165 × 110 mm; lower stack parameter: 33 mm.
- Imported Pi 5 STEP root-context bounds: 88.5 × 57.63 mm in plan, from
  z = 1.616 to 23.36 mm. The STEP includes detailed connectors and 2711
  nested BRep bodies; the simple Pi envelope is kept as an editable guide.
- Bottom display placeholder starts at z = 27 mm, leaving about 3.64 mm
  above the tallest imported Pi feature. This is **not** yet a proven cooling
  or mounting clearance.
- ESP32-S3 board outline is estimated at 25.4 × 63 mm from the supplied
  PADS design. Its 8 mm height is a placeholder; no 3D board model was
  supplied.
- The Pi-to-battery plan gap is only about 1.7 mm at the closest point.
  Battery tolerance, swelling allowance, insulation, connector access and
  standoffs require physical validation.
- The Nintendo STL scans were reduced to ten 50,000-face local proxies and
  imported under `00_REFERENCE/Nintendo_DS`, hidden by default. Their units
  are inferred as millimetres from their overall sizes.

The layout scripts do not automatically save a design. The user saved the
current Phase 1 model as `D2K_phase1`; a copy now also lives in the D2K
Fusion project.

## Fusion cloud project

`organize_fusion_project.py` creates the numbered folders in the **D2K**
Fusion project and copies the saved `D2K_phase1` design from Default Project
to the D2K root without deleting the original. `upload_project_assets.py`
uploads the Pi 5 STEP, ROCK 4D STEP (future comparison only), ten extracted
ESP32 design-package files, and ten lightweight Nintendo mesh proxies when
`UPLOAD_PHASE = "core"`. Set `UPLOAD_PHASE = "full_scans"` and run it again
to upload the ten original high-resolution Nintendo STL pieces into separate
`Original_FullRes` folders. The two phases are separate because full scans
total about 1.25 GB and require longer Fusion cloud processing.

On 2026-09-22, the D2K project contained the copied `D2K_phase1` design,
all 10 full-resolution Nintendo scans, all 10 proxy scans, the Pi and ROCK
models, the Pi license, and all 10 ESP32 source-package files. Fusion reported
all of these cloud items complete. The original downloads and extracted local
files remain untouched; Fusion may translate uploaded CAD files into native
Fusion designs, so the local originals remain the format-preserving sources.
