import SwiftUI
import AppKit
import OneDisplayCore

public struct AppMenuView: View {
    @State private var displays: [DisplayItem] = DisplayManager.shared.detectDisplays()
    @State private var isSleepInhibited: Bool = SleepInhibitor.shared.isSleepPrevented

    private let brightnessManager = BrightnessManager()
    private let virtualManager = VirtualDisplayManager()

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            // Header bar
            HStack(spacing: 8) {
                Text("OneDisplay")
                    .font(.headline)
                    .fontWeight(.bold)

                Button(action: refreshDisplays) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh Connected Displays")

                Spacer()

                // Coffee / Sleep inhibitor button
                Button(action: toggleSleepInhibition) {
                    HStack(spacing: 4) {
                        Image(systemName: isSleepInhibited ? "cup.and.saucer.fill" : "cup.and.saucer")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isSleepInhibited ? .orange : .secondary)
                    }
                    .padding(6)
                    .background(isSleepInhibited ? Color.orange.opacity(0.18) : Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(isSleepInhibited ? "Display Sleep Inhibited (Click to allow sleep)" : "Prevent Display Sleep (Caffeine mode)")
            }
            .padding(.horizontal, 4)

            Divider()

            // Display Cards
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach($displays) { $disp in
                        DisplayCardView(
                            display: $disp,
                            onBrightnessChange: { newBrightness in
                                brightnessManager.applyBrightness(displayID: disp.id, sliderValue: newBrightness)
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: max(165, min(CGFloat(displays.count) * 170.0, 420)))

            Divider()

            // Footer bar
            HStack {
                Menu {
                    Button("1080p (1920 × 1080, 16:9)") {
                        createDummy(width: 1920, height: 1080)
                    }
                    Button("4K UHD (3840 × 2160, 16:9)") {
                        createDummy(width: 3840, height: 2160)
                    }
                    Button("1440p (2560 × 1440, 16:9)") {
                        createDummy(width: 2560, height: 1440)
                    }
                    Button("1600p (2560 × 1600, 16:10)") {
                        createDummy(width: 2560, height: 1600)
                    }
                    Button("Ultrawide (3440 × 1440, 21:9)") {
                        createDummy(width: 3440, height: 1440)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.rectangle.on.rectangle")
                            .font(.system(size: 13))
                        Text("Add Virtual Dummy")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.primary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()

                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Settings")

                Button(action: quitApp) {
                    Image(systemName: "power")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Quit OneDisplay")
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .frame(width: 360)
        .onAppear {
            refreshDisplays()
        }
    }

    private func refreshDisplays() {
        let detected = DisplayManager.shared.detectDisplays()
        if !detected.isEmpty {
            self.displays = detected
        }
        self.isSleepInhibited = SleepInhibitor.shared.isSleepPrevented
    }

    private func toggleSleepInhibition() {
        isSleepInhibited = SleepInhibitor.shared.toggle()
    }

    private func createDummy(width: Int, height: Int) {
        let count = displays.filter { $0.isVirtual }.count + 1
        let name = "Virtual Dummy \(count) (\(width)×\(height))"
        let id = virtualManager.createVirtualDisplay(name: name, width: width, height: height)
        let newItem = DisplayItem(
            id: id,
            name: name,
            isBuiltIn: false,
            isVirtual: true,
            brightness: 1.0,
            contrast: 0.5,
            volume: 0.5,
            currentModeString: "\(width) × \(height) @ 60Hz"
        )
        displays.append(newItem)
    }

    private func openSettings() {
        SettingsWindowController.shared.show()
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
