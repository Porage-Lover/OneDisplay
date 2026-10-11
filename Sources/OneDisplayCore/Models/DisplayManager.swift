import Foundation
import CoreGraphics
import AppKit

public final class DisplayManager: @unchecked Sendable {
    public static let shared = DisplayManager()

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

            items.append(DisplayItem(
                id: DisplayID(id),
                name: name,
                isBuiltIn: isBuiltIn,
                isVirtual: false,
                brightness: 0.75,
                contrast: 0.5,
                volume: 0.5
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
                volume: 0.5
            ))
        }

        return items
    }
}
