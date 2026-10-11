import SwiftUI
import AppKit
import OneDisplayCore

public struct AppMenuView: View {
    @State private var displays: [DisplayItem] = DisplayManager.shared.detectDisplays()
    @State private var isSleepInhibited: Bool = SleepInhibitor.shared.isSleepPrevented

    private let brightnessManager = BrightnessManager()
    private let ddcController = DDCController()
    private let virtualManager = VirtualDisplayManager()

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            // Header bar
            HStack {
                Text("OneDisplay")
                    .font(.headline)
                    .fontWeight(.bold)
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
                            },
                            onVolumeChange: { newVolume in
                                let intVal = UInt16(round(newVolume * 100))
                                ddcController.write(displayID: disp.id, opcode: .audioVolume, value: intVal)
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: max(150, min(CGFloat(displays.count) * 155.0, 360)))

            Divider()

            // Footer bar
            HStack {
                Button(action: addVirtualDisplay) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.rectangle.on.rectangle")
                            .font(.system(size: 13))
                        Text("Add Virtual Dummy")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

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
        .frame(width: 340)
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

    private func addVirtualDisplay() {
        let count = displays.filter { $0.isVirtual }.count + 1
        let id = virtualManager.createVirtualDisplay(name: "Virtual Dummy \(count)", width: 1920, height: 1080)
        let newItem = DisplayItem(
            id: id,
            name: "Virtual Dummy \(count)",
            isBuiltIn: false,
            isVirtual: true,
            brightness: 1.0,
            contrast: 0.5,
            volume: 0.5
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
