"""Import lightweight OG DS and OG 3DS scan proxies into 00_REFERENCE.

Run prepare_reference_assets.py first. Original scans remain untouched in
fusion/assets/local/source. Imported mesh bodies are hidden with the reference
component by default so the editable D2K layout remains easy to inspect.
"""

from pathlib import Path

import adsk.core
import adsk.fusion


PROXIES = (
    Path(r"C:\Users\alexi\Repos\D2K\fusion\assets\local\reference_proxy")
)
MODELS = {
    "OG_3DS": (
        "Bottom Shell.stl", "Button Shell.stl", "LCD Bezel.stl", "Top Shell.stl"
    ),
    "OG_DS": (
        "Bottom Scan.stl", "Bottom Screen Scan.stl", "Hinge Scan.stl",
        "LidScan.stl", "Top Screen Scan.stl", "Trigger Scan.stl"
    ),
}


def run(_context: str):
    design = adsk.fusion.Design.cast(adsk.core.Application.get().activeProduct)
    if not design:
        raise RuntimeError("No active Fusion design")

    def occurrence(parent, name):
        for index in range(parent.occurrences.count):
            found = parent.occurrences.item(index)
            if found.component.name == name:
                return found
        raise RuntimeError("Missing component " + name)

    master = occurrence(design.rootComponent, "D2K_MASTER").component
    reference = occurrence(master, "00_REFERENCE").component
    nintendo_occurrence = occurrence(reference, "Nintendo_DS")
    nintendo = nintendo_occurrence.component

    current_names = {
        nintendo.meshBodies.item(i).name for i in range(nintendo.meshBodies.count)
    }
    added = 0
    for group, filenames in MODELS.items():
        pending = [(name, PROXIES / group.lower() / name)
                   for name in filenames if group + " - " + name not in current_names]
        if not pending:
            continue
        for _, source in pending:
            if not source.is_file():
                raise FileNotFoundError(source)
        feature = nintendo.features.baseFeatures.itemByName(group + " proxy meshes")
        if not feature:
            feature = nintendo.features.baseFeatures.add()
            feature.name = group + " proxy meshes"
        if not feature.startEdit():
            raise RuntimeError("Could not edit mesh base feature " + group)
        try:
            for name, source in pending:
                imported = nintendo.meshBodies.add(
                    str(source), adsk.fusion.MeshUnits.MillimeterMeshUnit, feature
                )
                if not imported or imported.count != 1:
                    raise RuntimeError("Could not import proxy " + str(source))
                imported.item(0).name = group + " - " + name
                added += 1
        finally:
            feature.finishEdit()

    nintendo_occurrence.isLightBulbOn = False
    print("Nintendo references:", nintendo.meshBodies.count,
          "mesh bodies; newly imported", added,
          "; reference visibility off")
