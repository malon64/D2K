"""Flat-cable variant of W2 (HDMI) and W3 (USB touch): Adafruit DIY USB/HDMI parts.

Adds Cables_V1_flat to D2K_Electronics_V1, to compare with Cables_V1_stock:
- W2: Right Angle micro HDMI plug (Adafruit 3557/3558) on the Pi HDMI0, the
  20-pin 10 mm FPC ribbon folded behind the Pi, across the gap between the
  screens and behind the 5in, then a Straight HDMI plug adapter (3548) in the
  5in HDMI port, the ribbon folding back 180° behind the screen.
- W3: Straight USB A plug (4109) in the Pi's lower USB port, ribbon behind
  the Pi and the 5in, Straight micro B plug (4106) in the 5in Touch port.
Adapter sizes are Adafruit's published dimensions; the insertion depths
(9.5 mm HDMI A, 12 mm USB A, 5.5 mm micro B, 6.5 mm micro HDMI), the plate
layout of the right-angle adapter and the ribbon thickness (0.3 mm) are
estimates. The ribbon route follows the flat bench layout of this design;
the printed lengths size the ribbon to order.
"""

import math

import adsk.core
import adsk.fusion

DOC_NAME = "D2K_Electronics_V1"
COMP_NAME = "Cables_V1_flat"
RIBBON_W, RIBBON_T = 10.0, 0.3

T = adsk.fusion.TemporaryBRepManager.get()


def P(v):
    return adsk.core.Point3D.create(v[0] / 10, v[1] / 10, v[2] / 10)


def box(lo, hi):
    lo, hi = [min(a, b) for a, b in zip(lo, hi)], [max(a, b) for a, b in zip(lo, hi)]
    obb = adsk.core.OrientedBoundingBox3D.create(
        P([(lo[k] + hi[k]) / 2 for k in range(3)]),
        adsk.core.Vector3D.create(1, 0, 0), adsk.core.Vector3D.create(0, 1, 0),
        (hi[0] - lo[0]) / 10, (hi[1] - lo[1]) / 10, (hi[2] - lo[2]) / 10)
    return T.createBox(obb)


def world_bb(occ, body_name):
    bb = occ.component.bRepBodies.itemByName(body_name).createForAssemblyContext(occ).boundingBox
    return ([bb.minPoint.x * 10, bb.minPoint.y * 10, bb.minPoint.z * 10],
            [bb.maxPoint.x * 10, bb.maxPoint.y * 10, bb.maxPoint.z * 10])


def ribbon(name, pts, width_axes):
    """Orthogonal ribbon: segment i joins pts[i] -> pts[i+1] (one axis changes),
    RIBBON_W wide along width_axes[i], RIBBON_T thick along the third axis."""
    items, length = [], 0.0
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        run = [k for k in range(3) if abs(a[k] - b[k]) > 1e-6]
        if not run:
            continue
        r, w = run[0], width_axes[i]
        t = 3 - r - w
        lo, hi = list(a), list(b)
        lo[w], hi[w] = a[w] - RIBBON_W / 2, a[w] + RIBBON_W / 2
        lo[t], hi[t] = a[t] - RIBBON_T / 2, a[t] + RIBBON_T / 2
        items.append(("%s_ribbon_%d" % (name, i), box(lo, hi)))
        length += abs(b[r] - a[r])
    return items, length


def overlap(a, b):
    return [min(a[1][k], b[1][k]) - max(a[0][k], b[0][k]) for k in range(3)]


