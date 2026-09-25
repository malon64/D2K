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
| [constraints.md](constraints.md) | Mechanical, electrical and tooling constraints, and the minimum envelopes set by the parts. |
| [parts.md](parts.md) | Part specs used in the models: dimensions, electrical data, sources, modelling assumptions. |
| [electronics/](electronics/) | `gen_d2k_lbr.py` generates `D2K.lbr` (EAGLE 9 library of the V1 modules, uploaded as `D2K.flbr`); `gen_d2k_v1_sch.py` generates `D2K_V1.sch`, the V1 bench interconnect schematic (uploaded as the `D2K_V1` Electronics design). |
| [scripts/electronics_v1/](scripts/electronics_v1/) | Build scripts for the `D2K_Electronics_V1` design, numbered in run order. |
| [scripts/tools/](scripts/tools/) | Read-only helpers: design inventory, project tree listing / admin download. |
| [scripts/phase1/](scripts/phase1/) | **Legacy.** Scripts behind the removed `D2K_phase1` layout (envelopes, reference imports, project organisation). Kept for the reference-import and project-organisation code. |
| [phase1/](phase1/) | **Legacy.** Phase 1 notes (README and asset manifest of the Fusion project). |
| `assets/local/` | Git-ignored. Local source meshes/STEP files that the phase 1 import scripts expect. |

## Fusion project map (2026-09-25)

```
D2K/
  D2K_Electronics_V1    V1 electronics reference models (Pi 5 + cooler, 4in DSI, 5in HDMI H). Light.
  D2K.flbr              Electronics library generated from electronics/D2K.lbr.
  D2K_V1 (fsch + fprj)  V1 bench interconnect schematic generated from electronics/D2K_V1.sch.
  (D2K_phase1           Legacy mechanical layout, removed by the user on 2026-09-25.)
  00_REFERENCE/         Nintendo DS/3DS scans (full-res + 50k proxies), AYN_Thor and R36S (empty).
  01_ELECTRONICS/       Raspberry_Pi_5 (official STEP as rpi-5b_no_graphics), ESP32_S3 design package,
                        ROCK_4D_future, empty Waveshare/Battery/Audio_Amp/Speakers folders.
  02_CONTROLS/, 03_D2K_CASE/   Folder structure only.
  99_PROJECT_ADMIN/     Documentation + Fusion_Scripts (older copies of phase1/ and scripts/phase1/).
```

## Running a script

The scripts are written for the **Fusion MCP** script executor (Claude Code
with the `fusion` MCP server on `http://127.0.0.1:27182/mcp`). Each file is
self-contained and defines `run(context)`; the executor calls it. Fusion runs
on this PC, so the MCP `script` argument can simply run the repo file (the
repo is then exactly what ran):

```python
SCRIPT = r'C:\Users\alexi\Repos\D2K\fusion\scripts\electronics_v1\70_cables_v1_stock.py'
def run(context):
    g = {'__name__': 'd2k_script', '__file__': SCRIPT}
    exec(compile(open(SCRIPT, encoding='utf-8').read(), SCRIPT, 'exec'), g)
    g['run'](context)
```

Pass `readOnly: true` for the tools. A script that raises is rolled back by
Fusion as a whole.

To rebuild `D2K_Electronics_V1` from scratch: `00` → `10` → `20` → `30` → `40`
→ `70` (each part script activates or checks the document and skips existing
components; `65` only patches designs built before its fix).
To refresh the library and the V1 schematic: `python electronics/gen_d2k_lbr.py`,
`python electronics/gen_d2k_v1_sch.py`, then `60`. **Uploading a name that
already exists creates a second file, not a version**: delete the old `D2K`
library and `D2K_V1` schematic + design first (`DataFile.deleteMe()`, files
must be closed; deleted items go to the Fusion project's trash).
Any Python 3 works; Fusion's bundled one is at
`%LOCALAPPDATA%\Autodesk\webdeploy\production\<build>\Python\python.exe`.

## Working rules

- **Go easy on Fusion.** One short script at a time, wait for the result, no
  retries on a timeout. Opening the heavy legacy `D2K_phase1` froze and then
  crashed Fusion once (2026-09-25); an upload also keeps Fusion busy for a
  while (calls time out until it finishes). Check
  `Get-Process Fusion360 | Select Responding` before sending more.
- Fusion sometimes opens a popup (for example after an upload); every MCP
  call then times out while Windows still says Fusion responds. Ask the user
  to close it; the queued calls run afterwards.
- Editing a base feature: reach its bodies through `bf.bodies` and always
  `finishEdit()` in a `finally` (a failure left the design stuck in edit mode
  once; one undo recovered it).
- Keep designs light: simple part models, not detailed vendor STEP files
  (the official Pi 5 STEP has 2711 bodies). Future shell designs reference
  `D2K_Electronics_V1` components.
- Screenshots don't work in the Electronics editor. Export the sheet with
  `app.executeTextCommand('Electron.run "EXPORT IMAGE <path.png> 100"')`;
  the export leaves out the part names/values (`>NAME`, `>VALUE`).
- The Fusion API cannot create Electronics documents or schematic content
  (`adsk.electron` is read-only). Generate EAGLE XML here and upload it with
  `DataFolder.uploadFile`; Fusion converts `.lbr`/`.sch`/`.brd`.
- Change a model in Fusion → update its script here and the matching doc
  (decision, open question, constraint) in the same change.
