import Foundation
import CoreGraphics
import AppKit
import Metal
import QuartzCore

private final class EDR1x1View: NSView {
    override func makeBackingLayer() -> CALayer {
        let layer = CAMetalLayer()
        layer.device = MTLCreateSystemDefaultDevice()
        layer.wantsExtendedDynamicRangeContent = true
        layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
        return layer
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
    }
}

public final class XDRManager: @unchecked Sendable {
    public static let shared = XDRManager()
    private let lock = NSLock()
    private var currentHeadroomMultipliers: [DisplayID: Double] = [:]
    private var enforcerWindows: [DisplayID: NSWindow] = [:]
    private var baseGammaTables: [DisplayID: ([Float], [Float], [Float])] = [:]

    public init() {}

    public func maxEDRHeadroom(for displayID: DisplayID) -> Double {
        if let sc = screen(for: displayID) {
            let pot = sc.maximumPotentialExtendedDynamicRangeColorComponentValue
            return pot > 1.0 ? min(2.0, pot) : 1.0
        }
        return 1.0
    }

    @discardableResult
    public func setEDRHeadroom(displayID: DisplayID, multiplier: Double) -> Bool {
        let isUnboosting = multiplier <= 1.001

        if isUnboosting {
            lock.lock()
            currentHeadroomMultipliers[displayID] = 1.0
            let win = enforcerWindows.removeValue(forKey: displayID)
            let baseTable = baseGammaTables.removeValue(forKey: displayID)
            lock.unlock()

            let cleanup = {
                if var (r, g, b) = baseTable {
                    _ = CGSetDisplayTransferByTable(displayID.rawValue, 256, &r, &g, &b)
                }
                win?.orderOut(nil)
                CGDisplayRestoreColorSyncSettings()
            }

            if Thread.isMainThread {
                cleanup()
            } else {
                DispatchQueue.main.async(execute: cleanup)
            }
            return true
        }

        // Verify hardware capability
        let maxPot = maxEDRHeadroom(for: displayID)
        guard maxPot > 1.001 else {
            return false
        }

        let clamped = max(1.0, min(maxPot, multiplier))

        lock.lock()
        currentHeadroomMultipliers[displayID] = clamped

        // Capture base hardware gamma table if not already saved
        if baseGammaTables[displayID] == nil {
            var sampleCount: UInt32 = 0
            var r = [Float](repeating: 0, count: 256)
            var g = [Float](repeating: 0, count: 256)
            var b = [Float](repeating: 0, count: 256)
            let err = CGGetDisplayTransferByTable(displayID.rawValue, 256, &r, &g, &b, &sampleCount)
            if err == .success && sampleCount == 256 {
                baseGammaTables[displayID] = (r, g, b)
            } else {
                let linear = (0..<256).map { Float($0) / 255.0 }
                baseGammaTables[displayID] = (linear, linear, linear)
            }
        }

        guard let (baseR, baseG, baseB) = baseGammaTables[displayID] else {
            lock.unlock()
            return false
        }
        lock.unlock()

        let apply = { [self] in
            // Check if still boosted before altering display
            lock.lock()
            let currentMult = currentHeadroomMultipliers[displayID] ?? 1.0
            guard currentMult > 1.001 else {
                lock.unlock()
                return
            }

            if enforcerWindows[displayID] == nil {
                let win = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                    styleMask: [.borderless],
                    backing: .buffered,
                    defer: false
                )
                win.isReleasedWhenClosed = false
                win.isOpaque = false
                win.backgroundColor = .clear
                win.ignoresMouseEvents = true
                win.level = .screenSaver
                win.hasShadow = false
                win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
                win.contentView = EDR1x1View(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
                win.orderFrontRegardless()
                enforcerWindows[displayID] = win
            }
            lock.unlock()

            // Scale gamma table into unlocked EDR headroom
            let mult = Float(clamped)
            var boostedR = baseR.map { $0 * mult }
            var boostedG = baseG.map { $0 * mult }
            var boostedB = baseB.map { $0 * mult }

            _ = CGSetDisplayTransferByTable(displayID.rawValue, 256, &boostedR, &boostedG, &boostedB)
        }

        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }

        return true
    }

    public func getHeadroom(for displayID: DisplayID) -> Double {
        lock.lock()
        defer { lock.unlock() }
        return currentHeadroomMultipliers[displayID] ?? 1.0
    }

    public func isBoosted(for displayID: DisplayID) -> Bool {
        return getHeadroom(for: displayID) > 1.01
    }

    public func tearDownAll() {
        lock.lock()
        let windows = Array(enforcerWindows.values)
        enforcerWindows.removeAll()
        let tables = baseGammaTables
        baseGammaTables.removeAll()
        currentHeadroomMultipliers.removeAll()
        lock.unlock()

        let cleanup = {
            for win in windows {
                win.orderOut(nil)
            }
            for (dispID, (r, g, b)) in tables {
                var cr = r, cg = g, cb = b
                _ = CGSetDisplayTransferByTable(dispID.rawValue, 256, &cr, &cg, &cb)
            }
            CGDisplayRestoreColorSyncSettings()
        }

        if Thread.isMainThread {
            cleanup()
        } else {
            DispatchQueue.main.async(execute: cleanup)
        }
    }

    private func screen(for displayID: DisplayID) -> NSScreen? {
        for screen in NSScreen.screens {
            if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
               num.uint32Value == displayID.rawValue {
                return screen
            }
        }
        return nil
    }
}
