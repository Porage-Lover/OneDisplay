import Foundation
import CoreGraphics
import AppKit

public struct VirtualDisplayConfig: Sendable {
    public let name: String
    public let width: Int
    public let height: Int
    public let hiDPI: Bool

    public init(name: String, width: Int, height: Int, hiDPI: Bool = true) {
        self.name = name
        self.width = width
        self.height = height
        self.hiDPI = hiDPI
    }
}

public final class VirtualDisplayManager: @unchecked Sendable {
    public static let shared = VirtualDisplayManager()

    private let lock = NSLock()
    private var activeVirtualConfigs: [DisplayID: VirtualDisplayConfig] = [:]
    private var activeVirtualObjects: [DisplayID: AnyObject] = [:]
    private var simulatedIDCounter: UInt32 = 9000

    public init() {}

    public func generateModes(aspectWidth: Int, aspectHeight: Int, maxDimension: Int = 3840) -> [DisplayMode] {
        guard aspectWidth > 0 && aspectHeight > 0 else { return [] }
        let baseHeights = [360, 480, 720, 900, 1080, 1200, 1440, 1600, 1800, 2160, 2400, 2880, 3840]
        var result: [DisplayMode] = []
        for h in baseHeights {
            let w = (h * aspectWidth) / aspectHeight
            if max(w, h) <= maxDimension {
                result.append(DisplayMode(width: w, height: h, scale: 2.0, refreshRate: 60.0, isHiDPI: true))
                result.append(DisplayMode(width: w, height: h, scale: 1.0, refreshRate: 60.0, isHiDPI: false))
            }
        }
        return result
    }

    public func createVirtualDisplay(name: String, width: Int, height: Int, hiDPI: Bool = true) -> DisplayID {
        lock.lock()
        defer { lock.unlock() }

        // Attempt creation via native CGVirtualDisplay private framework
        if let descClass = NSClassFromString("CGVirtualDisplayDescriptor") as? NSObject.Type,
           let dispClass = NSClassFromString("CGVirtualDisplay") as? NSObject.Type {
            let desc = descClass.init()
            desc.setValue(name, forKey: "name")
            desc.setValue(UInt32(width), forKey: "maxPixelsWide")
            desc.setValue(UInt32(height), forKey: "maxPixelsHigh")
            desc.setValue(CGSize(width: width, height: height), forKey: "sizeInMillimeters")
            desc.setValue(UInt32(0x1234), forKey: "productID")
            desc.setValue(UInt32(0x5678), forKey: "vendorID")
            desc.setValue(UInt32(simulatedIDCounter), forKey: "serialNum")

            let alloced = dispClass.perform(NSSelectorFromString("alloc")).takeUnretainedValue()
            let disp = alloced.perform(NSSelectorFromString("initWithDescriptor:"), with: desc).takeUnretainedValue()

            if let displayIDVal = disp.value(forKey: "displayID") as? CGDirectDisplayID, displayIDVal != 0 {
                let id = DisplayID(displayIDVal)
                activeVirtualObjects[id] = disp
                activeVirtualConfigs[id] = VirtualDisplayConfig(name: name, width: width, height: height, hiDPI: hiDPI)
                return id
            }
        }

        // Fallback simulated virtual ID
        simulatedIDCounter += 1
        let fallbackID = DisplayID(simulatedIDCounter)
        let config = VirtualDisplayConfig(name: name, width: width, height: height, hiDPI: hiDPI)
        activeVirtualConfigs[fallbackID] = config
        return fallbackID
    }

    @discardableResult
    public func destroy(id: DisplayID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        activeVirtualObjects.removeValue(forKey: id)
        return activeVirtualConfigs.removeValue(forKey: id) != nil
    }

    public func activeDisplays() -> [DisplayItem] {
        lock.lock()
        defer { lock.unlock() }
        return activeVirtualConfigs.map { id, config in
            DisplayItem(
                id: id,
                name: config.name,
                isBuiltIn: false,
                isVirtual: true,
                brightness: 1.0,
                contrast: 0.5,
                volume: 0.5
            )
        }
    }
}
