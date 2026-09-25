"""Migrate the Phase 1 Fusion component tree to the numbered D2K hierarchy.

This script moves existing occurrences and keeps their component definitions,
sketches, features, and bodies. It is safe to rerun on an already migrated tree.
"""

import adsk.core
import adsk.fusion


def run(_context: str):
    design = adsk.fusion.Design.cast(adsk.core.Application.get().activeProduct)
    if not design:
        raise RuntimeError("No active Fusion design")

    def occurrence(parent, name):
        for index in range(parent.occurrences.count):
            item = parent.occurrences.item(index)
            if item.component.name == name:
                return item
        return None

    def component(parent, name):
        item = occurrence(parent, name)
        return item.component if item else None

    def rename_child(parent, old, new):
        found = component(parent, new)
        if found:
            return found
        found = component(parent, old)
        if not found:
            raise RuntimeError("Missing component " + old)
        found.name = new
        return found

    def ensure_child(parent, name):
        found = component(parent, name)
        if found:
            return found
        made = parent.occurrences.addNewComponent(adsk.core.Matrix3D.create()).component
        made.name = name
        return made

    def rehome(source, name, target):
        original = occurrence(source, name)
        if not original:
            if component(target, name):
                return
            raise RuntimeError("Cannot move missing component " + name)
        if component(target, name):
            raise RuntimeError("Target already contains " + name)
        placed = target.occurrences.addExistingComponent(
            original.component, adsk.core.Matrix3D.create()
        )
        if not placed or placed.component != original.component:
            raise RuntimeError("Could not place " + name)
        if not original.deleteMe():
            raise RuntimeError("Could not remove prior occurrence of " + name)

    def remove_empty(parent, name):
        item = occurrence(parent, name)
        if not item:
            return
        owned = item.component
        if owned.bRepBodies.count or owned.meshBodies.count or owned.occurrences.count:
            raise RuntimeError("Refusing to remove nonempty " + name)
        if not item.deleteMe():
            raise RuntimeError("Could not remove empty " + name)

    master = component(design.rootComponent, "D2K_MASTER")
    if not master:
        raise RuntimeError("D2K_MASTER is missing")

    reference = rename_child(master, "REFERENCE", "00_REFERENCE")
    electronics = rename_child(master, "ELECTRONICS", "01_ELECTRONICS")
    controls = rename_child(master, "CONTROLS", "02_CONTROLS")
    case = rename_child(master, "ENCLOSURE", "03_D2K_CASE")

    rename_child(case, "LowerCase", "Lower")
    rename_child(case, "UpperCase", "Upper")
    hinge = component(case, "Hinge")
    if not hinge:
        raise RuntimeError("Hinge component is missing")

    speakers = ensure_child(electronics, "Speakers")
    for name in ("Speaker_L", "Speaker_R"):
        rehome(electronics, name, speakers)
    rename_child(electronics, "Raspberry_Pi_5", "Raspberry_Pi_5.step")
    rename_child(electronics, "Top_Display_5in", "Waveshare_5in_HDMI")
    rename_child(electronics, "Bottom_Display_4in", "Waveshare_4_DSI")
    rename_child(electronics, "Battery_placeholder", "Battery")

    old_keepouts = component(master, "KEEP_OUTS")
    if old_keepouts:
        old_shoulders = component(old_keepouts, "Shoulder_Mechanisms")
        if not old_shoulders:
            raise RuntimeError("Shoulder keep-outs are missing")
        for side in ("L", "R"):
            target = ensure_child(controls, side + "1_" + side + "2")
            rehome(old_shoulders, side + "1", target)
            rehome(old_shoulders, side + "2", target)
        remove_empty(old_keepouts, "Shoulder_Mechanisms")
        for name in (
            "HDMI_Hinge_Path",
            "Power_Audio_Hinge_Path",
            "Cable_Service_Loops",
        ):
            rehome(old_keepouts, name, hinge)
        remove_empty(old_keepouts, "Cooling")
        remove_empty(old_keepouts, "Connector_Clearances")
        remove_empty(master, "KEEP_OUTS")

    print("Migrated D2K tree; top groups:",
          [master.occurrences.item(i).component.name
           for i in range(master.occurrences.count)])
    print("Case children:",
          [case.occurrences.item(i).component.name
           for i in range(case.occurrences.count)])
