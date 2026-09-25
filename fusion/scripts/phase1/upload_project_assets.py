"""Upload supplied D2K source pieces into the D2K Fusion cloud project.

Run through the Fusion MCP script executor after organize_fusion_project.py.
Set UPLOAD_PHASE to "core" for the STEP/electronics files and lightweight
reference proxies, or "full_scans" for the original high-resolution STLs.
Uploads are asynchronous; verify completion in the project after running.
"""

from pathlib import Path

import adsk.core


UPLOAD_PHASE = "core"
LOCAL = Path(r"C:\Users\alexi\Repos\D2K\fusion\assets\local")
DOWNLOADS = Path(r"C:\Users\alexi\Downloads")


def child(parent, name):
    folder = parent.dataFolders.itemByName(name)
    if not folder:
        folder = parent.dataFolders.add(name)
        if not folder:
            raise RuntimeError(f"Could not create cloud folder {name}")
    return folder


def destination(root, parts):
    folder = root
    for part in parts:
        folder = child(folder, part)
    return folder


def plan():
    items = []
    if UPLOAD_PHASE == "core":
        pi = LOCAL / "electronics" / "pi5"
        items.extend([
            (("01_ELECTRONICS", "Raspberry_Pi_5"), pi / "rpi-5b_no_graphics.step"),
            (("01_ELECTRONICS", "Raspberry_Pi_5"), pi / "LICENSE.txt"),
            (("01_ELECTRONICS", "ROCK_4D_future"),
             DOWNLOADS / "Radxa_ROCK_4D_3D_v1_11_20250328.stp"),
        ])
        esp = LOCAL / "electronics" / "esp32" / "ESP32-S3-DevKitC-1"
        items.extend(
            (("01_ELECTRONICS", "ESP32_S3", file.parent.name), file)
            for file in sorted(esp.rglob("*"))
            if file.is_file() and file.name != ".DS_Store"
        )
        for key in ("og_ds", "og_3ds"):
            cloud = "OG_DS" if key == "og_ds" else "OG_3DS"
            folder = LOCAL / "reference_proxy" / key
            items.extend(
                (("00_REFERENCE", "Nintendo_DS", cloud, "Proxy_50k"), file)
                for file in sorted(folder.glob("*.stl"))
            )
    elif UPLOAD_PHASE == "full_scans":
        for key in ("og_ds", "og_3ds"):
            cloud = "OG_DS" if key == "og_ds" else "OG_3DS"
            folder = LOCAL / "source" / key
            items.extend(
                (("00_REFERENCE", "Nintendo_DS", cloud, "Original_FullRes"), file)
                for file in sorted(folder.glob("*.stl"))
            )
    else:
        raise ValueError(f"Unsupported upload phase: {UPLOAD_PHASE}")
    return items


def run(_context: str):
    app = adsk.core.Application.get()
    project = next((p for p in app.data.dataProjects if p.name == "D2K"), None)
    if not project:
        raise RuntimeError("D2K cloud project not found")
    started = skipped = 0
    for folder_parts, path in plan():
        if not path.is_file():
            raise FileNotFoundError(path)
        folder = destination(project.rootFolder, folder_parts)
        existing = next((f for f in folder.dataFiles if f.name == path.name), None)
        if existing:
            print("present", "/".join(folder_parts), path.name,
                  "complete", existing.isComplete)
            skipped += 1
            continue
        future = folder.uploadFile(str(path))
        if not future:
            raise RuntimeError(f"Could not start upload: {path}")
        print("started", "/".join(folder_parts), path.name,
              "bytes", path.stat().st_size, "state", future.uploadState)
        started += 1
    print("phase", UPLOAD_PHASE, "started", started, "already present", skipped)
