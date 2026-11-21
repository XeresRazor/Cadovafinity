# Baseplate build times (native)

Date: 2026-11-20. Machine: Apple M4 Max. Build: `swift test` (debug configuration).

Method: `GridfinityCustomizers/Tests/GridfinityModelsTests/BuildTimeTests.swift` (opt-in). Production geometry (Cadova default segmentation), a fresh `ModelFileGenerator.evaluate` per run, bounds and volume measured so the full tree is evaluated, `ContinuousClock` timing, median of three runs, serialized (`--no-parallel`). The three runs agree within a few percent, so no run was served from a cache.

Run with `GRIDFINITY_BENCH=1 swift test --skip-update --no-parallel --filter BuildTime`. Extra configurations, beyond the limits and unvalidated: `GRIDFINITY_EXTRA="style,gx,gy,screws;..."` (style is the raw value 0 to 4) with `GRIDFINITY_EXTRA_ONLY=1`; `GRIDFINITY_RUNS=n`.

| Configuration | Cells | Median seconds | Volume (mm^3) |
|---|---|---|---|
| 1x1 thin | 1x1 | 0.02 | 1051.4 |
| 5x5 weighted | 5x5 | 0.22 | 239159.0 |
| 5x5 skeletonized, magnets, counterbore | 5x5 | 0.52 | 152067.8 |
| 6x6 screw together, 2 screws per cell | 6x6 | 0.77 | 228809.5 |
| 10x10 skeletonized | 10x10 | 2.20 | 613244.3 |
| 10x10 weighted | 10x10 | 0.92 | 961609.0 |
| 10x10 screw together minimal | 10x10 | 0.30 | 459980.9 |
| drawer 500 x 400 weighted | 11x9 | 0.96 | 1230410.6 |

Slowest styles beyond 10 cells (skeletonized, and screw together with 3 screws per cell; single configuration each, 3 runs):

| Cells | Skeletonized | Screw together, 3 screws |
|---|---|---|
| 14x14 | 4.37 s | 4.50 s (4.61 s in a second run) |
| 15x15 | 5.23 s | 5.37 s |
| 16x16 | 5.88 s | 6.51 s |
| 20x20 | 10.19 s | 10.95 s |
| 24x24 | 18.90 s | not run |

## Limits

The time grows with the cell count, a little faster than linearly beyond 10 cells. The slowest style stays under 5 seconds natively up to 14 x 14 and passes it at 15 x 15, but a browser builds on one thread and slower than native, and a 14 cell plate is 588 mm, larger than any common printer. `BaseplateLimits.gridSize` is therefore 1...10 per axis (a 420 mm plate; 10 x 10 skeletonized takes 2.2 s natively, the slowest in range) and the drawer range is 42...420 mm. The drawer size changes only the cell count and padding, not the cost per cell. 10 x 10 is the largest product of cells in range, so no cap on `gridX * gridY` is needed.

## Segmentation

Compared on the 5x5 plates, median of three, Cadova default segmentation (`minAngle 2°`, `minSize 0.15`) against `.withSegmentation(minAngle: 8°, minSize: 0.25)` (OpenSCAD's `$fa = 8`, `$fs = 0.25`):

| Plate | Default | 8° / 0.25 | Default / coarse time | Volume default | Volume coarse | Relative difference |
|---|---|---|---|---|---|---|
| 5x5 weighted | 0.22 s | 0.11 s | 2.0 | 239159.0 | 239222.0 | 2.6e-4 |
| 5x5 skeletonized | 0.53 s | 0.20 s | 2.6 | 152067.8 | 152084.4 | 1.1e-4 |

Decision: use Cadova's default segmentation, as the lidded bin does. The default is at most 2.6 times slower than OpenSCAD's coarse setting, under the threshold of 3, and the volumes differ by under 0.03 percent, so the finer curves cost no meaningful time and the limits above were measured with the setting the executable uses. This applies to the executable in Task 8.
