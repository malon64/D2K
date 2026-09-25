"""Waveshare 5inch HDMI LCD (H) simplified model, placed above the 4in DSI.

Front coordinates (mm): glass faces +Z, PCB at Z = -1.6..0, parts on the back
(-Z), PCB corner at the local origin. The Waveshare size drawing is a rear
view, so x_front = 121 - x_rear. The layer stack (EVA, LCD, glass) and part
heights are ESTIMATED (total ~13.6 mm): measure the real screen.
"""

import adsk.core
import adsk.fusion

DOC_NAME = "D2K_Electronics_V1"
COMP_NAME = "Waveshare_5in_HDMI_LCD_H"
OFFSET_CM = (-0.635, 9.684, 0)  # centred over the 4in DSI, 25 mm gap

T = adsk.fusion.TemporaryBRepManager.get()


def P(x, y, z):
    return adsk.core.Point3D.create(x / 10, y / 10, z / 10)


def box(x0, x1, y0, y1, z0, z1):
    obb = adsk.core.OrientedBoundingBox3D.create(
        P((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
        adsk.core.Vector3D.create(1, 0, 0), adsk.core.Vector3D.create(0, 1, 0),
        abs(x1 - x0) / 10, abs(y1 - y0) / 10, abs(z1 - z0) / 10)
    return T.createBox(obb)


def cyl(x, y, z0, z1, d):
    return T.createCylinderOrCone(P(x, y, z0), d / 20, P(x, y, z1), d / 20)


def boolean(body, tool, kind):
    T.booleanOperation(body, tool, kind)


def add_bodies(comp, items):
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

    m = adsk.core.Matrix3D.create()
    m.translation = adsk.core.Vector3D.create(*OFFSET_CM)
    occ = root.occurrences.addNewComponent(m)
    c = occ.component
    c.name = COMP_NAME
    c.partNumber = "Waveshare 5inch HDMI LCD (H)"
    c.description = (
        "5in TFT 800x480, 5-pt capacitive USB touch, toughened glass. PCB/glass 121x76, tabs to 89.48, "
        "4x holes 109x84 (d3.2). Ports on one edge: HDMI type A (Display), micro-USB Touch (touch + "
        "power), mini-HDMI VGA, 3.5mm audio jack; 4-pin speaker header; DC micro-USB power + 5 OSD "
        "buttons on the other edge. 5V ~400mA. Stack thickness ~13.6 ESTIMATED - measure.")

    union = adsk.fusion.BooleanTypes.UnionBooleanType
    diff = adsk.fusion.BooleanTypes.DifferenceBooleanType
    pcb = box(0, 121, 0, 76, -1.6, 0)
    for x, y0, y1 in [(6, -6.74, 0), (115, -6.74, 0), (6, 76, 82.74), (115, 76, 82.74)]:
        boolean(pcb, box(x - 4.5, x + 4.5, y0, y1, -1.6, 0), union)
    for x, y in [(6, -4), (115, -4), (6, 80), (115, 80)]:
        boolean(pcb, cyl(x, y, -3, 1, 3.2), diff)
    items = [
        ("PCB_with_tabs", pcb),
        ("EVA_spacer", box(2, 119, 2, 74, 0, 1.5)),
        ("LCD_module", box(0.15, 120.85, 0.1, 75.9, 1.5, 5.0)),
        ("Touch_glass", box(0, 121, 0, 76, 5.0, 6.0)),
        ("ActiveArea_108x64.8", box(6.5, 114.5, 5.6, 70.4, 6.0, 6.05)),
        ("HDMI_A_Display", box(108.8, 122.0, 25.5, 40.5, -7.6, -1.6)),
        ("microUSB_Touch", box(115.6, 122.5, 46.3, 53.7, -4.2, -1.6)),
        ("miniHDMI_VGA", box(113.3, 121.8, 7.4, 19.4, -5.1, -1.6)),
        ("Audio_jack_3.5mm", box(109.0, 124.0, 61.4, 67.4, -6.6, -1.6)),
        ("Speaker_header_4p", box(81.0, 87.0, 66.0, 76.0, -6.1, -1.6)),
        ("microUSB_DC_power", box(-0.6, 4.9, 6.3, 13.7, -4.2, -1.6)),
        ("Scaler_RTD2660", box(50, 64, 30, 44, -2.8, -1.6)),
    ]
    for i, y in enumerate([71.0, 58.5, 46.7, 34.8, 22.2]):
        items.append(("OSD_button_%d" % (i + 1), box(-0.8, 2.7, y - 3.5, y + 3.5, -5.1, -1.6)))
    add_bodies(c, items)
    print(COMP_NAME, "bodies", c.bRepBodies.count)