def run(context):
    app = adsk.core.Application.get()
    for doc in app.documents:
        if doc.name.split(" v")[0] == DOC_NAME:
            doc.activate()
    if app.activeDocument.name.split(" v")[0] != DOC_NAME:
        print("ABORT", DOC_NAME, "is not open")
        return
    des = adsk.fusion.Design.cast(app.activeProduct)
    root = des.rootComponent
    if any(o.component.name == COMP_NAME for o in root.occurrences):
        print("SKIP", COMP_NAME, "exists")
        return
    occs = {o.component.name: o for o in root.occurrences}
    pi, ws5 = occs["Raspberry_Pi_5"], occs["Waveshare_5in_HDMI_LCD_H"]
    items, report = [], []

    # --- W2 Pi end: right-angle micro HDMI (3557/3558), 17.5 x 15 x 14.5 mm.
    lo, hi = world_bb(pi, "microHDMI0")
    face, cx, cz = lo[1], (lo[0] + hi[0]) / 2, (lo[2] + hi[2]) / 2
    plug_out = 14.5 - 6.5                          # part of the 14.5 mm outside the port
    items.append(("W2_RA_microHDMI_plug", box([cx - 3.75, face - plug_out, cz - 2.0], [cx + 3.75, face, cz + 2.0])))
    plate_top, plate_bot = cz + 4.0, cz + 4.0 - 17.5   # ribbon leaves towards -Z (Pi component side)
    items.append(("W2_RA_microHDMI_plate", box([cx - 7.5, face - plug_out - 4.0, plate_bot],
                                               [cx + 7.5, face - plug_out, plate_top])))
    y_plate = face - plug_out - 2.0

    # --- W2 5in end: straight HDMI plug adapter (3548), 27.5 x 17.3 x 5 mm.
    lo, hi = world_bb(ws5, "HDMI_A_Display")
    h_face, h_cy, h_cz = hi[0], (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2
    h_end = h_face + 27.5 - 9.5
    hdmi_a = ([h_face, h_cy - 8.65, h_cz - 2.5], [h_end, h_cy + 8.65, h_cz + 2.5])
    items.append(("W2_straight_HDMI_A_adapter", box(*hdmi_a)))

    # --- W3 Pi end: straight USB A plug (4109), 30 x 17 x 5 mm, in the port next to the PCB.
    pcb_lo, pcb_hi = world_bb(pi, "PCB")
    pcb_zc = (pcb_lo[2] + pcb_hi[2]) / 2
    lo, hi = world_bb(pi, "USB_A_stack_USB2")
    u_face, u_cy = lo[0], (lo[1] + hi[1]) / 2
    near, far = (lo[2], hi[2]) if abs(lo[2] - pcb_zc) < abs(hi[2] - pcb_zc) else (hi[2], lo[2])
    u_cz = near + (far - near) / 4
    u_end = u_face - (30.0 - 12.0)
    items.append(("W3_straight_USB_A_adapter", box([u_end, u_cy - 8.5, u_cz - 2.5], [u_face, u_cy + 8.5, u_cz + 2.5])))

    # --- W3 5in end: straight micro B plug (4106), 23 x 17 x 3 mm, in the Touch port.
    lo, hi = world_bb(ws5, "microUSB_Touch")
    t_face, t_cy, t_cz = hi[0], (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2
    t_end = t_face + 23.0 - 5.5
    micro_b = ([t_face, t_cy - 8.5, t_cz - 1.5], [t_end, t_cy + 8.5, t_cz + 1.5])
    items.append(("W3_straight_microB_adapter", box(*micro_b)))

    # --- Ribbon routes (flat bench layout: 5in above the 4in, both glass +Z).
    fold_x = max(h_end, t_end) + 1.2             # 180° fold just past the 5in adapters
    back_lo, back_up_hdmi, back_up_usb = -24.15, -9.15, -9.75
    gap_y_hdmi, gap_y_usb = 72.15, 80.15         # climb between the two screens
    hd_pts = [[cx, y_plate, plate_bot], [cx, y_plate, back_lo], [cx, gap_y_hdmi, back_lo],
              [cx, gap_y_hdmi, back_up_hdmi], [cx, h_cy, back_up_hdmi], [cx, h_cy, -8.25],
              [fold_x, h_cy, -8.25], [fold_x, h_cy, h_cz], [h_end, h_cy, h_cz]]
    hd_items, hd_len = ribbon("W2", hd_pts, [0, 0, 0, 0, 0, 1, 1, 1])
    ux = cx - 12.0                               # USB run beside the HDMI run, behind it
    us_pts = [[u_end, u_cy, u_cz], [u_end - 1.15, u_cy, u_cz], [u_end - 1.15, u_cy, back_lo - 0.7],
              [ux, u_cy, back_lo - 0.7], [ux, gap_y_usb, back_lo - 0.7], [ux, gap_y_usb, back_up_usb],
              [ux, t_cy, back_up_usb], [ux, t_cy, -8.25], [fold_x, t_cy, -8.25], [fold_x, t_cy, t_cz],
              [t_end, t_cy, t_cz]]
    us_items, us_len = ribbon("W3", us_pts, [1, 1, 1, 0, 0, 0, 0, 1, 1, 1])
    items += hd_items + us_items

    occ = root.occurrences.addNewComponent(adsk.core.Matrix3D.create())
    comp = occ.component
    comp.name = COMP_NAME
    comp.partNumber = "Adafruit DIY USB/HDMI cable parts"
    comp.description = ("Flat-cable variant of W2/W3: Adafruit 3557 or 3558 (RA micro HDMI), 3548 (straight HDMI "
                        "A), 4109 (straight USB A), 4106 (straight micro B), 20-pin 10 mm FPC ribbons 3560-3563. "
                        "Compare with Cables_V1_stock. Insertion depths and ribbon route estimated.")
    bf = comp.features.baseFeatures.add()
    bf.startEdit()
    try:
        for n, b in items:
            comp.bRepBodies.add(b, bf).name = n
    finally:
        bf.finishEdit()

    black = des.appearances.itemByName("D2K_glass_black")
    metal = des.appearances.itemByName("D2K_connector_metal")
    grey = des.appearances.itemByName("D2K_cable_grey")
    for b in comp.bRepBodies:
        b.appearance = (grey if "_ribbon_" in b.name else metal if b.name.endswith("_plug") else black) or b.appearance

    report.append("W2 HDMI ribbon centreline %.0f mm, W3 USB ribbon %.0f mm (plus ~15 mm in the clips)" % (hd_len, us_len))
    ov = overlap(hdmi_a, micro_b)
    report.append("5in adapters HDMI A vs micro B overlap (x, y, z mm): %.2f %.2f %.2f -> %s" % (
        ov[0], ov[1], ov[2], "COLLIDE" if min(ov) > 0 else "clear"))
    report.append("reach past parts: Pi micro-HDMI plate to y=%.1f, USB A adapter to x=%.1f, 5in adapters+fold to x=%.1f"
                  % (face - plug_out - 4.0, u_end - 1.3, fold_x + 0.15))
    print(COMP_NAME, "bodies", comp.bRepBodies.count)
    print("\n".join(report))
