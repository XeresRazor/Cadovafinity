# Lidded Bin Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port `lid-bin.scad` (smkent, CC BY 4.0) to a Swift/Cadova package `LiddedBin` on top of `GridfinityRebuilt`, verified against OpenSCAD output with a symmetric-difference mesh comparison. The web customizer is a later plan.

**Architecture:** First extend the library (`GridfinityRebuilt`): a corner-segment parity option, `patternLinear`, and a reusable `GridfinityTestSupport` product holding the OpenSCAD comparison harness (volume, bounds, symmetric difference against imported STL). Then a new package `LiddedBin` with a model library target (`LiddedBinModel`: configuration plus geometry, no `@Parameter`) and a small executable (`lidded-bin`) that builds the parts as Cadova models. Each OpenSCAD module of `lid-bin.scad` becomes a method on a `LiddedBinDesign` value.

**Tech Stack:** Swift 6.3, Cadova 1.3 (URL dependency), Swift Testing, OpenSCAD (`/opt/homebrew/bin/openscad`), Python 3 stdlib.

**Spec:** `docs/superpowers/specs/2026-11-17-cadova-gridfinity-port-design.md`. Library core plan (done): `docs/superpowers/plans/2026-11-17-library-core.md`.

## Global Constraints

- Packages live side by side: `Cadovafinity/GridfinityRebuilt/` (exists) and `Cadovafinity/LiddedBin/` (new). `LiddedBin` depends on the library with `.package(path: "../GridfinityRebuilt")`.
- `swift-tools-version: 6.3`, `platforms: [.macOS(.v15)]`, `swiftSettings: [.interoperabilityMode(.Cxx)]` on EVERY target that imports Cadova, including test targets and the test-support target.
- Cadova dependency is `.package(url: "https://github.com/tomasf/Cadova.git", from: "1.3.0")` in both packages.
- The model library never uses `@Parameter`. Customizer parameters come in the next plan.
- `lid-bin.scad` sets `d_wall = 1.60` (OpenSCAD applies it everywhere). The design must use `Dimensions` with `dWall = 1.6`. Nothing hardcodes `0.95`.
- The `custom` compartment pattern and its text notice are dropped (spec decision): `Text` cannot use system fonts in the customizer.
- Do not run `git commit`. Do not stage. A git repo now exists at `Cadovafinity/`; leave it alone. Do not edit sandbox allowlists or `~/.claude` config.
- Build offline: `swift test --skip-update`. The SwiftPM cache holds the dependencies. If the sandbox blocks something, report BLOCKED with the exact error.
- Run Python with `python3 -I`. OpenSCAD is `/opt/homebrew/bin/openscad`.
- Test tolerances: volume relative `1e-4`, bounds `0.05` mm, symmetric difference as set in Task 3. Never widen a tolerance to make a test pass; investigate the geometry.
- No em dashes in comments, docs or READMEs.
- Source paths: `$SRC` = `/Users/shinohara/Downloads/3D Printing/Gridfinity/Lidded Bins`. The consumer file is `$SRC/lid-bin.scad`. Library OpenSCAD is `$SRC/gridfinity-rebuilt-openscad/`. Cadova source is `/Users/shinohara/Downloads/3D Printing/Cadova/Cadova`.

## File Structure

```
GridfinityRebuilt/                         (existing package, modified)
  Package.swift                            # add GridfinityTestSupport product + target
  Sources/GridfinityRebuilt/
    BlockWall.swift                        # + cornerSegments parameter
    BinGeometry.swift                      # shell/wall take cornerSegments
    PatternLinear.swift                    # new: patternLinear
  Sources/GridfinityTestSupport/           # new product
    Metrics.swift                          # Metrics, measure, compare
    ReferenceSet.swift                     # reference.json + STL lookup
    SymmetricDifference.swift              # symmetricDifferenceVolume
    Expect.swift                           # expectMatchesReference (Swift Testing)
  Reference/generate.py                    # + saves stl/<case>.stl
  Tests/GridfinityRebuiltTests/            # migrated to GridfinityTestSupport; Measure.swift removed
LiddedBin/                                 (new package)
  Package.swift
  Sources/LiddedBinModel/
    LiddedBinConfiguration.swift           # enums + LiddedBinConfiguration
    LidFit.swift                           # tolerance constants
    LiddedBinDesign.swift                  # derived values and helpers (lid_pos, pocket_size)
    LidLip.swift                           # lip profile, lip mask, tabs, grip masks
    BinBody.swift                          # base grid, pockets, bin solid
    LidBody.swift                          # lid
    Parts.swift                            # Part enum and part assembly
  Sources/lidded-bin/main.swift            # builds models to Models/
  Tests/LiddedBinModelTests/
  Reference/{generate.py, reference.json, stl/}
  README.md
.gitignore                                 # at Cadovafinity/
```

---

### Task 1: Corner-segment parity in the library

OpenSCAD makes a 90 degree `rotate_extrude` with `$fn * 90 / 360` segments, while Cadova's `revolved(in:)` uses the full segment count for any angle. The corners of the wall sweep therefore differ in tessellation (sagitta about 0.15 mm at 16 versus 64 segments for an 8 mm radius), which would swamp a symmetric-difference check on 0.1 mm fit features. Add an option that makes the corner revolves use a chosen segment count while everything else keeps the ambient segmentation.

**Files:**
- Modify: `GridfinityRebuilt/Sources/GridfinityRebuilt/BlockWall.swift`
- Modify: `GridfinityRebuilt/Sources/GridfinityRebuilt/BinGeometry.swift`
- Modify: `GridfinityRebuilt/Tests/GridfinityRebuiltTests/BlockTests.swift`, `BinGeometryTests.swift`

**Interfaces:**
- Consumes: existing `sweepRounded(width:height:profile:)`, `Dimensions.blockWall(gridX:gridY:length:profile:)`, `BinGeometry.shell(cutting:)`, `BinGeometry.wall(profileSegments:)`.
- Produces:
  - `public func sweepRounded(width:height:profile:cornerSegments: Int? = nil) -> any Geometry3D`
  - `Dimensions.blockWall(gridX:gridY:length:profile:cornerSegments: Int? = nil)`
  - `BinGeometry.shell(cutting:cornerSegments: Int? = nil)` and `BinGeometry.wall(cornerSegments: Int? = nil)`. The old `profileSegments` parameter is removed.
- With `cornerSegments == nil`, output is identical to today.

- [ ] **Step 1: Write the failing tests**

Add to `BlockTests.swift` (uses the existing helpers `measure`, `reference`, `expectMatches`):

```swift
@Test func `corner segments option reproduces OpenSCAD tessellation without test-level workarounds`() async throws {
    let wall = d.blockWall(
        gridX: 2, gridY: 1,
        profile: d.wallProfile(height: 16),
        cornerSegments: 16
    )
    // Ambient segmentation stays at 64 (measure applies it); only corners use 16.
    expectMatches(try await measure(wall), try reference("block_wall_2x1"), volumeTolerance: 1e-4)
}

@Test func `nil corner segments is unchanged`() async throws {
    let a = try await measure(d.blockWall(gridX: 2, gridY: 1, profile: d.wallProfile(height: 16)))
    let b = try await measure(d.blockWall(gridX: 2, gridY: 1, profile: d.wallProfile(height: 16), cornerSegments: nil))
    #expect(abs(a.volume - b.volume) < 1e-9)
}
```

Expected: the first test fails to compile (`cornerSegments` unknown).

- [ ] **Step 2: Run to verify failure**

Run (from `GridfinityRebuilt/`): `swift test --skip-update --filter BlockTests`
Expected: build error.

- [ ] **Step 3: Implement in `sweepRounded`**

The corner revolve must use `cornerSegments`, but the profile itself (fillet offsets) must keep the ambient segmentation, or the corners would get a different fillet than the straight sides. Read the ambient segmentation at the revolve site and pin it onto the profile before switching the environment for the revolve. Read `$CADOVA/Sources/Cadova/Abstract Layer/Environment/Values/Environment+Segmentation.swift` for the exact way to read the current segmentation inside a geometry (an `@Environment(\.segmentation)` property in a `Geometry3D` struct is the usual form) and for `withSegmentation(_:)` taking a `Segmentation` value.

Structure to implement:

```swift
public func sweepRounded(
    width w: Double, height h: Double,
    profile: any Geometry2D,
    cornerSegments: Int? = nil
) -> any Geometry3D {
    // ... existing sides unchanged ...
    // corners: if cornerSegments is set, build them through a small private
    // Geometry3D struct (CornerSweep) that reads the ambient segmentation,
    // applies it to `profile` via withSegmentation(ambient), then revolves under
    // withSegmentation(count: cornerSegments).
}
```

`corner(sx, sy, from:)` keeps its signature; only its body changes when `cornerSegments` is non-nil.

Thread `cornerSegments` through `blockWall`, `BinGeometry.wall(cornerSegments:)` (replacing `profileSegments`) and `BinGeometry.shell(cutting:cornerSegments:)`.

- [ ] **Step 4: Migrate the existing wall and shell tests**

In `BlockTests.swift` and `BinGeometryTests.swift`, replace each use of the `quarterTurnSegments` workaround (`.withSegmentation(count: quarterTurnSegments)` on the sweep with profile segmented separately) with `cornerSegments: 16`, delete `quarterTurnSegments` and `measureShell`'s duplicated segmentation logic, and keep every tolerance as it is. `measureShell` should become a plain `measure(bin.shell(cornerSegments: 16))` for the tight shell tests.

- [ ] **Step 5: Run the full suite**

Run: `swift test --skip-update`
Expected: all tests pass (25 existing plus the 2 new), tight tolerances unchanged at `1e-4`.

- [ ] **Step 6: Mutation check**

Temporarily change the `from: 90°` corner start to `from: 0°` in the `corner(-1, 1, ...)` call and confirm a wall test fails. Restore exactly and re-run the suite.

---

### Task 2: `patternLinear`

Port of `pattern_linear` (`$SRC/gridfinity-rebuilt-openscad/gridfinity-rebuilt-utility.scad`, the module near the end of the file). The lidded bin's grip masks and base grid use it.

