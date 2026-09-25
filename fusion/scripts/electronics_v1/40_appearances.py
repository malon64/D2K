"""Colour the D2K_Electronics_V1 bodies by role, fit the view, and save.

Appearance names are looked up by content because the Fusion UI is French
("Plastique - Brillant (blanc)"): the library names are localised.
"""

import adsk.core
import adsk.fusion

DOC_NAME = "D2K_Electronics_V1"

COLOURS = {
    "glass": ("D2K_glass_black", 20, 20, 24),
    "screen": ("D2K_active_area", 40, 90, 140),
    "case": ("D2K_case_alu_black", 45, 45, 50),
    "pi": ("D2K_pcb_green", 30, 120, 60),
    "ws": ("D2K_pcb_blue", 30, 70, 160),
    "metal": ("D2K_connector_metal", 190, 190, 195),
    "plastic": ("D2K_connector_plastic", 240, 240, 230),
    "cooler": ("D2K_cooler_alu", 160, 165, 175),
}


def pick(comp_name, body_name):
    n = body_name
    if n.startswith("ActiveArea"):
        return "screen"
    if n.startswith(("Case_Glass", "Boss", "Standoff")):
        return "case"
    if n.startswith(("Touch_glass", "LCD_module", "EVA", "SoC", "Scaler")):
        return "glass"
    if n.startswith("Cooler"):
        return "cooler"
    if n.startswith(("PCB", "Adapter_PCB")):
        return "pi" if comp_name.startswith("Raspberry") else "ws"
    if n.startswith(("USB", "RJ45", "microHDMI", "HDMI", "miniHDMI", "microUSB", "Audio")):
        return "metal"
    return "plastic"


def run(context):
    app = adsk.core.Application.get()
    doc = app.activeDocument
    if doc.name.split(" v")[0] != DOC_NAME:
        print("ABORT active document is", doc.name)
        return
    des = adsk.fusion.Design.cast(app.activeProduct)

    base = None
    for lib in app.materialLibraries:
        if lib.appearances.count > 50:
            base = lib.appearances.item(0)
            for i in range(min(lib.appearances.count, 400)):
                a = lib.appearances.item(i)
                if "Plastic" in a.name or "Plastique" in a.name:
                    base = a
                    break
            break

    made = {}
    for key, (name, r, g, b) in COLOURS.items():
        a = des.appearances.itemByName(name)
        if not a:
            a = des.appearances.addByCopy(base, name)
            for p in a.appearanceProperties:
                if p.objectType == adsk.core.ColorProperty.classType() and \
                        (p.id in ("opaque_albedo", "generic_diffuse") or p.name in ("Color", "Couleur")):
                    try:
                        p.value = adsk.core.Color.create(r, g, b, 0)
                    except RuntimeError:
                        pass
        made[key] = a

    for occ in des.rootComponent.occurrences:
        for body in occ.component.bRepBodies:
            body.appearance = made[pick(occ.component.name, body.name)]

    vp = app.activeViewport
    cam = vp.camera
    cam.viewOrientation = adsk.core.ViewOrientations.IsoTopRightViewOrientation
    cam.isFitView = True
    vp.camera = cam
    print("appearances from", base.name, "- saved", doc.save("Appearances"))
