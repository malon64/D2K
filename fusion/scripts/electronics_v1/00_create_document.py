"""Create the D2K_Electronics_V1 design and save it at the root of the D2K Fusion project.

Run once, through the Fusion MCP script executor. Then run the 10/20/30 part
scripts, 40_appearances.py, and save. Skips if the design already exists.
"""

import adsk.core
import adsk.fusion

DOC_NAME = "D2K_Electronics_V1"
PROJECT = "D2K"


def run(context):
    app = adsk.core.Application.get()
    proj = [p for p in app.data.dataProjects if p.name == PROJECT][0]
    for i in range(proj.rootFolder.dataFiles.count):
        if proj.rootFolder.dataFiles.item(i).name == DOC_NAME:
            print("SKIP", DOC_NAME, "already exists in", PROJECT)
            return
    doc = app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
    des = adsk.fusion.Design.cast(app.activeProduct)
    des.fusionUnitsManager.distanceDisplayUnits = adsk.fusion.DistanceUnits.MillimeterDistanceUnits
    ok = doc.saveAs(DOC_NAME, proj.rootFolder,
                    "D2K V1 electronics reference models (Pi 5, Waveshare 5in HDMI H, Waveshare 4in DSI)", "")
    print("saved", ok)
