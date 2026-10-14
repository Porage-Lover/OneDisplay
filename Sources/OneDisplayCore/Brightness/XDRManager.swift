import Foundation
import CoreGraphics
import AppKit
import Metal
import QuartzCore

final class EDRMetalView: NSView {
    private var metalLayer: CAMetalLayer?
    private var commandQueue: MTLCommandQueue?
    private var currentMultiplier: Double = 1.0

    override func makeBackingLayer() -> CALayer {
        let layer = CAMetalLayer()
        if let dev = MTLCreateSystemDefaultDevice() {
            layer.device = dev
            self.commandQueue = dev.makeCommandQueue()
        }
        layer.pixelFormat = .rgba16Float
        layer.wantsExtendedDynamicRangeContent = true
        layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
        layer.compositingFilter = "multiplyBlendMode"
        layer.presentsWithTransaction = true
        layer.displaySyncEnabled = true
        self.metalLayer = layer
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

    func render(multiplier: Double) {
        self.currentMultiplier = multiplier
        guard let layer = self.metalLayer,
              let queue = self.commandQueue,
              let drawable = layer.nextDrawable() else {
            return
        }

        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = drawable.texture
        passDescriptor.colorAttachments[0].loadAction = .clear
        let v = Double(max(1.0, multiplier))
        passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: v, green: v, blue: v, alpha: 1.0)
        passDescriptor.colorAttachments[0].storeAction = .store

        CATransaction.begin()
        if let commandBuffer = queue.makeCommandBuffer() {
            if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) {
                encoder.endEncoding()
            }
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        CATransaction.commit()
    }
}

final class EDROverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(screenFrame: NSRect) {
        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.isReleasedWhenClosed = false
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = true
        self.level = .screenSaver
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]

        let metalView = EDRMetalView(frame: NSRect(origin: .zero, size: screenFrame.size))
        metalView.autoresizingMask = [.width, .height]
        self.contentView = metalView
    }

    func updateMultiplier(_ multiplier: Double) {
        if let metalView = self.contentView as? EDRMetalView {
            metalView.render(multiplier: multiplier)
        }
    }
}

public final class XDRManager: @unchecked Sendable {
    public static let shared = XDRManager()
    private let lock = NSLock()
    private var currentHeadroomMultipliers: [DisplayID: Double] = [:]
    private var enforcerWindows: [DisplayID: EDROverlayWindow] = [:]

    public init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func maxEDRHeadroom(for displayID: DisplayID) -> Double {
        if let sc = screen(for: displayID) {
            let pot = sc.maximumPotentialExtendedDynamicRangeColorComponentValue
            return pot > 1.0 ? min(2.0, pot) : 1.6
        }
        return 1.6
    }

    @discardableResult
    public func setEDRHeadroom(displayID: DisplayID, multiplier: Double) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if multiplier <= 1.001 {
            currentHeadroomMultipliers[displayID] = 1.0
            let win = enforcerWindows.removeValue(forKey: displayID)
            let cleanup = {
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

        let clamped = max(1.0, min(2.0, multiplier))
        currentHeadroomMultipliers[displayID] = clamped

        let apply = { [self] in
            let targetFrame: NSRect
            if let sc = self.screen(for: displayID) {
                targetFrame = sc.frame
            } else {
                let bounds = CGDisplayBounds(displayID.rawValue)
                targetFrame = NSRect(x: bounds.origin.x, y: bounds.origin.y, width: bounds.width, height: bounds.height)
            }

            let window: EDROverlayWindow
            if let existing = enforcerWindows[displayID] {
                window = existing
                if window.frame != targetFrame {
                    window.setFrame(targetFrame, display: true)
                }
            } else {
                window = EDROverlayWindow(screenFrame: targetFrame)
                enforcerWindows[displayID] = window
                window.orderFrontRegardless()
            }

            window.updateMultiplier(clamped)
            CGDisplayRestoreColorSyncSettings()
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
        currentHeadroomMultipliers.removeAll()
        lock.unlock()

        let cleanup = {
            for win in windows {
                win.orderOut(nil)
            }
            CGDisplayRestoreColorSyncSettings()
        }

        if Thread.isMainThread {
            cleanup()
        } else {
            DispatchQueue.main.sync(execute: cleanup)
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

    @objc private func screenParametersDidChange(_ notification: Notification) {
        lock.lock()
        let activeWindows = enforcerWindows
        let multipliers = currentHeadroomMultipliers
        lock.unlock()

        DispatchQueue.main.async { [self] in
            for (displayID, window) in activeWindows {
                if let sc = self.screen(for: displayID) {
                    window.setFrame(sc.frame, display: true)
                    let mult = multipliers[displayID] ?? 1.0
                    window.updateMultiplier(mult)
                }
            }
        }
    }
}
