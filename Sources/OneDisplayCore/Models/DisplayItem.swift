import Foundation

public struct DisplayItem: Identifiable, Hashable, Codable, Sendable {
    public var id: DisplayID
    public var name: String
    public var isBuiltIn: Bool
    public var isVirtual: Bool
    public var brightness: Double
    public var contrast: Double
    public var volume: Double

    public init(
        id: DisplayID,
        name: String,
        isBuiltIn: Bool = false,
        isVirtual: Bool = false,
        brightness: Double = 0.5,
        contrast: Double = 0.5,
        volume: Double = 0.5
    ) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.isVirtual = isVirtual
        self.brightness = brightness
        self.contrast = contrast
        self.volume = volume
    }
}
