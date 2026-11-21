import Testing
import Foundation
@_spi(ParameterInternals) import Cadova
import GridfinityTestSupport
@testable import GridfinityModels

/// Checks the customizer's parameter catalog and the default build of the real
/// `gridfinity-baseplate` executable.
///
/// Cadova's customizer page starts the model executable with `CADOVA_CUSTOMIZER_REQUEST` naming a
/// JSON request. A request with `listParameters` makes the project write every model's parameters
/// (label, type, default, range, step, unit) and metadata to that path instead of building, and
/// `values` sets parameter values by key, as the page does when a visitor changes them. A request
/// with `model` and `output` builds that model into the output directory. Both work natively, so
/// these tests run the debug executable `.build/debug/gridfinity-baseplate`. `swift test` does not
/// build executables, so build it first (`swift build`). The tests fail if it is missing, but
/// cannot tell whether it is current, so build before testing after editing `main.swift`. The
/// request format is Cadova's internal contract with its page (Cadova 1.3.0,
/// `CustomizerRequest.swift`), not public API, so a Cadova update can change it.
@Suite struct CatalogTests {
    struct Catalog: Decodable {
        let title: String?
        let description: String?
        let author: String?
        let license: String?
        let models: [Model]
    }

    struct Model: Decodable {
        let name: String
        let title: String?
        let description: String?
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
        let options: [Option]?
    }

    struct Option: Decodable, Equatable {
        let label: String
        let value: String
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

    enum CatalogError: Error, CustomStringConvertible {
        case failed(Int32), missing
        var description: String {
            switch self {
            case .failed(let status): "gridfinity-baseplate exited with status \(status)"
            case .missing: "gridfinity-baseplate has not been built; run `swift build` before `swift test`"
            }
        }
    }

    static let packageRoot = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static let executable = packageRoot.appending(path: ".build/debug/gridfinity-baseplate")

    static func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "gridfinity-baseplate-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Runs the executable with the given request in `directory`.
    static func run(_ body: [String: Any], in directory: URL) throws {
        guard FileManager.default.fileExists(atPath: executable.path) else { throw CatalogError.missing }
        let request = directory.appending(path: "request.json")
        try JSONSerialization.data(withJSONObject: body).write(to: request)
        let process = Process()
        process.executableURL = executable
        process.environment = ProcessInfo.processInfo.environment
            .merging(["CADOVA_CUSTOMIZER_REQUEST": request.path]) { $1 }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CatalogError.failed(process.terminationStatus) }
    }

