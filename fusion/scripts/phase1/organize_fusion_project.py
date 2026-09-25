"""Create the D2K cloud-project asset tree and copy the Phase 1 design.

Run through the Fusion MCP script executor. The source document is copied,
not moved or deleted, so its existing version remains in Default Project.
The operation is idempotent: existing folders and a same-named design are
reused rather than duplicated.
"""

import adsk.core


FOLDERS = {
    "00_REFERENCE": {
        "AYN_Thor": {},
        "Nintendo_DS": {"OG_DS": {}, "OG_3DS": {}},
        "R36S": {},
    },
    "01_ELECTRONICS": {
        "Raspberry_Pi_5": {},
        "Waveshare_5in_HDMI": {},
        "Waveshare_4_DSI": {},
        "ESP32_S3": {},
        "Battery": {},
        "Audio_Amp": {},
        "Speakers": {},
        "ROCK_4D_future": {},
    },
    "02_CONTROLS": {
        "CirclePad_L": {},
        "CirclePad_R": {},
        "DPad": {},
        "ABXY": {},
        "Start_Select_Home": {},
        "L1_L2": {},
        "R1_R2": {},
    },
    "03_D2K_CASE": {"Lower": {}, "Upper": {}, "Hinge": {}},
}


def ensure_folders(parent, children, path="D2K"):
    for name, grandchildren in children.items():
        folder = parent.dataFolders.itemByName(name)
        if not folder:
            folder = parent.dataFolders.add(name)
            if not folder:
                raise RuntimeError(f"Could not create {path}/{name}")
            print("created", f"{path}/{name}")
        ensure_folders(folder, grandchildren, f"{path}/{name}")


def run(_context: str):
    app = adsk.core.Application.get()
    doc = app.activeDocument
    if not doc or doc.name != "D2K_phase1" or not doc.dataFile:
        raise RuntimeError("Open the saved D2K_phase1 design first")
    if doc.isModified:
        raise RuntimeError("D2K_phase1 has unsaved changes; review them first")

    project = next((p for p in app.data.dataProjects if p.name == "D2K"), None)
    if not project:
        raise RuntimeError("D2K cloud project not found")
    root = project.rootFolder
    ensure_folders(root, FOLDERS)

    existing = next((f for f in root.dataFiles if f.name == "D2K_phase1"), None)
    if existing:
        print("design already in D2K root", existing.id)
    else:
        copy = doc.dataFile.copy(root)
        if not copy:
            raise RuntimeError("Could not copy D2K_phase1 to the D2K project")
        print("copied D2K_phase1", copy.id)
    print("source preserved", doc.dataFile.parentProject.name, doc.dataFile.id)
