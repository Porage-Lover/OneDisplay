import Foundation
import AppKit
import CoreGraphics

public final class OverlayDimmer: @unchecked Sendable {
    public static let shared = OverlayDimmer()
    private var windows: [CGDirectDisplayID: NSWindow] = [:]
    private let lock = NSLock()

    public init() {}

    public func setDimming(displayID: CGDirectDisplayID, alpha: CGFloat) {
        DispatchQueue.main.async { [self] in
            lock.lock()
            defer { lock.unlock() }

            if alpha <= 0.005 {
                windows[displayID]?.orderOut(nil)
                return
            }

            let win: NSWindow
            if let existing = windows[displayID] {
                win = existing
            } else {
                win = createWindow(for: displayID)
                windows[displayID] = win
            }

            win.alphaValue = min(0.92, max(0.0, alpha))
            win.orderFrontRegardless()
        }
    }

    private func createWindow(for displayID: CGDirectDisplayID) -> NSWindow {
        let bounds = CGDisplayBounds(displayID)
        let win = NSWindow(
            contentRect: bounds,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.backgroundColor = .black
        win.isOpaque = false
        win.ignoresMouseEvents = true
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelKey.overlayWindow.rawValue) + 1)
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        return win
    }
}
