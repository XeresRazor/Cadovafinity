import Testing
import Foundation
import Cadova
import GridfinityRebuilt
@testable import LiddedBinModel

/// Opt-in native build-time benchmark. Run with
/// `LIDDED_BIN_BENCH=1 swift test --skip-update --filter BuildTime`.
/// Uses the production setting (Cadova's default segmentation, `cornerSegments == nil`) and a
/// fresh `ModelFileGenerator.evaluate` per run.
struct BuildTimeTests {
    struct Case {
        var gx: Int, gy: Int, gz: Double, dx: Int, dy: Int
        var part: LiddedBinPart
        var label: String { "\(gx)x\(gy)x\(Int(gz)) div \(dx)x\(dy) \(part.rawValue)" }
    }

    static let cases: [Case] = [
        Case(gx: 1, gy: 1, gz: 1, dx: 1, dy: 1, part: .bin),
        Case(gx: 2, gy: 2, gz: 3, dx: 6, dy: 6, part: .bin),
        Case(gx: 3, gy: 3, gz: 3, dx: 6, dy: 6, part: .bin),
        Case(gx: 4, gy: 4, gz: 4, dx: 6, dy: 6, part: .bin),
        Case(gx: 6, gy: 6, gz: 3, dx: 6, dy: 6, part: .bin),
        Case(gx: 6, gy: 6, gz: 6, dx: 6, dy: 6, part: .bin),
        Case(gx: 6, gy: 6, gz: 6, dx: 12, dy: 12, part: .bin),
        Case(gx: 6, gy: 6, gz: 12, dx: 6, dy: 6, part: .bin),
        Case(gx: 2, gy: 2, gz: 3, dx: 6, dy: 6, part: .lid),
        Case(gx: 4, gy: 4, gz: 4, dx: 6, dy: 6, part: .lid),
        Case(gx: 6, gy: 6, gz: 3, dx: 6, dy: 6, part: .lid),
        Case(gx: 2, gy: 2, gz: 3, dx: 6, dy: 6, part: .bothOpen),
        Case(gx: 6, gy: 6, gz: 3, dx: 6, dy: 6, part: .bothOpen),
    ]

    /// Extra corner cases, from the `LIDDED_BIN_EXTRA` environment variable:
    /// semicolon separated `gx,gy,gz,dx,dy,part`.
    static var extraCases: [Case] {
        guard let s = ProcessInfo.processInfo.environment["LIDDED_BIN_EXTRA"] else { return [] }
        return s.split(separator: ";").compactMap { item in
            let f = item.split(separator: ",").map(String.init)
            guard f.count == 6, let gx = Int(f[0]), let gy = Int(f[1]), let gz = Double(f[2]),
                  let dx = Int(f[3]), let dy = Int(f[4]), let part = LiddedBinPart(rawValue: f[5])
            else { return nil }
            return Case(gx: gx, gy: gy, gz: gz, dx: dx, dy: dy, part: part)
        }
    }

    func run(_ c: Case) async throws -> (seconds: Double, volume: Double) {
        var config = LiddedBinConfiguration()
        config.gridX = c.gx; config.gridY = c.gy; config.gridZ = c.gz
        config.divX = c.dx; config.divY = c.dy
        let design = LiddedBinDesign(config)
        let g = design.geometry(for: c.part)
        let clock = ContinuousClock()
        var volume = 0.0
        let elapsed = try await clock.measure {
            volume = try await ModelFileGenerator.evaluate { evaluator in
                _ = await evaluator.bounds(of: g)
                return await evaluator.measurements(of: g).volume
            }
        }
        let comps = elapsed.components
        return (Double(comps.seconds) + Double(comps.attoseconds) / 1e18, volume)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LIDDED_BIN_BENCH"] == "1"))
    func `native build times`() async throws {
        let runs = Int(ProcessInfo.processInfo.environment["LIDDED_BIN_RUNS"] ?? "3") ?? 3
        let all = ProcessInfo.processInfo.environment["LIDDED_BIN_EXTRA_ONLY"] == "1"
            ? Self.extraCases : Self.cases + Self.extraCases
        for c in all {
            var times: [Double] = []
            var volume = 0.0
            for _ in 0..<runs {
                let r = try await run(c)
                times.append(r.seconds)
                volume = r.volume
                if r.seconds > 120 { break }
            }
            let median = times.sorted()[times.count / 2]
            let all = times.map { String(format: "%.2f", $0) }.joined(separator: " ")
            print("BENCH | \(c.label) | median \(String(format: "%.2f", median)) s | runs \(all) | volume \(String(format: "%.1f", volume))")
        }
    }
}
