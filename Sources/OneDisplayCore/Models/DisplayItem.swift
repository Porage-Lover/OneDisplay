import Foundation

public struct DisplayItem: Identifiable, Hashable, Codable, Sendable {
    public var id: DisplayID
    public var name: String
    public var isBuiltIn: Bool
    public var isVirtual: Bool
    public var brightness: Double
    public var contrast: Double
    public var volume: Double
    public var currentModeString: String
    public var availableModes: [DisplayMode]
    public var isXDRHeadroomBoosted: Bool
    public var rotation: Int
    public var isMirrored: Bool

    public init(
        id: DisplayID,
        name: String,
        isBuiltIn: Bool = false,
        isVirtual: Bool = false,
        brightness: Double = 0.5,
        contrast: Double = 0.5,
        volume: Double = 0.5,
        currentModeString: String = "",
        availableModes: [DisplayMode] = [],
        isXDRHeadroomBoosted: Bool = false,
        rotation: Int = 0,
        isMirrored: Bool = false
    ) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.isVirtual = isVirtual
        self.brightness = brightness
        self.contrast = contrast
        self.volume = volume
        self.currentModeString = currentModeString
        self.availableModes = availableModes
        self.isXDRHeadroomBoosted = isXDRHeadroomBoosted
        self.rotation = rotation
        self.isMirrored = isMirrored
    }
}
