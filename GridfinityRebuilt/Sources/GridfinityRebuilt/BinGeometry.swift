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
    public func shell(cutting: (any Geometry3D)? = nil, cornerSegments: Int? = nil) -> any Geometry3D {
        Union {
            bottom(cutting: cutting)
            wall(cornerSegments: cornerSegments)
        }
    }

    /// The solid bottom block of `gridfinityInit`, with `cutting` subtracted.
    func bottom(cutting: (any Geometry3D)? = nil) -> any Geometry3D {
        let bottomHeight = internalHeight == 0 ? height - 0.1 : internalHeight
        return dimensions.blockBottom(height: bottomHeight, gridX: gridX, gridY: gridY)
            .subtracting {
                if let cutting { cutting }
            }
    }

    /// The wall of `gridfinityInit`. When `cornerSegments` is given, the wall's corner revolves
    /// use that segment count (see ``sweepRounded(width:height:profile:cornerSegments:)``).
    func wall(cornerSegments: Int? = nil) -> any Geometry3D {
        let d = dimensions
        let profile: any Geometry2D = lipStyle == .regular
            ? d.wallProfile(height: height)
            : d.lipelessWallProfile(height: height)
        return d.blockWall(gridX: gridX, gridY: gridY, profile: profile, cornerSegments: cornerSegments)
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