**Files:**
- Create: `GridfinityRebuilt/Sources/GridfinityRebuilt/PatternLinear.swift`
- Modify: `GridfinityRebuilt/Reference/reference.scad`, `Reference/generate.py`
- Test: `GridfinityRebuilt/Tests/GridfinityRebuiltTests/PatternTests.swift`

**Interfaces:**
- Produces: `public func patternLinear(x: Int, y: Int, spacingX sx: Double, spacingY sy: Double? = nil, _ geometry: any Geometry3D) -> any Geometry3D`. Matches OpenSCAD: `yy = sy <= 0 ? sx : sy`; the grid is centered on the origin: `translate([-(x-1)*sx/2, -(y-1)*yy/2])`, cell `(i, j)` at `(i*sx, j*yy)`.

- [ ] **Step 1: Add a reference case**

In `reference.scad` add, before the `// CASES:` marker (an asymmetric cell so offset and centering errors show):

```openscad
else if (case == "pattern_linear") {
    pattern_linear(3, 2, 10, 7) translate([1, 2, 0]) cube([2, 3, 4]);
}
```

Add `"pattern_linear"` to `CASES` and run `python3 -I Reference/generate.py pattern_linear`.

- [ ] **Step 2: Write the failing test**

```swift
import Testing
import Cadova
@testable import GridfinityRebuilt

struct PatternTests {
    @Test func `patternLinear matches OpenSCAD`() async throws {
        let cell = Box([2, 3, 4]).translated(x: 1, y: 2)
        let actual = try await measure(patternLinear(x: 3, y: 2, spacingX: 10, spacingY: 7, cell))
        expectMatches(actual, try reference("pattern_linear"), volumeTolerance: 1e-9, boundsTolerance: 1e-6)
    }

    @Test func `spacingY defaults to spacingX`() async throws {
        let cell = Box([1, 1, 1])
        let a = try await measure(patternLinear(x: 2, y: 2, spacingX: 5, cell))
        let b = try await measure(patternLinear(x: 2, y: 2, spacingX: 5, spacingY: 5, cell))
        #expect(a.min.y == b.min.y && a.max.y == b.max.y)
    }
}
```

Run: `swift test --skip-update --filter PatternTests`. Expected: build error.

- [ ] **Step 3: Implement**

```swift
import Cadova

/// `pattern_linear`: a `x` by `y` grid of copies of `geometry`, centered on the origin.
///
/// Port of the OpenSCAD module of the same name. `spacingY` defaults to `spacingX`.
public func patternLinear(
    x: Int, y: Int,
    spacingX sx: Double,
    spacingY sy: Double? = nil,
    _ geometry: any Geometry3D
) -> any Geometry3D {
    let yy = (sy ?? sx) <= 0 ? sx : (sy ?? sx)
    return Union {
        for i in 0..<max(x, 0) {
            for j in 0..<max(y, 0) {
                geometry.translated(x: Double(i) * sx, y: Double(j) * yy)
            }
        }
    }
    .translated(x: -Double(x - 1) * sx / 2, y: -Double(y - 1) * yy / 2)
}
```

If Cadova's builder rejects `for` inside `Union { }`, build an array of translated copies and use the array-based union initializer found in `$CADOVA/Sources/Cadova/Abstract Layer/Operations/`.

- [ ] **Step 4: Run, expect PASS**

Run: `swift test --skip-update`
Expected: all pass.

---

### Task 3: `GridfinityTestSupport` product with symmetric-difference check

Move the harness out of the test target into a product both packages' tests use, and add the symmetric-difference comparison (volume of `(A minus B) plus (B minus A)` between the OpenSCAD STL and the Cadova geometry).

**Files:**
- Modify: `GridfinityRebuilt/Package.swift`
- Create: `GridfinityRebuilt/Sources/GridfinityTestSupport/{Metrics,ReferenceSet,SymmetricDifference,Expect}.swift`
- Delete: `GridfinityRebuilt/Tests/GridfinityRebuiltTests/Measure.swift`
- Modify: `GridfinityRebuilt/Reference/generate.py`; all existing tests (imports and call sites)
- Create: `/Users/shinohara/Downloads/3D Printing/Gridfinity/Cadovafinity/.gitignore`
- Test: `GridfinityRebuilt/Tests/GridfinityRebuiltTests/SymmetricDifferenceTests.swift`

**Interfaces:**
- Produces (all `public`):
  - `struct Metrics { var volume: Double; var min: Vector3D; var max: Vector3D }`
  - `func measure(_ geometry: any Geometry3D, segments: Int = 64) async throws -> Metrics`
  - `struct ReferenceSet { init(packageDirectory: URL); static func containing(file: StaticString = #filePath) -> ReferenceSet; func metrics(_ name: String) throws -> Metrics; func stlURL(_ name: String) -> URL }`. `containing(file:)` walks up from the caller's file to the directory holding `Package.swift` and uses its `Reference/` folder (`reference.json`, `stl/`).
  - `func compare(_ actual: Metrics, _ expected: Metrics, volumeTolerance: Double, boundsTolerance: Double) -> [String]` (empty means match)
  - `func symmetricDifferenceVolume(_ geometry: any Geometry3D, against stl: URL, segments: Int = 64) async throws -> Double`
  - `let defaultSymmetricDifferenceTolerance: Double` (mm cubed, set in Step 7)
  - `func expectMatchesReference(_ name: String, _ geometry: any Geometry3D, references: ReferenceSet = .containing(), volumeTolerance: Double = 1e-4, boundsTolerance: Double = 0.05, symmetricDifferenceTolerance: Double? = defaultSymmetricDifferenceTolerance, segments: Int = 64, sourceLocation: SourceLocation = #_sourceLocation) async throws`
- Consumes: Cadova `Import(model:)` (STL import), `ModelFileGenerator.evaluate`.

- [ ] **Step 1: Write the manifest changes**

In `GridfinityRebuilt/Package.swift`, add a product and a target, and make the test target depend on it:

```swift
.library(name: "GridfinityTestSupport", targets: ["GridfinityTestSupport"]),
...
.target(
    name: "GridfinityTestSupport",
    dependencies: ["Cadova"],
    swiftSettings: [.interoperabilityMode(.Cxx)]
),
.testTarget(
    name: "GridfinityRebuiltTests",
    dependencies: ["GridfinityRebuilt", "GridfinityTestSupport", "Cadova"],
    swiftSettings: [.interoperabilityMode(.Cxx)]
),
```

Also create `Cadovafinity/.gitignore`:

```
.build/
.superpowers/
.DS_Store
**/Reference/stl/
```

- [ ] **Step 2: Make `generate.py` save the STLs**

In `GridfinityRebuilt/Reference/generate.py`, `run_case` currently exports to a temp directory. Export to `Reference/stl/<case>.stl` (create the directory), keep parsing metrics from that file, and keep the failure handling. Run `python3 -I Reference/generate.py` (all cases) and confirm `Reference/stl/` has one file per case and `reference.json` numbers are unchanged (diff against a copy taken before).

- [ ] **Step 3: Write the failing symmetric-difference test**

`Tests/GridfinityRebuiltTests/SymmetricDifferenceTests.swift`:

```swift
import Testing
import Cadova
import GridfinityTestSupport
@testable import GridfinityRebuilt

struct SymmetricDifferenceTests {
    let refs = ReferenceSet.containing()

    @Test func `identical geometry has near-zero symmetric difference`() async throws {
        let d = Dimensions.standard
        let v = try await symmetricDifferenceVolume(d.blockBaseSolid(), against: refs.stlURL("block_base_solid"))
        #expect(v < 0.01, "symmetric difference \(v) mm^3")
    }

    @Test func `a 0_2 mm change is detected`() async throws {
        var d = Dimensions.standard
        d.rFo1 += 0.2   // grows the base's outer corner radius
        let v = try await symmetricDifferenceVolume(d.blockBaseSolid(), against: refs.stlURL("block_base_solid"))
        #expect(v > 0.5, "expected a visible difference, got \(v) mm^3")
    }
}
```

Run: `swift test --skip-update --filter SymmetricDifferenceTests`. Expected: build error (`GridfinityTestSupport` has no sources yet).

- [ ] **Step 4: Implement the support target**

`Metrics.swift` (moved from the old `Measure.swift`, made public):

```swift
import Foundation
import Cadova

public struct Metrics: Sendable {
    public var volume: Double
    public var min: Vector3D
    public var max: Vector3D
    public init(volume: Double, min: Vector3D, max: Vector3D) {
        self.volume = volume; self.min = min; self.max = max
    }
}

public func measure(_ geometry: any Geometry3D, segments: Int = 64) async throws -> Metrics {
    let g = geometry.withSegmentation(count: segments)
    return try await ModelFileGenerator.evaluate { evaluator in
        let bounds = await evaluator.bounds(of: g)
        let volume = await evaluator.measurements(of: g).volume
        return Metrics(volume: volume, min: bounds?.minimum ?? .zero, max: bounds?.maximum ?? .zero)
    }
}

public func compare(
    _ actual: Metrics, _ expected: Metrics,
    volumeTolerance: Double, boundsTolerance: Double
) -> [String] {
    var problems: [String] = []
    let relative = abs(actual.volume - expected.volume) / Swift.max(expected.volume, 1e-9)
    if relative > volumeTolerance {
        problems.append("volume \(actual.volume) vs reference \(expected.volume) (relative \(relative), allowed \(volumeTolerance))")
    }
    let pairs: [(String, Double, Double)] = [
        ("min.x", actual.min.x, expected.min.x), ("min.y", actual.min.y, expected.min.y),
        ("min.z", actual.min.z, expected.min.z), ("max.x", actual.max.x, expected.max.x),
        ("max.y", actual.max.y, expected.max.y), ("max.z", actual.max.z, expected.max.z),
    ]
    for (label, a, e) in pairs where abs(a - e) > boundsTolerance {
        problems.append("\(label) \(a) vs reference \(e) (allowed \(boundsTolerance))")
    }
    return problems
}
```

