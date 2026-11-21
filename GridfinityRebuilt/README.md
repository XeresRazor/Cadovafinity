# GridfinityRebuilt

A Swift/Cadova port of parts of
[gridfinity-rebuilt-openscad](https://github.com/kennetek/gridfinity-rebuilt-openscad). It is
verified against OpenSCAD output. `../LiddedBin` is its first consumer.

License: this package is a port of
[gridfinity-rebuilt-openscad](https://github.com/kennetek/gridfinity-rebuilt-openscad), which is
released under the MIT License. This package is also MIT licensed (see `LICENSE`), and that file
carries the upstream copyright notice and permission text that the MIT License requires, plus
the notice of the Gridfinity system the upstream project is based on.

## Scope

Ported:

- `Dimensions`: the Gridfinity constants and derived values
- height math: `HeightMode`, `LipStyle`, `Dimensions.binHeight(_:mode:lip:snap:)`
- profiles: `baseProfile`, `wallProfile`, `lipelessWallProfile`
- `roundedRectangle2D` and `roundedRectangle`
- block base, block wall (`sweepRounded`, `blockWall`) and block bottom
- the base cell: `blockBaseHole`, `refinedHole`, `blockBase`, and `gridfinityBase`
- `BaseplateDimensions`, the baseplate constants
- `BinGeometry`, the `gridfinityInit` shell and `cut_move` placement
- the helpers `patternLinear` (both overloads), `patternCircular`, `copyMirror`, `roundedSquare` and `clamp`

Not yet ported: the compartment cutters, the tab styles and scoops, the lite bin and the spiral
vase modules. The bin and spiral vase customizers are planned.

## Model

`Dimensions` carries every constant that OpenSCAD keeps as a global (`hBase`, `rBase`, `lGrid`,
`dWall`, `dDiv`, `dClear`, `hLip` and so on), plus the derived `dWall2` and `dMagic`.
`Dimensions.standard` uses the upstream defaults, including `dWall = 0.95`. A design that
overrides a constant in its own `.scad` file sets it on a copy, for example
`d.dWall = 1.6`, and derived values follow.

`BinGeometry` carries what OpenSCAD passes through special variables: `gridX` and `gridY`
(`$gxx`, `$gyy`), `height` (`$dh`), `internalHeight` (`$dh0`), `lipStyle` (`$style_lip`) and the
`Dimensions`. It offers:

- `shell(cutting:cornerSegments:)`: the solid bottom block (minus `cutting`) plus the wall
- `placed(x:y:w:h:_:)`: moves geometry to the middle of a compartment, like `cut_move`

`patternLinear(x:y:spacingX:spacingY:_:)` is the grid-of-copies helper.

`cornerSegments` overrides the segment count of the rounded corners so a fixed `$fn` in an
OpenSCAD reference can be matched exactly. Leave it nil normally.

## GridfinityTestSupport

A second library product for verification code. It imports `Testing`, so add it only to
`.testTarget` dependencies, never to a library or executable target. It provides:

- `ReferenceSet`: finds a package's `Reference/reference.json` and `Reference/stl/`.
  `ReferenceSet.containing(file:)` walks up from a source file to the nearest `Package.swift`.
- `expectMatchesReference(_:_:references:volumeTolerance:boundsTolerance:symmetricDifferenceTolerance:segments:)`:
  measures a Cadova geometry and compares volume (default 1e-4 relative), bounds (0.05 mm) and
  symmetric difference against the reference STL (default 0.05 mm^3).
- `measure`, `compare`, `symmetricDifferenceVolume`, `Metrics`.

Another package uses it like this:

```swift
// Package.swift
.testTarget(
    name: "MyTests",
    dependencies: [
        "MyModel", "Cadova",
        .product(name: "GridfinityTestSupport", package: "GridfinityRebuilt"),
    ],
    swiftSettings: [.interoperabilityMode(.Cxx)]
)
```

```swift
// a test file
import GridfinityTestSupport

@Test func matchesOpenSCAD() async throws {
    try await expectMatchesReference("my_case", myGeometry())
}
```

Without `references:`, the reference set is resolved from the calling test file, so each package
uses its own `Reference/` folder. Pass `ReferenceSet.containing()` explicitly to be certain.
The reference folder must contain `reference.json` (name to `volume`, `min`, `max`) and
`stl/<name>.stl`. Every target that imports Cadova needs `.interoperabilityMode(.Cxx)`.

## Regenerating references

```
python3 -I Reference/generate.py            # all cases, or pass case names
swift test --skip-update
```

OpenSCAD is required (`/opt/homebrew/bin/openscad`). The script runs `Reference/reference.scad`
with `$fn = 64`, writes `Reference/reference.json` and `Reference/stl/<case>.stl`.
`Reference/stl/` is generated and git-ignored.

The suite has 57 tests, all passing.

## Known limits

- Volume and bounding box alone cannot see some defects (a wrongly sized fillet can keep both
  almost unchanged). The symmetric difference check against the OpenSCAD mesh covers that: a
  mutation that halved one radius was caught at 0.74 mm^3 against a 0.05 mm^3 limit.
- Tessellation parity: OpenSCAD and Cadova place segment points differently, so comparing
  curved geometry needs matching segment counts. Use `cornerSegments` (16 for a quarter turn at
  `$fn = 64`) on the wall and shell.
- Reference STL float32 noise: reference STLs are float32 so that Cadova's mesh import does not
  collapse near-coincident vertices. The residual noise in symmetric difference is about 1e-7
  to 1e-2 mm^3, well under the 0.05 mm^3 limit.
