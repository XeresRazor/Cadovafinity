"""Render a cross-section of the bin and the lid to a PNG, with only the standard library.

A development aid for judging the lid fit by eye. It slices STL files with OpenSCAD
(`projection(cut=true)`), then rasterizes the two outlines: the bin in blue, the lid in orange,
overlap in purple, with a 1 mm grid (grid lines are darkened pixels, not labels).

Usage:
    python3 -I render_section.py BIN.stl LID.stl OUT.png X_CUT Y0 Z0 WIDTH HEIGHT [PIXELS_PER_MM] [LID_DZ]
    python3 -I render_section.py --plan BIN.stl LID.stl OUT.png Z_CUT X0 Y0 WIDTH HEIGHT [PIXELS_PER_MM] [LID_DZ] [LID_DX] [LID_DY]

BIN.stl and LID.stl are exports in the model's own coordinates. The lid exported as the `lid`
part sits on the print bed; pass LID_DZ (default 20.1 = storage height 16 + base 5 - lid
thickness 0.9) to move it back to the closed position. The cut is the plane x = X_CUT, seen along
x: the horizontal axis of the image is world y (starting at Y0, WIDTH mm wide) and the vertical
axis is world z (from Z0 up, HEIGHT mm tall). Needs /opt/homebrew/bin/openscad.

With `--plan` the cut is the horizontal plane z = Z_CUT, seen from above: the horizontal axis of
the image is world x (starting at X0, WIDTH mm wide) and the vertical axis is world y (from Y0 up,
HEIGHT mm tall). LID_DZ works as above; LID_DX and LID_DY (default 0) also move the lid, for
example along the slide direction to show it part way open. A plan view shows the detent bump on
the bin's slot face and the notch in the lid's plate edge.
"""
import re, subprocess, struct, sys, tempfile, zlib
from pathlib import Path

OPENSCAD = "/opt/homebrew/bin/openscad"


def section_svg(stl, x_cut, dz, out):
    """The cut at x = x_cut, as SVG: svg x is world y and svg y is minus world z."""
    scad = Path(out).with_suffix(".scad")
    scad.write_text(
        f'projection(cut=true) multmatrix([[0,1,0,0],[0,0,1,0],[1,0,0,-({x_cut})],[0,0,0,1]]) '
        f'translate([0,0,{dz}]) import("{Path(stl).resolve()}");\n'
    )
    subprocess.run([OPENSCAD, "-o", str(out), str(scad)], check=True, capture_output=True)


def plan_svg(stl, z_cut, dx, dy, dz, out):
    """The cut at z = z_cut, as SVG: svg x is world x and svg y is minus world y."""
    scad = Path(out).with_suffix(".scad")
    scad.write_text(
        f'projection(cut=true) translate([0,0,-({z_cut})]) '
        f'translate([{dx},{dy},{dz}]) import("{Path(stl).resolve()}");\n'
    )
    subprocess.run([OPENSCAD, "-o", str(out), str(scad)], check=True, capture_output=True)


def polygons(svg):
    text = Path(svg).read_text()
    result = []
    for d in re.findall(r'<path d="(.*?)"', text, re.S):
        for sub in re.split(r"(?=M )", d):
            pts = [(float(a), float(b)) for a, b in re.findall(r"(-?\d+\.?\d*(?:e-?\d+)?),(-?\d+\.?\d*(?:e-?\d+)?)", sub)]
            if len(pts) > 2:
                result.append(pts)
    return result


def inside(polys, x, y):
    c = False
    for pts in polys:
        j = len(pts) - 1
        for i in range(len(pts)):
            xi, yi = pts[i]
            xj, yj = pts[j]
            if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
                c = not c
            j = i
    return c


def crossings(polys, y):
    """The sorted x positions where the outlines cross the line at height y (even-odd rule)."""
    xs = []
    for pts in polys:
        j = len(pts) - 1
        for i in range(len(pts)):
            xi, yi = pts[i]
            xj, yj = pts[j]
            if (yi > y) != (yj > y):
                xs.append((xj - xi) * (y - yi) / (yj - yi) + xi)
            j = i
    return sorted(xs)


def row_inside(polys, y, xs):
    """Whether each x in xs is inside the outlines; the same test as `inside`, one row at a time."""
    cuts = crossings(polys, y)
    result, k = [], 0
    for x in xs:
        while k < len(cuts) and cuts[k] <= x:
            k += 1
        result.append((len(cuts) - k) % 2 == 1)
    return result


def write_png(path, width, height, rows):
    raw = b"".join(b"\x00" + bytes(r) for r in rows)

    def chunk(tag, data):
        body = struct.pack(">I", len(data)) + tag + data
        return body + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
    Path(path).write_bytes(png)


def main():
    args = sys.argv[1:]
    plan = bool(args) and args[0] == "--plan"
    if plan:
        args = args[1:]
    bin_stl, lid_stl, out, cut, u0, v0, w, h = args[:8]
    scale = float(args[8]) if len(args) > 8 else 100
    lid_dz = float(args[9]) if len(args) > 9 else 20.1
    lid_dx = float(args[10]) if plan and len(args) > 10 else 0
    lid_dy = float(args[11]) if plan and len(args) > 11 else 0
    u0, v0, w, h = float(u0), float(v0), float(w), float(h)
    with tempfile.TemporaryDirectory() as tmp:
        if plan:
            plan_svg(bin_stl, cut, 0, 0, 0, f"{tmp}/bin.svg")
            plan_svg(lid_stl, cut, lid_dx, lid_dy, lid_dz, f"{tmp}/lid.svg")
        else:
            section_svg(bin_stl, cut, 0, f"{tmp}/bin.svg")
            section_svg(lid_stl, cut, lid_dz, f"{tmp}/lid.svg")
        bin_polys, lid_polys = polygons(f"{tmp}/bin.svg"), polygons(f"{tmp}/lid.svg")
    width, height = int(w * scale), int(h * scale)
    # Image columns run along the first world axis (y for a section, x for a plan) and rows down
    # the second (z or y); svg y is minus that second axis
    sxs = [u0 + (px + 0.5) / scale for px in range(width)]
    rows = []
    for py in range(height):
        sy = -(v0 + h) + (py + 0.5) / scale
        bin_row, lid_row = row_inside(bin_polys, sy, sxs), row_inside(lid_polys, sy, sxs)
        row = bytearray()
        for sx, in_bin, in_lid in zip(sxs, bin_row, lid_row):
            colour = (255, 255, 255)
            if in_bin and in_lid:
                colour = (150, 60, 150)
            elif in_bin:
                colour = (90, 130, 200)
            elif in_lid:
                colour = (235, 150, 40)
            if abs(sx - round(sx)) < 0.5 / scale or abs(sy - round(sy)) < 0.5 / scale:
                colour = tuple(int(c * 0.8) for c in colour)
            row += bytes(colour)
        rows.append(row)
    write_png(out, width, height, rows)


if __name__ == "__main__":
    main()
