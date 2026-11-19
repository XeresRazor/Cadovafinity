import GridfinityRebuilt

/// The ranges the model accepts. The customizer offers the same ranges, so a visitor cannot leave them.
public struct LiddedBinLimits: Sendable {
    public static let gridSize = 1...6
    public static let dividers = 0...12
    public static let divMultiple = 1.0...5.0
    /// The side gap between the lid and the slot face, in mm.
    public static let lidClearance = 0.05...0.6
    /// The rise of the slot roof slope and the lid chamfer, in mm. 0.8 is the original 45 degree
    /// roof; at 2.0 the roof tip is 0.7 mm below the lip's inner top chamfer.
    public static let lidChamfer = 0.8...2.0
    public static let unitsHeight = 1.0...12.0
    /// The millimeter height ranges follow from the maximum unit height, so all three height
    /// styles allow the same tallest bin: a 12 unit bin is 84 mm tall outside, and its
    /// internal height is that less the 5 mm base and the 2.2 mm lid allowance.
    public static let internalHeight = 5.0...(unitsHeight.upperBound * 7 - 5 - 2.2)
    public static let externalHeight = 14.0...(unitsHeight.upperBound * 7)

    public static func heightRange(for mode: HeightMode) -> ClosedRange<Double> {
        switch mode {
        case .units: unitsHeight
        case .internalMillimeters: internalHeight
        case .externalMillimeters: externalHeight
        }
    }
}

public extension LiddedBinConfiguration {
    /// A copy with every value clamped to what the model supports. In-range input is returned unchanged.
    func validated() -> LiddedBinConfiguration {
        var c = self
        c.gridX = min(max(c.gridX, LiddedBinLimits.gridSize.lowerBound), LiddedBinLimits.gridSize.upperBound)
        c.gridY = min(max(c.gridY, LiddedBinLimits.gridSize.lowerBound), LiddedBinLimits.gridSize.upperBound)
        c.divX = min(max(c.divX, LiddedBinLimits.dividers.lowerBound), LiddedBinLimits.dividers.upperBound)
        c.divY = min(max(c.divY, LiddedBinLimits.dividers.lowerBound), LiddedBinLimits.dividers.upperBound)
        c.divMultiple = min(max(c.divMultiple, LiddedBinLimits.divMultiple.lowerBound), LiddedBinLimits.divMultiple.upperBound)
        c.lidClearance = min(max(c.lidClearance, LiddedBinLimits.lidClearance.lowerBound), LiddedBinLimits.lidClearance.upperBound)
        c.lidChamfer = min(max(c.lidChamfer, LiddedBinLimits.lidChamfer.lowerBound), LiddedBinLimits.lidChamfer.upperBound)
        let heights = LiddedBinLimits.heightRange(for: c.heightMode)
        c.gridZ = min(max(c.gridZ, heights.lowerBound), heights.upperBound)
        let storage = LiddedBinDesign(c).storageHeight
        c.internalHeightOverride = min(max(c.internalHeightOverride, 0), max(storage, 0))
        return c
    }
}
