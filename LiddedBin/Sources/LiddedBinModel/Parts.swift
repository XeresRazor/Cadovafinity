import Cadova
import GridfinityRebuilt

extension LiddedBinDesign {
    /// The Cadova part names used by the closed and open assemblies.
    public static let binPartName = "Bin"
    public static let lidPartName = "Lid"

    /// The geometry for one `Part` value of lid-bin.scad.
    public func geometry(for part: LiddedBinPart) -> any Geometry3D {
        switch part {
        case .bin:
            return binSolid(pockets: pockets())
        case .lid:
            return lidBody().translated(z: -storageHeight - d.hBase + fit.thickness)
        case .bothClosed:
            return assembly(lidOffset: .zero)
        case .bothOpen:
            return assembly(lidOffset: lidPosition(adjust: -(d.hLip * 2)))
        case .binSlice:
            // pockets nil cuts the whole interior (a deliberate deviation from OpenSCAD, whose
            // empty-children quirk leaves a solid bin), so the slice is a hollow ring.
            let bh = storageHeight + d.hBase - fit.thickness * 2
            return binSolid(pockets: nil)
                .translated(z: -bh)
                .intersecting {
                    Rectangle([d.lGrid * gridX, d.lGrid * gridY])
                        .aligned(at: .center)
                        .extruded(height: d.hLip * 3)
                }
        }
    }

    /// The bin and the lid as two named parts. The lid keeps the placement `gf_bin_lid` gives it
    /// (it is not moved to the print bed), shifted by `lidOffset`.
    private func assembly(lidOffset: Vector2D) -> any Geometry3D {
        Union {
            binSolid(pockets: pockets()).inPart(Part(Self.binPartName))
            lidBody()
                .translated(x: lidOffset.x, y: lidOffset.y)
                .inPart(Part(Self.lidPartName))
        }
    }
}
