import Foundation
import Cadova

public enum ReferenceError: Error, CustomStringConvertible {
    case missing(String)
    case malformed(String)
    case missingSTL(String)
    case packageNotFound(String)

    public var description: String {
        switch self {
        case .missing(let n): "no reference case named \(n) in reference.json"
        case .malformed(let n): "reference case \(n) has malformed min/max arrays"
        case .missingSTL(let p): "reference STL not found at \(p); run `python3 -I Reference/generate.py`"
        case .packageNotFound(let f): "no Package.swift found above \(f)"
        }
    }
}

public struct ReferenceSet: Sendable {
    public let packageDirectory: URL

    public init(packageDirectory: URL) {
        self.packageDirectory = packageDirectory
    }

    /// Walks up from `file` to the directory holding Package.swift.
    public static func containing(file: String = #filePath) -> ReferenceSet {
        var dir = URL(fileURLWithPath: file).deletingLastPathComponent()
        while dir.path != "/" {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                return ReferenceSet(packageDirectory: dir)
            }
            dir = dir.deletingLastPathComponent()
        }
        // Fall back to the file's own directory; metrics()/stlURL() will then fail with a clear error.
        return ReferenceSet(packageDirectory: URL(fileURLWithPath: file).deletingLastPathComponent())
    }

    private var referenceDirectory: URL { packageDirectory.appendingPathComponent("Reference") }

    public func stlURL(_ name: String) -> URL {
        referenceDirectory.appendingPathComponent("stl/\(name).stl")
    }

    private struct Raw: Decodable {
        var volume: Double
        var min: [Double]
        var max: [Double]
    }

    public func metrics(_ name: String) throws -> Metrics {
        let url = referenceDirectory.appendingPathComponent("reference.json")
        let all = try JSONDecoder().decode([String: Raw].self, from: Data(contentsOf: url))
        guard let raw = all[name] else { throw ReferenceError.missing(name) }
        guard raw.min.count == 3, raw.max.count == 3 else { throw ReferenceError.malformed(name) }
        return Metrics(
            volume: raw.volume,
            min: Vector3D(raw.min[0], raw.min[1], raw.min[2]),
            max: Vector3D(raw.max[0], raw.max[1], raw.max[2])
        )
    }
}
