# Lid fit: findings and design

## Print feedback

A bin and lid printed from the customizer at 0.2 mm layers showed three problems:

1. The lid fit is too loose.
2. The detent touches the lid lightly. The contact is noticeable but gives no positive stop.
3. The lid's top outer edge should be chamfered to match the slope of the slot. The existing slope is too small to see in a print.

## Measurements of the original geometry

Cross-sections of the 2x2x3 bin and lid (lid in the closed position), taken across the slide direction at the slot (x = 0) and through the detent (x = 37.15). Units are mm. Wall of the bin at y = 41.75.

| Feature | Value |
|---|---|
| Lid plate thickness | 0.9 (z 19.9 to 20.8) |
| Plate to divider top, vertical gap | 0.1 |
| Slot face, y | 40.55 (wall 1.2 thick at the slot) |
| Lid edge, y | 40.10 (side gap 0.45 per side, 0.9 in total) |
| Lid tongue height above the plate | about 0.6 |
| Lid tongue chamfer | rises 0.51 from the plate edge (0.13 above the plate top) to a peak 0.64 above the plate top (45 degrees, parallel to the slot roof) |
| Slot roof | 45 degrees, rising 0.798 over 0.798, to a tip at y = 39.75, z = 21.6 on the 45 degree underside of the stacking lip |
| Stacking lip inner face, y | 39.85 (0.7 in from the slot face), vertical from z = 21.7 to the inner top chamfer at z = 23.5 |
| Detent bump protrusion into the slot | 0.6 (face at y = 39.95) |
| Bump overlap with the lid edge as it slides past | about 0.15 |
| Lid notch recess at the bump | face at y = 39.5, so 0.45 deeper than the bump face |
| Closed lid and bin overlap | 1.392 mm^3, all of it a 0.1 wide sliver at the open end (x = -37.6 to -37.5) where the lid's rim meets the bin wall; none at the detents |

The side gap at the plate edge comes from the plate inset `sz = 0.5 + 3 * lid_hfit_tolerance` (3.8 mm, against the 1.2 wall thickness: `0.5 + 2 * 1.2 + 2 * 0.45`). The 0.30 offset in `gf_bin_lid` (`offset(delta = 0.30)`) only moves the tongue's chamfer against the slot roof (perpendicular gap about 0.229 mm). With the notch 0.45 deeper than the bump, a closed lid does not touch the bump, so nothing catches it.

## Design

Three controls in a "Lid fit" group. Each has an original-equivalent value that reproduces the OpenSCAD model exactly, so the OpenSCAD reference tests keep their meaning.

| Control | New default | Original equivalent | Effect |
|---|---|---|---|
| Lid clearance (mm) | 0.20 | 0.45 | The gap between the lid's plate edge and the slot face, on each side. The plate and tongue inset is `0.5 + 2 * wall + 2 * clearance`. The tongue offset is derived as `min(0.30, clearance + 0.10)`, so the chamfer keeps its original 0.229 mm perpendicular gap to the slot roof for clearances of 0.20 and above and tightens with smaller values (0.129 mm at 0.10). |
| Lid chamfer (mm) | 1.4 | 0.8 (the 45 degree roof) | The rise of the slot roof, range 0.8 to 2.0. The run of a steeper roof is fixed by the wall: the roof ends on the stacking lip's vertical inner face 0.7 in from the slot face, which does not move because bins above stack on it. The slope is `rise / 0.7` (63 degrees at 1.4, 71 degrees at 2.0), interpolated between 0.8 and 0.896 where the roof first reaches the vertical face. The lid tongue's chamfer stays parallel to the roof with the same perpendicular gap (0.229 at the default clearance): the lid's groove roof is lowered by `0.1 * (s - sqrt((1 + s^2) / 2))` for slope `s`, so the 0.1 horizontal step between the lid and bin grooves stays 0.071 across the roof. The tongue peak rises to 0.89 above the plate top at 1.4 and 1.30 at 2.0. |
| Detent interference (mm) | 0.25 | 0.15 | Overlap of the bump with the lid's plate edge as the lid slides past it, range 0.05 to 0.6. The bump protrudes `side gap + interference` from the slot face (0.45 by default), so the overlap does not change with the clearance. |

Detent catch (`DetentStyle.seated`, the default; `openSCADOriginal` keeps the original round bump and its notch 0.45 deeper than the bump):

- The bump sits where the original one does, on each side wall at the closed end, and keeps its height (z 19.75 to 22.85 for a 3 unit bin). In plan view it is a trapezoid: a 30 degree ramp (to the slide direction) on the open-end side, a 0.8 mm flat top, and a 65 degree stop face on the closed-end side that ends where the original bump ends. At the default protrusion of 0.45 the ramp runs 0.78 and the stop face 0.21, so the bump is 1.79 long (the original is 1.8). The angles, the flat length and the seat clearance are constants in `LidFit`.
- The notch in the lid is the bump grown by a 0.05 seat clearance all round. Closed, the bump nests in the notch without touching: 0.05 across the slide direction, 0.10 along it at the ramp and 0.055 at the stop face.
- A closing lid meets the ramp first, rides over the bump and drops into the notch. Opening, the notch's stop face climbs the bump's stop face: the plate edge has to give way by the full overlap within about 0.15 mm of travel, against about 0.8 mm for the ramp side, so opening takes a definite push.
- For each lid direction the profile is placed with its stop face toward the closed end: the tab frame is mirrored along the slide direction for the right and down directions.
- Above the slot roof the bump is inside the wall. Above the plate top it is clipped to the stacking lip's inner face (0.7 in from the slot face), which only matters for protrusions over 0.7 (large clearance and interference together), so the bump never stands out of the lip.
- The bump sits where the plate edge starts to curve into its corner (corner radius 2.6 at the default clearance), so the deepest overlap while sliding is 0.24 rather than the 0.25 measured on the straight edge.

Where the controls appear: all three on the Bin, Lid and open assembly tabs, after Lip grips. Both parts depend on each: the clearance and the interference set the bump protrusion on the bin and the lid's size and notch, and the chamfer shapes the roof and the tongue.

## Verification

OpenSCAD reference tests use the original-equivalent preset. New behavior has no reference and is checked by cross-section measurements (ray casting) of side gap (the plate edge gap equals the clearance, within 0.01 mm), tongue height, chamfer size, bump interference (within 0.01 mm of the setting) and the notch seat (closed overlap 0 in all four lid directions, seat gaps within 0.01 mm), a slide sweep of the bin and lid overlap, plus rendered cross-section and plan-view images (`LiddedBin/Reference/tools/render_section.py`, with `--plan` for a cut at constant z).

The feel of the fit cannot be tested without a print. The defaults are starting values to tune on the customizer page.
