# GridfinityRebuilt Library Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Swift/Cadova package `GridfinityRebuilt` containing the core of gridfinity-rebuilt-openscad (constants, height math, base and wall profiles, block base, wall, bottom and bin shell, compartment placement), verified against OpenSCAD output.

**Architecture:** Each OpenSCAD module becomes a small Cadova `Geometry2D`/`Geometry3D` type or function. OpenSCAD's global variables (`d_wall`, `$dh`, `$gxx`, and so on) become explicit values: a `Dimensions` struct for constants and a `BinGeometry` struct for per-bin values. Correctness is checked by exporting STL from the original OpenSCAD code and comparing volume and bounding box with the Cadova result.

**Tech Stack:** Swift 6.3 (swift-tools-version 6.3), Cadova (local checkout), Swift Testing, OpenSCAD (`/opt/homebrew/bin/openscad`), Python 3 stdlib for the reference harness.

**Spec:** `docs/superpowers/specs/2026-11-17-cadova-gridfinity-port-design.md`

## Global Constraints

- Package lives in `Cadovafinity/GridfinityRebuilt/`. The lidded bin package is a later plan.
- `swift-tools-version: 6.3`, `platforms: [.macOS(.v15)]`, and `swiftSettings: [.interoperabilityMode(.Cxx)]` on EVERY target that imports Cadova, including the test target.
- Library code never uses `@Parameter`. All OpenSCAD parameters are typed initializer arguments.
- Numbers come from `standard.scad` and `gridfinity-rebuilt-utility.scad` in `../Lidded Bins/gridfinity-rebuilt-openscad` and are copied exactly.
- `d_wall` is configurable. `lid-bin.scad` overrides it to `1.60` (OpenSCAD's last-assignment-wins applies it to every use in the library), so no code may hardcode `0.95`.
- Do not run `git commit`, and do not initialize a repository. Staging and committing are left to the user.
- The sandbox blocks GitHub. Build offline from the SwiftPM cache (`swift build --skip-update`), and set `CADOVA_BUILD_FROM_SOURCE=1` if the Cadova binary download fails.
- Documentation and comments use no em dashes.
- Source reference paths below are relative to `/Users/shinohara/Downloads/3D Printing/Gridfinity/Lidded Bins/` (called `$SRC`). Cadova is at `/Users/shinohara/Downloads/3D Printing/Cadova/Cadova` (called `$CADOVA`).

## File Structure

```
GridfinityRebuilt/
  Package.swift
  Sources/GridfinityRebuilt/
    Dimensions.swift         # Dimensions struct: standard.scad constants + derived values
    Heights.swift            # HeightMode, LipStyle, Dimensions.binHeight(...)
    RoundedRectangle.swift   # rounded rectangle 2D/3D helpers
    Profiles.swift           # profile_base, profile_wall, profile_wall2
    BlockBase.swift          # block_base_solid
    BlockWall.swift          # sweep_rounded + block_wall
    BlockBottom.swift        # block_bottom
    BinGeometry.swift        # per-bin values ($gxx, $gyy, $dh, $dh0) + shell + cut_move
  Tests/GridfinityRebuiltTests/
    Measure.swift            # measure(geometry) -> volume + bounds, reference loader
    DimensionsTests.swift
    HeightsTests.swift
    ProfilesTests.swift
    BlockTests.swift
    BinGeometryTests.swift
  Reference/
    reference.scad           # selects one OpenSCAD case via -D case="..."
    generate.py              # runs openscad per case, writes reference.json
    reference.json           # generated: volume + bbox per case
```

---

### Task 1: Package scaffold, Dimensions and Heights

**Files:**
- Create: `GridfinityRebuilt/Package.swift`
- Create: `GridfinityRebuilt/Sources/GridfinityRebuilt/Dimensions.swift`
- Create: `GridfinityRebuilt/Sources/GridfinityRebuilt/Heights.swift`
- Test: `GridfinityRebuilt/Tests/GridfinityRebuiltTests/DimensionsTests.swift`
- Test: `GridfinityRebuilt/Tests/GridfinityRebuiltTests/HeightsTests.swift`

**Interfaces:**
- Produces:
  - `public struct Dimensions: Sendable` with `public static let standard: Dimensions`, stored `var`s named after `standard.scad` in camelCase (`hBase`, `rBase`, `rC1`, `rC2`, `hBot`, `rFo1`, `rFo2`, `rFo3`, `lGrid`, `dDiv`, `dWall`, `dClear`, `hLip`, `rF1`, `rF2`) and computed `dWall2: Double`, `dMagic: Double`.
  - `public enum HeightMode: Int, Sendable { case units = 0, internalMillimeters = 1, externalMillimeters = 2 }`
  - `public enum LipStyle: Int, Sendable { case regular = 0, removed = 1, removedKeepHeight = 2 }`
  - `Dimensions.binHeight(_ z: Double, mode: HeightMode = .units, lip: LipStyle = .regular, snap: Bool = true) -> Double`

- [ ] **Step 1: Write the manifest**

`GridfinityRebuilt/Package.swift`:

```swift
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "GridfinityRebuilt",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "GridfinityRebuilt", targets: ["GridfinityRebuilt"]),
    ],
    dependencies: [
        .package(path: "../../../Cadova/Cadova"),
    ],
    targets: [
        .target(
            name: "GridfinityRebuilt",
            dependencies: ["Cadova"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .testTarget(
            name: "GridfinityRebuiltTests",
            dependencies: ["GridfinityRebuilt", "Cadova"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ]
)
```

Relative path check: from `Gridfinity/Cadovafinity/GridfinityRebuilt/`, three levels up is `3D Printing/`, so `../../../Cadova/Cadova` is the Cadova checkout. Verify with `ls ../../../Cadova/Cadova/Package.swift` from the package directory. If that fails, use the absolute path `/Users/shinohara/Downloads/3D Printing/Cadova/Cadova`.

- [ ] **Step 2: Write the failing Dimensions test**

Expected values come from `standard.scad`: `d_wall2 = 4 - 0.8 - 0.25*sqrt(2) = 2.846446...`, `d_magic = -2*0.25 - 2*0.95 + 1.2 = -1.2`.

`Tests/GridfinityRebuiltTests/DimensionsTests.swift`:

```swift
import Testing
@testable import GridfinityRebuilt

struct DimensionsTests {
    @Test func `standard constants match standard.scad`() {
        let d = Dimensions.standard
        #expect(d.hBase == 5)
        #expect(d.rBase == 4)
        #expect(d.rC1 == 0.8)
        #expect(d.rC2 == 2.4)
        #expect(d.hBot == 2.2)
        #expect(d.rFo1 == 8.5)
        #expect(d.rFo2 == 3.2)
        #expect(d.rFo3 == 1.6)
        #expect(d.lGrid == 42)
        #expect(d.dDiv == 1.2)
        #expect(d.dWall == 0.95)
        #expect(d.dClear == 0.25)
        #expect(d.hLip == 3.548)
        #expect(d.rF1 == 0.6)
    }

    @Test func `derived values`() {
        let d = Dimensions.standard
        #expect(abs(d.dWall2 - (4 - 0.8 - 0.25 * 2.0.squareRoot())) < 1e-12)
        #expect(abs(d.dMagic - -1.2) < 1e-12)
    }

    @Test func `wall thickness override changes dMagic only`() {
        var d = Dimensions.standard
        d.dWall = 1.6
        #expect(abs(d.dMagic - (-0.5 - 3.2 + 1.2)) < 1e-12)
        #expect(d.dWall2 == Dimensions.standard.dWall2)
    }
}
```

- [ ] **Step 3: Run it to verify it fails**

Run (from `GridfinityRebuilt/`): `swift test --skip-update --filter DimensionsTests`
Expected: build error, `Dimensions` not found. (If the build instead fails on dependency resolution or the Cadova binary download, apply the offline fallbacks in Global Constraints before continuing.)

- [ ] **Step 4: Implement Dimensions**

`Sources/GridfinityRebuilt/Dimensions.swift`:

```swift
import Foundation

/// The dimensions from gridfinity-rebuilt-openscad's `standard.scad`.
///
/// Names follow the OpenSCAD variables in camelCase (`r_base` is `rBase`).
/// Wall thickness is a variable because designs such as the lidded bin override it.
public struct Dimensions: Sendable {
    /// Height of the base.
    public var hBase = 5.0
    /// Outside rounded radius of bin.
    public var rBase = 4.0
    /// Lower base chamfer "radius".
    public var rC1 = 0.8
    /// Upper base chamfer "radius".
    public var rC2 = 2.4
    /// Bottom thickness of bin.
    public var hBot = 2.2
    /// Outside radii 1, 2 and 3.
    public var rFo1 = 8.5
    public var rFo2 = 3.2
    public var rFo3 = 1.6
    /// Length of a grid unit.
    public var lGrid = 42.0
    /// Width of divider between compartments.
    public var dDiv = 1.2
    /// Minimum wall thickness.
    public var dWall = 0.95
    /// Tolerance fit factor.
    public var dClear = 0.25
    /// Lip height.
    public var hLip = 3.548
    /// Top edge fillet radius.
    public var rF1 = 0.6
    /// Internal fillet radius.
    public var rF2 = 2.8

    public init() {}

    public static let standard = Dimensions()

    /// `d_wall2` in standard.scad.
    public var dWall2: Double { rBase - rC1 - dClear * 2.0.squareRoot() }
    /// `d_magic` in standard.scad.
    public var dMagic: Double { -2 * dClear - 2 * dWall + dDiv }
}
```

- [ ] **Step 5: Run Dimensions tests, expect PASS**

Run: `swift test --skip-update --filter DimensionsTests`
Expected: 3 tests pass.

- [ ] **Step 6: Get expected height values from OpenSCAD**

Run (from `GridfinityRebuilt/`):

```bash
cat > /tmp/heights.scad <<'EOF'
include </Users/shinohara/Downloads/3D Printing/Gridfinity/Lidded Bins/gridfinity-rebuilt-openscad/standard.scad>
function hf (z, d, l) = ((d==0)?z*7:(d==1)?h_bot+z+h_base:z-((l==1)?h_lip:0))+(l==2?h_lip:0);
function height (z,d=0,l=0,s=true) = (s?((abs(hf(z,d,l))%7==0)?hf(z,d,l):hf(z,d,l)+7-abs(hf(z,d,l))%7):hf(z,d,l))-h_base;
echo(a=height(3), b=height(3,0,0,false), c=height(20,1,0,true), d=height(20,1,0,false), e=height(30,2,0,true), f=height(30,2,1,false), g=height(30,2,2,false));
EOF
openscad -o /tmp/heights.echo.stl /tmp/heights.scad 2>&1 | grep ECHO
```

Expected: one `ECHO:` line. Use these seven numbers (a to g) as the expected values in Step 7. (Do not trust numbers written in this plan; use the output.)

- [ ] **Step 7: Write the failing Heights test**

`Tests/GridfinityRebuiltTests/HeightsTests.swift`, filling `A`...`G` with the echoed values:

```swift
import Testing
@testable import GridfinityRebuilt

struct HeightsTests {
    let d = Dimensions.standard

    @Test func `height modes match OpenSCAD`() {
        #expect(abs(d.binHeight(3) - A) < 1e-9)                                   // height(3)
        #expect(abs(d.binHeight(3, snap: false) - B) < 1e-9)                      // height(3,0,0,false)
        #expect(abs(d.binHeight(20, mode: .internalMillimeters) - C) < 1e-9)      // height(20,1,0,true)
        #expect(abs(d.binHeight(20, mode: .internalMillimeters, snap: false) - D) < 1e-9)
        #expect(abs(d.binHeight(30, mode: .externalMillimeters) - E) < 1e-9)
        #expect(abs(d.binHeight(30, mode: .externalMillimeters, lip: .removed, snap: false) - F) < 1e-9)
        #expect(abs(d.binHeight(30, mode: .externalMillimeters, lip: .removedKeepHeight, snap: false) - G) < 1e-9)
    }
}
```

- [ ] **Step 8: Run it to verify it fails**

Run: `swift test --skip-update --filter HeightsTests`
Expected: build error, `binHeight` not found.

- [ ] **Step 9: Implement Heights**

`Sources/GridfinityRebuilt/Heights.swift` (port of `hf` and `height`; OpenSCAD `%` is `fmod`, which is `truncatingRemainder`):

```swift
import Foundation

/// What the bin's `z` value means (`gridz_define` in the OpenSCAD files).
public enum HeightMode: Int, Sendable {
    /// `z` is the height in units of 7mm (Zack's method).
    case units = 0
    /// `z` is the internal height in millimeters.
    case internalMillimeters = 1
    /// `z` is the overall external height in millimeters.
    case externalMillimeters = 2
}

/// Lip style of a bin (`sl` in `gridfinityInit`, `l` in `height`).
public enum LipStyle: Int, Sendable {
    /// Regular stacking lip.
    case regular = 0
    /// Lip removed subtractively.
    case removed = 1
    /// Lip removed, overall height retained.
    case removedKeepHeight = 2
}

extension Dimensions {
    /// Port of OpenSCAD `hf`.
    func rawHeight(_ z: Double, mode: HeightMode, lip: LipStyle) -> Double {
        let base: Double
        switch mode {
        case .units: base = z * 7
        case .internalMillimeters: base = hBot + z + hBase
        case .externalMillimeters: base = z - (lip == .removed ? hLip : 0)
        }
        return base + (lip == .removedKeepHeight ? hLip : 0)
    }

    /// Port of OpenSCAD `height`: the storage height `$dh` of a bin, in millimeters.
    ///
    /// With `snap`, the value is rounded up to a multiple of 7mm first.
    public func binHeight(
        _ z: Double,
        mode: HeightMode = .units,
        lip: LipStyle = .regular,
        snap: Bool = true
    ) -> Double {
        let h = rawHeight(z, mode: mode, lip: lip)
        let snapped: Double
        if snap {
            let r = abs(h).truncatingRemainder(dividingBy: 7)
            snapped = r == 0 ? h : h + 7 - r
        } else {
            snapped = h
        }
        return snapped - hBase
    }
}
```

- [ ] **Step 10: Run all tests, expect PASS**

Run: `swift test --skip-update`
Expected: all tests pass.

---

### Task 2: OpenSCAD reference harness

**Files:**
- Create: `GridfinityRebuilt/Reference/reference.scad`
- Create: `GridfinityRebuilt/Reference/generate.py`
- Create (generated): `GridfinityRebuilt/Reference/reference.json`
- Create: `GridfinityRebuilt/Tests/GridfinityRebuiltTests/Measure.swift`
- Test: `GridfinityRebuilt/Tests/GridfinityRebuiltTests/MeasureTests.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `Reference/reference.json`: `{ "<case>": { "volume": Double, "min": [x,y,z], "max": [x,y,z] } }`.
  - `struct Metrics { var volume: Double; var min: Vector3D; var max: Vector3D }` and `func measure(_ g: any Geometry3D) async throws -> Metrics` (Cadova result, evaluated with 64 segments per circle).
  - `func reference(_ name: String) throws -> Metrics` (reads `reference.json`).
  - `func expectMatches(_ actual: Metrics, _ expected: Metrics, volumeTolerance: Double = 0.01, boundsTolerance: Double = 0.05)`: volume within a relative `volumeTolerance`, each bounds coordinate within `boundsTolerance` mm.

Cases are added to `reference.scad` and `generate.py` by later tasks; this task creates the mechanism with one trivial case so it can be verified.

- [ ] **Step 1: Write the reference scad with a trivial case**

`Reference/reference.scad` (the `case` variable is set with `-D`; `$fn` is set by the script):

```openscad
include <../../../Lidded Bins/gridfinity-rebuilt-openscad/gridfinity-rebuilt-utility.scad>

case = "unit_cube";

if (case == "unit_cube") {
    cube([2, 3, 4]);
}
// CASES: later tasks append `else if (case == "...") { ... }` blocks above this line.
```

The include path is relative to the scad file. Verify: `openscad -o /tmp/t.stl -D 'case="unit_cube"' Reference/reference.scad` from `GridfinityRebuilt/` must succeed. If the include fails, replace it with the absolute path.

- [ ] **Step 2: Write the generator**

`Reference/generate.py` (stdlib only; run with `python3 -I`):

```python
"""Runs OpenSCAD for each reference case and records volume and bounding box.

Usage: python3 -I Reference/generate.py [case ...]   (default: all cases)
"""
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCAD = HERE / "reference.scad"
OUT = HERE / "reference.json"
OPENSCAD = "/opt/homebrew/bin/openscad"
FN = 64  # keep equal to the segment count used by Tests Measure.swift

CASES = ["unit_cube"]


def parse_ascii_stl(path):
    verts = []
    for line in path.read_text().splitlines():
        m = re.match(r"\s*vertex\s+(\S+)\s+(\S+)\s+(\S+)", line)
        if m:
            verts.append(tuple(float(g) for g in m.groups()))
    volume = 0.0
    for i in range(0, len(verts), 3):
        a, b, c = verts[i:i + 3]
        volume += (
            a[0] * (b[1] * c[2] - b[2] * c[1])
            - a[1] * (b[0] * c[2] - b[2] * c[0])
            + a[2] * (b[0] * c[1] - b[1] * c[0])
        ) / 6.0
    mins = [min(v[k] for v in verts) for k in range(3)]
    maxs = [max(v[k] for v in verts) for k in range(3)]
    return {"volume": abs(volume), "min": mins, "max": maxs}


def run_case(name):
    with tempfile.TemporaryDirectory() as tmp:
        stl = Path(tmp) / f"{name}.stl"
        subprocess.run(
            [OPENSCAD, "-o", str(stl), "--export-format", "asciistl",
             "-D", f'case="{name}"', "-D", f"$fn={FN}", str(SCAD)],
            check=True, capture_output=True, text=True,
        )
        return parse_ascii_stl(stl)


def main():
    names = sys.argv[1:] or CASES
    data = json.loads(OUT.read_text()) if OUT.exists() else {}
    for name in names:
        data[name] = run_case(name)
        print(name, data[name])
    OUT.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Generate and sanity-check the reference**

Run: `python3 -I Reference/generate.py`
Expected: prints `unit_cube {'volume': 24.0, 'min': [0.0, 0.0, 0.0], 'max': [2.0, 3.0, 4.0]}` (volume `24.0` up to float noise) and creates `Reference/reference.json`.

- [ ] **Step 4: Write the failing Measure test**

`Tests/GridfinityRebuiltTests/MeasureTests.swift`:

```swift
import Testing
import Cadova

struct MeasureTests {
    @Test func `measure matches the reference harness for a cube`() async throws {
        let actual = try await measure(Box([2, 3, 4]))
        let expected = try reference("unit_cube")
        expectMatches(actual, expected)
    }
}
```

- [ ] **Step 5: Run it to verify it fails**

Run: `swift test --skip-update --filter MeasureTests`
Expected: build error, `measure` not found.

- [ ] **Step 6: Implement the helpers**

`Tests/GridfinityRebuiltTests/Measure.swift`:

```swift
import Foundation
import Testing
import Cadova

struct Metrics {
    var volume: Double
    var min: Vector3D
    var max: Vector3D
}

/// Segment count per full circle. Keep equal to FN in Reference/generate.py.
let referenceSegments = 64

func measure(_ geometry: any Geometry3D) async throws -> Metrics {
    let g = geometry.withSegmentation(count: referenceSegments)
    return try await ModelFileGenerator.evaluate { evaluator in
        let bounds = await evaluator.bounds(of: g)
        let volume = await evaluator.measurements(of: g).volume
        return Metrics(
            volume: volume,
            min: bounds?.minimum ?? .zero,
            max: bounds?.maximum ?? .zero
        )
    }
}

private struct RawMetrics: Decodable {
    var volume: Double
    var min: [Double]
    var max: [Double]
}

func reference(_ name: String) throws -> Metrics {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // GridfinityRebuiltTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // package root
        .appendingPathComponent("Reference/reference.json")
    let all = try JSONDecoder().decode([String: RawMetrics].self, from: Data(contentsOf: url))
    guard let raw = all[name] else {
        throw ReferenceError.missing(name)
    }
    return Metrics(
        volume: raw.volume,
        min: Vector3D(raw.min[0], raw.min[1], raw.min[2]),
        max: Vector3D(raw.max[0], raw.max[1], raw.max[2])
    )
}

enum ReferenceError: Error { case missing(String) }

func expectMatches(
    _ actual: Metrics,
    _ expected: Metrics,
    volumeTolerance: Double = 0.01,
    boundsTolerance: Double = 0.05,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let relative = abs(actual.volume - expected.volume) / max(expected.volume, 1e-9)
    #expect(relative <= volumeTolerance,
            "volume \(actual.volume) vs reference \(expected.volume)",
            sourceLocation: sourceLocation)
    for (a, e, label) in [
        (actual.min.x, expected.min.x, "min.x"), (actual.min.y, expected.min.y, "min.y"),
        (actual.min.z, expected.min.z, "min.z"), (actual.max.x, expected.max.x, "max.x"),
        (actual.max.y, expected.max.y, "max.y"), (actual.max.z, expected.max.z, "max.z"),
    ] {
        #expect(abs(a - e) <= boundsTolerance, "\(label) \(a) vs reference \(e)",
                sourceLocation: sourceLocation)
    }
}
```

If `Vector3D` lacks `.zero` or the `Vector3D(_:_:_:)` initializer, use the form that compiles (`Vector3D(x:y:z:)` or array literal `[x, y, z]`). If `bounds(of:)` or `measurements(of:)` is not `async`, drop the `await`. Both signatures are in `$CADOVA/Sources/Cadova/Concrete Layer/` (grep `GeometryEvaluator+`).

- [ ] **Step 7: Run it, expect PASS**

Run: `swift test --skip-update --filter MeasureTests`
Expected: 1 test passes.

---

### Task 3: Rounded rectangle and wall/base profiles

**Files:**
- Create: `Sources/GridfinityRebuilt/RoundedRectangle.swift`
- Create: `Sources/GridfinityRebuilt/Profiles.swift`
- Modify: `Reference/reference.scad`, `Reference/generate.py` (add cases)
- Test: `Tests/GridfinityRebuiltTests/ProfilesTests.swift`

**Interfaces:**
- Consumes: `Dimensions`, `Metrics`/`measure`/`reference`/`expectMatches`.
- Produces:
  - `func roundedRectangle2D(length: Double, width: Double, radius: Double) -> any Geometry2D` (centered).
  - `func roundedRectangle(length: Double, width: Double, height: Double, radius: Double) -> any Geometry3D` (centered in XY, extruded from z=0 up).
  - `extension Dimensions { func baseProfile() -> any Geometry2D; func wallProfile(height dh: Double) -> any Geometry2D; func lipelessWallProfile(height dh: Double) -> any Geometry2D }`

Sources: `$SRC/gridfinity-rebuilt-openscad/gridfinity-rebuilt-utility.scad` lines 108-117 (`profile_base`), 237-282 (`profile_wall_sub_sub`, `profile_wall_sub`, `profile_wall`, `profile_wall2`), 480-485 (`rounded_rectangle`).

- [ ] **Step 1: Add reference cases**

Append before the `// CASES:` marker in `Reference/reference.scad`, using a fixed `$dh = 16` (a 3 unit bin) and `$dh0 = 0`:

```openscad
else if (case == "profile_base") {
    linear_extrude(10) profile_base();
}
else if (case == "profile_wall") {
    $dh = 16;
    linear_extrude(10) profile_wall();
}
else if (case == "profile_wall2") {
    $dh = 16;
    linear_extrude(10) profile_wall2();
}
else if (case == "rounded_rectangle") {
    rounded_rectangle(40, 20, 7, 4);
}
```

In `generate.py` set `CASES = ["unit_cube", "profile_base", "profile_wall", "profile_wall2", "rounded_rectangle"]`, then run `python3 -I Reference/generate.py`. Expected: four new entries. Sanity check by eye: `profile_wall2` is a `d_wall` by 16 rectangle extruded 10, so volume is `0.95 * 16 * 10 = 152`.

- [ ] **Step 2: Write the failing tests**

`Tests/GridfinityRebuiltTests/ProfilesTests.swift`:

```swift
import Testing
import Cadova
@testable import GridfinityRebuilt

struct ProfilesTests {
    let d = Dimensions.standard
    let dh = 16.0

    @Test func `rounded rectangle matches OpenSCAD`() async throws {
        let actual = try await measure(roundedRectangle(length: 40, width: 20, height: 7, radius: 4))
        expectMatches(actual, try reference("rounded_rectangle"))
    }

    @Test func `base profile matches OpenSCAD`() async throws {
        let actual = try await measure(d.baseProfile().extruded(height: 10))
        expectMatches(actual, try reference("profile_base"))
    }

    @Test func `wall profile matches OpenSCAD`() async throws {
        let actual = try await measure(d.wallProfile(height: dh).extruded(height: 10))
        expectMatches(actual, try reference("profile_wall"))
    }

    @Test func `lipless wall profile matches OpenSCAD`() async throws {
        let actual = try await measure(d.lipelessWallProfile(height: dh).extruded(height: 10))
        expectMatches(actual, try reference("profile_wall2"))
    }
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `swift test --skip-update --filter ProfilesTests`
Expected: build error, symbols not found.

- [ ] **Step 4: Implement RoundedRectangle**

`Sources/GridfinityRebuilt/RoundedRectangle.swift` (OpenSCAD: `linear_extrude(height) offset(rad) offset(-rad) square([length,width], center=true)`; both offsets are round):

```swift
import Cadova

/// A centered rectangle whose corners are rounded with the given radius.
func roundedRectangle2D(length: Double, width: Double, radius: Double) -> any Geometry2D {
    Rectangle([length, width])
        .aligned(at: .center)
        .offset(amount: -radius, style: .round)
        .offset(amount: radius, style: .round)
}

/// `rounded_rectangle` in the utility file: centered in XY, from z = 0 up to `height`.
func roundedRectangle(length: Double, width: Double, height: Double, radius: Double) -> any Geometry3D {
    roundedRectangle2D(length: length, width: width, radius: radius)
        .extruded(height: height)
}
```

- [ ] **Step 5: Implement Profiles**

`Sources/GridfinityRebuilt/Profiles.swift`. Transform order matches OpenSCAD read bottom-up (innermost first), which in a Cadova chain reads left to right:

```swift
import Cadova
import Foundation

extension Dimensions {
    /// `profile_base`.
    func baseProfile() -> any Geometry2D {
        Polygon([
            [0, 0],
            [0, hBase],
            [rBase, hBase],
            [rBase - rC2, hBase - rC2],
            [rBase - rC2, rC1],
            [rBase - rC2 - rC1, 0],
        ])
    }

    /// `profile_wall_sub_sub`.
    private func wallSubSub(height dh: Double) -> any Geometry2D {
        Polygon([
            [0, 0],
            [dWall / 2, 0],
            [dWall / 2, dh - 1.2 - dWall2 + dWall / 2],
            [dWall2 - dClear, dh - 1.2],
            [dWall2 - dClear, dh + hBase],
            [0, dh + hBase],
        ])
    }

    /// `profile_wall_sub`.
    private func wallSub(height dh: Double) -> any Geometry2D {
        wallSubSub(height: dh)
            .subtracting {
                baseProfile()
                    .flipped(along: .x)
                    .translated(x: rBase - dClear, y: dh)
                    .offset(amount: dClear, style: .miter)
            }
    }

    /// `profile_wall`: the wall cross-section with stacking lip. X is the distance
    /// outward from the wall's inner edge, Y is height above the bin's base plane.
    func wallProfile(height dh: Double) -> any Geometry2D {
        wallSub(height: dh)
            .subtracting {
                // Round the top edge: remove the circle area not covered by the filleted profile.
                Circle(radius: rBase / 2)
                    .translated(y: dh + hBase - dClear * 2.0.squareRoot())
                    .subtracting {
                        wallSub(height: dh)
                            .offset(amount: -rF1, style: .miter)
                            .offset(amount: rF1, style: .round)
                    }

                // Remove any negative geometry in edge cases.
                Rectangle([100 * lGrid, 100 * lGrid])
                    .flipped(along: .y)
            }
            .flipped(along: .x)
            .translated(x: rBase)
    }

    /// `profile_wall2`: lipless wall profile.
    func lipelessWallProfile(height dh: Double) -> any Geometry2D {
        Rectangle([dWall, dh])
            .flipped(along: .x)
            .translated(x: rBase)
    }
}
```

Notes for the implementer: `offset(delta=-r_f1)` is `.offset(amount: -rF1, style: .miter)` and `offset(r=r_f1)` is `.offset(amount: rF1, style: .round)`. If `Rectangle` in Cadova is centered by default rather than corner-anchored (check `$CADOVA/Sources/Cadova/Abstract Layer/2D/Rectangle.swift`), add `.aligned(at: .min)` to the two rectangles so they occupy the same quadrant as OpenSCAD's `square`.

- [ ] **Step 6: Run the tests**

Run: `swift test --skip-update --filter ProfilesTests`
Expected: 4 tests pass. If `wall profile` fails on volume, diff the outline: write both extrusions to files (`Reference` case STL vs a Cadova `.3mf`) and compare in a viewer. The usual causes are a flipped axis in `baseProfile().flipped(...)` or `offset` style. Do not loosen tolerances to pass.

---

### Task 4: Block base solid

**Files:**
- Create: `Sources/GridfinityRebuilt/BlockBase.swift`
- Modify: `Reference/reference.scad`, `Reference/generate.py`
- Test: `Tests/GridfinityRebuiltTests/BlockTests.swift`

**Interfaces:**
- Consumes: `Dimensions`, `roundedRectangle(length:width:height:radius:)`.
- Produces: `extension Dimensions { func blockBaseSolid(nx: Double = 1, ny: Double = 1, length l: Double? = nil, offset o: Double = 0) -> any Geometry3D }`. Default `l` is `lGrid`. `nx`/`ny` correspond to `dbnx`/`dbny`.

Source: `block_base_solid`, `gridfinity-rebuilt-utility.scad` lines 167-185.

- [ ] **Step 1: Add reference cases**

Append to `reference.scad` before `// CASES:`:

```openscad
else if (case == "block_base_solid") {
    block_base_solid(1, 1, l_grid, 0);
}
else if (case == "block_base_solid_offset") {
    block_base_solid(1, 1, l_grid, -1.5);
}
```

Add both names to `CASES`, run `python3 -I Reference/generate.py`.

- [ ] **Step 2: Write the failing tests**

`Tests/GridfinityRebuiltTests/BlockTests.swift`:

```swift
import Testing
import Cadova
@testable import GridfinityRebuilt

struct BlockTests {
    let d = Dimensions.standard

    @Test func `block base solid matches OpenSCAD`() async throws {
        let actual = try await measure(d.blockBaseSolid())
        expectMatches(actual, try reference("block_base_solid"))
    }

    @Test func `block base solid with negative offset matches OpenSCAD`() async throws {
        let actual = try await measure(d.blockBaseSolid(offset: -1.5))
        expectMatches(actual, try reference("block_base_solid_offset"))
    }
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `swift test --skip-update --filter BlockTests`
Expected: build error, `blockBaseSolid` not found.

- [ ] **Step 4: Implement**

`Sources/GridfinityRebuilt/BlockBase.swift`. `mirror([0,0,1])` is `.flipped(along: .z)`; the two `hull()` calls become `.convexHull()` over a union of two extrusions:

```swift
import Cadova
import Foundation

extension Dimensions {
    /// `block_base_solid`: one grid cell's base, narrowing toward the bottom.
    func blockBaseSolid(
        nx: Double = 1,
        ny: Double = 1,
        length: Double? = nil,
        offset o: Double = 0
    ) -> any Geometry3D {
        let l = length ?? lGrid
        let xx = nx * l - 0.05
        let yy = ny * l - 0.05
        let oo = (o / 2) * (2.0.squareRoot() - 1)

        return Union {
            // Chamfered lower section
            Union {
                roundedRectangle(
                    length: xx - 2 * rC2 - 2 * rC1 + o,
                    width: yy - 2 * rC2 - 2 * rC1 + o,
                    height: hBase + oo,
                    radius: rFo3 / 2
                )
                roundedRectangle(
                    length: xx - 2 * rC2 + o,
                    width: yy - 2 * rC2 + o,
                    height: hBase - rC1 + oo,
                    radius: rFo2 / 2
                )
            }
            .convexHull()

            // Upper section, blending out to the full cell width
            Union {
                roundedRectangle(
                    length: xx - 2 * rC2 + o,
                    width: yy - 2 * rC2 + o,
                    height: rC2,
                    radius: rFo2 / 2
                )
                roundedRectangle(
                    length: xx + o,
                    width: yy + o,
                    height: hBot / 2 + abs(10 * o),
                    radius: rFo1 / 2
                )
                .flipped(along: .z)
            }
            .convexHull()
            .translated(z: oo)
        }
        .flipped(along: .z)
        .translated(z: hBase)
    }
}
```

- [ ] **Step 5: Run the tests**

Run: `swift test --skip-update --filter BlockTests`
Expected: 2 tests pass. A tolerance miss usually means a transform applied in the wrong order. Check the `translated(z: oo)` placement against the OpenSCAD source before touching tolerances.

---

### Task 5: Block wall (sweep_rounded) and block bottom

**Files:**
- Create: `Sources/GridfinityRebuilt/BlockWall.swift`
- Create: `Sources/GridfinityRebuilt/BlockBottom.swift`
- Modify: `Reference/reference.scad`, `Reference/generate.py`
- Modify: `Tests/GridfinityRebuiltTests/BlockTests.swift`

**Interfaces:**
- Consumes: `Dimensions.wallProfile(height:)`, `lipelessWallProfile(height:)`, `roundedRectangle`.
- Produces:
  - `func sweepRounded(width w: Double, height h: Double, profile: any Geometry2D) -> any Geometry3D`: port of `sweep_rounded`. Four straight sections plus four 90 degree revolved corners, profile in positive X.
  - `extension Dimensions { func blockWall(gridX gx: Double, gridY gy: Double, length l: Double? = nil, profile: any Geometry2D) -> any Geometry3D }`: port of `block_wall`; translates up by `hBase`.
  - `extension Dimensions { func blockBottom(height h: Double = 2.2, gridX gx: Double, gridY gy: Double, length l: Double? = nil) -> any Geometry3D }`: port of `block_bottom`.

Sources: `sweep_rounded` lines 513-531, `block_wall` 284-288, `block_bottom` 290-293, utility file.

- [ ] **Step 1: Add reference cases**

Append to `reference.scad`:

```openscad
else if (case == "block_wall_2x1") {
    $dh = 16;
    block_wall(2, 1, l_grid) profile_wall();
}
else if (case == "block_wall_lipless_1x1") {
    $dh = 16;
    block_wall(1, 1, l_grid) profile_wall2();
}
else if (case == "block_bottom_2x1") {
    block_bottom(15.9, 2, 1, l_grid);
}
```

Add the three names to `CASES`, regenerate.

- [ ] **Step 2: Write the failing tests**

Append to `BlockTests`:

```swift
    @Test func `block wall 2x1 matches OpenSCAD`() async throws {
        let actual = try await measure(
            d.blockWall(gridX: 2, gridY: 1, profile: d.wallProfile(height: 16))
        )
        expectMatches(actual, try reference("block_wall_2x1"))
    }

    @Test func `lipless block wall 1x1 matches OpenSCAD`() async throws {
        let actual = try await measure(
            d.blockWall(gridX: 1, gridY: 1, profile: d.lipelessWallProfile(height: 16))
        )
        expectMatches(actual, try reference("block_wall_lipless_1x1"))
    }

    @Test func `block bottom 2x1 matches OpenSCAD`() async throws {
        let actual = try await measure(d.blockBottom(height: 15.9, gridX: 2, gridY: 1))
        expectMatches(actual, try reference("block_bottom_2x1"))
    }
```

- [ ] **Step 3: Run to verify it fails**

Run: `swift test --skip-update --filter BlockTests`
Expected: build error, `blockWall` not found.

- [ ] **Step 4: Implement sweepRounded and blockWall**

`Sources/GridfinityRebuilt/BlockWall.swift`. In OpenSCAD, `rotate([90,0,0]) linear_extrude(height=h, center=true)` extrudes the profile (profile X stays X, profile Y becomes Z) along Y, centered. In Cadova: extrude along Z, center it, rotate 90 degrees about X. The 4-fold repetition comes from `pattern_circular(2)` plus mirrors; here the four sides and four corners are written out:

```swift
import Cadova

/// `sweep_rounded`: sweeps a profile around a rounded rectangle of the given
/// width (X) and height (Y), measured to the profile's origin.
///
/// The profile's X axis is the outward distance from the path and its Y axis is Z.
func sweepRounded(width w: Double, height h: Double, profile: any Geometry2D) -> any Geometry3D {
    let sideAlongY = profile
        .extruded(height: h)
        .translated(z: -h / 2)
        .rotated(x: 90°)
        .translated(x: w / 2)

    let sideAlongX = profile
        .extruded(height: w)
        .translated(z: -w / 2)
        .rotated(x: 90°)
        .translated(x: h / 2)
        .rotated(z: 90°)

    func corner(_ sx: Double, _ sy: Double, from start: Angle) -> any Geometry3D {
        profile
            .revolved(in: start..<(start + 90°))
            .translated(x: sx * w / 2, y: sy * h / 2)
    }

    return Union {
        sideAlongY
        sideAlongY.rotated(z: 180°)
        sideAlongX
        sideAlongX.rotated(z: 180°)
        corner(1, 1, from: 0°)
        corner(-1, 1, from: 90°)
        corner(-1, -1, from: 180°)
        corner(1, -1, from: 270°)
    }
}

extension Dimensions {
    /// `block_wall`: the bin's wall, swept around the outline of a `gx` by `gy` block.
    func blockWall(
        gridX gx: Double,
        gridY gy: Double,
        length: Double? = nil,
        profile: any Geometry2D
    ) -> any Geometry3D {
        let l = length ?? lGrid
        return sweepRounded(
            width: gx * l - 2 * rBase - 0.5 - 0.001,
            height: gy * l - 2 * rBase - 0.5 - 0.001,
            profile: profile
        )
        .translated(z: hBase)
    }
}
```

The `sideAlongX` derivation: OpenSCAD does `rotate([0,0,90]) translate([h/2,0,0]) rotate([90,0,0]) linear_extrude(height=w, center=true)`. That is: extrude along Y with length `w`, shift +X by `h/2`, then rotate 90 degrees about Z, which moves the shift onto +Y and the extrusion onto the X axis. This is what the chain above does. If the angle literal `90°` is unavailable, use `Angle(degrees: 90)` per Cadova's `Angle` docs.

- [ ] **Step 5: Implement blockBottom**

`Sources/GridfinityRebuilt/BlockBottom.swift`:

```swift
import Cadova

extension Dimensions {
    /// `block_bottom`: the solid floor block above the base.
    func blockBottom(
        height h: Double = 2.2,
        gridX gx: Double,
        gridY gy: Double,
        length: Double? = nil
    ) -> any Geometry3D {
        let l = length ?? lGrid
        return roundedRectangle(
            length: gx * l - 0.5 - dWall / 4,
            width: gy * l - 0.5 - dWall / 4,
            height: h,
            radius: rBase + 0.01
        )
        .translated(z: hBase + 0.1)
    }
}
```

- [ ] **Step 6: Run the tests**

Run: `swift test --skip-update --filter BlockTests`
Expected: 5 tests pass. If `block wall` volume is off by a visible amount, suspect corner revolve direction (quadrant order) or that `revolved` ignores negative X. Print `bounds` of each of the eight pieces to find the one that is misplaced.

---

### Task 6: BinGeometry (per-bin values, shell, compartment placement)

**Files:**
- Create: `Sources/GridfinityRebuilt/BinGeometry.swift`
- Modify: `Reference/reference.scad`, `Reference/generate.py`
- Test: `Tests/GridfinityRebuiltTests/BinGeometryTests.swift`

**Interfaces:**
- Consumes: `Dimensions`, `blockBottom`, `blockWall`, `wallProfile`, `lipelessWallProfile`, `LipStyle`.
- Produces:
  - `public struct BinGeometry: Sendable` with `gridX: Double`, `gridY: Double`, `height: Double` (`$dh`), `internalHeight: Double` (`$dh0`, 0 means default), `lipStyle: LipStyle`, `dimensions: Dimensions`; `init(gridX:gridY:height:internalHeight: = 0, lipStyle: = .regular, dimensions: = .standard)`.
  - `BinGeometry.shell(cutting: (any Geometry3D)? = nil) -> any Geometry3D`: port of `gridfinityInit`, with the cut applied to the bottom block only (as the original does with `children()`).
  - `BinGeometry.compartmentTransform(x:y:w:h:) -> Transform3D`-equivalent applied through `func placed(x: Double, y: Double, w: Double, h: Double, _ geometry: any Geometry3D) -> any Geometry3D`: port of `cut_move` (including the clamp `clp` and the `$dh0` branch).

Sources: `gridfinityInit` lines 61-83, `cut_move` 100-106, `cut_move_unsafe` 295-302 (read the whole function before implementing), utility file.

- [ ] **Step 1: Add reference cases**

Append to `reference.scad`:

```openscad
else if (case == "init_2x1x3") {
    gridfinityInit(2, 1, 16, 0, l_grid, 0) {}
}
else if (case == "init_2x1x3_lipless") {
    gridfinityInit(2, 1, 16, 0, l_grid, 1) {}
}
else if (case == "cut_move_marker") {
    // A unit cube moved to the middle of compartment (1, 0, w=1, h=1) of a 3x2 bin.
    $gxx = 3; $gyy = 2; $dh = 16; $dh0 = 0;
    cut_move(1, 0, 1, 1) translate([-0.5, -0.5, 0]) cube(1);
}
```

Add the three to `CASES`, regenerate. Note: `gridfinityInit` calls `block_bottom(h0==0?$dh-0.1:h0, ...)`, so with `h0 = 0` the bottom height is `dh - 0.1`.

- [ ] **Step 2: Write the failing tests**

`Tests/GridfinityRebuiltTests/BinGeometryTests.swift`:

```swift
import Testing
import Cadova
@testable import GridfinityRebuilt

struct BinGeometryTests {
    @Test func `regular 2x1x3 shell matches OpenSCAD`() async throws {
        let bin = BinGeometry(gridX: 2, gridY: 1, height: 16)
        expectMatches(try await measure(bin.shell()), try reference("init_2x1x3"))
    }

    @Test func `lipless 2x1x3 shell matches OpenSCAD`() async throws {
        let bin = BinGeometry(gridX: 2, gridY: 1, height: 16, lipStyle: .removed)
        expectMatches(try await measure(bin.shell()), try reference("init_2x1x3_lipless"))
    }

    @Test func `cut_move places geometry at the compartment center`() async throws {
        let bin = BinGeometry(gridX: 3, gridY: 2, height: 16)
        let marker = Box([1, 1, 1]).aligned(at: .centerXY)
        let actual = try await measure(bin.placed(x: 1, y: 0, w: 1, h: 1, marker))
        expectMatches(actual, try reference("cut_move_marker"), boundsTolerance: 0.001)
    }
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `swift test --skip-update --filter BinGeometryTests`
Expected: build error, `BinGeometry` not found.

- [ ] **Step 4: Implement**

`Sources/GridfinityRebuilt/BinGeometry.swift`. First open `cut_move_unsafe` in the utility file (lines 295-302) and confirm the translate chain before relying on the version below, which is transcribed from it:

```swift
import Cadova

/// The per-bin values OpenSCAD passes through special variables:
/// `$gxx`, `$gyy`, `$dh`, `$dh0` and `$style_lip`.
public struct BinGeometry: Sendable {
    public var gridX: Double
    public var gridY: Double
    /// Storage height of the bin (`$dh`), as returned by ``Dimensions/binHeight(_:mode:lip:snap:)``.
    public var height: Double
    /// Internal block height override (`$dh0`). Zero means "use the default".
    public var internalHeight: Double
    public var lipStyle: LipStyle
    public var dimensions: Dimensions

    public init(
        gridX: Double,
        gridY: Double,
        height: Double,
        internalHeight: Double = 0,
        lipStyle: LipStyle = .regular,
        dimensions: Dimensions = .standard
    ) {
        self.gridX = gridX
        self.gridY = gridY
        self.height = height
        self.internalHeight = internalHeight
        self.lipStyle = lipStyle
        self.dimensions = dimensions
    }

    /// `gridfinityInit`: the solid bottom block (minus `cutting`) plus the wall.
    public func shell(cutting: (any Geometry3D)? = nil) -> any Geometry3D {
        let d = dimensions
        let bottomHeight = internalHeight == 0 ? height - 0.1 : internalHeight
        let profile: any Geometry2D = lipStyle == .regular
            ? d.wallProfile(height: height)
            : d.lipelessWallProfile(height: height)

        return Union {
            d.blockBottom(height: bottomHeight, gridX: gridX, gridY: gridY)
                .subtracting {
                    if let cutting { cutting }
                }
            d.blockWall(gridX: gridX, gridY: gridY, profile: profile)
        }
    }

    /// `cut_move`: moves `geometry` from the origin to the middle of the compartment
    /// at (x, y) spanning w by h cells. Z is moved to the top of the bin's base block.
    /// Values are clamped to the bin like OpenSCAD's `clp`.
    public func placed(
        x: Double, y: Double, w: Double, h: Double,
        _ geometry: any Geometry3D
    ) -> any Geometry3D {
        let d = dimensions
        func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(max(v, lo), hi) }

        let cx = clamp(x, 0, gridX)
        let cy = clamp(y, 0, gridY)
        let cw = clamp(w, 0, gridX - x)
        let ch = clamp(h, 0, gridY - y)

        let xx = gridX * d.lGrid + d.dMagic
        let yy = gridY * d.lGrid + d.dMagic
        let z = (internalHeight == 0 ? height : internalHeight) + d.hBase

        return geometry
            .translated(
                x: (cw * xx / gridX - d.dDiv) / 2,
                y: (ch * yy / gridY - d.dDiv) / 2
            )
            .translated(x: (-xx + d.dDiv) / 2, y: (-yy + d.dDiv) / 2)
            .translated(x: cx * xx / gridX, y: cy * yy / gridY)
            .translated(z: z)
    }
}
```

The three `translated` calls apply in the order shown (innermost first), which is the reverse of how the OpenSCAD `translate` lines read top to bottom. All three are pure translations, so order does not change the result; the chain exists to mirror the source for review.

- [ ] **Step 5: Run the tests**

Run: `swift test --skip-update --filter BinGeometryTests`
Expected: 3 tests pass.

- [ ] **Step 6: Run the full suite**

Run: `swift test --skip-update`
Expected: every test in every file passes. Report the output, including the test count.

- [ ] **Step 7: Stage and stop**

The repository is not initialized and the user commits manually. Stage nothing, commit nothing. Report the file list, the passing test output, and anything that needed a tolerance or API workaround.

---

## Self-Review

- **Spec coverage:** `Standard` constants and height math (Task 1); profiles (Task 3); `Block` pieces and rounded rectangle (Tasks 3 to 5); bin shell and compartment placement (Task 6); OpenSCAD comparison on bounding box and volume (Task 2 onward); configurable `d_wall` (Tasks 1 and 6). Not in this plan, by design: pockets and cutters (`block_cutter`, tabs, scoops), `Baseplate`, magnet and screw holes, the lidded bin, the customizer. These belong to later plans in the spec's order of work.
- **Placeholder scan:** the `A` to `G` values in Task 1 Step 7 are intentionally filled from the OpenSCAD run in Step 6. All other steps contain complete code.
- **Type consistency:** `Dimensions`, `binHeight`, `HeightMode`, `LipStyle`, `baseProfile`, `wallProfile(height:)`, `lipelessWallProfile(height:)`, `blockBaseSolid`, `sweepRounded`, `blockWall(gridX:gridY:length:profile:)`, `blockBottom(height:gridX:gridY:length:)`, `BinGeometry`, `shell(cutting:)`, `placed(x:y:w:h:_:)`, `Metrics`, `measure`, `reference`, `expectMatches` are used with the same names and signatures in every task.
- **Known risk:** Cadova API spellings (`Vector3D` initializers, `bounds(of:)` async-ness, `Rectangle` anchoring, the `°` literal) are marked at the point of use with the file to check. Tolerances are 1% volume and 0.05 mm bounds; do not widen them to hide a geometry error.
