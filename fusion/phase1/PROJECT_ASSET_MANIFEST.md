# D2K Fusion project asset manifest

This file documents the data migrated out of the local repository into the
Fusion cloud project named **D2K**. The saved working model is `D2K_phase1`
at the project root.

## 00_REFERENCE

`Nintendo_DS/OG_DS` contains six full-resolution scan pieces and six
50k-face working proxies: Bottom Scan, Bottom Screen Scan, Hinge Scan,
LidScan, Top Screen Scan, and Trigger Scan.

`Nintendo_DS/OG_3DS` contains four full-resolution scan pieces and four
50k-face working proxies: Bottom Shell, Button Shell, LCD Bezel, and Top
Shell.

`AYN_Thor` and `R36S` folders are intentionally empty: no files were supplied
for those references.

## 01_ELECTRONICS

- `Raspberry_Pi_5`: `rpi-5b_no_graphics.step` and the supplied MIT license.
- `ESP32_S3`: extracted source data grouped by Schematic, PCB, Gerber,
  fabrication requirements, BOM, and placement. This includes DSN, ASC, PCB,
  PDF, XLS/XLSX, ZIP, and HTML source files. No 3D STEP model was included in
  the supplied ESP32 package.
- `ROCK_4D_future`: `Radxa_ROCK_4D_3D_v1_11_20250328.stp`. It is archived for
  comparison only and is not the Phase 1 fit reference.
- `Waveshare_5in_HDMI`, `Waveshare_4_DSI`, `Battery`, `Audio_Amp`, and
  `Speakers` remain empty until source documents or models are supplied.

## 02_CONTROLS / 03_D2K_CASE

These folders carry the project structure. Their controlled geometry is in
`D2K_phase1`; no separate supplier files were supplied for the controls or
case.

## Source fidelity

Full-resolution Nintendo STL source pieces are retained as `Original_FullRes`.
The `Proxy_50k` copies are deliberate reduced-poly working meshes. Uploaded
STEP and STL CAD files may be translated by Fusion; the original downloaded
archives and extracted files remain external source backups until the requested
local-directory removal is completed.
