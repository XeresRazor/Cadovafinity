import Foundation
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

struct ReferenceResolutionTests {
    @Test func `expectMatchesReference resolves references from the caller without an argument`() async throws {
        try await expectMatchesReference("block_base_solid", Dimensions.standard.blockBaseSolid())
    }

    @Test func `containing(file:) resolves the package that holds the given path`() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("fakepkg-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root.appendingPathComponent("Reference"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("Tests/FakeTests"), withIntermediateDirectories: true)
        try Data("// fake".utf8).write(to: root.appendingPathComponent("Package.swift"))
        let json = #"{"only_here": {"volume": 1.0, "min": [0,0,0], "max": [1,1,1]}}"#
        try Data(json.utf8).write(to: root.appendingPathComponent("Reference/reference.json"))

        let fake = ReferenceSet.containing(file: root.appendingPathComponent("Tests/FakeTests/X.swift").path)
        #expect(fake.packageDirectory.standardizedFileURL.resolvingSymlinksInPath()
                == root.standardizedFileURL.resolvingSymlinksInPath())
        #expect(try fake.metrics("only_here").volume == 1.0)
        #expect(throws: ReferenceError.self) { try fake.metrics("block_base_solid") }

        let ours = ReferenceSet.containing()
        #expect(ours.packageDirectory.standardizedFileURL != fake.packageDirectory.standardizedFileURL)
        #expect(throws: ReferenceError.self) { try ours.metrics("only_here") }
    }
}
