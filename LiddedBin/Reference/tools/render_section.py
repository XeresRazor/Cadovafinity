"""Render a cross-section of the bin and the lid to a PNG, with only the standard library.

A development aid for judging the lid fit by eye. It slices STL files with OpenSCAD
(`projection(cut=true)`), then rasterizes the two outlines: the bin in blue, the lid in orange,
overlap in purple, with a 1 mm grid (grid lines are darkened pixels, not labels).

Usage:
    python3 -I render_section.py BIN.stl LID.stl OUT.png X_CUT Y0 Z0 WIDTH HEIGHT [PIXELS_PER_MM] [LID_DZ]

BIN.stl and LID.stl are exports in the model's own coordinates. The lid exported as the `lid`
part sits on the print bed; pass LID_DZ (default 20.1 = storage height 16 + base 5 - lid
thickness 0.9) to move it back to the closed position. The cut is the plane x = X_CUT, seen along
x: the horizontal axis of the image is world y (starting at Y0, WIDTH mm wide) and the vertical
axis is world z (from Z0 up, HEIGHT mm tall). Needs /opt/homebrew/bin/openscad.
"""
import re, subprocess, struct, sys, tempfile, zlib
from pathlib import Path

OPENSCAD = "/opt/homebrew/bin/openscad"


def section_svg(stl, x_cut, dz, out):
    scad = Path(out).with_suffix(".scad")
    scad.write_text(
        f'projection(cut=true) multmatrix([[0,1,0,0],[0,0,1,0],[1,0,0,-({x_cut})],[0,0,0,1]]) '
        f'translate([0,0,{dz}]) import("{Path(stl).resolve()}");\n'
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


def write_png(path, width, height, rows):
    raw = b"".join(b"\x00" + bytes(r) for r in rows)

    def chunk(tag, data):
        body = struct.pack(">I", len(data)) + tag + data
        return body + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
    Path(path).write_bytes(png)


def main():
    bin_stl, lid_stl, out, x_cut, y0, z0, w, h = sys.argv[1:9]
    scale = float(sys.argv[9]) if len(sys.argv) > 9 else 100
    lid_dz = float(sys.argv[10]) if len(sys.argv) > 10 else 20.1
    y0, z0, w, h = float(y0), float(z0), float(w), float(h)
    with tempfile.TemporaryDirectory() as tmp:
        section_svg(bin_stl, x_cut, 0, f"{tmp}/bin.svg")
        section_svg(lid_stl, x_cut, lid_dz, f"{tmp}/lid.svg")
        bin_polys, lid_polys = polygons(f"{tmp}/bin.svg"), polygons(f"{tmp}/lid.svg")
    width, height = int(w * scale), int(h * scale)
    rows = []
    for py in range(height):
        sy = -(z0 + h) + (py + 0.5) / scale        # svg y is minus world z
        row = bytearray()
        for px in range(width):
            sx = y0 + (px + 0.5) / scale
            in_bin, in_lid = inside(bin_polys, sx, sy), inside(lid_polys, sx, sy)
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
