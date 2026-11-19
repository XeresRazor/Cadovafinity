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
| Lid chamfer run | about 0.5 (45 degrees, parallel to the slot roof) |
| Slot roof | 45 degrees, rising about 0.8 over about 0.8 |
| Detent bump protrusion into the slot | 0.6 (face at y = 39.95) |
| Bump overlap with the lid edge as it slides past | about 0.15 |
| Lid notch recess at the bump | face at y = 39.5, so 0.45 deeper than the bump face |

The side gap is `lid_hfit_tolerance` (1.1 against a 1.2 wall thickness, 0.1) plus the 0.30 offset in `gf_bin_lid` (`offset(delta = 0.30)`). With the notch 0.45 deeper than the bump, a closed lid does not touch the bump, so nothing catches it.

## Design

Three controls in a "Lid fit" group. Each has an original-equivalent value that reproduces the OpenSCAD model exactly, so the OpenSCAD reference tests keep their meaning.

| Control | New default | Original equivalent | Effect |
|---|---|---|---|
| Lid clearance (mm) | 0.15 | 0.30 | The offset around the lid tongue. Side gap about 0.25 per side. |
| Lid chamfer (mm) | 1.0 | about 0.5 (original geometry) | 45 degree chamfer on the lid tongue's top outer edge and the matching slot roof. The overhang is thickened inward under the roof to make room. |
| Detent interference (mm) | 0.25 | 0.15 | Overlap of the bump with the lid edge. Bump protrusion = side gap + interference. |

Detent catch: the lid notch becomes a seat just deeper than the bump (about 0.05 clearance). The opening side of the bump is steeper than the closing side, so the lid clicks into place and opening needs a definite push.

Where the controls appear: Lid clearance on the Lid tab and the open assembly; Lid chamfer and Detent interference on the Bin, Lid and open assembly tabs (both parts carry them).

## Verification

OpenSCAD reference tests use the original-equivalent preset. New behavior has no reference and is checked by cross-section measurements (ray casting) of side gap, tongue height, chamfer size, bump interference and the notch seat, plus rendered cross-section images (`LiddedBin/Reference/tools/render_section.py`).

The feel of the fit cannot be tested without a print. The defaults are starting values to tune on the customizer page.
