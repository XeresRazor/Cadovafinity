# Customizer build times (native)

Date: 2026-11-18. Machine: Apple M4 Max (`sysctl -n machdep.cpu.brand_string`). Build: `swift test` (debug configuration).

Method: `LiddedBin/Tests/LiddedBinModelTests/BuildTimeTests.swift` (opt-in). Production geometry (Cadova default segmentation, `cornerSegments` nil, lip grips xy), a fresh `ModelFileGenerator.evaluate` per run, bounds and volume measured so the full boolean tree is evaluated, `ContinuousClock` timing, median of three runs. Repeats were not served from a cache: the first run matched the later runs (for example 0.05 0.05 0.05 s), so the median of three is valid.

Run with `LIDDED_BIN_BENCH=1 swift test --skip-update --filter BuildTime`. Extra configurations can be added with `LIDDED_BIN_EXTRA="gx,gy,gz,dx,dy,part;..."` (and `LIDDED_BIN_EXTRA_ONLY=1`, `LIDDED_BIN_RUNS=n`).

| Configuration (grid, dividers) | Part | Median seconds | Volume (mm^3) |
|---|---|---|---|
| 1x1x1, div 1x1 | bin | 0.05 | 7464.9 |
| 2x2x3, div 6x6 (default) | bin | 0.05 | 40250.3 |
| 3x3x3, div 6x6 | bin | 0.07 | 72400.8 |
| 4x4x4, div 6x6 | bin | 0.09 | 135607.0 |
| 6x6x3, div 6x6 | bin | 0.13 | 213393.8 |
| 6x6x6, div 6x6 | bin | 0.13 | 308593.5 |
| 6x6x6, div 12x12 | bin | 0.15 | 440182.8 |
| 6x6x12, div 6x6 | bin | 0.13 | 498992.8 |
| 2x2x3, div 6x6 | lid | 0.03 | 6491.6 |
| 4x4x4, div 6x6 | lid | 0.04 | 25671.7 |
| 6x6x3, div 6x6 | lid | 0.04 | 57552.5 |
| 2x2x3, div 6x6 | bin and lid (open) | 0.06 | 46741.9 |
| 6x6x3, div 6x6 | bin and lid (open) | 0.15 | 270946.4 |

Corner and beyond-range checks (single run each):

| Configuration | Part | Seconds | Volume (mm^3) |
|---|---|---|---|
| 6x6x12, div 12x12 (range corner) | bin | 0.17 | 774947.9 |
| 6x6x12, div 12x12 | bin and lid (open) | 0.16 | 832500.4 |
| 8x8x12, div 12x12 | bin | 0.19 | 1111389.9 |
| 10x10x12, div 12x12 | bin | 0.26 | 1483101.3 |
| 12x12x12, div 12x12 | bin | 0.37 | 1840754.2 |
| 12x12x12, div 24x24 | bin | 0.43 | 2950129.5 |
| 12x12x20, div 12x12 | bin | 0.38 | 2749952.9 |
| 12x12x12, div 12x12 | bin and lid (open) | 0.39 | 2070154.1 |

## Limits decision

The rule (any in-range Bin builds natively in under 5 s) is satisfied with a wide margin: the slowest measured case, even far outside the ranges, is 0.43 s. Cost grows slowly with grid size and dividers, so the corner of the ranges (6x6x12, dividers 12x12) takes 0.17 s and no product cap on `gridX * gridY * divX * divY` is needed.

The ranges are therefore not limited by build time. The existing ranges are kept: grid size 1...6 (a 6x6 bin is 252 mm, about the largest common print bed), dividers 0...12, units height 1...12. They already exceed the required minimums (grid 1...4, dividers 0...8, height 1...8). A WebAssembly build on one thread is typically several times to ten times slower, so the corner would be roughly 1 to 2 s in the browser, still comfortable.

Millimeter height ranges now derive from the unit maximum: external maximum is `12 * 7 = 84`, internal maximum is `84 - 5 - 2.2 = 76.8` (previously 100 and 80, which allowed bins taller than the unit range).
