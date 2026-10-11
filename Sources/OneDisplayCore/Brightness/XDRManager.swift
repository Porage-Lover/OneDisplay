import Foundation
import CoreGraphics
import AppKit

public final class XDRManager: @unchecked Sendable {
    private let lock = NSLock()
    private var currentHeadroomMultipliers: [DisplayID: Double] = [:]

    public init() {}

    public func maxEDRHeadroom(for displayID: DisplayID) -> Double {
        for screen in NSScreen.screens {
            if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
               num.uint32Value == displayID.rawValue {
                return screen.maximumExtendedDynamicRangeColorComponentValue
            }
        }
        return 1.0
    }

    @discardableResult
    public func setEDRHeadroom(displayID: DisplayID, multiplier: Double) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let clamped = max(1.0, min(2.0, multiplier))
        currentHeadroomMultipliers[displayID] = clamped
        return true
    }

    public func getHeadroom(for displayID: DisplayID) -> Double {
        lock.lock()
        defer { lock.unlock() }
        return currentHeadroomMultipliers[displayID] ?? 1.0
    }
}
