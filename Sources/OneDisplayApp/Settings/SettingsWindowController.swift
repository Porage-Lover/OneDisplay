import SwiftUI
import AppKit

public final class SettingsWindowController {
    public static let shared = SettingsWindowController()
    private var window: NSWindow?

    public init() {}

    public func show() {
        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 320),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            win.center()
            win.title = "OneDisplay Settings"
            win.isReleasedWhenClosed = false
            win.contentView = NSHostingView(rootView: SettingsView())
            self.window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}
