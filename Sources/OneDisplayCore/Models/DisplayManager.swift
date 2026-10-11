import Foundation
import CoreGraphics
import AppKit

public final class DisplayManager: @unchecked Sendable {
    public static let shared = DisplayManager()
    private let modeManager = DisplayModeManager()

    public init() {}

    public func detectDisplays() -> [DisplayItem] {
        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: 16)
        var displayCount: UInt32 = 0
        CGGetOnlineDisplayList(16, &onlineDisplays, &displayCount)

        var items: [DisplayItem] = []
        for i in 0..<Int(displayCount) {
            let id = onlineDisplays[i]
            let isBuiltIn = CGDisplayIsBuiltin(id) != 0
            var name = isBuiltIn ? "Built-in Retina Display" : "External Display \(id)"

            for screen in NSScreen.screens {
                if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                   num.uint32Value == id {
                    name = screen.localizedName
                    break
                }
            }

            // Read actual hardware backlight brightness
            let hwBrightness = DisplayHardwareController.shared.getBrightness(for: id) ?? 0.75

            // Read active mode resolution
            var currentModeStr = ""
            if let curMode = CGDisplayCopyDisplayMode(id) {
                let w = curMode.width
                let h = curMode.height
                let hz = Int(round(curMode.refreshRate))
                currentModeStr = "\(w) × \(h)\(hz > 0 ? " @ \(hz)Hz" : "")"
            }

            // Distinct resolution list
            let rawModes = modeManager.getModes(for: DisplayID(id))
            var seen = Set<String>()
            var distinctModes: [DisplayMode] = []
            for m in rawModes {
                let key = "\(m.width)x\(m.height)"
                if !seen.contains(key) {
                    seen.insert(key)
                    distinctModes.append(m)
                }
            }
            // Sort by width descending
            distinctModes.sort { $0.width > $1.width }

            items.append(DisplayItem(
                id: DisplayID(id),
                name: name,
                isBuiltIn: isBuiltIn,
                isVirtual: false,
                brightness: hwBrightness,
                contrast: 0.5,
                volume: 0.5,
                currentModeString: currentModeStr,
                availableModes: Array(distinctModes.prefix(8)),
                isXDRHeadroomBoosted: false
            ))
        }

        if items.isEmpty {
            items.append(DisplayItem(
                id: DisplayID(1),
                name: "Main Display",
                isBuiltIn: true,
                isVirtual: false,
                brightness: 0.75,
                contrast: 0.5,
                volume: 0.5,
                currentModeString: "1920 × 1080 @ 60Hz"
            ))
        }

        return items
    }
}
