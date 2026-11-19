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
`lidded-bin` carry the metadata author "smkent (original design), ported by XeresRazor" and
license "CC BY 4.0", and the metadata description names the original design and its license.

## Dependency

The bin body is built on `../GridfinityRebuilt`, a port of
[gridfinity-rebuilt-openscad](https://github.com/kennetek/gridfinity-rebuilt-openscad), which is
released under the MIT License (stated on its GitHub page). The OpenSCAD copy next to
`lid-bin.scad` contains only `.scad` files, so the license text is not in that copy.

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
| `lidClearance` | side gap between lid and slot (`0.5 + 3 * lid_hfit_tolerance` inset, 0.45 per side) | 0.20 (original-equivalent 0.45; clamped to 0.10...0.6) |
| `lidChamfer` | rise of the slot roof, the slope that holds the lid down; the lid's edge chamfer follows it, about 0.6 times as tall | 1.4 (original-equivalent 0.8; clamped to 0.8...1.8) |
| `detentInterference` | how far the bump on the bin overlaps the lid's edge as the lid slides past it | 0.25 (original-equivalent 0.15; clamped to 0.10...0.40) |
| `detentStyle` (`seated`, `original`; internal preset field, not in the customizer) | `seated` is the catch the lid snaps into; `original` is lid-bin.scad's round bump | `seated` (`original` in the original-equivalent preset) |
| `cornerSegments` | none | nil |

`cornerSegments` exists only to force the same corner tessellation as an OpenSCAD reference
built with a fixed `$fn`. Leave it nil in production.

`divMultiple` is clamped to 1...5, the range of `div_multiple` in the OpenSCAD customizer. Without
the clamp a value of 0 or less made the multisize pocket loops infinite.

The lid fit constants (`lid_wall_thickness`, `lid_thickness`, `lid_hfit_tolerance`,
`lid_vfit_tolerance`, `lid_vpos_tolerance`, `bin_separator_wall_thickness`,
`interior_base_wall_adjust`) live in the internal `LidFit` type with the original defaults. They
are not part of the public configuration; tests vary them through an internal initializer.

## Lid fit

Three lid fit controls of this port are not exposed by lid-bin.scad. Each has an
original-equivalent value. `LiddedBinConfiguration.openSCADOriginal` is a configuration with
every lid fit field set to that value (`lidClearance = 0.45`, `lidChamfer = 0.8`,
`detentInterference = 0.15` with `detentStyle = .original`, the original detent shape), and the
OpenSCAD reference tests build their designs from it.

`lidClearance` (mm) is the gap between the lid's edge and the slot face on each side. The
original inset `0.5 + 3 * lid_hfit_tolerance` fixes a gap of 0.45 mm per side.

- Default: 0.20 mm. Original-equivalent value: 0.45 mm.
- Effect: the plate and tongue are inset from the block outline by
  `0.5 + 2 * lid_wall_thickness + 2 * lidClearance`, so the vertical plate edge sits exactly
  `lidClearance` from the slot face. The offset around the tongue (`offset(delta = 0.30)` in the
  original) is derived as `min(0.30, lidClearance + 0.10)`: clearances of 0.20 and above keep the
  original 0.229 mm perpendicular gap between the tongue's chamfer and the slot roof, and smaller
  ones tighten it (0.129 mm at 0.10). The bin depends on it through the detent bumps, whose
  protrusion is `lidClearance + detentInterference`.
- Customizer: "Lid clearance" (0.10...0.6 mm, step 0.05) on all three tabs.
- The lid tongue peak depends on the clearance: a tighter clearance gives a taller tongue. With
  a lid chamfer of 1.4 the peak is 1.11 mm above the plate top at a clearance of 0.10 and 0.89 mm
  at 0.20.

`lidChamfer` (mm) is the rise of the slot roof: the slope from the slot face, at the top of the
lid plate, up and inward to where it meets the inside of the wall. The lid tongue's top outer
edge has a chamfer parallel to the roof, so it follows the same slope.

- Default: 1.4 mm. Original-equivalent value: 0.8 mm (the original 45 degree roof, which rises
  0.798 mm over a run of 0.798 mm and ends on the 45 degree underside of the stacking lip).
  Range: 0.8...1.8 mm.
- Effect: the run of a steeper roof is fixed by the wall. It ends on the stacking lip's vertical
  inner face, 0.7 mm in from the slot face (the inner face is not moved, since bins above stack
  on it), so the slope is `lidChamfer / 0.7`: about 63 degrees at 1.4 and 69 degrees at 1.8.
  Between 0.8 and 0.896 (where the roof first reaches the vertical face) the slope is
  interpolated, which keeps the rise within 0.003 mm of the setting. The tongue's chamfer keeps a perpendicular gap of
  0.229 mm (at the default clearance) to the roof for every rise, and the tongue's peak above
  the plate grows from 0.64 mm (0.8) to 0.89 mm (1.4).
- Customizer: "Lid chamfer" (0.8...1.8 mm, step 0.1) on all three tabs, since both the bin and
  the lid carry the slope.

`detentInterference` (mm) is how far the detent bumps on the bin overlap the lid's plate edge as
the lid slides past them. There is one bump on each side wall at the closed end, and a matching
notch in each side of the lid.

- Default: 0.25 mm. Original-equivalent value: 0.15 mm (the original bump protrudes 0.6 mm from
  the slot face against a 0.45 mm side gap). Range: 0.10...0.40 mm.
- Effect: the bump protrudes `lidClearance + detentInterference` from the slot face (0.45 mm by
  default), so the overlap stays the same when the clearance changes. In plan view the bump is
  a trapezoid: a 30 degree ramp (to the slide direction) on the side toward the open end, a
  0.8 mm flat top, and a 65 degree stop face on the side toward the closed end, which ends where
  the original bump ends. At the default protrusion the ramp runs 0.78 mm and the stop face
  0.21 mm, so the bump is 1.79 mm long, about the original 1.8. The notch in the lid is the bump
  grown by a 0.05 mm seat clearance all round, so in the closed position the bump nests in the
  notch with 0.05 mm of play across the slide direction (0.10 mm along it at the ramp and
  0.055 mm at the stop face) and the parts do not touch. A closing lid meets the gentle ramp
  first and the bump drops into the notch; opening, the notch's stop face has to climb the
  bump's steep stop face, which takes a definite push. The bump keeps the original height
  (z 19.75 to 22.85 for a 3 unit bin). Where it reaches above the slot roof it is inside the
  wall, and above the plate top it is clipped to the lip's inner face, which only affects
  protrusions over 0.7 mm. The original detent (`detentStyle = .original`) is the round bump
  0.6 mm deep with a notch 0.45 mm deeper than the bump, so a closed lid sits clear of it.
- The bumps sit where the lid plate's edge starts to curve into its corner, so while the lid
  slides the deepest overlap is 0.24 mm rather than the full 0.25 (measured on the straight
  edge), and the overlap ends about 1.85 mm after the lid starts to open.
- Customizer: "Detent interference" (0.10...0.40 mm, step 0.05) on all three tabs, since the bin
  carries the bumps and the lid the notches.

## Parts

`LiddedBinDesign(configuration).geometry(for:)` returns one of the `LiddedBinPart` values
(`Part` in `lid-bin.scad`):

| Part | Contents |
|---|---|
| `bin` | The bin. |
| `lid` | The lid, positioned as in OpenSCAD: its bottom is at z = -0.2 (lid_thickness less the vertical position tolerance). |
| `bothClosed` | Bin and lid as two Cadova parts named "Bin" and "Lid", lid closed. |
| `bothOpen` | The same, with the lid slid open. |
| `binSlice` | A thin slice of the bin at the lip for print testing, a hollow ring. |

## Build

```
swift run lidded-bin
```

This writes three 3MF files to `Models/`, all built with the default parameter values:
`Bin`, `Lid` and `Bin and lid (open)` (the open assembly, with the bin and the lid as two
separate parts). `Models/` is generated output and is git-ignored. The closed assembly and the
bin slice are not exported; they remain available as `LiddedBinPart.bothClosed` and
`LiddedBinPart.binSlice` in the library.

## Customizer parameters

`Sources/lidded-bin/main.swift` declares the parameters of the web customizer with Cadova's
`@Parameter`, one tab per model. Every default comes from `LiddedBinInput.defaults` (the
defaults of `LiddedBinConfiguration`), and every range from `LiddedBinLimits`. The model library
itself does not use `@Parameter`.

| Label | Values | Default | lid-bin.scad | Tabs |
|---|---|---|---|---|
| Grid width | 1...6 cells | 2 | `gridx` | all |
| Grid depth | 1...6 cells | 2 | `gridy` | all |
| Height style | 7 mm units, Internal height, Overall height | 7 mm units | `gridz_define` | all |
| Height | 1...12 units, step 1 | 3 | `gridz` | all, when Height style is 7 mm units |
| Internal height | 5...76.8 mm, step 1 | 20 | `gridz` | all, when Height style is Internal height |
| Overall height | 14...84 mm, step 1 | 30 | `gridz` | all, when Height style is Overall height |
| Snap to 7 mm | on, off | off | `enable_zsnap` | all, when Height style is Internal height or Overall height |
| Internal block height | 0...80 mm | 0 | `height_internal` | all |
| Lid direction | Up, Down, Left, Right | Left | `Lid_Orientation` | all |
| Lip grips | None, Along X, Along Y, Along X and Y | Along X and Y | `Lip_Grips` | all |
| Lid clearance | 0.10...0.6 mm, step 0.05 | 0.20 | gap between the lid and the slot on each side; smaller is tighter (original value 0.45) | all |
| Lid chamfer | 0.8...1.8 mm, step 0.1 | 1.4 | rise of the slot roof that holds the lid down; the lid's chamfer follows it, about 0.6 times as tall (original value 0.8) | all |
| Detent interference | 0.10...0.40 mm, step 0.05 | 0.25 | overlap of the bump with the lid's edge; more is a firmer click and a stiffer lid (original value 0.15) | all |
| Interior style | Minimal, Partially raised | Minimal | `Interior_Style` | Bin, Bin and lid (open) |
| Compartments | Equal grid, Two sizes | Equal grid | `div_pattern` | Bin, Bin and lid (open) |
| Dividers X | 0...12 | 6 | `divx` | Bin, Bin and lid (open) |
| Dividers Y | 0...12 | 6 | `divy` | Bin, Bin and lid (open) |
| Size multiple | 1...5, step 0.5 | 2 | `div_multiple` | Bin, Bin and lid (open), when Compartments is Two sizes |

All parameters are declared in the project, so a value is shared between the tabs that show it.
Cadova lists a parameter on a tab only when that model reads it, and on every tab when the
project body reads it. The settings the lid depends on, including the three lid fit controls
(which shape both parts), are read in the project body, so every tab lists the lid fit controls
right after Lip grips; the bin-only settings are read only inside the `Bin` and
`Bin and lid (open)` models, since the lid geometry does not depend on them. The conditional
parameters are read only while they apply.
Internal block height is clamped to the bin's storage height by `validated()`.

The catalog can be printed natively, the way Cadova's customizer page asks for it: write a
request file and run the built executable with `CADOVA_CUSTOMIZER_REQUEST` naming it.

```
swift build
echo '{"listParameters": "/tmp/catalog.json"}' > /tmp/request.json
CADOVA_CUSTOMIZER_REQUEST=/tmp/request.json .build/debug/lidded-bin
```

A `"values"` object in the request, keyed by the parameter keys the catalog lists, gives the
catalog for other choices (for example another Height style). This request format is Cadova's
internal contract with its customizer page (Cadova 1.3.0), not public API.
`CustomizerCatalogTests` checks the catalog this way, so run `swift build` before `swift test`
after changing `main.swift`; `swift test` does not rebuild the executable.

## Publishing the customizer

`swift package generate-customizer` builds a static web page from `lidded-bin`, with the model
compiled to WebAssembly so it runs in the visitor's browser. The page offers three tabs, one for
each exported model (`Bin`, `Lid` and `Bin and lid (open)`), each with the parameters listed
above and a download button.

Build it locally (needs the Swift 6.4.0 toolchain from swift.org, and network access to fetch
dependencies):

```
cd LiddedBin
swift package generate-customizer
```

This writes the page to `Customizer/`, which is git-ignored. The command was not run in the
development sandbox (no network and no WebAssembly toolchain), so neither the build nor the
page's behavior in a browser has been verified here.

Preview it locally:

```
python3 -m http.server --directory Customizer 8000
```

Then open <http://localhost:8000>.

To publish on GitHub Pages, push the repository to GitHub, open Settings, Pages, and set the
source to GitHub Actions. The workflow `.github/workflows/customizer.yml` at the repository root
builds `lidded-bin` from the `LiddedBin` folder with Cadova's `BuildCustomizer` action (pinned to
1.3.0, the Cadova version in `Package.resolved`) and deploys it on every push to `main` or on a
manual run. The sibling `../GridfinityRebuilt` dependency resolves because both packages are in
the same checkout.