`ReferenceSet.swift`: reads `<package>/Reference/reference.json` (`{"name": {"volume", "min": [3], "max": [3]}}`, throwing a clear `ReferenceError` for a missing case or malformed arrays, as the old `reference()` did) and exposes `stlURL(_:)` as `<package>/Reference/stl/<name>.stl`. `containing(file:)` walks up directories from `URL(fileURLWithPath: "\(file)")` until it finds `Package.swift`.

`SymmetricDifference.swift`:

```swift
import Foundation
import Cadova

public func symmetricDifferenceVolume(
    _ geometry: any Geometry3D, against stl: URL, segments: Int = 64
) async throws -> Double {
    guard FileManager.default.fileExists(atPath: stl.path) else {
        throw ReferenceError.missingSTL(stl.path)   // message: run Reference/generate.py
    }
    let mine = geometry.withSegmentation(count: segments)
    let theirs = Import(model: stl)
    let difference = Union {
        mine.subtracting { theirs }
        theirs.subtracting { mine }
    }
    return try await ModelFileGenerator.evaluate { evaluator in
        await evaluator.measurements(of: difference).volume
    }
}
```

Verify the exact `Import(model:)` signature in `$CADOVA/Sources/Cadova/Abstract Layer/Import/3D/` and adjust. Imported geometry must be manifold; OpenSCAD's Manifold export is.

`Expect.swift` first tries `import Testing` in this regular target:

```swift
import Testing
import Cadova

public func expectMatchesReference(
    _ name: String, _ geometry: any Geometry3D,
    references: ReferenceSet = .containing(),
    volumeTolerance: Double = 1e-4, boundsTolerance: Double = 0.05,
    symmetricDifferenceTolerance: Double? = defaultSymmetricDifferenceTolerance,
    segments: Int = 64,
    sourceLocation: SourceLocation = #_sourceLocation
) async throws {
    let actual = try await measure(geometry, segments: segments)
    let expected = try references.metrics(name)
    for problem in compare(actual, expected, volumeTolerance: volumeTolerance, boundsTolerance: boundsTolerance) {
        Issue.record(Comment(rawValue: "\(name): \(problem)"), sourceLocation: sourceLocation)
    }
    if let limit = symmetricDifferenceTolerance {
        let v = try await symmetricDifferenceVolume(geometry, against: references.stlURL(name), segments: segments)
        #expect(v <= limit, "\(name): symmetric difference \(v) mm^3 exceeds \(limit)", sourceLocation: sourceLocation)
    }
}
```

Fallback if SwiftPM or the linker refuses `import Testing` in a non-test target (a link error about missing `Testing` symbols or rpath): drop `Expect.swift` from the target and give each test target a 10-line `expectMatchesReference` wrapper that calls `compare`, `symmetricDifferenceVolume` and `#expect`. Record which route was taken in the report.

`ReferenceSet.containing()` defaults its `file` from the caller only when used as a default argument in the caller's file; if the default argument captures this file instead of the test's, make `references` a required argument in tests (`ReferenceSet.containing()` evaluated in the test file) and say so in the report.

- [ ] **Step 5: Migrate existing tests**

Replace the old `Measure.swift` helpers across `Tests/GridfinityRebuiltTests/*.swift`: add `import GridfinityTestSupport`, delete `Measure.swift`, replace `reference("x")` with `ReferenceSet.containing().metrics("x")` (or a `let refs`), and `expectMatches(a, b, ...)` with a local call to `compare` plus `#expect(problems.isEmpty)`, OR convert the geometry tests to `expectMatchesReference` where the case name is the same. Keep every existing tolerance. Do not enable the symmetric-difference check on migrated tests yet; use `symmetricDifferenceTolerance: nil` there.

- [ ] **Step 6: Run the suite**

Run: `swift test --skip-update`
Expected: all previous tests pass plus the two symmetric-difference tests. If `a 0_2 mm change is detected` fails because the change is too small to reach 0.5 mm cubed, raise `rFo1` delta (`+0.5`) and note the measured value in the report; the point is to prove sensitivity.

- [ ] **Step 7: Calibrate `defaultSymmetricDifferenceTolerance`**

For these already-referenced cases, measure the symmetric difference with the Cadova geometry built exactly as the existing tests build it (use `cornerSegments: 16` for wall and shell cases): `block_base_solid`, `block_base_solid_offset`, `block_wall_2x1`, `block_bottom_2x1`, `init_2x1x3`, `init_2x1x3_lipless`, `init_2x1x3_dw16`. Write a throwaway test that prints the seven values (do not leave it in). Set `defaultSymmetricDifferenceTolerance` to the larger of `0.5` and five times the largest observed value, with a doc comment stating the measured values and the date. Then enable `symmetricDifferenceTolerance: defaultSymmetricDifferenceTolerance` (the default) on those seven tests so each also checks the mesh. Re-run the suite.

- [ ] **Step 8: Mutation check on the mesh comparison**

Mutate `rFo3 / 2` to `rFo3` in `blockBaseSolid` (the constant the volume and bounds checks could not see). Report whether the symmetric-difference check now fails `block_base_solid`. Restore exactly. (If it still survives, say so: it means the effect is below the tolerance, which belongs in the report.)

---

### Task 4: LiddedBin package, configuration, derived values and reference harness

**Files:**
- Create: `LiddedBin/Package.swift`
- Create: `LiddedBin/Sources/LiddedBinModel/{LiddedBinConfiguration,LidFit,LiddedBinDesign}.swift`
- Create: `LiddedBin/Sources/lidded-bin/main.swift` (minimal stub that builds; replaced in Task 8)
- Create: `LiddedBin/Reference/generate.py`, `LiddedBin/Reference/reference.json`
- Test: `LiddedBin/Tests/LiddedBinModelTests/DesignTests.swift`

**Interfaces:**
- Produces:
  - `public enum InteriorStyle { case minimal, partialRaised }`, `LipGrips { case none, x, y, xy }`, `LidOrientation { case up, down, left, right }`, `CompartmentPattern { case grid, multiSize }`, `LiddedBinPart { case bin, lid, bothClosed, bothOpen, binSlice }`. All `String` raw values, `Sendable`, `CaseIterable`.
  - `public struct LiddedBinConfiguration: Sendable` with defaults taken from `lid-bin.scad`: `gridX = 2`, `gridY = 2` (Int), `gridZ = 3.0`, `heightMode: HeightMode = .units`, `snapHeight = false`, `internalHeightOverride = 0.0`, `interiorStyle = .minimal`, `lipGrips = .xy`, `lidOrientation = .left`, `compartmentPattern = .grid`, `divX = 6`, `divY = 6` (Int), `divMultiple = 2.0`, `cornerSegments: Int? = nil` (parity setting, nil in production), `public init()`.
  - `struct LidFit` with `wallThickness = 1.2`, `thickness = 0.9`, `hFitTolerance = 1.1`, `vFitTolerance = 0.1`, `vPosTolerance = 0.2`, `lipFitTolerance` (`min(0.1, vFitTolerance)`), `separatorWallThickness = 1.2`, `interiorBaseWallAdjust = 0.4`.
  - `public struct LiddedBinDesign: Sendable { public init(_ configuration: LiddedBinConfiguration); let configuration; let d: Dimensions (dWall = 1.6); let fit: LidFit; var gridX, gridY: Double; var storageHeight: Double; var innerHeight: Double; var bin: BinGeometry; var lidDirection: Vector2D; func lidPosition(adjust: Double = 0) -> Vector2D; func pocketSize(xUnits: Double, yUnits: Double) -> Vector2D }`.
- Consumes: `GridfinityRebuilt` (`Dimensions`, `BinGeometry`, `HeightMode`, ...), `GridfinityTestSupport`.

- [ ] **Step 1: Manifest**

```swift
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "LiddedBin",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LiddedBinModel", targets: ["LiddedBinModel"]),
        .executable(name: "lidded-bin", targets: ["lidded-bin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tomasf/Cadova.git", from: "1.3.0"),
        .package(path: "../GridfinityRebuilt"),
    ],
    targets: [
        .target(
            name: "LiddedBinModel",
            dependencies: [
                "Cadova",
                .product(name: "GridfinityRebuilt", package: "GridfinityRebuilt"),
            ],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .executableTarget(
            name: "lidded-bin",
            dependencies: ["LiddedBinModel", "Cadova"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .testTarget(
            name: "LiddedBinModelTests",
            dependencies: [
                "LiddedBinModel", "Cadova",
                .product(name: "GridfinityRebuilt", package: "GridfinityRebuilt"),
                .product(name: "GridfinityTestSupport", package: "GridfinityRebuilt"),
            ],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ]
)
```

Stub `Sources/lidded-bin/main.swift`:

```swift
import Cadova
import LiddedBinModel

await Project {
    await Model("placeholder") { Box(1) }
}
```

- [ ] **Step 2: Reference generator**

`LiddedBin/Reference/generate.py` runs `lid-bin.scad` itself (it calls `main()` at include time, so it cannot be wrapped) with `-D` overrides. Base it on `GridfinityRebuilt/Reference/generate.py` (same STL parsing, same failure reporting, same `FN = 64`, STL kept in `Reference/stl/<case>.stl`, metrics in `reference.json`), with these differences: the SCAD path is `$SRC/lid-bin.scad` (from `LiddedBin/Reference/` that is `../../../Lidded Bins/lid-bin.scad`), and cases are a dict from case name to a list of `NAME=VALUE` defines, each passed as `-D NAME=VALUE` (strings quoted: `Part="bin"`). Start with:

```python
CASES = {
    "bin_2x2x3_nogrips": ['Part="bin"', 'Lip_Grips="none"'],
    "lid_2x2x3_nogrips": ['Part="lid"', 'Lip_Grips="none"'],
}
```

(Later tasks add cases.) Run `python3 -I Reference/generate.py bin_2x2x3_nogrips` once to confirm OpenSCAD produces an STL; record the time it takes.

- [ ] **Step 3: Write the failing design tests**

