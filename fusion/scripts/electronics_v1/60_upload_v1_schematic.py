"""Upload the V1 schematic (and the refreshed library) to the D2K Fusion project root.

Fusion converts D2K_V1.sch into an Electronics design and D2K.lbr into D2K.flbr.
Re-uploading an existing name creates a SECOND file, not a version: delete the
old D2K library and D2K_V1 schematic + design first. Regenerate both first:
    python fusion/electronics/gen_d2k_lbr.py
    python fusion/electronics/gen_d2k_v1_sch.py
"""

import adsk.core

PROJECT = "D2K"
FILES = [
    r"C:\Users\alexi\Repos\D2K\fusion\electronics\D2K.lbr",
    r"C:\Users\alexi\Repos\D2K\fusion\electronics\D2K_V1.sch",
]


def run(context):
    app = adsk.core.Application.get()
    proj = [p for p in app.data.dataProjects if p.name == PROJECT][0]
    for path in FILES:
        future = proj.rootFolder.uploadFile(path)
        print("upload started", path.rsplit("\\", 1)[-1], "state", future.uploadState)
