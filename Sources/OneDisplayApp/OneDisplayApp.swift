import SwiftUI
import AppKit
import OneDisplayCore

@main
struct OneDisplayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("OneDisplay", systemImage: "display") {
            AppMenuView()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let server = HTTPServer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? server.start(port: 8969)
    }

    func applicationWillTerminate(_ notification: Notification) {
        server.stop()
    }
}