`Tests/LiddedBinModelTests/DesignTests.swift`. Expected numbers are derived from `lid-bin.scad` by hand: with `d_wall = 1.6`, `d_magic = -2*0.25 - 2*1.6 + 1.2 = -2.5`; default storage height `height(3) = 21 - 5 = 16`; inner height `16 + 5 - 1.6 = 19.4`; `lid_pos(0)` for `left` on a 2x2 is `(-84, 0)`; `pocket_size(1/3, 1/3)` for 2x2 is `(1/3) * (2*42 - 2.5) / 2 - 1.2 = 12.38333...` in both axes.

```swift
import Testing
import Cadova
import GridfinityRebuilt
@testable import LiddedBinModel

struct DesignTests {
    @Test func `derived heights for the default configuration`() {
        let design = LiddedBinDesign(LiddedBinConfiguration())
        #expect(abs(design.storageHeight - 16) < 1e-9)
        #expect(abs(design.innerHeight - 19.4) < 1e-9)
    }

    @Test func `wall thickness is 1_6`() {
        let design = LiddedBinDesign(LiddedBinConfiguration())
        #expect(design.d.dWall == 1.6)
        #expect(abs(design.d.dMagic - -2.5) < 1e-12)
    }

    @Test func `lid position follows orientation`() {
        var c = LiddedBinConfiguration()
        c.lidOrientation = .left
        #expect(LiddedBinDesign(c).lidPosition() == Vector2D(-84, 0))
        c.lidOrientation = .up
        #expect(LiddedBinDesign(c).lidPosition() == Vector2D(0, 84))
        c.lidOrientation = .right
        #expect(LiddedBinDesign(c).lidPosition(adjust: 10) == Vector2D(94, 0))
        c.lidOrientation = .down
        #expect(LiddedBinDesign(c).lidPosition(adjust: -7.096) == Vector2D(0, -(84 - 7.096)))
    }

    @Test func `pocket size`() {
        let size = LiddedBinDesign(LiddedBinConfiguration()).pocketSize(xUnits: 1.0 / 3, yUnits: 1.0 / 3)
        #expect(abs(size.x - 12.383333333) < 1e-6)
        #expect(abs(size.y - 12.383333333) < 1e-6)
    }

    @Test func `height modes map to the library`() {
        var c = LiddedBinConfiguration()
        c.heightMode = .internalMillimeters
        c.gridZ = 20
        c.snapHeight = true
        #expect(abs(LiddedBinDesign(c).storageHeight - 23) < 1e-9)   // same as height(20,1,0,true) in standard.scad
    }
}
```

Run: `swift test --skip-update` in `LiddedBin/`. Expected: build error (types not found).

- [ ] **Step 4: Implement**

`LiddedBinConfiguration.swift`: the enums and the struct exactly as in Interfaces, each property with a `///` comment quoting the `lid-bin.scad` parameter name (e.g. `/// gridx`).

`LidFit.swift`:

```swift
/// The lid fit constants from lid-bin.scad.
struct LidFit: Sendable {
    var wallThickness = 1.2          // lid_wall_thickness
    var thickness = 0.9              // lid_thickness
    var hFitTolerance = 1.1          // lid_hfit_tolerance
    var vFitTolerance = 0.1          // lid_vfit_tolerance
    var vPosTolerance = 0.2          // lid_vpos_tolerance
    var lipFitTolerance: Double { min(0.1, vFitTolerance) }   // lid_lip_fit_tolerance
    var separatorWallThickness = 1.2 // bin_separator_wall_thickness
    var interiorBaseWallAdjust = 0.4 // interior_base_wall_adjust
}
```

`LiddedBinDesign.swift`:

```swift
import Cadova
import GridfinityRebuilt

public struct LiddedBinDesign: Sendable {
    public let configuration: LiddedBinConfiguration
    let d: Dimensions
    let fit = LidFit()

    public init(_ configuration: LiddedBinConfiguration) {
        self.configuration = configuration
        var d = Dimensions.standard
        d.dWall = 1.6              // d_wall in lid-bin.scad
        self.d = d
    }

    var gridX: Double { Double(configuration.gridX) }
    var gridY: Double { Double(configuration.gridY) }

    /// bin_storage_height
    var storageHeight: Double {
        d.binHeight(configuration.gridZ, mode: configuration.heightMode, lip: .regular, snap: configuration.snapHeight)
    }
    /// bin_inner_height
    var innerHeight: Double { storageHeight + d.hBase - d.dWall }

    var bin: BinGeometry {
        BinGeometry(gridX: gridX, gridY: gridY, height: storageHeight,
                    internalHeight: configuration.internalHeightOverride,
                    lipStyle: .regular, dimensions: d)
    }

    /// lid_pos_multiple
    var lidDirection: Vector2D {
        switch configuration.lidOrientation {
        case .right: Vector2D(1, 0)
        case .left: Vector2D(-1, 0)
        case .up: Vector2D(0, 1)
        case .down: Vector2D(0, -1)
        }
    }

    /// lid_pos
    func lidPosition(adjust: Double = 0) -> Vector2D {
        let m = lidDirection
        return Vector2D(m.x * (d.lGrid * gridX + adjust), m.y * (d.lGrid * gridY + adjust))
    }

    /// pocket_size
    func pocketSize(xUnits: Double, yUnits: Double) -> Vector2D {
        Vector2D(
            xUnits * (gridX * d.lGrid + d.dMagic) / gridX - fit.separatorWallThickness,
            yUnits * (gridY * d.lGrid + d.dMagic) / gridY - fit.separatorWallThickness
        )
    }
}
```

`Vector2D(_:_:)` and `==` may need adjusting to Cadova's actual initializers; check its source.

- [ ] **Step 5: Run, expect PASS**

Run (from `LiddedBin/`): `swift test --skip-update`
Expected: 5 tests pass. First run resolves the path dependency; if resolution needs network and fails, report BLOCKED with the exact error.

---

### Task 5: Bin body (lip wall, tabs, grips, base grid, pockets)

**Files:**
- Create: `LiddedBin/Sources/LiddedBinModel/LidLip.swift`
- Create: `LiddedBin/Sources/LiddedBinModel/BinBody.swift`
- Modify: `LiddedBin/Reference/generate.py`, `Reference/reference.json`
- Test: `LiddedBin/Tests/LiddedBinModelTests/BinBodyTests.swift`

**Interfaces:**
- Consumes: `LiddedBinDesign`, `Dimensions` (`wallProfile`, `blockWall`, `blockBottom`, `blockBaseSolid`, `roundedRectangle`), `BinGeometry.placed`, `patternLinear`, `cornerSegments`.
- Produces on `LiddedBinDesign` (all internal):
  - `lidLipWallProfile(lid: Bool) -> any Geometry2D` (`gf_profile_wall_lid_lip`)
  - `lidLipMask() -> any Geometry3D` (`gf_bin_lid_lip_mask`)
  - `roundedRect(height:addSize:radius:) -> any Geometry3D` (`gf_bin_rounded_rect`)
  - `lidTabs(adjust: Bool = false) -> any Geometry3D` (`gf_bin_lid_tabs`)
  - `lipGripMasks() -> (any Geometry3D)?` (`gf_bin_lid_grip_masks`; nil when grips are `.none`)
  - `baseGrid(sizeOffset: Double = 0)`, `baseGridInterior()` (`gf_base_grid`, `gf_base_grid_interior`)
  - `pocket(x:y:w:h:) -> any Geometry3D` (`gf_cut_pocket`) and `pockets() -> (any Geometry3D)?` (`gf_cut_pockets`; nil when the pattern produces no pockets)
  - `binSolid(pockets: (any Geometry3D)?) -> any Geometry3D` (`gf_bin_solid`)

Faithful behaviors to preserve (they look odd but are what OpenSCAD does):
- In `gf_bin_solid`, the pocket cut is `intersection() { rounded_rect; children(); }`. With NO children (`pockets == nil`, which is `gf_bin(pockets=false)` or a default pattern with `divx` or `divy` of zero), the intersection has a single operand, so nothing is cut (an empty intersection is empty) and the bin stays solid. Port that: `nil` means subtract the rounded rect alone.
- In `gf_base_grid`, the `intersection` with the big square sits INSIDE `pattern_linear`, so the square moves with each cell.
- In `gf_bin_solid`'s last piece, `intersection() { if (partial_raised) {slab}; gf_base_grid_interior(); }` is the slab intersected with the interior when `partial_raised`, and just the interior otherwise.

- [ ] **Step 1: Add reference cases**

In `LiddedBin/Reference/generate.py` extend `CASES` (all `Part="bin"`):

```python
"bin_2x2x3_nogrips":      ['Part="bin"', 'Lip_Grips="none"'],
"bin_2x2x3_xy":           ['Part="bin"'],                                  # defaults: grips xy, lid left, 6x6
"bin_1x1x2_nogrips_div2": ['Part="bin"', 'Lip_Grips="none"', 'gridx=1', 'gridy=1', 'gridz=2', 'divx=2', 'divy=1'],
"bin_1x1x2_nogrips_div0": ['Part="bin"', 'Lip_Grips="none"', 'gridx=1', 'gridy=1', 'gridz=2', 'divx=0', 'divy=0'],
"bin_3x2x3_grips_x":      ['Part="bin"', 'Lip_Grips="x"', 'gridx=3', 'gridy=2', 'divx=3', 'divy=2'],
"bin_2x2x3_partial_raised": ['Part="bin"', 'Lip_Grips="none"', 'Interior_Style="partial_raised"', 'divx=2', 'divy=2'],
```

Run `python3 -I Reference/generate.py` and record each case's time. Confirm in the report that `bin_1x1x2_nogrips_div0` is the SOLID bin (its volume is much larger than `bin_1x1x2_nogrips_div2`).

- [ ] **Step 2: Write the failing tests**

`BinBodyTests.swift`. Each test builds a configuration equal to the case's defines and calls `expectMatchesReference` (defaults: volume 1e-4, bounds 0.05, symmetric difference default). Set `cornerSegments = 16` in every configuration (OpenSCAD tessellation parity).

