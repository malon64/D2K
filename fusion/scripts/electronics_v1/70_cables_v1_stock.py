"""Stock V1 cables around the ports: the space the bench cables really take.

Adds a Cables_V1_stock component to D2K_Electronics_V1 with, for W1-W5 of
fusion/wiring.md:
- each plug's overmold (the part outside the receptacle), placed from the
  receptacle body of the part models, so it follows the parts if they move;
- the first metres of each round cable: straight out of the plug, then a 90°
  turn at the cable's minimum bend radius, then 25 mm straight;
- the 22-pin FFC on its real route (around the Pi edge and over the Active
  Cooler) and the 2-wire 4in power lead with its Dupont housing.
These are keep-outs for the compaction study and the shell, not a full bench
route. Plug sizes, cable diameters and bend radii are TYPICAL values: measure
the actual cables (fusion/open-questions.md M9).
Run after 10/20/30 (and 65 on designs built before its fix).
"""

import math

import adsk.core
import adsk.fusion

DOC_NAME = "D2K_Electronics_V1"
COMP_NAME = "Cables_V1_stock"
AX = {"x": 0, "y": 1, "z": 2}

# name, part component, receptacle body, outward (axis, sign), width axis,
# plug W x H x L (mm, outside the receptacle), cable diameter, min bend radius,
# first-bend direction (axis, sign), port selector
PORTS = [
    ("W1_USB-C_PSU", "Raspberry_Pi_5", "USB_C_Power_5V5A", ("y", -1), "x", 12.5, 6.5, 22, 4.5, 25, ("z", -1), None),
    ("W2_microHDMI_Pi", "Raspberry_Pi_5", "microHDMI0", ("y", -1), "x", 11, 6.5, 20, 6.0, 30, ("x", 1), None),
    ("W2_HDMI_A_5in", "Waveshare_5in_HDMI_LCD_H", "HDMI_A_Display", ("x", 1), "y", 21, 11, 38, 6.0, 30, ("y", -1), None),
    ("W3_USB-A_Pi", "Raspberry_Pi_5", "USB_A_stack_USB2", ("x", -1), "y", 16, 8, 30, 4.0, 20, ("y", 1), "near_pcb"),
    ("W3_microUSB_Touch_5in", "Waveshare_5in_HDMI_LCD_H", "microUSB_Touch", ("x", 1), "y", 11, 6.5, 20, 4.0, 20, ("y", 1), None),
]

# FFC 22-pin 0.5 mm (12 mm wide, 0.3 mm thick), world mm boxes: out of the 4in
# adapter connector under the Pi, around the Pi's SD-card edge, over the
# Active Cooler (push pins top at Z -21.9), down beside DISP1 and into it.
FFC_BOXES = [
    (84.0, 100.0, 19.25, 31.25, -3.75, -3.45),
    (100.0, 100.3, 19.25, 31.25, -22.5, -3.45),
    (54.0, 100.3, 19.25, 31.25, -22.5, -22.2),
    (50.0, 54.0, 8.2, 31.25, -22.5, -22.2),   # diagonal fold, approximated
    (50.0, 50.3, 8.2, 20.2, -22.5, -7.5),
    (49.45, 50.3, 8.2, 20.2, -7.8, -7.5),
]
# 2-pin Dupont housing on GPIO pins 4/6 (world mm) and the lead to the 4in JST
DUPONT = (81.93, 87.01, 57.05, 59.59, -23.1, -9.1)
LEAD_CORNERS = [(84.47, 58.32, -23.1), (84.47, 58.32, -27.5), (84.47, 64.5, -27.5),
                (84.47, 64.5, -3.7), (84.47, 50.5, -3.7)]  # planar (X const): lines + arcs
LEAD_DIA, LEAD_BEND = 2.5, 3.0

T = adsk.fusion.TemporaryBRepManager.get()


def P(v):
    return adsk.core.Point3D.create(v[0] / 10, v[1] / 10, v[2] / 10)


