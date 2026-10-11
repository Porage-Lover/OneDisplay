import Foundation
import CoreGraphics

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
    private let lock = NSLock()
    private var activeVirtualDisplays: [DisplayID: VirtualDisplayConfig] = [:]
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

        simulatedIDCounter += 1
        let id = DisplayID(simulatedIDCounter)
        let config = VirtualDisplayConfig(name: name, width: width, height: height, hiDPI: hiDPI)
        activeVirtualDisplays[id] = config
        return id
    }

    @discardableResult
    public func destroy(id: DisplayID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeVirtualDisplays.removeValue(forKey: id) != nil
    }

    public func activeDisplays() -> [DisplayItem] {
        lock.lock()
        defer { lock.unlock() }
        return activeVirtualDisplays.map { id, config in
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