```swift
import Testing
import Cadova
import GridfinityRebuilt
import GridfinityTestSupport
@testable import LiddedBinModel

struct BinBodyTests {
    let refs = ReferenceSet.containing()

    func config(_ edit: (inout LiddedBinConfiguration) -> Void = { _ in }) -> LiddedBinDesign {
        var c = LiddedBinConfiguration()
        c.cornerSegments = 16
        edit(&c)
        return LiddedBinDesign(c)
    }

    @Test func `2x2x3 bin without grips`() async throws {
        let design = config { $0.lipGrips = .none }
        try await expectMatchesReference("bin_2x2x3_nogrips", design.binSolid(pockets: design.pockets()), references: refs)
    }

    @Test func `2x2x3 bin with default grips`() async throws {
        let design = config()
        try await expectMatchesReference("bin_2x2x3_xy", design.binSolid(pockets: design.pockets()), references: refs)
    }

    @Test func `1x1x2 bin with two compartments`() async throws {
        let design = config { $0.lipGrips = .none; $0.gridX = 1; $0.gridY = 1; $0.gridZ = 2; $0.divX = 2; $0.divY = 1 }
        try await expectMatchesReference("bin_1x1x2_nogrips_div2", design.binSolid(pockets: design.pockets()), references: refs)
    }

    @Test func `zero divisions leave the bin solid like OpenSCAD`() async throws {
        let design = config { $0.lipGrips = .none; $0.gridX = 1; $0.gridY = 1; $0.gridZ = 2; $0.divX = 0; $0.divY = 0 }
        #expect(design.pockets() == nil)
        try await expectMatchesReference("bin_1x1x2_nogrips_div0", design.binSolid(pockets: nil), references: refs)
    }

    @Test func `3x2x3 bin with X grips`() async throws {
        let design = config { $0.lipGrips = .x; $0.gridX = 3; $0.gridY = 2; $0.divX = 3; $0.divY = 2 }
        try await expectMatchesReference("bin_3x2x3_grips_x", design.binSolid(pockets: design.pockets()), references: refs)
    }

    @Test func `partially raised interior`() async throws {
        let design = config { $0.lipGrips = .none; $0.interiorStyle = .partialRaised; $0.divX = 2; $0.divY = 2 }
        try await expectMatchesReference("bin_2x2x3_partial_raised", design.binSolid(pockets: design.pockets()), references: refs)
    }
}
```

`pockets() == nil` needs the optional's `Geometry3D` existential to compare; write it as `#expect(design.pockets() == nil)` only if it compiles, else `#expect(design.pockets().map { _ in true } == nil)`.

Run: expected build error.

- [ ] **Step 3: Implement `LidLip.swift`**

Port from `$SRC/lid-bin.scad` lines 158-227 (lip profile, lip mask, grip masks) and 279-316 (tabs). Every OpenSCAD `$dh` is `storageHeight`. Code to write (verify each line against the `.scad`):

```swift
import Cadova
import GridfinityRebuilt

extension LiddedBinDesign {
    /// gf_profile_wall_lid_lip
    func lidLipWallProfile(lid: Bool) -> any Geometry2D {
        let dh = storageHeight
        return d.wallProfile(height: dh)
            .subtracting {
                Polygon([
                    [0, 0],
                    [0, fit.thickness + fit.vFitTolerance],
                    [d.dWall2, fit.thickness + fit.vFitTolerance + d.dWall2],
                    [d.dWall2, 0],
                ])
                .translated(
                    x: lid ? fit.hFitTolerance : fit.wallThickness,
                    y: dh - fit.thickness - fit.vFitTolerance - fit.vPosTolerance
                )
                .flipped(along: .x)
                .translated(x: d.rBase)
            }
    }

    /// gf_bin_lid_lip_mask
    func lidLipMask() -> any Geometry3D {
        let p = lidPosition(adjust: -(d.rBase + 0.5))
        return Rectangle([d.lGrid * gridX, d.lGrid * gridY])
            .aligned(at: .center)
            .extruded(height: d.hLip * 10)
            .translated(x: p.x, y: p.y, z: storageHeight + d.hBase - fit.thickness - fit.vPosTolerance)
    }

    /// gf_bin_rounded_rect: third argument is the radius, default r_fo1.
    func roundedRect(height: Double, addSize: Double = 0, radius: Double? = nil) -> any Geometry3D {
        roundedRectangle(
            length: gridX * d.lGrid + addSize + 0.005,
            width: gridY * d.lGrid + addSize + 0.005,
            height: height,
            radius: (radius ?? d.rFo1) / 2 + 0.001
        )
    }

    /// gf_bin_lid_grip_mask_shape (2D)
    private func gripShape() -> any Geometry2D {
        let gripW = d.lGrid / 2 - d.hLip * 2 - 2
        let radius = 3.0
        return Union {
            Rectangle([gripW, d.hLip * 10])
            Rectangle([gripW * 5, d.hLip * 9]).translated(x: -gripW * 2, y: d.hLip * 0.75)
        }
        .offset(amount: -radius, style: .round)
        .offset(amount: 2 * radius, style: .round)
        .offset(amount: -radius, style: .round)
        .intersecting {
            Rectangle([gripW + radius * 2, d.hLip]).translated(x: -radius)
        }
        .translated(x: -(gripW - d.lGrid / 2) / 2)
    }

    /// gf_bin_lid_grip_mask_set(num_grid): rotate([90,0,90]) translate([0,0,l*n/2]) linear_extrude(l/2, center=true)
    private func gripSet(numGrid: Int) -> any Geometry3D {
        gripShape()
            .extruded(height: d.lGrid / 2)
            .translated(z: -d.lGrid / 4)
            .translated(z: d.lGrid * Double(numGrid) / 2)
            .rotated(x: 90°, y: 0°, z: 90°)
    }

    /// gf_bin_lid_grip_mask
    private func gripMask() -> any Geometry3D {
        let gx = configuration.gridX, gy = configuration.gridY
        let grips = configuration.lipGrips
        return Union {
            if grips == .x || grips == .xy {
                patternLinear(x: 1, y: gy, spacingX: d.lGrid * gridX, spacingY: d.lGrid, gripSet(numGrid: gx))
            }
            if grips == .y || grips == .xy {
                patternLinear(x: gx, y: 1, spacingX: d.lGrid, spacingY: d.lGrid * gridY, gripSet(numGrid: gy).rotated(z: 90°))
            }
        }
        .translated(z: storageHeight + d.hBase + d.hLip * 0.25)
    }

    /// gf_bin_lid_grip_masks: both the mask and the mask rotated 180 degrees.
    func lipGripMasks() -> (any Geometry3D)? {
        guard configuration.lipGrips != .none else { return nil }
        return Union {
            gripMask()
            gripMask().rotated(z: 180°)
        }
    }

    /// gf_bin_lid_tabs
    func lidTabs(adjust: Bool = false) -> any Geometry3D {
        let adj = adjust ? -fit.hFitTolerance * 1.5 + fit.wallThickness : 0
        let cr = 0.6
        let m = lidDirection
        let tabPosX = m.x * (-(d.lGrid * gridX - 0.5) / 2 + d.rBase + cr)
        let tabPosY = m.y * (-(d.lGrid * gridY - 0.5) / 2 + d.rBase + cr)
        let sepX = abs(m.y) * (gridX * d.lGrid / 2 - 0.5 / 2 - fit.wallThickness + adj)
        let sepY = abs(m.x) * (gridY * d.lGrid / 2 - 0.5 / 2 - fit.wallThickness + adj)

        let profile = Union {
            Circle(radius: cr)
            Rectangle(cr * 8).aligned(at: .center).translated(y: cr * 4)
        }
        .offset(amount: cr * 0.5, style: .round)
        .offset(amount: -(cr * 0.5), style: .round)
        .intersecting {
            Rectangle([cr * 3, cr * 2]).aligned(at: .center)
        }

        let tab = profile
            .extruded(height: fit.lipFitTolerance * 2 + fit.thickness + 2)
            .rotated(z: m.x != 0 ? 0° : 270°)
            .translated(x: sepX, y: sepY, z: -fit.vFitTolerance - fit.vPosTolerance)

        return Union {
            tab
            tab.flipped(along: m.x != 0 ? .y : .x)
        }
        .translated(
            x: tabPosX, y: tabPosY,
            z: storageHeight + d.hBase - fit.thickness - fit.lipFitTolerance / 2 - 0.001
        )
    }
}
```

Notes: `rotate([90,0,90])` applies X then Y then Z; confirm `.rotated(x:y:z:)` in Cadova uses the same order (read `$CADOVA/Sources/Cadova/Abstract Layer/Transformable/`). The `mirror([0, ml])` with `ml = 0` is a no-op in OpenSCAD, so the loop is "the tab, and the tab mirrored". `Rectangle(cr * 8)` is an 8 cr square: use the square initializer (a single `Double` for both axes) if Cadova has one, else `Rectangle([cr*8, cr*8])`.

- [ ] **Step 4: Implement `BinBody.swift`**

Port from `$SRC/lid-bin.scad` lines 318-444.

