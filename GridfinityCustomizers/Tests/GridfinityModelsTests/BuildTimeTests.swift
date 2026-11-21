import Testing
import Foundation
import Cadova
@testable import GridfinityModels

/// Opt-in native build-time benchmark. Run with
/// `GRIDFINITY_BENCH=1 swift test --skip-update --filter BuildTime`.
/// Uses a fresh `ModelFileGenerator.evaluate` per run and measures bounds and volume so the whole
/// tree is evaluated. `GRIDFINITY_SEG=1` adds the segmentation comparison.
struct BuildTimeTests {
    struct Case {
        var label: String
        var style: PlateStyle
        var gx = 5, gy = 5
        var drawer: (Double, Double)? = nil
        var magnets = true
        var holes: ScrewHoleStyle = .counterbore
        var screws = 1
        /// Extra cases skip validation so they can probe beyond the limits.
        var raw = false

        var configuration: BaseplateConfiguration {
            var c = BaseplateConfiguration()
            c.plateStyle = style; c.magnetHoles = magnets; c.screwHoles = holes; c.screwsPerCell = screws
            if let drawer { c.gridX = 0; c.gridY = 0; c.drawerX = drawer.0; c.drawerY = drawer.1 }
            else { c.gridX = gx; c.gridY = gy }
            return raw ? c : c.validated()
        }
    }

    static let cases: [Case] = [
        Case(label: "1x1 thin", style: .thin, gx: 1, gy: 1),
        Case(label: "5x5 weighted", style: .weighted),
        Case(label: "5x5 skeletonized, magnets, counterbore", style: .skeletonized),
        Case(label: "6x6 screw together, 2 screws", style: .screwTogether, gx: 6, gy: 6, screws: 2),
        Case(label: "10x10 skeletonized", style: .skeletonized, gx: 10, gy: 10),
        Case(label: "10x10 weighted", style: .weighted, gx: 10, gy: 10),
        Case(label: "10x10 screw together minimal", style: .screwTogetherMinimal, gx: 10, gy: 10),
        Case(label: "drawer 500 x 400 weighted", style: .weighted, drawer: (500, 400)),
    ]

    /// Extra cases from `GRIDFINITY_EXTRA`: semicolon separated `style,gx,gy,screws`
    /// (style is the raw value 0 to 4); `GRIDFINITY_EXTRA_ONLY=1` skips the standard list.
    static var extraCases: [Case] {
        guard let s = ProcessInfo.processInfo.environment["GRIDFINITY_EXTRA"] else { return [] }
        return s.split(separator: ";").compactMap { item in
            let f = item.split(separator: ",").compactMap { Int($0) }
            guard f.count == 4, let style = PlateStyle(rawValue: f[0]) else { return nil }
            return Case(label: "\(f[1])x\(f[2]) \(style.displayName), \(f[3]) screws", style: style,
                        gx: f[1], gy: f[2], screws: f[3], raw: true)
        }
    }

    static func seconds(_ d: Duration) -> Double {
        Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
    }

    func run(_ c: Case, segmentation: Bool = false) async throws -> (seconds: Double, volume: Double) {
        let base = BaseplateDesign(c.configuration).geometry()
        let g: any Geometry3D = segmentation ? base.withSegmentation(minAngle: 8°, minSize: 0.25) : base
        var volume = 0.0
        let elapsed = try await ContinuousClock().measure {
            volume = try await ModelFileGenerator.evaluate { evaluator in
                _ = await evaluator.bounds(of: g)
                return await evaluator.measurements(of: g).volume
            }
        }
        return (Self.seconds(elapsed), volume)
    }

    func median(_ c: Case, segmentation: Bool = false) async throws -> (median: Double, runs: [Double], volume: Double) {
        let n = Int(ProcessInfo.processInfo.environment["GRIDFINITY_RUNS"] ?? "3") ?? 3
        var times: [Double] = []
        var volume = 0.0
        for _ in 0..<n {
            let r = try await run(c, segmentation: segmentation)
            times.append(r.seconds); volume = r.volume
            if r.seconds > 120 { break }
        }
        return (times.sorted()[times.count / 2], times, volume)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["GRIDFINITY_BENCH"] == "1"))
    func `native build times`() async throws {
        let only = ProcessInfo.processInfo.environment["GRIDFINITY_EXTRA_ONLY"] == "1"
        for c in (only ? [] : Self.cases) + Self.extraCases {
            let r = try await median(c)
            let runs = r.runs.map { String(format: "%.2f", $0) }.joined(separator: " ")
            let cfg = BaseplateDesign(c.configuration)
            print("BENCH | \(c.label) | cells \(cfg.cellsX)x\(cfg.cellsY) | median \(String(format: "%.2f", r.median)) s | runs \(runs) | volume \(String(format: "%.1f", r.volume))")
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["GRIDFINITY_BENCH"] == "1"))
    func `segmentation comparison`() async throws {
        for c in Self.cases where c.gx == 5 && c.gy == 5 && c.drawer == nil && c.style != .thin {
            let a = try await median(c)
            let b = try await median(c, segmentation: true)
            let rel = abs(a.volume - b.volume) / a.volume
            print("SEG | \(c.label) | default \(String(format: "%.2f", a.median)) s vol \(String(format: "%.1f", a.volume)) | fa8 fs0.25 \(String(format: "%.2f", b.median)) s vol \(String(format: "%.1f", b.volume)) | rel diff \(rel) | ratio \(a.median / b.median)")
        }
    }
}
