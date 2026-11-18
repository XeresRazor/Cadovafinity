# LiddedBin

A Swift/Cadova model of a Gridfinity bin with a sliding lid. It is a port of the OpenSCAD design
`lid-bin.scad`, and its output is checked against OpenSCAD's own output for the same settings.

## Attribution and license

This is a port of "Gridfinity Bins with Lids" by smkent (GitHub) / bulbasaur0 (Printables). The
header of the original `lid-bin.scad` reads:

> Gridfinity Bins with Lids. By smkent (GitHub) / bulbasaur0 (Printables).
> Licensed under Creative Commons (4.0 International License) Attribution

The original is licensed under CC BY 4.0: <https://creativecommons.org/licenses/by/4.0/>.

This package is a port with changes: it is written in Swift with Cadova instead of OpenSCAD, and
the custom compartment pockets feature was dropped (see "Known differences"). Models exported by
`lidded-bin` carry the metadata author "smkent (original design)" and license "CC BY 4.0".

## Dependency

The bin body is built on `../GridfinityRebuilt`, a port of
[gridfinity-rebuilt-openscad](https://github.com/kennetek/gridfinity-rebuilt-openscad). The
OpenSCAD copy next to `lid-bin.scad` (`gridfinity-rebuilt-openscad/`) contains only `.scad` files
and has no license file, and its headers carry no license text. I could not confirm its license
from that copy. It is commonly described as MIT, but the license should be confirmed against the
upstream repository before this package is published or redistributed.

`LiddedBin` also depends on [Cadova](https://github.com/tomasf/Cadova) (1.3.0 or later).
`d_wall` is 1.6 mm throughout, as `lid-bin.scad` sets it, so the design uses
`Dimensions.dWall = 1.6`.

## Configuration

`LiddedBinConfiguration` holds the user-facing settings. The names in the second column are the
variables in `lid-bin.scad`.

| Swift property | lid-bin.scad | Default |
|---|---|---|
| `gridX` | `gridx` | 2 |
| `gridY` | `gridy` | 2 |
| `gridZ` | `gridz` | 3 |
| `heightMode` | `gridz_define` | `.units` |
| `snapHeight` | `enable_zsnap` | false |
| `internalHeightOverride` | `height_internal` | 0 |
| `interiorStyle` (`minimal`, `partialRaised`) | `Interior_Style` | `minimal` |
| `lipGrips` (`none`, `x`, `y`, `xy`) | `Lip_Grips` | `xy` |
| `lidOrientation` (`up`, `down`, `left`, `right`) | `Lid_Orientation` | `left` |
| `compartmentPattern` (`grid`, `multiSize`) | `div_pattern` (`default`, `multisize`) | `grid` |
| `divX` | `divx` | 6 |
| `divY` | `divy` | 6 |
| `divMultiple` | `div_multiple` (clamped to 1...5) | 2 |
| `cornerSegments` | none | nil |

`cornerSegments` exists only to force the same corner tessellation as an OpenSCAD reference
built with a fixed `$fn`. Leave it nil in production.

`divMultiple` is clamped to 1...5, the range of `div_multiple` in the OpenSCAD customizer. Without
the clamp a value of 0 or less made the multisize pocket loops infinite.

The lid fit constants (`lid_wall_thickness`, `lid_thickness`, `lid_hfit_tolerance`,
`lid_vfit_tolerance`, `lid_vpos_tolerance`, `bin_separator_wall_thickness`,
`interior_base_wall_adjust`) live in the internal `LidFit` type with the original defaults. They
are not part of the public configuration; tests vary them through an internal initializer.

## Parts

`LiddedBinDesign(configuration).geometry(for:)` returns one of the `LiddedBinPart` values
(`Part` in `lid-bin.scad`):

| Part | Contents |
|---|---|
| `bin` | The bin. |
| `lid` | The lid, positioned as in OpenSCAD: its bottom is at z = -0.2 (lid_thickness less the vertical position tolerance). |
| `bothClosed` | Bin and lid as two Cadova parts named "Bin" and "Lid", lid closed. |
| `bothOpen` | The same, with the lid slid open. |
| `binSlice` | A thin slice of a solid bin for print testing. |

## Build

```
swift run lidded-bin
```

This writes five 3MF files to `Models/` (`Bin`, `Lid`, `Bin and lid, closed`,
`Bin and lid, open`, `Bin slice`). `Models/` is generated output and is git-ignored.

## Verify against OpenSCAD

OpenSCAD is required (the scripts expect `/opt/homebrew/bin/openscad`).

```
python3 -I Reference/generate.py     # optionally pass case names to regenerate only those
swift test
```

`generate.py` runs `lid-bin.scad` for each case with `-D $fn=64` plus the case's overrides. It
writes `Reference/reference.json` (volume and bounding box, measured on OpenSCAD's
full-precision output) and `Reference/stl/<case>.stl`. `Reference/stl/` is generated and
git-ignored; `reference.json` is committed. The tests need the STL files, so run the script
first on a fresh checkout.

Each reference test builds the Cadova geometry for the same settings with `cornerSegments = 16`
(a quarter turn at `$fn = 64`) and compares it to OpenSCAD:

- volume: relative tolerance 1e-4
- bounding box: 0.05 mm per coordinate
- symmetric difference against the OpenSCAD mesh: 0.05 mm^3

Cases cover bins, lids, all four lid orientations, grips, height modes, the multisize pattern,
fit-constant sweeps, and the bin slice.

Float32 note: the STL files in `Reference/stl/` have every coordinate rounded to float32, as a
binary STL would store. OpenSCAD's double-precision output mixes rounded and exact vertices on
shared planes, and Cadova's import then loses small wedges of volume (up to about 6 mm^3 in
the cases investigated). Rounding fixes that, and it adds a noise floor of roughly 0.001 to
0.02 mm^3 to the symmetric difference, which is why the tolerance is 0.05. The one exception
is `lid_2x2x3_fit_sweep`, which `generate.py` keeps in full precision (`FULL_PRECISION`)
because float32 rounding made the import drop a wedge there.

The suite currently has 44 tests (`swift test --skip-update`), all passing. `ProductionTests`
build the default configuration with `cornerSegments == nil` and Cadova's default segmentation,
as the exporter does, and check volume, bounds, symmetric difference and the closed bin/lid
interference against the references; it also checks that `divMultiple` of 0 or less is clamped. The closed bin and
lid assemblies have no OpenSCAD CLI reference (`lid-bin.scad` uses them for preview only), so
the lid placement there is checked by footprint, shift and overlap tests instead.

## Known differences

- Custom compartment pockets are dropped: the `custom` value of `div_pattern` and its text
  notice are not ported, because `Text` cannot use system fonts in the planned web customizer.
- With zero compartment divisions (`divx = 0` and `divy = 0` with the grid pattern), OpenSCAD
  intersects with an empty `children()` and cuts nothing, so the bin comes out solid. The port
  reproduces this on purpose (no pockets means no interior cut).
- In the closed position the lid and the bin overlap by about 1.4 mm^3 (the lid tabs against the
  lip). This is present in the original design, not introduced by the port. The two parts are
  exported as separate bodies, so the assembly volume is the sum of both.

## Next step

A web customizer. The model library deliberately does not use `@Parameter`; customizer
parameters come in the next piece of work.
