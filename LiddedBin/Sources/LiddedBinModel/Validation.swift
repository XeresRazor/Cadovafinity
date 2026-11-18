import GridfinityRebuilt

/// The ranges the model accepts. The customizer offers the same ranges, so a visitor cannot leave them.
public struct LiddedBinLimits: Sendable {
    public static let gridSize = 1...6
    public static let dividers = 0...12
    public static let divMultiple = 1.0...5.0
    public static let unitsHeight = 1.0...12.0
    public static let internalHeight = 5.0...80.0
    public static let externalHeight = 14.0...100.0

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
        let heights = LiddedBinLimits.heightRange(for: c.heightMode)
        c.gridZ = min(max(c.gridZ, heights.lowerBound), heights.upperBound)
        let storage = LiddedBinDesign(c).storageHeight
        c.internalHeightOverride = min(max(c.internalHeightOverride, 0), max(storage, 0))
        return c
    }
}
