import Cadova
import GridfinityRebuilt

extension InteriorStyle: ParameterChoice {
    public var displayName: String {
        switch self {
        case .minimal: "Minimal"
        case .partialRaised: "Partially raised"
        }
    }
}

extension LipGrips: ParameterChoice {
    public var displayName: String {
        switch self {
        case .none: "None"
        case .x: "Along X"
        case .y: "Along Y"
        case .xy: "Along X and Y"
        }
    }
}

extension LidOrientation: ParameterChoice {
    public var displayName: String {
        switch self {
        case .up: "Up"
        case .down: "Down"
        case .left: "Left"
        case .right: "Right"
        }
    }
}

extension CompartmentPattern: ParameterChoice {
    public var displayName: String {
        switch self {
        case .grid: "Equal grid"
        case .multiSize: "Two sizes"
        }
    }
}

/// How the customizer expresses the bin height. Each style has its own height control.
public enum HeightStyle: String, ParameterChoice, Sendable {
    case sevenMillimeterUnits, internalHeight, externalHeight

    public var displayName: String {
        switch self {
        case .sevenMillimeterUnits: "7 mm units"
        case .internalHeight: "Internal height"
        case .externalHeight: "Overall height"
        }
    }

    public var mode: HeightMode {
        switch self {
        case .sevenMillimeterUnits: .units
        case .internalHeight: .internalMillimeters
        case .externalHeight: .externalMillimeters
        }
    }
}
