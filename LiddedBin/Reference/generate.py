"""Runs OpenSCAD on lid-bin.scad for each reference case and records volume and bounding box.

lid-bin.scad calls main() at include time, so it is run directly with -D overrides.

Volume and bounds are measured on OpenSCAD's full-precision ASCII STL. The STL kept in
Reference/stl/ for the symmetric-difference check then has every coordinate rounded to float32,
which is what a binary STL stores. OpenSCAD's double-precision output mixes float32-rounded and
exact vertices on shared planes (for example 12.8 and 12.799999997 on a bin's floor top), which
leaves sliver triangles about 1e-10 mm thick. When Cadova imports such a mesh, Manifold's
topology cleanup collapses vertices next to those slivers and changes the solid (the
bin_1x1x2_nogrips_div2 case lost 6.33 mm^3 that way). With float32 coordinates the slivers
collapse to exact duplicates and the import keeps the solid.
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
SCAD = (HERE / "../../../Lidded Bins/lid-bin.scad").resolve()
OUT = HERE / "reference.json"
STL_DIR = HERE / "stl"
OPENSCAD = "/opt/homebrew/bin/openscad"
FN = 64  # keep equal to the segment count used by GridfinityTestSupport measure()

# Case name -> list of NAME=VALUE defines, each passed as -D NAME=VALUE (strings quoted).
CASES = {
    "bin_2x2x3_nogrips": ['Part="bin"', 'Lip_Grips="none"'],
    "lid_2x2x3_nogrips": ['Part="lid"', 'Lip_Grips="none"'],
    "bin_2x2x3_xy": ['Part="bin"'],  # defaults: grips xy, lid left, 6x6
    "bin_1x1x2_nogrips_div2": ['Part="bin"', 'Lip_Grips="none"', 'gridx=1', 'gridy=1', 'gridz=2', 'divx=2', 'divy=1'],
    "bin_1x1x2_nogrips_div0": ['Part="bin"', 'Lip_Grips="none"', 'gridx=1', 'gridy=1', 'gridz=2', 'divx=0', 'divy=0'],
    "bin_3x2x3_grips_x": ['Part="bin"', 'Lip_Grips="x"', 'gridx=3', 'gridy=2', 'divx=3', 'divy=2'],
    "lid_2x2x3_xy": ['Part="lid"'],
    "lid_1x1x2_nogrips": ['Part="lid"', 'Lip_Grips="none"', 'gridx=1', 'gridy=1', 'gridz=2'],
    "lid_2x3x3_grips_y_up": ['Part="lid"', 'Lip_Grips="y"', 'gridx=2', 'gridy=3', 'Lid_Orientation="up"'],
    "bin_2x2x3_partial_raised": ['Part="bin"', 'Lip_Grips="none"', 'Interior_Style="partial_raised"', 'divx=2', 'divy=2'],
    # lid orientation (tabs and lip mask depend on it)
    "bin_2x2x3_left": ['Part="bin"', 'Lid_Orientation="left"', 'divx=2', 'divy=2'],
    "bin_2x2x3_right": ['Part="bin"', 'Lid_Orientation="right"', 'divx=2', 'divy=2'],
    "bin_2x2x3_up": ['Part="bin"', 'Lid_Orientation="up"', 'divx=2', 'divy=2'],
    "bin_2x2x3_down": ['Part="bin"', 'Lid_Orientation="down"', 'divx=2', 'divy=2'],
    "lid_2x2x3_right": ['Part="lid"', 'Lid_Orientation="right"'],
    "lid_2x2x3_down": ['Part="lid"', 'Lid_Orientation="down"'],
    # height modes
    "bin_2x2_internal_20_snap": ['Part="bin"', 'gridz_define=1', 'gridz=20', 'enable_zsnap=true', 'divx=2', 'divy=2'],
    "bin_2x2_external_30": ['Part="bin"', 'gridz_define=2', 'gridz=30', 'enable_zsnap=false', 'divx=2', 'divy=2'],
    "bin_2x2x3_height_internal": ['Part="bin"', 'height_internal=20', 'divx=2', 'divy=2'],
    # multisize pattern
    "bin_3x2x3_multisize": ['Part="bin"', 'div_pattern="multisize"', 'gridx=3', 'gridy=2', 'divx=3', 'divy=2', 'div_multiple=2', 'Lip_Grips="none"'],
    # gaps from the Task 5 review
    "bin_3x2x3_grips_y": ['Part="bin"', 'Lip_Grips="y"', 'gridx=3', 'gridy=2', 'divx=3', 'divy=2'],
    "bin_2x2x3_multisize_divx1": ['Part="bin"', 'div_pattern="multisize"', 'divx=1', 'divy=2', 'Lip_Grips="none"'],
    "bin_2x2x3_multisize_divy0": ['Part="bin"', 'div_pattern="multisize"', 'divx=2', 'divy=0', 'Lip_Grips="none"'],
    # fit-tolerance sweep (constants that cancel at their defaults)
    "bin_2x2x3_fit_sweep": ['Part="bin"', 'lid_hfit_tolerance=1.3', 'lid_vfit_tolerance=0.05', 'lid_vpos_tolerance=0.3', 'lid_wall_thickness=1.0', 'lid_thickness=1.1', 'divx=2', 'divy=2', 'Lip_Grips="none"'],
    "lid_2x2x3_fit_sweep": ['Part="lid"', 'lid_hfit_tolerance=1.3', 'lid_vfit_tolerance=0.05', 'lid_vpos_tolerance=0.3', 'lid_wall_thickness=1.0', 'lid_thickness=1.1', 'Lip_Grips="none"'],
    # bin slice (solid bin cut off at the lip)
    "bin_slice_2x2x3": ['Part="bin_slice"'],
    "bin_slice_1x1x2_up": ['Part="bin_slice"', 'gridx=1', 'gridy=1', 'gridz=2', 'Lid_Orientation="up"'],
}

# Cases whose STL keeps OpenSCAD's double-precision coordinates. For these, the float32 rounding
# above makes Manifold's import drop material instead of repairing slivers: the float32 file of
# lid_2x2x3_fit_sweep has volume 7819.9377 mm^3 but imports as 7818.5935 mm^3 (a 0.3 mm tall wedge
# of the lid's rim is lost, 1.34 mm^3), while the unrounded file imports as 7819.9366, equal to the
# OpenSCAD volume.
FULL_PRECISION = {"lid_2x2x3_fit_sweep"}


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


def run_case(name):
    defines = [arg for d in CASES[name] for arg in ("-D", d)]
    STL_DIR.mkdir(exist_ok=True)
    stl = STL_DIR / f"{name}.stl"
    start = time.monotonic()
    try:
        subprocess.run(
            [OPENSCAD, "-o", str(stl), "--export-format", "asciistl",
             "-D", f"$fn={FN}", *defines, str(SCAD)],
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
