"""Runs OpenSCAD on gridfinity-rebuilt-baseplate.scad for each reference case and records volume and bounding box.

The baseplate file runs its model at include time, so it is run directly with -D overrides.

Volume and bounds are measured on OpenSCAD's full-precision ASCII STL. The STL kept in
Reference/stl/ for the symmetric-difference check then has every coordinate rounded to float32,
which is what a binary STL stores. OpenSCAD's double-precision output mixes float32-rounded and
exact vertices on shared planes, which leaves sliver triangles about 1e-10 mm thick. When Cadova
imports such a mesh, Manifold's topology cleanup can collapse vertices next to those slivers and
change the solid. With float32 coordinates the slivers collapse to exact duplicates and the import
keeps the solid. Cases in FULL_PRECISION keep the unrounded file instead.

Usage: python3 -I Reference/generate.py [case ...]   (default: all cases)
"""
import json
import struct
import re
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCAD = (HERE / "../../../Lidded Bins/gridfinity-rebuilt-openscad/gridfinity-rebuilt-baseplate.scad").resolve()
OUT = HERE / "reference.json"
STL_DIR = HERE / "stl"
OPENSCAD = "/opt/homebrew/bin/openscad"
FN = 64  # keep equal to the segment count used by GridfinityTestSupport measure()

# Case name -> list of NAME=VALUE defines, each passed as -D NAME=VALUE (strings quoted).
CASES = {
    "thin_2x2": ['gridx=2', 'gridy=2', 'style_plate=0'],
}

# Cases whose STL keeps OpenSCAD's double-precision coordinates (no float32 rounding), for cases
# where the rounding makes Manifold's import drop material instead of repairing slivers.
FULL_PRECISION = set()


def parse_ascii_stl(path):
    verts = []
    for line in path.read_text().splitlines():
        m = re.match(r"\s*vertex\s+(\S+)\s+(\S+)\s+(\S+)", line)
        if m:
            verts.append(tuple(float(g) for g in m.groups()))
    volume = 0.0
    for i in range(0, len(verts), 3):
        a, b, c = verts[i:i + 3]
        volume += (
            a[0] * (b[1] * c[2] - b[2] * c[1])
            - a[1] * (b[0] * c[2] - b[2] * c[0])
            + a[2] * (b[0] * c[1] - b[1] * c[0])
        ) / 6.0
    mins = [min(v[k] for v in verts) for k in range(3)]
    maxs = [max(v[k] for v in verts) for k in range(3)]
    return {"volume": abs(volume), "min": mins, "max": maxs}


def round_stl_to_float32(path):
    """Rewrites an ASCII STL in place with every vertex coordinate rounded to float32."""
    def f32(text):
        return repr(struct.unpack("<f", struct.pack("<f", float(text)))[0])

    lines = []
    for line in path.read_text().splitlines():
        m = re.match(r"(\s*vertex\s+)(\S+)\s+(\S+)\s+(\S+)", line)
        lines.append(m.group(1) + " ".join(f32(g) for g in m.groups()[1:]) if m else line)
    path.write_text("\n".join(lines) + "\n")


def run_case(name, scad=None, stl=None):
    scad = scad or SCAD
    defines = [arg for d in CASES[name] for arg in ("-D", d)]
    STL_DIR.mkdir(exist_ok=True)
    stl = stl or STL_DIR / f"{name}.stl"
    start = time.monotonic()
    try:
        subprocess.run(
            [OPENSCAD, "-o", str(stl), "--export-format", "asciistl",
             "-D", f"$fn={FN}", *defines, str(scad)],
            check=True, capture_output=True, text=True,
        )
    except subprocess.CalledProcessError as e:
        print(f"OpenSCAD stderr for case {name}:\n{e.stderr}", file=sys.stderr)
        print(f"OpenSCAD stdout for case {name}:\n{e.stdout}", file=sys.stderr)
        raise SystemExit(
            f"generate.py: case {name!r} failed (OpenSCAD exit {e.returncode})"
        )
    print(f"{name}: OpenSCAD took {time.monotonic() - start:.1f}s", file=sys.stderr)
    metrics = parse_ascii_stl(stl)
    if name not in FULL_PRECISION:
        round_stl_to_float32(stl)
    return metrics


def main():
    names = sys.argv[1:] or list(CASES)
    data = json.loads(OUT.read_text()) if OUT.exists() else {}
    for name in names:
        data[name] = run_case(name)
        print(name, data[name])
    OUT.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
