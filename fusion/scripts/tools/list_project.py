"""Read-only: print the D2K Fusion project folder tree (files and folders).

Set DOWNLOAD_TO to a local folder to also download the non-Fusion files
(scripts, markdown, PDFs) found in 99_PROJECT_ADMIN.
"""

import adsk.core

PROJECT = "D2K"
DOWNLOAD_TO = None  # e.g. r"C:\Users\alexi\Downloads\d2k_fusion_admin"


def walk(folder, depth, download):
    print("  " * depth + "[" + folder.name + "]")
    for i in range(folder.dataFiles.count):
        d = folder.dataFiles.item(i)
        line = "  " * (depth + 1) + d.name + "." + d.fileExtension
        if download and d.fileExtension not in ("f3d", "flbr", "fsch", "fbrd"):
            line += " downloaded=" + str(d.download(DOWNLOAD_TO + "\\" + folder.name + "\\" + d.name, None))
        print(line)
    if depth < 4:
        for i in range(folder.dataFolders.count):
            sub = folder.dataFolders.item(i)
            walk(sub, depth + 1, download or (DOWNLOAD_TO and sub.name == "99_PROJECT_ADMIN"))


def run(context):
    app = adsk.core.Application.get()
    proj = [p for p in app.data.dataProjects if p.name == PROJECT][0]
    walk(proj.rootFolder, 0, False)
