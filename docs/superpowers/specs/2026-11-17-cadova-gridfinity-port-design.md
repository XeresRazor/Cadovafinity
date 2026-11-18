# Cadova port of gridfinity-rebuilt-openscad and the lidded bin

## Goal

Port gridfinity-rebuilt-openscad to a Swift library built on Cadova, port the
lidded bin (`lid-bin.scad`, by smkent) on top of it, and publish the lidded bin
as a Cadova web customizer.

## Sources

- OpenSCAD library: `../Lidded Bins/gridfinity-rebuilt-openscad` (MIT).
- Lidded bin: `../Lidded Bins/lid-bin.scad` (CC BY 4.0, attribution required).
- Cadova, helper packages, `gridfinity-cadova` (reference only) and the
  customizer docs (`Cadova.docc/WebCustomizer.md`): `../../Cadova`.

## Decisions

- Library scope: core, bins and baseplate. Lite and spiral vase are out.
- Library base: a faithful port of rebuilt-openscad, function by function, so
  dimensions match the OpenSCAD output. `gridfinity-cadova` is a style and API
  reference only.
- Packaging: two packages, `GridfinityRebuilt` (library) and `LiddedBin`
  (model and customizer), as sibling directories. `LiddedBin` depends on the
  library by local path during development and by URL once published.

## Library: GridfinityRebuilt

- `Standard`: constants from `standard.scad` and the height math (`hf`,
  `height`) covering the three height modes and 7mm snapping.
- Profiles: base, wall, bottom, rounded rectangle helpers.
- Types: `Block`, `Bin`, compartment cutters (dividers, tab styles, scoops),
  `Baseplate`.
- All OpenSCAD parameters are typed initializer arguments. The library does not
  use `@Parameter`, so it stays usable outside a customizer.

## Lidded bin: LiddedBin

- A `Model` declares `@Parameter`s. `Part` becomes a `ParameterChoice` enum
  (bin, lid, both closed, both open, bin slice).
- Other parameters: grid size, height mode and value, lip grips, lid
  orientation, interior style, divider pattern and counts.
- The "custom pockets" pattern is dropped, since it required editing source.
- Title, author, license and attribution go in `Metadata`.

## Web customizer

- Built with `swift package generate-customizer`, published through Cadova's
  GitHub Pages action (`Package.resolved` committed).
- WebAssembly limits to respect: `Text` only with bundled fonts, no ICU, single
  thread, smaller stack. The custom-pockets notice text is removed for this
  reason.

## Verification

OpenSCAD is installed (`/opt/homebrew/bin/openscad`). For each ported part,
export STL from the original with representative parameters and compare against
the Cadova output: bounding box, volume and, where practical, symmetric
difference volume. Physical fit is confirmed by a test print of the
`bin_slice` part.

## Order of work

1. Library core: constants, profiles, `Block`, `Bin`, lid-bin primitives.
2. Lidded bin, checked against OpenSCAD output.
3. Web customizer and Pages workflow.
4. Library extras: baseplate and remaining cutter styles.

Each step gets its own plan and build cycle.
