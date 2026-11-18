import GridfinityRebuilt

/// The plain values the customizer collects, with the defaults of `LiddedBinConfiguration`.
///
/// `internalHeight` and `externalHeight` are placeholders: they only take effect when
/// `heightStyle` selects them, and their defaults are the values the customizer starts those
/// controls at.
public struct LiddedBinInput: Sendable, Equatable {
    /// The single source of the customizer's default values. Every `@Parameter` in `lidded-bin`
    /// takes its default from here.
    public static let defaults = LiddedBinInput()

    public var gridX = 2
    public var gridY = 2
    public var heightStyle: HeightStyle = .sevenMillimeterUnits
    public var unitsHeight = 3.0
    public var internalHeight = 20.0
    public var externalHeight = 30.0
    public var snapHeight = false
    public var internalBlockHeight = 0.0
    public var lipGrips: LipGrips = .xy
    public var lidOrientation: LidOrientation = .left
    public var interiorStyle: InteriorStyle = .minimal
    public var compartmentPattern: CompartmentPattern = .grid
    public var divX = 6
    public var divY = 6
    public var divMultiple = 2.0

    public init() {}

    /// The validated configuration, taking the height from the field that matches `heightStyle`.
    public var configuration: LiddedBinConfiguration {
        var c = LiddedBinConfiguration()
        c.gridX = gridX; c.gridY = gridY
        c.heightMode = heightStyle.mode
        c.gridZ = switch heightStyle {
        case .sevenMillimeterUnits: unitsHeight
        case .internalHeight: internalHeight
        case .externalHeight: externalHeight
        }
        c.snapHeight = snapHeight
        c.internalHeightOverride = internalBlockHeight
        c.lipGrips = lipGrips; c.lidOrientation = lidOrientation
        c.interiorStyle = interiorStyle; c.compartmentPattern = compartmentPattern
        c.divX = divX; c.divY = divY; c.divMultiple = divMultiple
        return c.validated()
    }
}
