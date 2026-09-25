"""Waveshare 4-DSI-TOUCH-A (SKU 34354) simplified model, at the design origin.

Front coordinates (mm): glass faces +Z, back face at Z = 0, outline corner at
the origin. Rear-view drawing positions are mirrored: x_front = 108.3 - x_rear.
Source: Waveshare 4-DSI-TOUCH-A size drawing (see fusion/parts.md).
"""

import adsk.core
import adsk.fusion

DOC_NAME = "D2K_Electronics_V1"
COMP_NAME = "Waveshare_4in_DSI_TOUCH_A"

T = adsk.fusion.TemporaryBRepManager.get()


def P(x, y, z):  # the API works in cm
    return adsk.core.Point3D.create(x / 10, y / 10, z / 10)


def box(x0, x1, y0, y1, z0, z1):
    obb = adsk.core.OrientedBoundingBox3D.create(
        P((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
        adsk.core.Vector3D.create(1, 0, 0), adsk.core.Vector3D.create(0, 1, 0),
        abs(x1 - x0) / 10, abs(y1 - y0) / 10, abs(z1 - z0) / 10)
    return T.createBox(obb)


def cyl(x, y, z0, z1, d):
    return T.createCylinderOrCone(P(x, y, z0), d / 20, P(x, y, z1), d / 20)


def cut(body, tool):
    T.booleanOperation(body, tool, adsk.fusion.BooleanTypes.DifferenceBooleanType)


def add_bodies(comp, items):
    """One base feature per component keeps the timeline to a single entry."""
    bf = comp.features.baseFeatures.add()
    bf.startEdit()
    for name, b in items:
        comp.bRepBodies.add(b, bf).name = name
    bf.finishEdit()


def run(context):
    app = adsk.core.Application.get()
    if app.activeDocument.name.split(" v")[0] != DOC_NAME:
        print("ABORT active document is", app.activeDocument.name)
        return
    root = adsk.fusion.Design.cast(app.activeProduct).rootComponent
    if any(o.component.name == COMP_NAME for o in root.occurrences):
        print("SKIP", COMP_NAME, "exists")
        return

    occ = root.occurrences.addNewComponent(adsk.core.Matrix3D.create())
    c = occ.component
    c.name = COMP_NAME
    c.partNumber = "Waveshare 34354"
    c.description = (
        "4in IPS 480x800 (landscape 800x480), 5-pt capacitive (Goodix 0x14 via DSI I2C). "
        "Outline 108.3x65.1, AA 86.4x51.84, body 5.8. 8x M2.5 threaded: corners 100x56, "
        "inner 58x49 = Pi mounting pattern. Power 5V 180mA typ via 2-wire lead to Pi GPIO 5V/GND. "
        "22-pin 0.5mm reverse FFC 200mm to Pi 5 DSI1. Standoff heights and adapter connector "
        "positions are read from the drawing and approximate.")
    W, H = 108.3, 65.1
    items = [
        ("Case_Glass", box(0, W, 0, H, 0, 5.8)),
        ("ActiveArea_86.4x51.84", box((W - 86.4) / 2, (W + 86.4) / 2, (H - 51.84) / 2, (H + 51.84) / 2, 5.8, 5.85)),
    ]
    for x, y in [(4.15, 4.55), (104.15, 4.55), (4.15, 60.55), (104.15, 60.55)]:
        s = cyl(x, y, -2.1, 0, 5.0)
        cut(s, cyl(x, y, -2.2, 0.1, 2.2))
        items.append(("Boss_M2.5", s))
    for x, y in [(35.15, 8.05), (93.15, 8.05), (35.15, 57.05), (93.15, 57.05)]:
        s = cyl(x, y, -5.0, 0, 5.0)
        cut(s, cyl(x, y, -5.1, 0.1, 2.2))
        items.append(("Standoff_M2.5_PiMount", s))
    items += [
        ("Adapter_PCB", box(79.1, 93.1, 12.55, 52.55, -3.0, 0)),
        ("Conn_DSI_22p_0.5mm", box(79.6, 84.0, 16.5, 34.0, -4.2, -3.0)),
        ("Conn_Power_2p_5V_GND", box(80.0, 86.0, 44.5, 50.5, -7.5, -3.0)),
    ]
    add_bodies(c, items)
    print(COMP_NAME, "bodies", c.bRepBodies.count)
