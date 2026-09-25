# D2K Fusion work

Everything done in Autodesk Fusion for D2K is tracked here: the scripts that
build the Fusion models, the generated electronics library, and the written
record of decisions, open questions, wiring warnings and constraints. Fusion
holds the models; this folder holds how and why they were made.

The Fusion cloud project is **D2K** (Fusion personal-use licence; the Fusion
UI is in French).

## Contents

| Path | What it is |
| --- | --- |
| [roadmap.md](roadmap.md) | **Goals of the Fusion work** (see the wiring, shrink the electronics, design the clamshell) and the step plan. |
| [decisions.md](decisions.md) | Dated decision log (what was decided, why, what it affects). |
| [open-questions.md](open-questions.md) | Open questions and **missing data**, with how to resolve each. |
| [wiring.md](wiring.md) | V1 wiring (Pi 5 + two Waveshare screens) and **wiring warnings**. |
| [constraints.md](constraints.md) | Mechanical, electrical and tooling constraints, including clashes found between the models and the phase 1 layout. |
| [parts.md](parts.md) | Part specs used in the models: dimensions, electrical data, sources, modelling assumptions. |
| [electronics/](electronics/) | `gen_d2k_lbr.py` generates `D2K.lbr` (EAGLE 9 library of the V1 modules), uploaded to Fusion as `D2K.flbr`. |
| [scripts/electronics_v1/](scripts/electronics_v1/) | Build scripts for the `D2K_Electronics_V1` design, numbered in run order. |
| [scripts/tools/](scripts/tools/) | Read-only helpers: design inventory, project tree listing / admin download. |
| [scripts/phase1/](scripts/phase1/) | Scripts behind `D2K_phase1` (envelope layout, reference imports, project organisation), recovered from the Fusion project's `99_PROJECT_ADMIN/Fusion_Scripts`. |
| [phase1/](phase1/) | Phase 1 notes recovered from `99_PROJECT_ADMIN/Documentation` (README and asset manifest). |
| `assets/local/` | Git-ignored. Local source meshes/STEP files that the phase 1 import scripts expect. |

## Fusion project map (2026-09-25)

```
D2K/
  D2K_phase1            Mechanical master layout (envelopes, controls, case, Pi 5 STEP). HEAVY: ~7 GB in RAM.
  D2K_Electronics_V1    V1 electronics reference models (Pi 5 + cooler, 4in DSI, 5in HDMI H). Light.
  D2K.flbr              Electronics library generated from electronics/D2K.lbr.
  00_REFERENCE/         Nintendo DS/3DS scans (full-res + 50k proxies), AYN_Thor and R36S (empty).
  01_ELECTRONICS/       Raspberry_Pi_5 (official STEP as rpi-5b_no_graphics), ESP32_S3 design package,
                        ROCK_4D_future, empty Waveshare/Battery/Audio_Amp/Speakers folders.
  02_CONTROLS/, 03_D2K_CASE/   Folder structure only; geometry lives in D2K_phase1.
  99_PROJECT_ADMIN/     Documentation + Fusion_Scripts (older copies of phase1/ and scripts/phase1/).
```

## Running a script

The scripts are written for the **Fusion MCP** script executor (Claude Code
with the `fusion` MCP server on `http://127.0.0.1:27182/mcp`). Each file is
self-contained and defines `run(context)`; the executor calls it. Pass the
file content as the `script` argument, and `readOnly: true` for the tools.

To rebuild `D2K_Electronics_V1` from scratch: `00` → `10` → `20` → `30` → `40`
(each part script checks the active document and skips existing components).
To refresh the library: `python electronics/gen_d2k_lbr.py`, then `50`.
Any Python 3 works; Fusion's bundled one is at
`%LOCALAPPDATA%\Autodesk\webdeploy\production\<build>\Python\python.exe`.

## Working rules

- **Go easy on Fusion.** One short script at a time, wait for the result, no
  retries on a timeout. Opening `D2K_phase1` froze and then crashed Fusion
  once (2026-09-25); let the user open it, wait for it to load, then run only
  read-only inventory scripts.
- Keep electronics work out of `D2K_phase1`: models go to
  `D2K_Electronics_V1`, symbols to `D2K.flbr`. Reference the light models
  from the phase 1 layout later instead of copying heavy STEP bodies.
- The Fusion API cannot create Electronics documents or schematic content
  (`adsk.electron` is read-only). Generate EAGLE XML here and upload it with
  `DataFolder.uploadFile`; Fusion converts `.lbr`/`.sch`/`.brd`.
- Change a model in Fusion → update its script here and the matching doc
  (decision, open question, constraint) in the same change.