def box(x0, x1, y0, y1, z0, z1):
    obb = adsk.core.OrientedBoundingBox3D.create(
        P(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)),
        adsk.core.Vector3D.create(1, 0, 0), adsk.core.Vector3D.create(0, 1, 0),
        abs(x1 - x0) / 10, abs(y1 - y0) / 10, abs(z1 - z0) / 10)
    return T.createBox(obb)


def add(a, b, k=1.0):
    return [a[i] + k * b[i] for i in range(3)]


def unit(axis, sign):
    v = [0.0, 0.0, 0.0]
    v[AX[axis]] = float(sign)
    return v


def world_bb(occ, body_name):
    body = occ.component.bRepBodies.itemByName(body_name).createForAssemblyContext(occ)
    bb = body.boundingBox
    return ([bb.minPoint.x * 10, bb.minPoint.y * 10, bb.minPoint.z * 10],
            [bb.maxPoint.x * 10, bb.maxPoint.y * 10, bb.maxPoint.z * 10])


def filleted(corners, radius):
    """Split a polyline into ('line', p, q) and ('arc', start, mid, end) pieces,
    each inner corner replaced by a tangent arc of `radius`."""
    pieces, cur = [], list(corners[0])
    for i in range(1, len(corners) - 1):
        a, c, b = corners[i - 1], corners[i], corners[i + 1]
        u = [c[k] - a[k] for k in range(3)]
        w = [b[k] - c[k] for k in range(3)]
        lu, lw = math.sqrt(sum(x * x for x in u)), math.sqrt(sum(x * x for x in w))
        u, w = [x / lu for x in u], [x / lw for x in w]
        turn = math.acos(max(-1.0, min(1.0, sum(u[k] * w[k] for k in range(3)))))
        if turn < 1e-3:
            continue
        d = radius * math.tan(turn / 2)            # corner to tangent point
        t1, t2 = add(c, u, -d), add(c, w, d)
        bis = [w[k] - u[k] for k in range(3)]
        lb = math.sqrt(sum(x * x for x in bis))
        centre = add(c, [x / lb for x in bis], radius / math.cos(turn / 2))
        mid_dir = [c[k] - centre[k] for k in range(3)]
        lm = math.sqrt(sum(x * x for x in mid_dir))
        mid = add(centre, [x / lm for x in mid_dir], radius)
        pieces.append(("line", cur, t1))
        pieces.append(("arc", t1, mid, t2))
        cur = t2
    pieces.append(("line", cur, list(corners[-1])))
    return pieces


def path_plane(comp, pieces):
    """Offset origin plane containing the (axis-aligned, planar) path."""
    pts = [p for piece in pieces for p in piece[1:]]
    for axis, base in ((2, comp.xYConstructionPlane), (0, comp.yZConstructionPlane),
                       (1, comp.xZConstructionPlane)):
        vals = [p[axis] for p in pts]
        if max(vals) - min(vals) < 1e-6:
            if abs(vals[0]) < 1e-6:
                return base
            pin = comp.constructionPlanes.createInput()
            pin.setByOffset(base, adsk.core.ValueInput.createByReal(vals[0] / 10))
            plane = comp.constructionPlanes.add(pin)
            plane.isLightBulbOn = False
            return plane
    raise ValueError("path is not in an axis-aligned plane")


