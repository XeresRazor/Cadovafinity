import Cadova
import GridfinityRebuilt

public struct LiddedBinDesign: Sendable {
    public let configuration: LiddedBinConfiguration
    let d: Dimensions
    let fit: LidFit

    public init(_ configuration: LiddedBinConfiguration) {
        // The tongue offset follows the side gap: the default gap keeps the original 0.30 offset,
        // and a tighter gap tightens the chamfer against the slot roof with it.
        var fit = LidFit(sideClearance: configuration.lidClearance)
        fit.lipClearance = min(0.30, configuration.lidClearance + 0.10)
        fit.chamfer = configuration.lidChamfer
        fit.detentStyle = configuration.detentStyle
        fit.detentInterference = configuration.detentInterference
        self.init(configuration, fit: fit)
    }

    /// Internal: lets tests vary the lid fit constants.
    init(_ configuration: LiddedBinConfiguration, fit: LidFit) {
        self.configuration = configuration
        self.fit = fit
        var d = Dimensions.standard
        d.dWall = 1.6              // d_wall in lid-bin.scad
        self.d = d
    }

    var gridX: Double { Double(configuration.gridX) }
    var gridY: Double { Double(configuration.gridY) }

    /// bin_storage_height
    var storageHeight: Double {
        d.binHeight(configuration.gridZ, mode: configuration.heightMode, lip: .regular, snap: configuration.snapHeight)
    }
    /// bin_inner_height
    var innerHeight: Double { storageHeight + d.hBase - d.dWall }

    var bin: BinGeometry {
        BinGeometry(gridX: gridX, gridY: gridY, height: storageHeight,
                    internalHeight: configuration.internalHeightOverride,
                    lipStyle: .regular, dimensions: d)
    }

    /// lid_pos_multiple
    var lidDirection: Vector2D {
        switch configuration.lidOrientation {
        case .right: Vector2D(1, 0)
        case .left: Vector2D(-1, 0)
        case .up: Vector2D(0, 1)
        case .down: Vector2D(0, -1)
        }
    }

    /// lid_pos
    func lidPosition(adjust: Double = 0) -> Vector2D {
        let m = lidDirection
        return Vector2D(m.x * (d.lGrid * gridX + adjust), m.y * (d.lGrid * gridY + adjust))
    }

    /// pocket_size
    func pocketSize(xUnits: Double, yUnits: Double) -> Vector2D {
        Vector2D(
            xUnits * (gridX * d.lGrid + d.dMagic) / gridX - fit.separatorWallThickness,
            yUnits * (gridY * d.lGrid + d.dMagic) / gridY - fit.separatorWallThickness
        )
    }
}