```swift
import Cadova
import GridfinityRebuilt

extension LiddedBinDesign {
    /// gf_base_grid_interior
    func baseGridInterior() -> any Geometry3D {
        baseGrid(sizeOffset: -d.dWall - fit.interiorBaseWallAdjust)
            .translated(z: d.dWall)
    }

    /// gf_base_grid. The clipping box moves with each cell, as in OpenSCAD.
    func baseGrid(sizeOffset: Double = 0) -> any Geometry3D {
        patternLinear(
            x: configuration.gridX, y: configuration.gridY,
            spacingX: d.lGrid, spacingY: d.lGrid,
            d.blockBaseSolid(nx: 1, ny: 1, length: d.lGrid, offset: sizeOffset)
                .intersecting {
                    Rectangle([gridX * d.lGrid, gridY * d.lGrid])
                        .aligned(at: .center)
                        .extruded(height: d.hBase + d.hBot / 2)
                }
        )
    }

    /// gf_cut_pocket_interior
    private func pocketInterior(_ size: Vector2D) -> any Geometry3D {
        Rectangle(size)
            .aligned(at: .center)
            .extruded(height: innerHeight - fit.thickness - fit.vFitTolerance - fit.vPosTolerance + 0.001)
            .translated(z: -storageHeight - d.hBase + d.dWall)
    }

    /// gf_cut_pocket
    func pocket(x: Double, y: Double, w: Double, h: Double) -> any Geometry3D {
        bin.placed(x: x, y: y, w: w, h: h, pocketInterior(pocketSize(xUnits: w, yUnits: h)))
    }

    /// gf_cut_pockets (the custom pattern is not supported). nil when no pockets are produced.
    func pockets() -> (any Geometry3D)? {
        let c = configuration
        switch c.compartmentPattern {
        case .grid:
            guard c.divX > 0, c.divY > 0 else { return nil }
            let divX = Double(c.divX), divY = Double(c.divY)
            return Union {
                for x in 1...c.divX {
                    for y in 1...c.divY {
                        pocket(x: Double(x - 1) * gridX / divX, y: Double(y - 1) * gridY / divY,
                               w: gridX / divX, h: gridY / divY)
                    }
                }
            }
        case .multiSize:
            guard c.divX > 0, c.divY > 0 else { return nil }
            let divX = Double(c.divX), divY = Double(c.divY)
            let w = gridX / divX, h = gridY / divY
            let offDivX = (divX / 2).rounded(.up)
            let remGridX = w * (divX - offDivX)
            let offGridX = gridX - remGridX
            let remDivX = max(1, (remGridX / (w * c.divMultiple)).rounded(.down))
            let remDivY = max(1, (divY / c.divMultiple).rounded(.down))
            return Union {
                for x in stride(from: 1.0, through: offDivX, by: 1) {
                    for y in 1...c.divY {
                        pocket(x: (x - 1) * w, y: Double(y - 1) * h, w: w, h: h)
                    }
                }
                for x in stride(from: 1.0, through: remDivX, by: 1) {
                    for y in stride(from: 1.0, through: remDivY, by: 1) {
                        pocket(x: offGridX + (x - 1) * remGridX / remDivX,
                               y: (y - 1) * gridY / remDivY,
                               w: remGridX / remDivX, h: gridY / remDivY)
                    }
                }
            }
        }
    }

    /// gf_bin_solid. `pockets == nil` mirrors OpenSCAD's empty `children()`: the interior is cut whole.
    func binSolid(pockets: (any Geometry3D)?) -> any Geometry3D {
        let dh = storageHeight
        let override = configuration.internalHeightOverride
        let aa = -(0.5 + d.dWall * 1.25 + fit.separatorWallThickness / 4)
        let bottomHeight = (override == 0 ? dh - 0.1 : override)
            - fit.thickness - fit.vFitTolerance - fit.vPosTolerance

        // Wall with lid lip, tabs, lip mask and grips
        let wall = Union {
            d.blockWall(gridX: gridX, gridY: gridY, profile: lidLipWallProfile(lid: false),
                        cornerSegments: configuration.cornerSegments)
            lidTabs()
        }
        .subtracting {
            lidLipMask().translated(x: -fit.lipFitTolerance, z: -fit.lipFitTolerance)
            if let grips = lipGripMasks() { grips }
        }

        // Floor block with the interior base grid, minus the pockets
        let interiorCut = roundedRect(height: innerHeight, addSize: aa, radius: d.rBase * 2)
            .translated(z: d.dWall)
        let floor = Union {
            d.blockBottom(height: bottomHeight, gridX: gridX, gridY: gridY)
            baseGridInterior()
        }
        .subtracting {
            if let pockets { interiorCut.intersecting { pockets } } else { interiorCut }
        }

        // Base feet
        let interior = baseGridInterior()
        let interiorLimit: any Geometry3D = configuration.interiorStyle == .partialRaised
            ? Rectangle([d.lGrid * gridX, d.lGrid * gridY])
                .aligned(at: .center)
                .extruded(height: d.hBase - d.rC2)
                .translated(z: d.hBot + d.hBase - d.rC2 + 0.1)
                .intersecting { interior }
            : interior
        let feet = roundedRect(height: d.hBase + d.hBot / 2 * 10, addSize: -0.5)
            .translated(z: -1)
            .intersecting {
                Union {
                    baseGrid()
                    roundedRect(height: d.hBot / 2, addSize: -0.5).translated(z: d.hBase)
                }
                .subtracting { interiorLimit }
            }

        return Union { wall; floor; feet }
    }
}
```

The `Union { for ... }`, `if let` and `stride` forms must compile in Cadova's builders; if not, collect into an array and use the array initializer.

- [ ] **Step 5: Run the tests**

Run: `swift test --skip-update --filter BinBodyTests`
Expected: 6 tests pass. When one fails, diagnose by comparing the specific OpenSCAD module against its port (read the failure: volume off, which bound, or symmetric difference large). Useful bisection: the three parts of `binSolid` (wall, floor, feet) can each be measured alone, and the OpenSCAD side can be exported with the corresponding part isolated by a scratch copy of `lid-bin.scad` under `/tmp`. Do NOT edit `$SRC/lid-bin.scad`.

- [ ] **Step 6: Mutation checks (restore exactly after each)**

(a) `tabPosX` sign flipped: a bin test must fail. (b) the `-fit.lipFitTolerance` shift on `lidLipMask()` removed: a bin test must fail. (c) `0.4` interior adjust to `0.5`: a bin test must fail. (d) `rBase * 2` to `rBase` in `interiorCut`: a bin test must fail. Report which tests failed for each, and any that survived.

---

### Task 6: Lid body

**Files:**
- Create: `LiddedBin/Sources/LiddedBinModel/LidBody.swift`
- Modify: `LiddedBin/Reference/generate.py`
- Test: `LiddedBin/Tests/LiddedBinModelTests/LidBodyTests.swift`

