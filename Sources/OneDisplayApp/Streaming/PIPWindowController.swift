import SwiftUI
import AppKit
import OneDisplayCore

public final class PIPWindowController: @unchecked Sendable {
    public static let shared = PIPWindowController()
    private var window: NSPanel?

    public init() {}

    public func showPIP(for displayID: DisplayID, name: String) {
        DispatchQueue.main.async { [self] in
            if window == nil {
                let panel = NSPanel(
                    contentRect: NSRect(x: 100, y: 100, width: 480, height: 270),
                    styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
                    backing: .buffered,
                    defer: false
                )
                panel.level = .floating
                panel.isFloatingPanel = true
                panel.title = "PiP: \(name)"
                panel.isReleasedWhenClosed = false
                panel.contentView = NSHostingView(rootView: PIPStreamView(displayID: displayID))
                self.window = panel
            } else {
                window?.title = "PiP: \(name)"
                window?.contentView = NSHostingView(rootView: PIPStreamView(displayID: displayID))
            }
            window?.center()
            window?.makeKeyAndOrderFront(nil)
            window?.orderFrontRegardless()
        }
    }
}

public struct PIPStreamView: View {
    let displayID: DisplayID

    public var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 8) {
                Image(systemName: "pip.enter")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
                Text("Streaming Display \(displayID.rawValue)")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("ScreenCaptureKit PiP active • Floating overlay")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(minWidth: 320, minHeight: 180)
    }
}
