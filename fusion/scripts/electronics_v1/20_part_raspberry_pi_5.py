"""Raspberry Pi 5 + Active Cooler (SC1148) simplified model.

Local coordinates (mm): PCB bottom-left corner at the origin, component side
+Z, as in the official Raspberry Pi 5 mechanical drawing. The occurrence is
placed flipped onto the back of the 4in DSI (Waveshare's intended mount): the
Pi holes land on the screen's inner 58x49 standoffs, component side facing -Z.
Run after 10_part_waveshare_4in_dsi.py.

This is a light stand-in; the official detailed model is in the Fusion project
at 01_ELECTRONICS/Raspberry_Pi_5/rpi-5b_no_graphics (2711 bodies, heavy).
"""

import adsk.core
import adsk.fusion

DOC_NAME = "D2K_Electronics_V1"
COMP_NAME = "Raspberry_Pi_5"

# Flip 180 deg about Y, then translate so hole (3.5, 3.5) lands on the
# standoff at (93.15, 8.05) and the PCB bottom sits on the 5 mm standoffs.
PLACEMENT = [-1, 0, 0, 9.665,
             0, 1, 0, 0.455,
             0, 0, -1, -0.5,
             0, 0, 0, 1]  # cm

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


def cut(body, tool):
    T.booleanOperation(body, tool, adsk.fusion.BooleanTypes.DifferenceBooleanType)


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
    m.setWithArray(PLACEMENT)
    occ = root.occurrences.addNewComponent(m)
    c = occ.component
    c.name = COMP_NAME
    c.partNumber = "Raspberry Pi 5 + Active Cooler SC1148"
    c.description = (
        "PCB 85x56x1.6, 4x M2.5 (d2.7) holes 58x49 at 3.5 inset. Power USB-C 5V/5A PD (27W PSU, "
        "mains for V1). 2x micro-HDMI (HDMI0 x=25.8, HDMI1 x=39.2), 2x 22-pin 0.5mm MIPI CAM/DISP "
        "(DISP1 assumed nearer HDMI, check silkscreen), 40-pin GPIO, 4-pin fan header. Active Cooler "
        "63.5x42.5x13.7, push pins in the two d3 holes. Simplified volumes; connector sizes approx.")

    pcb = box(0, 85, 0, 56, 0, 1.6)
    for x, y in [(3.5, 3.5), (61.5, 3.5), (3.5, 52.5), (61.5, 52.5)]:
        cut(pcb, cyl(x, y, -1, 3, 2.7))
    for x, y in [(3.4, 9.5), (61.4, 46.0)]:  # Active Cooler push-pin holes
        cut(pcb, cyl(x, y, -1, 3, 3.0))
    items = [
        ("PCB", pcb),
        ("GPIO_40pin", box(7.1, 57.9, 49.96, 55.04, 1.6, 10.1)),
        ("USB_A_stack_USB2", box(69.5, 87.1, 40.4, 53.6, 1.6, 17.2)),
        ("USB_A_stack_USB3", box(69.5, 87.1, 22.5, 35.7, 1.6, 17.2)),
        ("RJ45_Ethernet", box(66.5, 88.0, 2.2, 18.2, 1.6, 15.1)),
        ("USB_C_Power_5V5A", box(6.7, 15.7, -1.0, 6.4, 1.6, 4.8)),
        ("microHDMI0", box(22.05, 29.55, -1.0, 6.5, 1.6, 5.0)),
        ("microHDMI1", box(35.45, 42.95, -1.0, 6.5, 1.6, 5.0)),
        ("MIPI_CAM_DISP1_22p", box(47.2, 49.9, 3.4, 15.9, 1.6, 3.6)),
        ("MIPI_CAM_DISP0_22p", box(52.8, 55.6, 3.4, 15.9, 1.6, 3.6)),
        ("PCIe_FFC_16p", box(0.7, 4.1, 21.5, 37.4, 1.6, 3.2)),
        ("Fan_header_4p", box(64.6, 67.6, 47.0, 53.0, 1.6, 5.8)),
        ("SoC_BCM2712", box(24.5, 41.5, 14.7, 31.0, 1.6, 3.0)),
        # Active Cooler: 63.5 x 42.5 footprint, heights above the PCB estimated
        # Base plate stops under the fan: the MIPI connectors stay exposed (product photo)
        ("Cooler_base", box(0.9, 34.4, 6.5, 49.0, 3.2, 5.2)),
        ("Cooler_base_under_fan", box(34.4, 64.4, 19.0, 49.0, 3.2, 5.2)),
        ("Cooler_fins", box(0.9, 34.4, 6.5, 49.0, 5.2, 14.9)),
        ("Cooler_fan_30x30", box(34.4, 64.4, 19.0, 49.0, 5.2, 14.9)),
    ]
    for x, y in [(3.4, 9.5), (61.4, 46.0)]:
        items.append(("Cooler_pushpin", cyl(x, y, 1.6, 16.9, 4.0)))
    add_bodies(c, items)
    print(COMP_NAME, "bodies", c.bRepBodies.count)
