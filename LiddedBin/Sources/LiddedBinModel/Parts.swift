import Cadova
import GridfinityRebuilt

extension LiddedBinDesign {
    /// The Cadova part names used by the closed and open assemblies.
    public static let binPartName = "Bin"
    public static let lidPartName = "Lid"

    /// The Cadova part names of the colored models (`coloredGeometry(for:colors:)`).
    public static let binBodyPartName = "Bin body"
    public static let dividersPartName = "Dividers"
    public static let lidRimPartName = "Lid rim and lip"
    public static let lidCenterPartName = "Lid center"

    /// The gap in mm between the bin and the lid in the separated layout.
    static let separatedGap = 10.0

    /// The geometry for one `Part` value of lid-bin.scad.
    public func geometry(for part: LiddedBinPart) -> any Geometry3D {
        model(for: part, colors: nil)
    }

    /// The geometry for one `Part` value as named, colored parts, so that a slicer can give each
    /// its own filament. The bin is the "Bin body" and "Dividers" parts (a bin without dividers
    /// has only the body), the lid the "Lid rim and lip" and "Lid center" parts, and the
    /// assemblies hold all of them, placed as in `geometry(for:)`. The union of the parts of each
    /// piece is exactly that piece. `.binSlice` is one "Bin body" part.
    public func coloredGeometry(for part: LiddedBinPart, colors: LiddedBinColors) -> any Geometry3D {
        model(for: part, colors: colors)
    }

    /// The one placement of every model, uncolored (`colors == nil`) or colored.
    private func model(for part: LiddedBinPart, colors: LiddedBinColors?) -> any Geometry3D {
        switch part {
        case .bin:
            return binModel(colors, inAssembly: false)
        case .lid:
            return lidModel(colors, inAssembly: false).translated(z: lidOnBedZ)
        case .lidOnPlate:
            return lidModel(colors, inAssembly: false).translated(z: lidOnPlateZ)
        case .bothSeparated:
            return separatedAssembly(colors)
        case .bothClosed:
            return assembly(colors, lidOffset: .zero)
        case .bothOpen:
            return assembly(colors, lidOffset: lidPosition(adjust: -(d.hLip * 2)))
        case .binSlice:
            // pockets nil cuts the whole interior (a deliberate deviation from OpenSCAD, whose
            // empty-children quirk leaves a solid bin), so the slice is a hollow ring.
            let bh = storageHeight + d.hBase - fit.thickness * 2
            let slice = binSolid(pockets: nil)
                .translated(z: -bh)
                .intersecting {
                    Rectangle([d.lGrid * gridX, d.lGrid * gridY])
                        .aligned(at: .center)
                        .extruded(height: d.hLip * 3)
                }
            guard let colors else { return slice }
            return slice.inPart(Part(Self.binBodyPartName, color: colors.binBody))
        }
    }

    /// The bin as it goes into a model. Uncolored it is the bare solid, or the "Bin" part in an
    /// assembly; colored it is the "Bin body" part and, if the bin has dividers, the "Dividers"
    /// part. A bin without pockets, or with a single compartment, has no Dividers part.
    private func binModel(_ colors: LiddedBinColors?, inAssembly: Bool) -> any Geometry3D {
        let pockets = pockets()
        guard let colors else {
            let solid = binSolid(pockets: pockets)
            return inAssembly ? solid.inPart(Part(Self.binPartName)) : solid
        }
        return Union {
            binBody(pockets: pockets).inPart(Part(Self.binBodyPartName, color: colors.binBody))
            if let dividers = binDividers(pockets: pockets) {
                // A single compartment has pockets but no dividers; it gets no empty part
                dividers.evaluating { g, evaluator in
                    let part = Part(Self.dividersPartName, color: colors.dividers)
                    return await evaluator.isEmpty(g) ? Empty() : g.inPart(part)
                }
            }
        }
    }

    /// The lid in the bin's coordinates (closed on the bin) as it goes into a model. Uncolored it
    /// is the bare solid, or the "Lid" part in an assembly; colored it is the "Lid rim and lip"
    /// and "Lid center" parts.
    private func lidModel(_ colors: LiddedBinColors?, inAssembly: Bool) -> any Geometry3D {
        guard let colors else {
            return inAssembly ? lidBody().inPart(Part(Self.lidPartName)) : lidBody()
        }
        return Union {
            lidRimAndLip().inPart(Part(Self.lidRimPartName, color: colors.lidRim))
            lidCenter().inPart(Part(Self.lidCenterPartName, color: colors.lidCenter))
        }
    }

    /// The bin and the lid. The lid keeps the placement `gf_bin_lid` gives it (it is not moved to
    /// the print bed), shifted by `lidOffset`.
    private func assembly(_ colors: LiddedBinColors?, lidOffset: Vector2D) -> any Geometry3D {
        Union {
            binModel(colors, inAssembly: true)
            lidModel(colors, inAssembly: true).translated(x: lidOffset.x, y: lidOffset.y)
        }
    }

    /// The z shift of the `.lid` placement: translate([0, 0, -$dh - h_base + lid_thickness]).
    private var lidOnBedZ: Double { -storageHeight - d.hBase + fit.thickness }

    /// The lid in print orientation with its lowest point at z = 0. The `.lid` placement puts the
    /// bottom of the plate at `-vPosTolerance`, so the lid is lifted by that much.
    private var lidOnPlateZ: Double { lidOnBedZ + fit.vPosTolerance }

    /// The bin (upright, base at z = 0) and the lid on the plate, side by side with
    /// `separatedGap` between their bounding boxes, the pair centered on the origin along the
    /// layout direction and each piece centered on the other axis. The layout runs along X when
    /// gridX <= gridY, along Y otherwise; the bin comes first, then the lid.
    /// The layout is measured on the bare solids; the union of the colored parts of each piece is
    /// that solid, so both kinds of model get the same shifts.
    private func separatedAssembly(_ colors: LiddedBinColors?) -> any Geometry3D {
        let alongX = gridX <= gridY
        let gap = Self.separatedGap
        let binShape = binSolid(pockets: pockets())
        let lidShape = lidBody().translated(z: lidOnPlateZ)
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
                binModel(colors, inAssembly: true).translated(x: binShift.x, y: binShift.y)
                lidModel(colors, inAssembly: true).translated(x: lidShift.x, y: lidShift.y, z: lidOnPlateZ)
            }
        }
    }
}
