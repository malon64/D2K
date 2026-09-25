"""Read-only: list the active design's components two levels deep with sizes.

Safe on heavy designs (no geometry queries below level 2). Run it with
readOnly=true through the Fusion MCP. Wait until the design has finished
loading: on D2K_phase1 any call times out while Fusion is still busy.
"""

import adsk.core
import adsk.fusion


def show(occ, depth):
    bb = occ.boundingBox
    size = ""
    if bb:
        a, b = bb.minPoint, bb.maxPoint
        size = "%.1f x %.1f x %.1f mm" % ((b.x - a.x) * 10, (b.y - a.y) * 10, (b.z - a.z) * 10)
    print("  " * depth + occ.name, "| bodies", occ.component.bRepBodies.count,
          "| children", occ.childOccurrences.count, "|", size)


def run(context):
    app = adsk.core.Application.get()
    root = adsk.fusion.Design.cast(app.activeProduct).rootComponent
    print("document", app.activeDocument.name)
    for occ in root.occurrences:
        show(occ, 0)
        for child in occ.childOccurrences:
            show(child, 1)
            for grandchild in child.childOccurrences:
                show(grandchild, 2)
