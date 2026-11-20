import Cadova
import GridfinityRebuilt

extension LiddedBinDesign {
    /// The Cadova part names used by the closed and open assemblies.
    public static let binPartName = "Bin"
    public static let lidPartName = "Lid"

    /// The gap in mm between the bin and the lid in the separated layout.
    static let separatedGap = 10.0

    /// The geometry for one `Part` value of lid-bin.scad.
    public func geometry(for part: LiddedBinPart) -> any Geometry3D {
        switch part {
        case .bin:
            return binSolid(pockets: pockets())
        case .lid:
            return lidBody().translated(z: -storageHeight - d.hBase + fit.thickness)
        case .lidOnPlate:
            return lidOnPlate()
        case .bothSeparated:
            return separatedAssembly()
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

    /// The lid in print orientation with its lowest point at z = 0. The `.lid` placement puts the
    /// bottom of the plate at `-vPosTolerance`, so the lid is lifted by that much.
    private func lidOnPlate() -> any Geometry3D {
        lidBody().translated(z: -storageHeight - d.hBase + fit.thickness + fit.vPosTolerance)
    }

    /// The bin (upright, base at z = 0) and the lid on the plate, side by side with
    /// `separatedGap` between their bounding boxes, the pair centered on the origin along the
    /// layout direction and each piece centered on the other axis. The layout runs along X when
    /// gridX <= gridY, along Y otherwise; the bin comes first, then the lid.
    private func separatedAssembly() -> any Geometry3D {
        let alongX = gridX <= gridY
        let gap = Self.separatedGap
        let binShape = binSolid(pockets: pockets())
        let lidShape = lidOnPlate()
        return measureBounds(of: [binShape, lidShape]) { boxes in
            guard let b = boxes[0], let l = boxes[1] else { return Empty() }
            let bSize = b.maximum - b.minimum
            let lSize = l.maximum - l.minimum
            let total = (alongX ? bSize.x + lSize.x : bSize.y + lSize.y) + gap
            let binStart = -total / 2
            let lidStart = binStart + (alongX ? bSize.x : bSize.y) + gap
            let binShift: Vector2D, lidShift: Vector2D
            if alongX {
                binShift = Vector2D(binStart - b.minimum.x, -(b.minimum.y + b.maximum.y) / 2)
                lidShift = Vector2D(lidStart - l.minimum.x, -(l.minimum.y + l.maximum.y) / 2)
            } else {
                binShift = Vector2D(-(b.minimum.x + b.maximum.x) / 2, binStart - b.minimum.y)
                lidShift = Vector2D(-(l.minimum.x + l.maximum.x) / 2, lidStart - l.minimum.y)
            }
            return Union {
                binShape.translated(x: binShift.x, y: binShift.y).inPart(Part(Self.binPartName))
                lidShape.translated(x: lidShift.x, y: lidShift.y).inPart(Part(Self.lidPartName))
            }
        }
    }
}