    /// The catalog for the given values, by key.
    static func catalog(values: [String: String] = [:]) throws -> Catalog {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appending(path: "catalog.json")
        try run(["listParameters": output.path, "values": values], in: directory)
        return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: output))
    }

    /// The single model of a catalog.
    static func baseplate(_ values: [String: String] = [:]) throws -> Model {
        let catalog = try catalog(values: values)
        try #require(catalog.models.count == 1)
        return catalog.models[0]
    }

    /// The parameter keys, found from the default catalog and, for the conditional ones, from the
    /// catalog in drawer mode with a screw together plate.
    static func keys() throws -> [String: String] {
        let first = try baseplate()
        let style = try #require(first.parameter("Plate style")).key
        let sizing = try #require(first.parameter("Size by")).key
        let all = try baseplate([style: PlateStyle.screwTogether.parameterString,
                                 sizing: PlateSizing.drawer.parameterString])
        let grid = first.parameters.map { ($0.label, $0.key) }
        return Dictionary(grid + all.parameters.map { ($0.label, $0.key) }) { a, _ in a }
    }

    static let grid = ["Grid width", "Grid depth"]
    static let drawer = ["Drawer width", "Drawer depth", "Align width", "Align depth"]
    static let holes = ["Magnet holes", "Screw holes"]
    static let screws = ["Screw diameter", "Screw head diameter", "Screw spacing", "Screws per cell"]

    @Test func `one model with the page metadata and the credits`() throws {
        let catalog = try Self.catalog()
        #expect(catalog.models.map(\.name) == ["Baseplate"])
        #expect(catalog.title == "Gridfinity Baseplate")
        #expect(catalog.author == "David Green (port)")
        #expect(catalog.license == "MIT")
        let description = try #require(catalog.description)
        #expect(description.contains("Original Gridfinity system by Zachary Freedman and Voidstar Lab LLC. Baseplate design from gridfinity-rebuilt-openscad by Kenneth Hodson. This is a port to Swift and Cadova."))
        #expect(description.contains("Plate: 5 x 5 cells, 209.5 x 209.5 mm"))
        #expect(!description.contains("\u{2014}"))
        // The single model's page shows the model's metadata, which it takes from the project
        let model = try #require(catalog.models.first)
        #expect(model.title == "Gridfinity Baseplate")
        #expect(model.description == description)
    }

    @Test func `the description reports the plate the parameters give`() throws {
        let keys = try Self.keys()
        let small = try Self.catalog(values: [try #require(keys["Grid width"]): "3",
                                              try #require(keys["Grid depth"]): "2"])
        #expect(small.description?.contains("Plate: 3 x 2 cells, 125.5 x 83.5 mm") == true)
        let drawer = try Self.catalog(values: [try #require(keys["Size by"]): PlateSizing.drawer.parameterString,
                                               try #require(keys["Drawer width"]): "300",
                                               try #require(keys["Drawer depth"]): "200.25"])
        #expect(drawer.description?.contains("Plate: 7 x 4 cells, 300 x 200.25 mm") == true)
    }

    @Test(arguments: PlateStyle.allCases)
    func `the controls follow the plate style`(_ style: PlateStyle) throws {
        let keys = try Self.keys()
        let model = try Self.baseplate([try #require(keys["Plate style"]): style.parameterString])
        let expected: [String]
        switch style {
        case .thin: expected = ["Plate style", "Size by"] + Self.grid + ["Color"]
        case .weighted, .skeletonized: expected = ["Plate style", "Size by"] + Self.grid + Self.holes + ["Color"]
        case .screwTogether, .screwTogetherMinimal:
            expected = ["Plate style", "Size by"] + Self.grid + Self.holes + Self.screws + ["Color"]
        }
        #expect(model.labels == expected, "\(style)")
        // One declaration each, whatever the style
        for p in model.parameters { #expect(p.key == keys[p.label], "\(style) \(p.label)") }
    }

    @Test func `the controls follow the sizing mode`() throws {
        let keys = try Self.keys()
        let sizing = try #require(keys["Size by"])
        let grid = try Self.baseplate([sizing: PlateSizing.gridCells.parameterString])
        #expect(grid.labels == ["Plate style", "Size by"] + Self.grid + ["Color"])
        let drawer = try Self.baseplate([sizing: PlateSizing.drawer.parameterString])
        #expect(drawer.labels == ["Plate style", "Size by"] + Self.drawer + ["Color"])
        // Every control together, in order
        let all = try Self.baseplate([sizing: PlateSizing.drawer.parameterString,
                                      try #require(keys["Plate style"]): PlateStyle.screwTogetherMinimal.parameterString])
        #expect(all.labels == ["Plate style", "Size by"] + Self.drawer + Self.holes + Self.screws + ["Color"])
    }

    @Test func `choices list the options in order with their display names`() throws {
        let keys = try Self.keys()
        let model = try Self.baseplate([try #require(keys["Plate style"]): PlateStyle.weighted.parameterString])
        let style = try #require(model.parameter("Plate style"))
        #expect(style.type == "choice")
        #expect(style.options == [Option(label: "Thin", value: "0"), Option(label: "Weighted", value: "1"),
                                  Option(label: "Skeletonized", value: "2"), Option(label: "Screw together", value: "3"),
                                  Option(label: "Screw together minimal", value: "4")])
        let sizing = try #require(model.parameter("Size by"))
        #expect(sizing.options == [Option(label: "Grid cells", value: "grid_cells"),
                                   Option(label: "Drawer size", value: "drawer")])
        let holes = try #require(model.parameter("Screw holes"))
        #expect(holes.options == [Option(label: "None", value: "0"), Option(label: "Countersink", value: "1"),
                                  Option(label: "Counterbore", value: "2")])
    }

    @Test func `defaults, ranges, steps, units and types come from the model library`() throws {
        let keys = try Self.keys()
        // Every parameter, from the default catalog and the one that lists all controls
        var all: [String: Parameter] = [:]
        for model in [try Self.baseplate(),
                      try Self.baseplate([try #require(keys["Size by"]): PlateSizing.drawer.parameterString,
                                          try #require(keys["Plate style"]): PlateStyle.screwTogether.parameterString])] {
            for p in model.parameters { all[p.label] = p }
        }
        #expect(all.count == 15)
        let d = BaseplateInput.defaults
        func value(_ label: String) -> JSONValue? { all[label]?.default }
        #expect(value("Plate style") == .string(d.plateStyle.parameterString))
        #expect(value("Size by") == .string(d.sizing.parameterString))
        #expect(value("Grid width") == .number(Double(d.gridX)))
        #expect(value("Grid depth") == .number(Double(d.gridY)))
        #expect(value("Drawer width") == .number(d.drawerX))
        #expect(value("Drawer depth") == .number(d.drawerY))
        #expect(value("Align width") == .number(d.fitX))
        #expect(value("Align depth") == .number(d.fitY))
        #expect(value("Magnet holes") == .bool(d.magnetHoles))
        #expect(value("Screw holes") == .string(d.screwHoles.parameterString))
        #expect(value("Screw diameter") == .number(d.screwDiameter))
        #expect(value("Screw head diameter") == .number(d.screwHeadDiameter))
        #expect(value("Screw spacing") == .number(d.screwSpacing))
        #expect(value("Screws per cell") == .number(Double(d.screwsPerCell)))
        #expect(value("Color") == .string(d.color.parameterString))
        #expect(d.color.parameterString == "#c8cdd6")
        #expect(d.plateStyle == .thin)

        func range(_ label: String) -> ClosedRange<Double>? {
            guard let p = all[label], let lo = p.minimum, let hi = p.maximum else { return nil }
            return lo...hi
        }
        func doubles(_ r: ClosedRange<Int>) -> ClosedRange<Double> { Double(r.lowerBound)...Double(r.upperBound) }
        #expect(range("Grid width") == doubles(BaseplateLimits.gridSize))
        #expect(range("Grid depth") == doubles(BaseplateLimits.gridSize))
        #expect(range("Drawer width") == BaseplateLimits.drawerSize)
        #expect(range("Drawer depth") == BaseplateLimits.drawerSize)
        #expect(range("Align width") == BaseplateLimits.fit)
        #expect(range("Align depth") == BaseplateLimits.fit)
        #expect(range("Screw diameter") == BaseplateLimits.screwDiameter)
        #expect(range("Screw head diameter") == BaseplateLimits.screwHeadDiameter)
        #expect(range("Screw spacing") == BaseplateLimits.screwSpacing)
        #expect(range("Screws per cell") == doubles(BaseplateLimits.screwsPerCell))
        #expect(all["Align width"]?.step == 0.1 && all["Align depth"]?.step == 0.1)

        let units = ["Grid width": "cells", "Grid depth": "cells", "Drawer width": "mm", "Drawer depth": "mm",
                     "Screw diameter": "mm", "Screw head diameter": "mm", "Screw spacing": "mm",
                     "Screws per cell": "screws"]
        for (label, p) in all { #expect(p.unit == units[label], "\(label)") }

        let types = ["Plate style": "choice", "Size by": "choice", "Screw holes": "choice",
                     "Grid width": "integer", "Grid depth": "integer", "Screws per cell": "integer",
                     "Magnet holes": "boolean", "Color": "color"]
        for (label, p) in all { #expect(p.type == (types[label] ?? "number"), "\(label)") }
    }

    /// The bounds and the color of the vertices in a 3MF the executable wrote.
    static func meshBounds(of file: URL) throws -> (min: [Double], max: [Double], xml: String) {
        let unzip = Process()
        unzip.executableURL = URL(filePath: "/usr/bin/unzip")
        unzip.arguments = ["-p", file.path, "3D/3dmodel.model"]
        let pipe = Pipe()
        unzip.standardOutput = pipe
        try unzip.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        unzip.waitUntilExit()
        let xml = String(decoding: data, as: UTF8.self)
        var lo = [Double.infinity, .infinity, .infinity], hi = [-Double.infinity, -.infinity, -.infinity]
        let vertex = /<vertex x="([^"]+)" y="([^"]+)" z="([^"]+)"/
        for match in xml.matches(of: vertex) {
            let v = [Double(match.1)!, Double(match.2)!, Double(match.3)!]
            for i in 0..<3 { lo[i] = min(lo[i], v[i]); hi[i] = max(hi[i], v[i]) }
        }
        return (lo, hi, xml)
    }

    @Test(arguments: [PlateStyle.thin, .weighted, .screwTogether])
    func `the download sits on the bed`(_ style: PlateStyle) async throws {
        let keys = try Self.keys()
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Self.run(["model": "Baseplate", "output": directory.path,
                      "values": [try #require(keys["Plate style"]): style.parameterString]], in: directory)
        let file = directory.appending(path: "Baseplate.3mf")
        let (lo, hi, xml) = try Self.meshBounds(of: file)

        var input = BaseplateInput.defaults
        input.plateStyle = style
        let design = BaseplateDesign(input.configuration)
        #expect(abs(lo[2]) < 1e-6, "\(style)")
        #expect(abs(hi[2] - (4.4 + design.floorDepth)) < 1e-6, "\(style)")
        #expect(abs((hi[0] - lo[0]) - design.width) < 1e-6 && abs((hi[1] - lo[1]) - design.depth) < 1e-6, "\(style)")
        #expect(xml.contains(#"name="Baseplate""#))
        #expect(xml.contains(##"color="#c8cdd6""##))

        // The download is the design moved up by its floor depth, with the same volume
        let placed = try await measure(design.geometry().translated(z: design.floorDepth))
        let original = try await measure(design.geometry())
        #expect(abs(placed.volume - original.volume) <= 1e-9 * original.volume)
        #expect(abs(placed.min.z) < 1e-9 && abs(placed.max.z - (4.4 + design.floorDepth)) < 1e-9)
    }
}
