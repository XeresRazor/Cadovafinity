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

The side gap at the plate edge comes from the plate inset `sz = 0.5 + 3 * lid_hfit_tolerance` (3.8 mm, against the 1.2 wall thickness: `0.5 + 2 * 1.2 + 2 * 0.45`). The 0.30 offset in `gf_bin_lid` (`offset(delta = 0.30)`) only moves the tongue's chamfer against the slot roof (perpendicular gap about 0.229 mm). With the notch 0.45 deeper than the bump, a closed lid does not touch the bump, so nothing catches it.

## Design

Three controls in a "Lid fit" group. Each has an original-equivalent value that reproduces the OpenSCAD model exactly, so the OpenSCAD reference tests keep their meaning.

| Control | New default | Original equivalent | Effect |
|---|---|---|---|
| Lid clearance (mm) | 0.20 | 0.45 | The gap between the lid's plate edge and the slot face, on each side. The plate and tongue inset is `0.5 + 2 * wall + 2 * clearance`. The tongue offset is derived as `min(0.30, clearance + 0.10)`, so the chamfer keeps its original 0.229 mm perpendicular gap to the slot roof for clearances of 0.20 and above and tightens with smaller values (0.129 mm at 0.10). |
| Lid chamfer (mm) | 1.4 | 0.8 (the 45 degree roof) | The rise of the slot roof, range 0.8 to 2.0. The run of a steeper roof is fixed by the wall: the roof ends on the stacking lip's vertical inner face 0.7 in from the slot face, which does not move because bins above stack on it. The slope is `rise / 0.7` (63 degrees at 1.4, 71 degrees at 2.0), interpolated between 0.8 and 0.896 where the roof first reaches the vertical face. The lid tongue's chamfer stays parallel to the roof with the same perpendicular gap (0.229 at the default clearance): the lid's groove roof is lowered by `0.1 * (s - sqrt((1 + s^2) / 2))` for slope `s`, so the 0.1 horizontal step between the lid and bin grooves stays 0.071 across the roof. The tongue peak rises to 0.89 above the plate top at 1.4 and 1.30 at 2.0. |
| Detent interference (mm) | 0.25 | 0.15 | Overlap of the bump with the lid edge. Bump protrusion = side gap + interference. |

Detent catch: the lid notch becomes a seat just deeper than the bump (about 0.05 clearance). The opening side of the bump is steeper than the closing side, so the lid clicks into place and opening needs a definite push.

Where the controls appear: Lid clearance on the Lid tab and the open assembly; Lid chamfer and Detent interference on the Bin, Lid and open assembly tabs (both parts carry them).

## Verification

OpenSCAD reference tests use the original-equivalent preset. New behavior has no reference and is checked by cross-section measurements (ray casting) of side gap (the plate edge gap equals the clearance, within 0.01 mm), tongue height, chamfer size, bump interference and the notch seat, plus rendered cross-section images (`LiddedBin/Reference/tools/render_section.py`).

The feel of the fit cannot be tested without a print. The defaults are starting values to tune on the customizer page.
