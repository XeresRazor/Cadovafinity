"""Runs OpenSCAD for each reference case and records volume and bounding box.

Usage: python3 -I Reference/generate.py [case ...]   (default: all cases)
"""
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCAD = HERE / "reference.scad"
OUT = HERE / "reference.json"
STL_DIR = HERE / "stl"
OPENSCAD = "/opt/homebrew/bin/openscad"
FN = 64  # keep equal to the segment count used by GridfinityTestSupport measure()

CASES = ["unit_cube", "profile_base", "profile_wall", "profile_wall2", "rounded_rectangle",
         "block_base_solid", "block_base_solid_offset",
         "block_wall_2x1", "block_wall_1x2", "block_wall_lipless_1x1", "block_bottom_2x1",
         "init_2x1x3", "init_2x1x3_lipless", "cut_move_marker", "cut_move_marker_dh0", "pattern_linear"]

# Cases that reuse a scad case with extra OpenSCAD defines. A later -D overrides the file's
# own assignment, and derived values such as d_magic (computed in standard.scad from d_wall)
# are evaluated with the overridden value. lid-bin.scad sets d_wall = 1.6.
# Maps case name -> (scad case name, extra defines).
VARIANTS = {
    "profile_wall_dw16": ("profile_wall", ["d_wall=1.6"]),
    "block_bottom_2x1_dw16": ("block_bottom_2x1", ["d_wall=1.6"]),
    "cut_move_marker_dw16": ("cut_move_marker", ["d_wall=1.6"]),
    "init_2x1x3_dw16": ("init_2x1x3", ["d_wall=1.6"]),
}
CASES += list(VARIANTS)


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


def run_case(name):
    scad_case, extra = VARIANTS.get(name, (name, []))
    defines = [arg for d in extra for arg in ("-D", d)]
    STL_DIR.mkdir(exist_ok=True)
    stl = STL_DIR / f"{name}.stl"
    try:
        subprocess.run(
            [OPENSCAD, "-o", str(stl), "--export-format", "asciistl",
             "-D", f'case="{scad_case}"', "-D", f"$fn={FN}", *defines, str(SCAD)],
            check=True, capture_output=True, text=True,
        )
    except subprocess.CalledProcessError as e:
        print(f"OpenSCAD stderr for case {name}:\n{e.stderr}", file=sys.stderr)
        print(f"OpenSCAD stdout for case {name}:\n{e.stdout}", file=sys.stderr)
        raise SystemExit(
            f"generate.py: case {name!r} failed (OpenSCAD exit {e.returncode})"
        )
    return parse_ascii_stl(stl)


def main():
    names = sys.argv[1:] or CASES
    data = json.loads(OUT.read_text()) if OUT.exists() else {}
    for name in names:
        data[name] = run_case(name)
        print(name, data[name])
    OUT.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
