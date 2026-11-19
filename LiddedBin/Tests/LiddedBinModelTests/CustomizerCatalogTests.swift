import Testing
import Foundation
import Cadova
@testable import LiddedBinModel

/// Checks the customizer's parameter catalog of the real `lidded-bin` executable.
///
/// Cadova's customizer page starts the model executable with `CADOVA_CUSTOMIZER_REQUEST` naming a
/// JSON request. A request with `listParameters` makes the project write every model's parameters
/// (label, type, default, range, step, unit) to that path instead of building, and `values` sets
/// parameter values by key, as the page does when a visitor changes them. That works natively,
/// so these tests run the debug executable `.build/debug/lidded-bin`. `swift test` does not build
/// executables, so build it first (`swift build`). The tests fail if it is missing, but cannot tell
/// whether it is current, so build before testing after editing `main.swift`. The
/// request format is Cadova's internal contract with its page (Cadova 1.3.0,
/// `CustomizerRequest.swift`), not public API, so a Cadova update can change it.
struct CustomizerCatalogTests {
    struct Catalog: Decodable {
        let title: String?
        let author: String?
        let license: String?
        let models: [Model]
    }

    struct Model: Decodable {
        let name: String
        let parameters: [Parameter]
        var labels: [String] { parameters.map(\.label) }
        func parameter(_ label: String) -> Parameter? { parameters.first { $0.label == label } }
    }

    struct Parameter: Decodable {
        let key: String
        let label: String
        let type: String
        let `default`: JSONValue
        let minimum: Double?
        let maximum: Double?
        let step: Double?
        let unit: String?
    }

    enum JSONValue: Decodable, Equatable {
        case number(Double), bool(Bool), string(String)
        init(from decoder: any Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let b = try? c.decode(Bool.self) { self = .bool(b) }
            else if let d = try? c.decode(Double.self) { self = .number(d) }
            else { self = .string(try c.decode(String.self)) }
        }
    }

    static let packageRoot = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static let executable = packageRoot.appending(path: ".build/debug/lidded-bin")

