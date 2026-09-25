"""Upload fusion/electronics/D2K.lbr to the D2K Fusion project root.

Fusion converts the EAGLE library into a native Electronics library (D2K.flbr).
Regenerate D2K.lbr first with fusion/electronics/gen_d2k_lbr.py. A second
upload of the same name adds a new version of D2K.flbr.
"""

import adsk.core

PROJECT = "D2K"
LBR = r"C:\Users\alexi\Repos\D2K\fusion\electronics\D2K.lbr"


def run(context):
    app = adsk.core.Application.get()
    proj = [p for p in app.data.dataProjects if p.name == PROJECT][0]
    future = proj.rootFolder.uploadFile(LBR)
    print("upload started, state", future.uploadState)
