"""One-off fix (2026-09-25) of two bodies already built in D2K_Electronics_V1.

- Raspberry_Pi_5 / Cooler_base covered the whole 63.5 x 42.5 footprint and hid
  the MIPI connectors; the real base plate stops under the fan.
- Waveshare_4in_DSI_TOUCH_A / Conn_Power_2p_5V_GND was 4.5 mm tall and ran
  into the Pi PCB resting 5 mm above the screen back.

The part scripts 10 and 20 already carry the corrected geometry; this script
only patches a design built before the fix. Skips bodies already fixed.
"""

import adsk.core
import adsk.fusion

DOC_NAME = "D2K_Electronics_V1"
T = adsk.fusion.TemporaryBRepManager.get()


def P(x, y, z):
    return adsk.core.Point3D.create(x / 10, y / 10, z / 10)


def box(x0, x1, y0, y1, z0, z1):
    obb = adsk.core.OrientedBoundingBox3D.create(
        P((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
        adsk.core.Vector3D.create(1, 0, 0), adsk.core.Vector3D.create(0, 1, 0),
        abs(x1 - x0) / 10, abs(y1 - y0) / 10, abs(z1 - z0) / 10)
    return T.createBox(obb)


def replace_body(comp, name, new_items):
    """Swap one body of the component's base feature.

    While a base feature is being edited its bodies are reached through
    bf.bodies (comp.bRepBodies does not list them), and the design must never
    be left in edit mode: a failure there once rolled the timeline back.
    """
    bf = comp.features.baseFeatures.item(0)
    bf.startEdit()
    try:
        old = [b for b in bf.bodies if b.name == name][0]
        appearance = old.appearance
        old.deleteMe()
        for new_name, tb in new_items:
            nb = comp.bRepBodies.add(tb, bf)
            nb.name = new_name
            nb.appearance = appearance
    finally:
        bf.finishEdit()


def run(context):
    app = adsk.core.Application.get()
    for doc in app.documents:
        if doc.name.split(" v")[0] == DOC_NAME:
            doc.activate()
    if app.activeDocument.name.split(" v")[0] != DOC_NAME:
        print("ABORT", DOC_NAME, "is not open")
        return
    root = adsk.fusion.Design.cast(app.activeProduct).rootComponent
    comps = {o.component.name: o.component for o in root.occurrences}

    pi = comps["Raspberry_Pi_5"]
    if pi.bRepBodies.itemByName("Cooler_base_under_fan"):
        print("SKIP cooler already fixed")
    else:
        replace_body(pi, "Cooler_base", [
            ("Cooler_base", box(0.9, 34.4, 6.5, 49.0, 3.2, 5.2)),
            ("Cooler_base_under_fan", box(34.4, 64.4, 19.0, 49.0, 3.2, 5.2)),
        ])
        print("cooler base fixed")

    ws4 = comps["Waveshare_4in_DSI_TOUCH_A"]
    conn = ws4.bRepBodies.itemByName("Conn_Power_2p_5V_GND")
    if conn.boundingBox.minPoint.z > -0.5:
        print("SKIP 4in power connector already fixed")
    else:
        replace_body(ws4, "Conn_Power_2p_5V_GND",
                     [("Conn_Power_2p_5V_GND", box(80.0, 86.0, 44.5, 50.5, -4.9, -3.0))])
        print("4in power connector fixed")