**Interfaces:**
- Consumes: `lidLipWallProfile(lid:)`, `lidLipMask()`, `roundedRect(height:addSize:radius:)`, `lidTabs(adjust:)`, `lipGripMasks()`, `blockWall`.
- Produces: `LiddedBinDesign.lidBody() -> any Geometry3D` (`gf_bin_lid`, in the bin's own coordinates: the lid sits closed on the bin).

- [ ] **Step 1: Add reference cases**

The reference `Part="lid"` output is `translate([0,0,-$dh - h_base + lid_thickness]) gf_bin_lid()`, i.e. the lid placed flat on the bed. Add:

```python
"lid_2x2x3_nogrips":  ['Part="lid"', 'Lip_Grips="none"'],
"lid_2x2x3_xy":       ['Part="lid"'],
"lid_1x1x2_nogrips":  ['Part="lid"', 'Lip_Grips="none"', 'gridx=1', 'gridy=1', 'gridz=2'],
"lid_2x3x3_grips_y_up": ['Part="lid"', 'Lip_Grips="y"', 'gridx=2', 'gridy=3', 'Lid_Orientation="up"'],
```

Run `python3 -I Reference/generate.py` for the new cases.

- [ ] **Step 2: Write the failing tests**

```swift
import Testing
import Cadova
import GridfinityRebuilt
import GridfinityTestSupport
@testable import LiddedBinModel

struct LidBodyTests {
    let refs = ReferenceSet.containing()

    func lidOnBed(_ design: LiddedBinDesign) -> any Geometry3D {
        // Part == "lid": translate([0, 0, -$dh - h_base + lid_thickness]) gf_bin_lid()
        design.lidBody().translated(z: -design.storageHeight - design.d.hBase + design.fit.thickness)
    }

    func design(_ edit: (inout LiddedBinConfiguration) -> Void = { _ in }) -> LiddedBinDesign {
        var c = LiddedBinConfiguration()
        c.cornerSegments = 16
        edit(&c)
        return LiddedBinDesign(c)
    }

    @Test func `2x2x3 lid without grips`() async throws {
        let d = design { $0.lipGrips = .none }
        try await expectMatchesReference("lid_2x2x3_nogrips", lidOnBed(d), references: refs)
    }

    @Test func `2x2x3 lid with default grips`() async throws {
        try await expectMatchesReference("lid_2x2x3_xy", lidOnBed(design()), references: refs)
    }

    @Test func `1x1x2 lid`() async throws {
        let d = design { $0.lipGrips = .none; $0.gridX = 1; $0.gridY = 1; $0.gridZ = 2 }
        try await expectMatchesReference("lid_1x1x2_nogrips", lidOnBed(d), references: refs)
    }

    @Test func `2x3x3 lid with Y grips opening upward`() async throws {
        let d = design { $0.lipGrips = .y; $0.gridX = 2; $0.gridY = 3; $0.lidOrientation = .up }
        try await expectMatchesReference("lid_2x3x3_grips_y_up", lidOnBed(d), references: refs)
    }
}
```

Run: expected build error (`lidBody` not found).

- [ ] **Step 3: Implement**

Port from `$SRC/lid-bin.scad` lines 229-277.

```swift
import Cadova
import GridfinityRebuilt

extension LiddedBinDesign {
    /// gf_bin_lid
    func lidBody() -> any Geometry3D {
        let dh = storageHeight
        let sz = 0.5 + fit.hFitTolerance * 3
        let plateZ = dh + d.hBase - fit.thickness - fit.vPosTolerance

        // Rim of the lid: the wall sweep clipped to the lip mask, minus the grips
        let rim = d.blockWall(gridX: gridX, gridY: gridY, profile: d.wallProfile(height: dh),
                              cornerSegments: configuration.cornerSegments)
            .intersecting { lidLipMask() }
            .subtracting {
                if let grips = lipGripMasks() { grips }
            }

        // Plate and inner lip, minus the tab notches
        let lipProfile = d.wallProfile(height: dh)
            .subtracting {
                Rectangle([d.rBase, dh - fit.vPosTolerance])
                Rectangle([d.rBase, dh + d.hLip]).translated(x: d.rBase)
                lidLipWallProfile(lid: true).offset(amount: 0.30, style: .miter)
            }
        let plate = Union {
            roundedRect(height: fit.thickness, addSize: -sz, radius: d.rFo1 - sz)
                .translated(z: plateZ)
            roundedRect(height: d.hLip + fit.thickness, addSize: -sz, radius: d.rFo1 - sz)
                .translated(z: plateZ)
                .intersecting {
                    d.blockWall(gridX: gridX, gridY: gridY, profile: lipProfile,
                                cornerSegments: configuration.cornerSegments)
                }
        }
        .subtracting { lidTabs(adjust: true) }

        return Union { rim; plate }
    }
}
```

Check line by line against the `.scad`: in OpenSCAD the lip profile is `difference() { profile_wall(); union() { square([r_base, $dh - lid_vpos_tolerance]); translate([r_base, 0]) square([r_base, $dh + h_lip]); } offset(delta = 0.30) gf_profile_wall_lid_lip(lid = true); }`, so the subtracted pieces are exactly the three listed. The rim's `intersection() { block_wall...; lip_mask }` then `difference` with the grips matches `rim`.

- [ ] **Step 4: Run, expect PASS**

Run: `swift test --skip-update --filter LidBodyTests`
Expected: 4 tests pass (see Task 5 Step 5 for diagnosing failures).

- [ ] **Step 5: Mutation checks (restore after each)**

(a) `offset(amount: 0.30` to `0.20`: a lid test must fail. (b) `fit.hFitTolerance * 3` to `* 2` in `sz`: must fail. (c) the `adjust: true` flag dropped from `lidTabs`: must fail. Report any survivors.

---

### Task 7: Configuration coverage (orientations, height modes, patterns)

**Files:**
- Modify: `LiddedBin/Reference/generate.py`
- Test: `LiddedBin/Tests/LiddedBinModelTests/VariantTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 4 to 6.
- Produces: nothing new in the library; this task is a test and correction pass that exercises the remaining options.

- [ ] **Step 1: Add reference cases**

```python
# lid orientation (tabs and lip mask depend on it), bin and lid for each
"bin_2x2x3_left":  ['Part="bin"', 'Lid_Orientation="left"',  'divx=2', 'divy=2'],
"bin_2x2x3_right": ['Part="bin"', 'Lid_Orientation="right"', 'divx=2', 'divy=2'],
"bin_2x2x3_up":    ['Part="bin"', 'Lid_Orientation="up"',    'divx=2', 'divy=2'],
"bin_2x2x3_down":  ['Part="bin"', 'Lid_Orientation="down"',  'divx=2', 'divy=2'],
"lid_2x2x3_right": ['Part="lid"', 'Lid_Orientation="right"'],
"lid_2x2x3_down":  ['Part="lid"', 'Lid_Orientation="down"'],
# height modes
"bin_2x2_internal_20_snap": ['Part="bin"', 'gridz_define=1', 'gridz=20', 'enable_zsnap=true', 'divx=2', 'divy=2'],
"bin_2x2_external_30":      ['Part="bin"', 'gridz_define=2', 'gridz=30', 'enable_zsnap=false', 'divx=2', 'divy=2'],
"bin_2x2x3_height_internal": ['Part="bin"', 'height_internal=20', 'divx=2', 'divy=2'],
# multisize pattern
"bin_3x2x3_multisize": ['Part="bin"', 'div_pattern="multisize"', 'gridx=3', 'gridy=2', 'divx=3', 'divy=2', 'div_multiple=2', 'Lip_Grips="none"'],
# gaps found in Task 5 review: Y-only grips on a non-square bin, and multisize edges
"bin_3x2x3_grips_y":          ['Part="bin"', 'Lip_Grips="y"', 'gridx=3', 'gridy=2', 'divx=3', 'divy=2'],
"bin_2x2x3_multisize_divx1":  ['Part="bin"', 'div_pattern="multisize"', 'divx=1', 'divy=2', 'Lip_Grips="none"'],
"bin_2x2x3_multisize_divy0":  ['Part="bin"', 'div_pattern="multisize"', 'divx=2', 'divy=0', 'Lip_Grips="none"'],
# fit-tolerance sweep: the fit constants cancel in places at their defaults, so vary them (Task 6 review)
"bin_2x2x3_fit_sweep": ['Part="bin"', 'lid_hfit_tolerance=1.3', 'lid_vfit_tolerance=0.05', 'lid_vpos_tolerance=0.3', 'lid_wall_thickness=1.0', 'lid_thickness=1.1', 'divx=2', 'divy=2', 'Lip_Grips="none"'],
"lid_2x2x3_fit_sweep": ['Part="lid"',  'lid_hfit_tolerance=1.3', 'lid_vfit_tolerance=0.05', 'lid_vpos_tolerance=0.3', 'lid_wall_thickness=1.0', 'lid_thickness=1.1', 'Lip_Grips="none"'],
```

Run `python3 -I Reference/generate.py` for these.

- [ ] **Step 2: Write the tests**

`VariantTests.swift` uses the same `design(_:)` helper and `expectMatchesReference` calls. One test per case above:

- `bin_2x2x3_left/right/up/down`: `lidOrientation` set, `divX = 2`, `divY = 2`, default grips, `design.binSolid(pockets: design.pockets())`.
- `lid_2x2x3_right`, `lid_2x2x3_down`: lid on bed, as in `LidBodyTests.lidOnBed` (move that helper to a shared file `TestHelpers.swift` in the test target and have both test files use it).
- `bin_2x2_internal_20_snap`: `heightMode = .internalMillimeters`, `gridZ = 20`, `snapHeight = true`.
- `bin_2x2_external_30`: `heightMode = .externalMillimeters`, `gridZ = 30`, `snapHeight = false`.
- `bin_2x2x3_height_internal`: `internalHeightOverride = 20`.
- `bin_3x2x3_multisize`: `compartmentPattern = .multiSize`, `gridX = 3`, `gridY = 2`, `divX = 3`, `divY = 2`, `divMultiple = 2`, `lipGrips = .none`.
- `bin_3x2x3_grips_y`: `lipGrips = .y`, `gridX = 3`, `gridY = 2`, `divX = 3`, `divY = 2`.
- `bin_2x2x3_multisize_divx1` and `bin_2x2x3_multisize_divy0`: multisize pattern edge cases (`divX = 1` makes the remainder width zero, so a pocket of non-positive size reaches the geometry; `divY = 0` makes the first loop empty). If Cadova rejects or mis-handles a non-positive `Rectangle`, skip pockets whose size is not positive in `pocket(...)` (OpenSCAD's `square` of non-positive size is empty), document it, and keep the reference as the check. Report what OpenSCAD does for each case before porting the guard.
- `bin_2x2x3_fit_sweep` and `lid_2x2x3_fit_sweep`: the same geometry with non-default lid fit constants (`hFitTolerance = 1.3`, `vFitTolerance = 0.05`, `vPosTolerance = 0.3`, `wallThickness = 1.0`, `thickness = 1.1`; note `lipFitTolerance = min(0.1, vFit)` becomes 0.05). This pins formulas where the constants cancel at their defaults (the groove top, the tab bottom). Make this possible by giving `LiddedBinDesign` an internal initializer `init(_ configuration: LiddedBinConfiguration, fit: LidFit)` (the existing public `init(_:)` uses `LidFit()`), and `LidFit` memberwise-initializable with its defaults. In OpenSCAD these are overridable top-level variables: confirm that `-D lid_vfit_tolerance=0.05` really changes the output (the sweep volumes must differ from the default-fit cases) and that `lid_lip_fit_tolerance` follows (it is `min(0.1, lid_vfit_tolerance)` in the scad). Both use `divX = 2`, `divY = 2`, `lipGrips = .none`, and the lid on the bed as in LidBodyTests.
- Housekeeping: delete `LiddedBin/Reference/__pycache__` and add `__pycache__/` to `/Users/shinohara/Downloads/3D Printing/Gridfinity/Cadovafinity/.gitignore`.

All with `cornerSegments = 16`.

- [ ] **Step 3: Run**

Run: `swift test --skip-update`
Expected: pass. Failures here point at orientation-dependent code (`lidTabs`, `lidLipMask`, `lidPosition`) or the multisize arithmetic; fix the port, not the tolerance, and report each fix.

- [ ] **Step 4: Mutation checks (restore after each)**

(a) swap the `.up` and `.down` direction vectors: orientation tests must fail. (b) `ceil` to `floor` in `offDivX`: multisize test must fail. (c) the `override == 0 ? dh - 0.1 : override` branch always taking `dh - 0.1`: `bin_2x2x3_height_internal` must fail. Report survivors.

---

### Task 8: Parts, bin slice and the executable

**Files:**
- Create: `LiddedBin/Sources/LiddedBinModel/Parts.swift`
- Modify: `LiddedBin/Sources/lidded-bin/main.swift`
- Modify: `LiddedBin/Reference/generate.py`
- Test: `LiddedBin/Tests/LiddedBinModelTests/PartsTests.swift`

**Interfaces:**
- Consumes: `binSolid`, `pockets`, `lidBody`, `lidPosition`, `BinGeometry`.
- Produces:
  - `LiddedBinDesign.geometry(for part: LiddedBinPart) -> any Geometry3D`
  - Part behavior: `bin`: `binSolid(pockets: pockets())`. `lid`: `lidBody()` placed flat on the bed (`translated(z: -storageHeight - hBase + thickness)`). `bothClosed`: bin and lid in one model, as two named Cadova parts (`"Bin"`, `"Lid"`) at their closed positions. `bothOpen`: the same with the lid translated by `lidPosition(adjust: -(hLip * 2))`. `binSlice`: the first `hLip * 3` of the bin printed upside-down-free for fit testing, exactly as `main()` does: `intersection() { translate([0,0,-bh]) gf_bin(pockets=false); linear_extrude(h_lip*3) square([l*gx, l*gy], center=true); }` with `bh = dh + h_base - lid_thickness*2` (pockets nil means no interior cut: the slice starts from a SOLID bin, because an empty intersection cuts nothing).
  - An executable that writes one 3MF per part for the default configuration into `LiddedBin/Models/`.

- [ ] **Step 1: Add reference cases**

```python
"bin_slice_2x2x3":       ['Part="bin_slice"'],
"bin_slice_1x1x2_up":    ['Part="bin_slice"', 'gridx=1', 'gridy=1', 'gridz=2', 'Lid_Orientation="up"'],
```

(`both_closed` and `both_open` have no CLI reference: OpenSCAD only draws the lid when `$preview` is true. They are checked against the bin and lid cases instead.)

- [ ] **Step 2: Write the failing tests**

```swift
import Testing
import Cadova
import GridfinityRebuilt
import GridfinityTestSupport
@testable import LiddedBinModel

struct PartsTests {
    let refs = ReferenceSet.containing()

    func design(_ edit: (inout LiddedBinConfiguration) -> Void = { _ in }) -> LiddedBinDesign {
        var c = LiddedBinConfiguration()
        c.cornerSegments = 16
        edit(&c)
        return LiddedBinDesign(c)
    }

    @Test func `bin slice matches OpenSCAD`() async throws {
        try await expectMatchesReference("bin_slice_2x2x3", design().geometry(for: .binSlice), references: refs)
    }

    @Test func `small bin slice with the lid up`() async throws {
        let d = design { $0.gridX = 1; $0.gridY = 1; $0.gridZ = 2; $0.lidOrientation = .up }
        try await expectMatchesReference("bin_slice_1x1x2_up", d.geometry(for: .binSlice), references: refs)
    }

    @Test func `bin part equals the bin reference`() async throws {
        try await expectMatchesReference("bin_2x2x3_xy", design().geometry(for: .bin), references: refs)
    }

    @Test func `lid part equals the lid reference`() async throws {
        try await expectMatchesReference("lid_2x2x3_xy", design().geometry(for: .lid), references: refs)
    }

    @Test func `closed assembly is the bin and the lid at their printed heights`() async throws {
        let bin = try refs.metrics("bin_2x2x3_xy")
        let closed = try await measure(design().geometry(for: .bothClosed))
        // The lid sits inside the bin's lip: the assembly's footprint is the bin's footprint.
        #expect(abs(closed.min.x - bin.min.x) < 0.05 && abs(closed.max.x - bin.max.x) < 0.05)
        #expect(abs(closed.min.y - bin.min.y) < 0.05 && abs(closed.max.y - bin.max.y) < 0.05)
        // The lid's volume adds to the bin's (they do not overlap, they fit with clearance).
        let lid = try refs.metrics("lid_2x2x3_xy")
        #expect(closed.volume > bin.volume)
        #expect(closed.volume < bin.volume + lid.volume + 1)
    }

    @Test func `open assembly moves the lid out along the lid direction`() async throws {
        let closed = try await measure(design().geometry(for: .bothClosed))
        let open = try await measure(design().geometry(for: .bothOpen))
        #expect(open.min.x < closed.min.x - 70)   // lid moved by about one bin width to the left
        #expect(abs(open.volume - closed.volume) < 1e-6)
    }
}
```

The `bothClosed` volume assertions verify that the two parts do not overlap (the fit clearance is the whole point of the design). If the assertion `closed.volume < bin.volume + lid.volume + 1` or `closed.volume > bin.volume` is awkward because the lid placed closed overlaps the bin's lip region slightly, report the measured overlap volume instead of loosening the number silently.

Run: expected build error.

- [ ] **Step 3: Implement `Parts.swift`**

```swift
import Cadova
import GridfinityRebuilt

extension LiddedBinDesign {
    public func geometry(for part: LiddedBinPart) -> any Geometry3D {
        switch part {
        case .bin:
            return binSolid(pockets: pockets())
        case .lid:
            return lidBody().translated(z: -storageHeight - d.hBase + fit.thickness)
        case .bothClosed:
            return assembly(lidOffset: nil)
        case .bothOpen:
            return assembly(lidOffset: lidPosition(adjust: -(d.hLip * 2)))
        case .binSlice:
            let bh = storageHeight + d.hBase - fit.thickness * 2
            return binSolid(pockets: nil)
                .translated(z: -bh)
                .intersecting {
                    Rectangle([d.lGrid * gridX, d.lGrid * gridY])
                        .aligned(at: .center)
                        .extruded(height: d.hLip * 3)
                }
        }
    }

    private func assembly(lidOffset: Vector2D?) -> any Geometry3D {
        Union {
            binSolid(pockets: pockets()).inPart(Part("Bin"))
            lidBody()
                .translated(x: lidOffset?.x ?? 0, y: lidOffset?.y ?? 0)
                .inPart(Part("Lid"))
        }
    }
}
```

`Part` here is Cadova's `Part`; the model's enum is `LiddedBinPart` to avoid the clash. Check Cadova's part API spelling in `$CADOVA/Sources/Cadova/Cadova.docc/WorkingWithParts.md` and fix as needed. If `measure` ignores part membership, keep the measurements as written; they use the whole geometry.

- [ ] **Step 4: Executable**

Replace the stub `main.swift`:

```swift
import Cadova
import LiddedBinModel

let design = LiddedBinDesign(LiddedBinConfiguration())

await Project(packageRelative: "Models") {
    Metadata(
        title: "Gridfinity Lidded Bin",
        description: "A Gridfinity bin with a sliding lid. Port of smkent's OpenSCAD design.",
        author: "smkent (original design)",
        license: "CC BY 4.0"
    )
    Environment {
        $0.tolerance = 0.2
    }
    await Model("Bin") { design.geometry(for: .bin) }
    await Model("Lid") { design.geometry(for: .lid) }
    await Model("Bin and lid, closed") { design.geometry(for: .bothClosed) }
    await Model("Bin and lid, open") { design.geometry(for: .bothOpen) }
    await Model("Bin slice") { design.geometry(for: .binSlice) }
}
```

`ModelOptions` for 3MF output come from Cadova defaults. Confirm the `Environment { }` and `Metadata(...)` spellings against `$CADOVA/Sources/Cadova/Cadova.docc/ModelAndProject.md` and `/Users/shinohara/Downloads/3D Printing/Cadova/gridfinity-cadova/Sources/generator/main.swift`.

- [ ] **Step 5: Run the tests, then the executable**

Run: `swift test --skip-update` (all pass). Then `swift run --skip-update lidded-bin`. Expected: five 3MF files appear in `LiddedBin/Models/`. If `cadova-viewer` is installed (`which cadova-viewer`), run `cadova-viewer info "Models/Bin.3mf"` and report the dimensions: a 2x2x3 bin should be about 83.5 mm square. If not installed, report that.

---

### Task 9: README, attribution, hygiene

**Files:**
- Create: `LiddedBin/README.md`
- Create: `GridfinityRebuilt/README.md`
- Modify: `Cadovafinity/.gitignore` (if needed)

- [ ] **Step 1: Write the READMEs**

`LiddedBin/README.md` must state: what the package is; that the design is a port of "Gridfinity Bins with Lids" by smkent (GitHub) / bulbasaur0 (Printables), licensed CC BY 4.0, with the attribution line from the top of `lid-bin.scad`; the library dependency (`GridfinityRebuilt`, a port of gridfinity-rebuilt-openscad, MIT); the dropped feature (custom compartment pockets, with the reason); how to build (`swift run lidded-bin`); how to run the OpenSCAD comparison (`python3 -I Reference/generate.py` then `swift test`, OpenSCAD required, `Reference/stl/` is generated and git-ignored); and a note that the customizer is the next step. Include the LICENSE note for CC BY 4.0 (link `https://creativecommons.org/licenses/by/4.0/`).

`GridfinityRebuilt/README.md`: scope (core, bins, baseplate planned), the `Dimensions` plus `BinGeometry` model, the `GridfinityTestSupport` product and how another package uses it, how to regenerate references, and the known limits (volume/bounds blind spots, quarter-turn tessellation parity via `cornerSegments`).

No em dashes anywhere.

- [ ] **Step 2: Final checks**

Run, in both packages: `swift test --skip-update`. Confirm `grep -rn "—" LiddedBin GridfinityRebuilt --include=*.swift --include=*.md --include=*.py` finds nothing and `grep -rn "0\.95" LiddedBin/Sources` finds nothing. Report test counts for both packages and the wall time of the OpenSCAD reference generation.

---

## Self-Review

- **Spec coverage:** lidded bin port with parameters as typed configuration (Tasks 4 to 8), `Part` enum (Task 8), dropped custom pockets (Global Constraints, Task 5 `pockets()`), attribution and license in `Metadata` and README (Tasks 8, 9), OpenSCAD comparison with symmetric difference (Task 3 onward), test-support product (Task 3). The customizer (`@Parameter`, `generate-customizer`, Pages workflow) is deliberately the next plan; the configuration struct is shaped so each field becomes one parameter. Library extras (baseplate, cutters, tabs, scoops) remain a later plan.
- **Placeholder scan:** the code for Tasks 5 and 6 is written out; spots that depend on Cadova API spellings (`Vector2D` initializers, `Union { for }`, `Rectangle(Double)`, `rotated(x:y:z:)` order, `Part`, `Import(model:)`) each name the Cadova file to read, and the tests decide correctness. The calibrated symmetric-difference tolerance is set by measurement in Task 3 Step 7, not guessed.
- **Type consistency:** `LiddedBinDesign` members (`storageHeight`, `innerHeight`, `lidPosition(adjust:)`, `pocketSize(xUnits:yUnits:)`, `binSolid(pockets:)`, `pockets()`, `lidBody()`, `lidTabs(adjust:)`, `lipGripMasks()`, `roundedRect(height:addSize:radius:)`, `geometry(for:)`) and library members (`blockWall(...cornerSegments:)`, `patternLinear(x:y:spacingX:spacingY:_:)`, `expectMatchesReference`, `ReferenceSet.containing()`) match across tasks.
- **Known risks:** (1) `Import(model:)` of an STL may need coordinate or unit options; (2) `import Testing` in a non-test target may not link (fallback given); (3) OpenSCAD render time of the 6x6 default bin; (4) `bothClosed` overlap assertions may need to be reported rather than asserted if the closed lid touches the bin by design.
