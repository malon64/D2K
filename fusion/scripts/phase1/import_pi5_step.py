"""Import the supplied Raspberry Pi 5 STEP under the D2K compute component.

The model is reference geometry. The original Phase 1 bounding volume remains
available but is hidden after a successful import. Set D2K_PI5_STEP to override
the default local source path.
"""

import os
from pathlib import Path

import adsk.core
import adsk.fusion


DEFAULT_SOURCE = (
    r"C:\Users\alexi\Repos\D2K\fusion\assets\local\electronics\pi5"
    r"\rpi-5b_no_graphics.step"
)


def run(_context: str):
    source = Path(os.environ.get("D2K_PI5_STEP", DEFAULT_SOURCE))
    if not source.is_file():
        raise FileNotFoundError(source)
    app = adsk.core.Application.get()
    design = adsk.fusion.Design.cast(app.activeProduct)
    if not design:
        raise RuntimeError("No active Fusion design")

    def child(parent, name):
        for index in range(parent.occurrences.count):
            comp = parent.occurrences.item(index).component
            if comp.name == name:
                return comp
        return None

    master = child(design.rootComponent, "D2K_MASTER")
    electronics = child(master, "01_ELECTRONICS") if master else None
    pi = child(electronics, "Raspberry_Pi_5.step") if electronics else None
    if not pi:
        raise RuntimeError("D2K Pi 5 component is missing")

    source_occurrence = None
    for index in range(pi.occurrences.count):
        candidate = pi.occurrences.item(index)
        if candidate.component.name == "STEP_Source":
            source_occurrence = candidate
            break
    if not source_occurrence:
        source_occurrence = pi.occurrences.addNewComponent(adsk.core.Matrix3D.create())
        source_occurrence.component.name = "STEP_Source"
    imported = source_occurrence.component
    if not (imported.bRepBodies.count or imported.occurrences.count):
        options = app.importManager.createSTEPImportOptions(str(source))
        if not options:
            raise RuntimeError("Could not create STEP import options")
        if not app.importManager.importToTarget(options, imported):
            raise RuntimeError("Fusion did not import the Pi 5 STEP")

    master_occurrence = next(
        design.rootComponent.occurrences.item(i)
        for i in range(design.rootComponent.occurrences.count)
        if design.rootComponent.occurrences.item(i).component.name == "D2K_MASTER"
    )
    electronics_native = next(
        master.occurrences.item(i)
        for i in range(master.occurrences.count)
        if master.occurrences.item(i).component.name == "01_ELECTRONICS"
    )
    electronics_proxy = electronics_native.createForAssemblyContext(master_occurrence)
    pi_native = next(
        electronics.occurrences.item(i)
        for i in range(electronics.occurrences.count)
        if electronics.occurrences.item(i).component.name == "Raspberry_Pi_5.step"
    )
    pi_proxy = pi_native.createForAssemblyContext(electronics_proxy)
    source_proxy = source_occurrence.createForAssemblyContext(pi_proxy)
    if not source_proxy:
        raise RuntimeError("Could not create Pi STEP occurrence in root assembly context")

    bounds = source_proxy.preciseBoundingBox
    desired_y = design.userParameters.itemByName("pi_center_y").value
    current_x = (bounds.minPoint.x + bounds.maxPoint.x) / 2
    current_y = (bounds.minPoint.y + bounds.maxPoint.y) / 2
    if abs(current_x) > 0.05 or abs(current_y - desired_y) > 0.05:
        delta = adsk.core.Vector3D.create(
            -current_x,
            desired_y - current_y,
            0.1 - bounds.minPoint.z,
        )
        transform = source_proxy.transform2
        translation = transform.translation
        translation.add(delta)
        transform.translation = translation
        source_proxy.transform2 = transform
        if design.snapshots.hasPendingSnapshot:
            snapshot = design.snapshots.add()
            if not snapshot:
                raise RuntimeError("Could not commit Pi 5 STEP alignment snapshot")
            snapshot.name = "Align Pi 5 STEP to lower layout"
    if pi.bRepBodies.count:
        pi.bRepBodies.item(0).isLightBulbOn = False
    final = source_proxy.preciseBoundingBox
    print("Pi 5 STEP under 01_ELECTRONICS/Raspberry_Pi_5.step/STEP_Source")
    print("aligned bbox mm", [round(value * 10, 3) for value in (
        final.minPoint.x, final.minPoint.y, final.minPoint.z,
        final.maxPoint.x, final.maxPoint.y, final.maxPoint.z,
    )])
