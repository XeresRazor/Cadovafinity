"""Runs OpenSCAD on gridfinity-rebuilt-baseplate.scad for each reference case and records volume and bounding box.

The baseplate file runs its model at include time, so it is run directly with -D overrides.
Cases in DEFS_CASES test the cutter modules on their own. They run a wrapper written to
Reference/generated/baseplate-defs.scad at run time (the original is never edited): the baseplate
source with its top-level gridfinityBaseplate call removed, its includes made absolute, and a
`case` selector appended; see defs_scad().

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
GENERATED_DIR = HERE / "generated"
STL_DIR = HERE / "stl"
OPENSCAD = "/opt/homebrew/bin/openscad"
FN = 64  # keep equal to the segment count used by GridfinityTestSupport measure()

# Case name -> list of NAME=VALUE defines, each passed as -D NAME=VALUE (strings quoted).
CASES = {
    "thin_2x2": ['gridx=2', 'gridy=2', 'style_plate=0'],
    "weighted_2x2": ['gridx=2', 'gridy=2', 'style_plate=1', 'enable_magnet=true', 'style_hole=2'],
    "skeleton_2x2": ['gridx=2', 'gridy=2', 'style_plate=2', 'enable_magnet=true', 'style_hole=2'],
    "skeleton_countersink_nomagnet": [
        'gridx=2', 'gridy=1', 'style_plate=2', 'enable_magnet=false', 'style_hole=1',
    ],
    "skeleton_noholes_nomagnet": [
        'gridx=1', 'gridy=1', 'style_plate=2', 'enable_magnet=false', 'style_hole=0',
    ],
    "screw_together_2x3": ['gridx=2', 'gridy=3', 'style_plate=3', 'n_screws=2'],
    "screw_together_minimal_2x2": ['gridx=2', 'gridy=2', 'style_plate=4'],
    "fit_x_drawer": ['gridx=0', 'gridy=2', 'distancex=150', 'fitx=0.5', 'style_plate=0'],
    "fit_both_drawer": [
        'gridx=0', 'gridy=0', 'distancex=130', 'distancey=95', 'fitx=-1', 'fity=1', 'style_plate=1',
    ],
    "weighted_magnet_off": ['gridx=2', 'gridy=2', 'style_plate=1', 'enable_magnet=false', 'style_hole=0'],
    "cutter_weight": ['case="cutter_weight"'],
    "cutter_skeleton": ['case="cutter_skeleton"'],
    "cutter_countersink": ['case="cutter_countersink"'],
    "cutter_counterbore": ['case="cutter_counterbore"'],
    "cutter_screws_2x3_n2": [
        'case="cutter_screws_2x3_n2"',
        'd_screw=3.35', 'd_screw_head=5', 'screw_spacing=0.5', 'n_screws=2',
    ],
    "cutter_holes_pattern": ['case="cutter_holes_pattern"'],
}

# Cases run through the definitions-only wrapper (defs_scad()) instead of the baseplate file.
DEFS_CASES = {
    "cutter_weight", "cutter_skeleton", "cutter_countersink", "cutter_counterbore",
    "cutter_screws_2x3_n2", "cutter_holes_pattern",
}

# The case selector appended to the wrapper; `case` is set with -D.
CASE_SELECTOR = """
case = "";
if (case == "cutter_weight") cutter_weight();
if (case == "cutter_skeleton") linear_extrude(5) profile_skeleton();
if (case == "cutter_countersink") cutter_countersink();
if (case == "cutter_counterbore") cutter_counterbore();
if (case == "cutter_screws_2x3_n2") cutter_screw_together(2, 3, 6.4);
if (case == "cutter_holes_pattern") hole_pattern() { block_base_hole(1); }
"""

# Cases whose STL keeps OpenSCAD's double-precision coordinates (no float32 rounding), for cases
# where the rounding makes Manifold's import drop material instead of repairing slivers.
FULL_PRECISION = set()


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise SystemExit(f"generate.py: expected exactly one occurrence of {old!r}, found {text.count(old)}")
    return text.replace(old, new)


def defs_scad():
    """Writes Reference/generated/baseplate-defs.scad and returns its path.

    The baseplate source without its top-level model call, so its modules can be called alone.
    """
    text = SCAD.read_text()
    text = replace_once(
        text,
        "color(\"tomato\")\ngridfinityBaseplate(gridx, gridy, l_grid, distancex, distancey, "
        "style_plate, enable_magnet, style_hole, fitx, fity);\n",
        "",
    )
    for lib in ("gridfinity-rebuilt-utility.scad", "standard.scad"):
        text = replace_once(text, f"include <{lib}>", f"include <{SCAD.parent / lib}>")
    GENERATED_DIR.mkdir(exist_ok=True)
    out = GENERATED_DIR / "baseplate-defs.scad"
    out.write_text(text + CASE_SELECTOR)
    return out


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
    scad = scad or (defs_scad() if name in DEFS_CASES else SCAD)
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
