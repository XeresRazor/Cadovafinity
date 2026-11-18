import Cadova

/// Ports OpenSCAD `sweep_rounded`: sweeps a profile around a rounded rectangle of the given
/// width (X) and height (Y), measured to the profile's origin.
///
/// The profile's X axis is the outward distance from the path and its Y axis is Z.
/// `width` (X) and `height` (Y) are in mm.
///
/// OpenSCAD makes a 90 degree `rotate_extrude` with a quarter of the full segment count, while
/// Cadova's `revolved(in:)` uses the full count for any angle. When `cornerSegments` is set,
/// the corner revolves use that count; the profile (and everything else) keeps the ambient
/// segmentation.
public func sweepRounded(
    width w: Double, height h: Double,
    profile: any Geometry2D,
    cornerSegments: Int? = nil
) -> any Geometry3D {
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

    @Sendable func corner(_ sx: Double, _ sy: Double, from start: Angle) -> any Geometry3D {
        let revolved: any Geometry3D
        if let cornerSegments {
            revolved = CornerSweep(profile: profile, start: start, segments: cornerSegments)
        } else {
            revolved = profile.revolved(in: start..<(start + 90°))
        }
        return revolved.translated(x: sx * w / 2, y: sy * h / 2)
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

/// A quarter-turn revolve whose profile keeps the ambient segmentation while the revolve
/// itself uses a fixed segment count.
private struct CornerSweep: Geometry3D {
    let profile: any Geometry2D
    let start: Angle
    let segments: Int
    @Environment(\.segmentation) private var ambient

    var body: any Geometry3D {
        let pinned: any Geometry2D
        switch ambient {
        case .fixed(let count):
            pinned = profile.withSegmentation(count: count)
        case .adaptive(let minAngle, let minSize):
            pinned = profile.withSegmentation(minAngle: minAngle, minSize: minSize)
        @unknown default:
            pinned = profile
        }
        return pinned
            .revolved(in: start..<(start + 90°))
            .withSegmentation(count: segments)
    }
}

extension Dimensions {
    /// Ports OpenSCAD `block_wall`: the bin's wall, swept around the outline of a block
    /// `gridX` by `gridY` cells. `length` is the grid pitch in mm; `profile` is drawn with X
    /// outward and Y as Z, in mm.
    public func blockWall(
        gridX gx: Double,
        gridY gy: Double,
        length: Double? = nil,
        profile: any Geometry2D,
        cornerSegments: Int? = nil
    ) -> any Geometry3D {
        let l = length ?? lGrid
        return sweepRounded(
            width: gx * l - 2 * rBase - 0.5 - 0.001,
            height: gy * l - 2 * rBase - 0.5 - 0.001,
            profile: profile,
            cornerSegments: cornerSegments
        )
        .translated(z: hBase)
    }
}
