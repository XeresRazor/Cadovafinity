import Testing
import Foundation
import Cadova
import GridfinityRebuilt
import GridfinityTestSupport
@testable import LiddedBinModel

/// Measures with Cadova's default segmentation and the same (default) environment as
/// Sources/lidded-bin/main.swift, with `cornerSegments == nil`.
struct ProductionTests {
    let refs = ReferenceSet.containing()
    let production = LiddedBinDesign(LiddedBinConfiguration())

    func produce(_ g: any Geometry3D) async throws -> Metrics {
        try await ModelFileGenerator.evaluate { evaluator in
            let bounds = await evaluator.bounds(of: g)
            let volume = await evaluator.measurements(of: g).volume
            return Metrics(volume: volume, min: bounds?.minimum ?? .zero, max: bounds?.maximum ?? .zero)
        }
    }

    func symmetricDifference(_ g: any Geometry3D, _ name: String) async throws -> Double {
        let theirs = Import(model: refs.stlURL(name))
        let difference = Union {
            g.subtracting { theirs }
            theirs.subtracting { g }
        }
        return try await ModelFileGenerator.evaluate { evaluator in
            await evaluator.measurements(of: difference).volume
        }
    }

    // Measured (default segmentation, volume vs reference.json relative / symmetric difference):
    // bin: volume +0.313 mm^3 (7.8e-6 relative; limit 2.4e-5), symmetric difference 3.376 mm^3
    //   (limit 5.0, capped: 3x would be 10.1; the difference is corner tessellation at Cadova's
    //   default segmentation vs the OpenSCAD STL).
    // lid: volume -0.148 mm^3 (2.3e-5 relative; limit 7e-5), symmetric difference 0.581 mm^3
    //   (limit 1.8). Lid bounds min z is -0.2 (lid_thickness less the position tolerance).
    // closed bin/lid interference: 1.39207 mm^3 (limit 1.392 +/- 0.2).

    @Test func `production bin matches the reference`() async throws {
        let m = try await produce(production.geometry(for: .bin))
        let ref = try refs.metrics("bin_2x2x3_xy")
        let problems = compare(m, ref, volumeTolerance: 2.4e-5, boundsTolerance: 0.05)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func `production lid matches the reference`() async throws {
        let m = try await produce(production.geometry(for: .lid))
        let ref = try refs.metrics("lid_2x2x3_xy")
        let problems = compare(m, ref, volumeTolerance: 7e-5, boundsTolerance: 0.05)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func `production bin symmetric difference`() async throws {
        let v = try await symmetricDifference(production.geometry(for: .bin), "bin_2x2x3_xy")
        #expect(v < 5.0, "symmetric difference \(v)")
    }

    @Test func `production lid symmetric difference`() async throws {
        let v = try await symmetricDifference(production.geometry(for: .lid), "lid_2x2x3_xy")
        #expect(v < 1.8, "symmetric difference \(v)")
    }

    @Test func `production closed interference`() async throws {
        let overlap = try await produce(
            production.binSolid(pockets: production.pockets()).intersecting { production.lidBody() })
        #expect(abs(overlap.volume - 1.392) < 0.2, "overlap \(overlap.volume)")
    }

    @Test func `div multiple at or below zero is clamped to one`() async throws {
        func volume(_ m: Double) async throws -> Double {
            let d = design { $0.compartmentPattern = .multiSize; $0.divMultiple = m }
            let p = try #require(d.pockets())
            return try await measure(p).volume
        }
        let one = try await volume(1)
        #expect(try await volume(0) == one)
        #expect(try await volume(-3) == one)
    }
}