The page shows the model's author and license (see "Attribution and license"), so it carries the
CC BY 4.0 attribution to smkent / bulbasaur0.

Limits of the WebAssembly build, from the Cadova guide: text can only use fonts included as
resources, ICU locale data is missing (so `DateFormatter` and `NumberFormatter` stop the build),
models build on a single thread and so are slower than native, and the browser gives a model
less stack space. `LiddedBin` does not use text.

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

The suite currently has 86 tests (`swift build --skip-update && swift test --skip-update`), all passing. `ProductionTests`
build the default configuration with `cornerSegments == nil` and Cadova's default segmentation,
as the exporter does, and check volume, bounds, symmetric difference and the closed bin/lid
interference against the references (with the original lid fit preset); `LidFitTests` measure
the lid clearance, the slot roof and the tongue chamfer by ray casts on the closed assembly;
`DetentTests` measure the detent (the bump's overlap with the plate edge, its plan-view angles,
the closed seat in all four lid directions, and a slide sweep of the overlap) by ray casts and
intersection volumes. `ValidationTests` also checks that `divMultiple` of 0 or less is clamped. The closed bin and
lid assemblies have no OpenSCAD CLI reference (`lid-bin.scad` uses them for preview only), so
the lid placement there is checked by footprint, shift and overlap tests instead.

## Known differences

- Custom compartment pockets are dropped: the `custom` value of `div_pattern` and its text
  notice are not ported, because `Text` cannot use system fonts in the planned web customizer.
- A `divX` or `divY` of 0 (grid pattern) gives an open hollow bin with no dividers. The original
  OpenSCAD model gives a solid bin there, because the interior cut intersects with an empty
  `children()` and cuts nothing. The port deliberately deviates: with no pockets it cuts the whole
  interior. `binSlice` is therefore a hollow ring. The references for these cases
  (`bin_1x1x2_nogrips_div0`, `bin_slice_2x2x3`, `bin_slice_1x1x2_up`) come from a patched copy of
  `lid-bin.scad` that `generate.py` writes to `Reference/generated/` (git-ignored); the original
  file is not edited.
- In the closed position the lid and the bin overlap by about 1.4 mm^3 (1.34 mm^3 with the
  default lid fit): a 0.1 mm wide sliver at the open end, where the lid's rim meets the bin wall
  that `gf_bin_lid_lip_mask`, moved by `lid_lip_fit_tolerance`, leaves standing. This is present
  in the original design, not introduced by the port. The two parts are
  exported as separate bodies, so the assembly volume is the sum of both.
