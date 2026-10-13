import Foundation
import CoreGraphics
import AppKit
import Metal

private final class EDRBackingView: NSView {
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

    public init() {}

    public func maxEDRHeadroom(for displayID: DisplayID) -> Double {
        for screen in NSScreen.screens {
            if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
               num.uint32Value == displayID.rawValue {
                let pot = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
                return pot > 1.0 ? min(2.0, pot) : 1.6
            }
        }
        return 1.6
    }

    @discardableResult
    public func setEDRHeadroom(displayID: DisplayID, multiplier: Double) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if multiplier <= 1.001 {
            currentHeadroomMultipliers[displayID] = 1.0
            DispatchQueue.main.async { [self] in
                if let win = enforcerWindows.removeValue(forKey: displayID) {
                    win.orderOut(nil)
                }
                CGDisplayRestoreColorSyncSettings()
            }
            return true
        }

        let clamped = max(1.0, min(2.0, multiplier))
        currentHeadroomMultipliers[displayID] = clamped

        DispatchQueue.main.async { [self] in
            if enforcerWindows[displayID] == nil {
                let bounds = CGDisplayBounds(displayID.rawValue)
                let win = NSWindow(
                    contentRect: NSRect(x: bounds.origin.x, y: bounds.origin.y, width: 4, height: 4),
                    styleMask: [.borderless],
                    backing: .buffered,
                    defer: false
                )
                win.isReleasedWhenClosed = false
                win.isOpaque = false
                win.backgroundColor = .clear
                win.ignoresMouseEvents = true
                win.level = .floating
                win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

                win.contentView = EDRBackingView(frame: NSRect(x: 0, y: 0, width: 4, height: 4))
                win.orderFrontRegardless()
                enforcerWindows[displayID] = win
            }

            // Restore ColorSync gamma so colors remain pristine and never clip or deep-fry
            CGDisplayRestoreColorSyncSettings()
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
}
