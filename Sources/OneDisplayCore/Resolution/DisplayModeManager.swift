import Foundation
import CoreGraphics

public final class DisplayModeManager: @unchecked Sendable {
    private let lock = NSLock()

    public init() {}

    public func getModes(for displayID: DisplayID) -> [DisplayMode] {
        lock.lock()
        defer { lock.unlock() }

        let options: [CFString: Any] = [
            kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue as Any
        ]
        guard let modeList = CGDisplayCopyAllDisplayModes(displayID.rawValue, options as CFDictionary) as? [CGDisplayMode] else {
            return []
        }

        var modes: [DisplayMode] = []
        for mode in modeList {
            let width = mode.width
            let height = mode.height
            let pixelWidth = mode.pixelWidth
            let scale = width > 0 ? Double(pixelWidth) / Double(width) : 1.0
            let refreshRate = mode.refreshRate
            let isHiDPI = scale > 1.0

            modes.append(DisplayMode(
                width: width,
                height: height,
                scale: scale,
                refreshRate: refreshRate,
                isHiDPI: isHiDPI
            ))
        }
        return modes
    }

    public func setMode(for displayID: DisplayID, mode: DisplayMode) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let options: [CFString: Any] = [
            kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue as Any
        ]
        guard let modeList = CGDisplayCopyAllDisplayModes(displayID.rawValue, options as CFDictionary) as? [CGDisplayMode] else {
            return false
        }

        for cgMode in modeList {
            if cgMode.width == mode.width && cgMode.height == mode.height {
                let err = CGDisplaySetDisplayMode(displayID.rawValue, cgMode, nil)
                return err == .success
            }
        }
        return false
    }
}