    /// Runs the executable with a `listParameters` request and the given values, by key.
    static func catalog(values: [String: String] = [:]) throws -> Catalog {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "lidded-bin-catalog-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appending(path: "catalog.json")
        let request = directory.appending(path: "request.json")
        let body: [String: Any] = ["listParameters": output.path, "values": values]
        try JSONSerialization.data(withJSONObject: body).write(to: request)

        let process = Process()
        process.executableURL = executable
        process.environment = ProcessInfo.processInfo.environment
            .merging(["CADOVA_CUSTOMIZER_REQUEST": request.path]) { $1 }
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CatalogError.failed(process.terminationStatus)
        }
        return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: output))
    }

    enum CatalogError: Error, CustomStringConvertible {
        case failed(Int32), missing
        var description: String {
            switch self {
            case .failed(let status): "lidded-bin exited with status \(status)"
            case .missing: "lidded-bin has not been built; run `swift build` before `swift test`"
            }
        }
    }

    static func requireExecutable() throws {
        guard FileManager.default.fileExists(atPath: executable.path) else { throw CatalogError.missing }
    }

    static let binOnly = ["Interior style", "Compartments", "Dividers X", "Dividers Y"]
    static let shared = ["Grid width", "Grid depth", "Height style", "Internal block height",
                         "Lid direction", "Lip grips"]
    static let fit = ["Lid clearance", "Lid chamfer", "Detent interference"]

    func models(_ catalog: Catalog) throws -> (bin: Model, lid: Model, open: Model) {
        let byName = Dictionary(uniqueKeysWithValues: catalog.models.map { ($0.name, $0) })
        return (try #require(byName["Bin"]), try #require(byName["Lid"]), try #require(byName["Bin and lid (open)"]))
    }

    @Test func `three tabs with the attribution`() throws {
        try Self.requireExecutable()
        let catalog = try Self.catalog()
        #expect(catalog.models.map(\.name) == ["Bin", "Lid", "Bin and lid (open)"])
        #expect(catalog.author == "smkent (original design), ported by XeresRazor")
        #expect(catalog.license == "CC BY 4.0")
        #expect(catalog.title == "Gridfinity Lidded Bin")
    }

    @Test func `bin-only parameters are not on the lid tab`() throws {
        try Self.requireExecutable()
        let (bin, lid, open) = try models(try Self.catalog())
        for label in Self.shared {
            #expect(bin.labels.contains(label) && lid.labels.contains(label) && open.labels.contains(label), "\(label)")
        }
        for label in Self.binOnly {
            #expect(bin.labels.contains(label) && open.labels.contains(label), "\(label)")
            #expect(!lid.labels.contains(label), "\(label)")
        }
        #expect(lid.labels == ["Grid width", "Grid depth", "Height style", "Height",
                               "Internal block height", "Lid direction", "Lip grips"] + Self.fit)
        // Both parts depend on every lid fit control, so every tab lists them after Lip grips,
        // with one declaration each
        for tab in [bin, lid, open] {
            let start = try #require(tab.labels.firstIndex(of: "Lip grips"))
            #expect(Array(tab.labels[(start + 1)...].prefix(3)) == Self.fit, "\(tab.name)")
        }
        for label in Self.fit {
            #expect(bin.parameter(label)?.key == lid.parameter(label)?.key, "\(label)")
            #expect(open.parameter(label)?.key == lid.parameter(label)?.key, "\(label)")
        }
        // Bin and open assembly share one declaration of each bin-only parameter
        for label in Self.binOnly {
            #expect(bin.parameter(label)?.key == open.parameter(label)?.key)
        }
    }

    @Test func `height controls follow the height style`() throws {
        try Self.requireExecutable()
        let defaults = try Self.catalog()
        let style = try #require(try models(defaults).bin.parameter("Height style"))
        let heights = ["Height", "Internal height", "Overall height"]
        let expected: [(HeightStyle, String, Bool)] = [
            (.sevenMillimeterUnits, "Height", false),
            (.internalHeight, "Internal height", true),
            (.externalHeight, "Overall height", true),
        ]
        for (value, height, snap) in expected {
            let catalog = try Self.catalog(values: [style.key: value.parameterString])
            let (bin, lid, open) = try models(catalog)
            for tab in [bin, lid, open] {
                #expect(tab.labels.filter(heights.contains) == [height], "\(value) \(tab.name)")
                #expect(tab.labels.contains("Snap to 7 mm") == snap, "\(value) \(tab.name)")
            }
        }
    }

    @Test func `size multiple appears only for two sizes`() throws {
        try Self.requireExecutable()
        let defaults = try Self.catalog()
        let (bin, lid, open) = try models(defaults)
        #expect(!bin.labels.contains("Size multiple") && !open.labels.contains("Size multiple"))
        let pattern = try #require(bin.parameter("Compartments"))
        let multi = try models(try Self.catalog(values: [pattern.key: CompartmentPattern.multiSize.parameterString]))
        #expect(multi.bin.labels.contains("Size multiple") && multi.open.labels.contains("Size multiple"))
        #expect(!multi.lid.labels.contains("Size multiple") && !lid.labels.contains("Size multiple"))
        #expect(multi.bin.parameter("Size multiple")?.key == multi.open.parameter("Size multiple")?.key)
    }

    @Test func `parameter defaults and ranges come from the model library`() throws {
        try Self.requireExecutable()
        let d = LiddedBinInput.defaults
        let style = try #require(try models(try Self.catalog()).bin.parameter("Height style"))
        // Collect every parameter, including the conditional ones, across the height styles
        var all: [String: Parameter] = [:]
        for s in HeightStyle.allCases {
            var values = [style.key: s.parameterString]
            let catalog = try Self.catalog(values: values)
            let pattern = try #require(try models(catalog).bin.parameter("Compartments"))
            values[pattern.key] = CompartmentPattern.multiSize.parameterString
            for model in try Self.catalog(values: values).models {
                for p in model.parameters { all[p.label] = p }
            }
        }
        func number(_ label: String) -> Double? {
            if case .number(let v) = all[label]?.default { v } else { nil }
        }
        func string(_ label: String) -> String? {
            if case .string(let v) = all[label]?.default { v } else { nil }
        }
        func bool(_ label: String) -> Bool? {
            if case .bool(let v) = all[label]?.default { v } else { nil }
        }
        #expect(number("Grid width") == Double(d.gridX))
        #expect(number("Grid depth") == Double(d.gridY))
        #expect(string("Height style") == d.heightStyle.parameterString)
        #expect(number("Height") == d.unitsHeight)
        #expect(number("Internal height") == d.internalHeight)
        #expect(number("Overall height") == d.externalHeight)
        #expect(bool("Snap to 7 mm") == d.snapHeight)
        #expect(number("Internal block height") == d.internalBlockHeight)
        #expect(string("Lid direction") == d.lidOrientation.parameterString)
        #expect(string("Lip grips") == d.lipGrips.parameterString)
        #expect(string("Interior style") == d.interiorStyle.parameterString)
        #expect(string("Compartments") == d.compartmentPattern.parameterString)
        #expect(number("Dividers X") == Double(d.divX))
        #expect(number("Dividers Y") == Double(d.divY))
        #expect(number("Size multiple") == d.divMultiple)
        #expect(number("Lid clearance") == d.lidClearance)
        #expect(number("Lid chamfer") == d.lidChamfer)
        #expect(number("Detent interference") == d.detentInterference)
        #expect(d.detentInterference == 0.25)
        #expect(all.count == 18)

        func range(_ label: String) -> ClosedRange<Double>? {
            guard let p = all[label], let lo = p.minimum, let hi = p.maximum else { return nil }
            return lo...hi
        }
        func doubles(_ r: ClosedRange<Int>) -> ClosedRange<Double> { Double(r.lowerBound)...Double(r.upperBound) }
        #expect(range("Grid width") == doubles(LiddedBinLimits.gridSize))
        #expect(range("Grid depth") == doubles(LiddedBinLimits.gridSize))
        #expect(range("Height") == LiddedBinLimits.unitsHeight)
        #expect(range("Internal height") == LiddedBinLimits.internalHeight)
        #expect(range("Overall height") == LiddedBinLimits.externalHeight)
        #expect(range("Dividers X") == doubles(LiddedBinLimits.dividers))
        #expect(range("Dividers Y") == doubles(LiddedBinLimits.dividers))
        #expect(range("Size multiple") == LiddedBinLimits.divMultiple)
        #expect(range("Lid clearance") == LiddedBinLimits.lidClearance)
        #expect(range("Lid chamfer") == LiddedBinLimits.lidChamfer)
        #expect(range("Detent interference") == LiddedBinLimits.detentInterference)
        #expect(LiddedBinLimits.detentInterference == 0.05...0.6)
        #expect(all["Lid clearance"]?.step == 0.05)
        #expect(all["Lid chamfer"]?.step == 0.1)
        #expect(all["Lid chamfer"]?.unit == "mm")
        #expect(all["Detent interference"]?.step == 0.05)
        #expect(all["Detent interference"]?.unit == "mm")
        #expect(all["Size multiple"]?.step == 0.5)
    }
}