def pipe(comp, name, pieces, dia):
    sk = comp.sketches.add(path_plane(comp, pieces))
    sk.name = name + "_path"

    def S(p):  # model mm -> sketch space Point3D
        return sk.modelToSketchSpace(P(p))

    first, last_pt = None, None
    for piece in pieces:
        if piece[0] == "line":
            start = last_pt if last_pt else S(piece[1])
            curve = sk.sketchCurves.sketchLines.addByTwoPoints(start, S(piece[2]))
            last_pt = curve.endSketchPoint
        else:
            curve = sk.sketchCurves.sketchArcs.addByThreePoints(last_pt, S(piece[2]), S(piece[3]))
            end = S(piece[3])
            a, b = curve.startSketchPoint, curve.endSketchPoint
            last_pt = a if a.geometry.distanceTo(end) < b.geometry.distanceTo(end) else b
        first = first or curve
    path = comp.features.createPath(first, True)
    pin = comp.features.pipeFeatures.createInput(path, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    pin.sectionType = adsk.fusion.PipeSectionTypes.CircularPipeSectionType
    pin.sectionSize = adsk.core.ValueInput.createByReal(dia / 10)
    feat = comp.features.pipeFeatures.add(pin)
    body = feat.bodies.item(0)
    body.name = name
    sk.isVisible = False
    return body


def appearance(des, name, rgb, fallback):
    a = des.appearances.itemByName(name)
    if a:
        return a
    base = des.appearances.itemByName(fallback)
    if not base:
        return None
    a = des.appearances.addByCopy(base, name)
    for p in a.appearanceProperties:
        if p.objectType == adsk.core.ColorProperty.classType() and \
                (p.id in ("opaque_albedo", "generic_diffuse") or p.name in ("Color", "Couleur")):
            try:
                p.value = adsk.core.Color.create(rgb[0], rgb[1], rgb[2], 0)
            except RuntimeError:
                pass
    return a


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
    pcb_lo, pcb_hi = world_bb(occs["Raspberry_Pi_5"], "PCB")
    pcb_zc = (pcb_lo[2] + pcb_hi[2]) / 2

    plug_items, cables = [], []
    for name, part, body, (oax, osg), wax, W, H, L, dia, bend, (bax, bsg), sel in PORTS:
        lo, hi = world_bb(occs[part], body)
        a, wi = AX[oax], AX[wax]
        h = 3 - a - wi
        face = hi[a] if osg > 0 else lo[a]
        centre = [(lo[k] + hi[k]) / 2 for k in range(3)]
        if sel == "near_pcb":  # stacked USB-A: the port next to the PCB
            near, far = (lo[h], hi[h]) if abs(lo[h] - pcb_zc) < abs(hi[h] - pcb_zc) else (hi[h], lo[h])
            centre[h] = near + (far - near) / 4
        b0, b1 = [0.0] * 3, [0.0] * 3
        b0[a], b1[a] = sorted((face, face + osg * L))
        b0[wi], b1[wi] = centre[wi] - W / 2, centre[wi] + W / 2
        b0[h], b1[h] = centre[h] - H / 2, centre[h] + H / 2
        plug_items.append((name + "_plug", box(b0[0], b1[0], b0[1], b1[1], b0[2], b1[2])))
        start = list(centre)
        start[a] = face + osg * L
        out, turn = unit(oax, osg), unit(bax, bsg)
        corner = add(start, out, 8 + bend)
        cables.append((name + "_cable", filleted([start, corner, add(corner, turn, bend + 25)], bend), dia))

    occ = root.occurrences.addNewComponent(adsk.core.Matrix3D.create())
    comp = occ.component
    comp.name = COMP_NAME
    comp.description = ("Stock bench cables W1-W5 near the ports (keep-outs). Plug sizes, cable diameters and "
                        "bend radii are typical values - measure the real cables. See fusion/wiring.md.")
    items = plug_items + [("W4_FFC_22p_%d" % i, box(*b)) for i, b in enumerate(FFC_BOXES)]
    items.append(("W5_Dupont_2p_GPIO4-6", box(*DUPONT)))
    bf = comp.features.baseFeatures.add()
    bf.startEdit()
    try:
        for n, b in items:
            comp.bRepBodies.add(b, bf).name = n
    finally:
        bf.finishEdit()

    made = [pipe(comp, n, pts, d) for n, pts, d in cables]
    made.append(pipe(comp, "W5_power_lead", filleted(LEAD_CORNERS, LEAD_BEND), LEAD_DIA))

    black = des.appearances.itemByName("D2K_glass_black")
    grey = appearance(des, "D2K_cable_grey", (70, 70, 75), "D2K_connector_metal")
    ffc = appearance(des, "D2K_ffc", (230, 225, 205), "D2K_connector_plastic")
    for b in comp.bRepBodies:
        if b.name.startswith("W4_FFC"):
            b.appearance = ffc or b.appearance
        elif b.name.endswith("_cable") or b.name == "W5_power_lead":
            b.appearance = grey or b.appearance
        else:
            b.appearance = black or b.appearance
    print(COMP_NAME, "bodies", comp.bRepBodies.count, [b.name for b in comp.bRepBodies])
