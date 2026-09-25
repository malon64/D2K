"""Inspect and make lightweight, aligned copies of supplied DS/3DS STL scans.

The original scans remain unchanged in fusion/assets/local/source/. The output
proxies are for visual proportion and hinge study, not precise measurements.
Requires NumPy and PyMeshLab (tested with pymeshlab 2025.7.post1).
"""

import argparse
import gc
import json
from pathlib import Path

import numpy as np
import pymeshlab


ROOT = Path(__file__).resolve().parents[2] / "assets" / "local"  # fusion/assets/local
GROUPS = {
    "og_3ds": [
        "Bottom Shell.stl",
        "Button Shell.stl",
        "LCD Bezel.stl",
        "Top Shell.stl",
    ],
    "og_ds": [
        "Bottom Scan.stl",
        "Bottom Screen Scan.stl",
        "Hinge Scan.stl",
        "LidScan.stl",
        "Top Screen Scan.stl",
        "Trigger Scan.stl",
    ],
}


def inspect_mesh(path: Path):
    meshes = pymeshlab.MeshSet()
    meshes.load_new_mesh(str(path))
    mesh = meshes.current_mesh()
    bounds = mesh.bounding_box()
    record = {
        "source": str(path),
        "vertices": mesh.vertex_number(),
        "faces": mesh.face_number(),
        "bbox_min": [float(v) for v in bounds.min()],
        "bbox_max": [float(v) for v in bounds.max()],
    }
    return meshes, record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inspect-only", action="store_true")
    parser.add_argument("--target-faces", type=int, default=50000)
    args = parser.parse_args()

    out_root = ROOT / "reference_proxy"
    out_root.mkdir(parents=True, exist_ok=True)
    manifest = {"units_assumed": "mm", "target_faces": args.target_faces, "groups": {}}

    for group, filenames in GROUPS.items():
        anchor_path = ROOT / "source" / group / filenames[0]
        anchor_set, anchor_data = inspect_mesh(anchor_path)
        anchor = (np.array(anchor_data["bbox_min"]) + np.array(anchor_data["bbox_max"])) / 2
        del anchor_set
        gc.collect()
        entries = []
        print(group, "anchor center (source STL coordinates)", anchor.tolist(), flush=True)
        for name in filenames:
            source = ROOT / "source" / group / name
            meshes, data = inspect_mesh(source)
            print(name, "faces", data["faces"], "bounds", data["bbox_min"], data["bbox_max"], flush=True)
            if not args.inspect_only:
                meshes.meshing_decimation_quadric_edge_collapse(
                    targetfacenum=args.target_faces,
                    preservetopology=False,
                    preserveboundary=True,
                )
                reduced = meshes.current_mesh()
                vertices = reduced.vertex_matrix() - anchor
                faces = reduced.face_matrix()
                normalized = pymeshlab.Mesh(vertex_matrix=vertices, face_matrix=faces)
                output = out_root / group / name
                output.parent.mkdir(parents=True, exist_ok=True)
                writer = pymeshlab.MeshSet()
                writer.add_mesh(normalized, name)
                writer.save_current_mesh(str(output), binary=True)
                data["proxy"] = str(output)
                data["proxy_vertices"] = normalized.vertex_number()
                data["proxy_faces"] = normalized.face_number()
                data["anchor_subtracted"] = anchor.tolist()
                print("  wrote", output, "faces", data["proxy_faces"], flush=True)
                del writer, normalized, reduced, vertices, faces
            entries.append(data)
            del meshes
            gc.collect()
        manifest["groups"][group] = entries

    if not args.inspect_only:
        manifest_path = out_root / "manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
        print("manifest", manifest_path, flush=True)


if __name__ == "__main__":
    main()
