import Foundation
import CoreGraphics

public struct DisplayID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: CGDirectDisplayID

    public init(rawValue: CGDirectDisplayID) {
        self.rawValue = rawValue
    }

    public init(_ id: CGDirectDisplayID) {
        self.rawValue = id
    }
}

extension DisplayID: CustomStringConvertible {
    public var description: String {
        return "\(rawValue)"
    }
}
