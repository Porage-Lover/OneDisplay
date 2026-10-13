import SwiftUI
import AppKit
import Combine
import OneDisplayCore

public struct AppMenuView: View {
    @State private var displays: [DisplayItem] = DisplayManager.shared.detectDisplays()
    @State private var isSleepInhibited: Bool = SleepInhibitor.shared.isSleepPrevented

    private let brightnessManager = BrightnessManager()
    private let virtualManager = VirtualDisplayManager.shared
    private let syncTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

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

                // Coffee / Sleep inhibitor button (Feature H)
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
                VStack(spacing: 12) {
                    ForEach($displays) { $disp in
                        DisplayCardView(
                            display: $disp,
                            allDisplays: displays,
                            onBrightnessChange: { newBrightness, isBuiltIn in
                                brightnessManager.applyBrightness(
                                    displayID: disp.id,
                                    sliderValue: newBrightness,
                                    isBuiltIn: isBuiltIn
                                )
                            },
                            onContrastChange: { newContrast, isBuiltIn in
                                brightnessManager.applyContrast(
                                    displayID: disp.id,
                                    contrastValue: newContrast,
                                    isBuiltIn: isBuiltIn
                                )
                            },
                            onDestroyVirtual: { id in
                                _ = virtualManager.destroy(id: id)
                                refreshDisplays()
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: max(210, min(CGFloat(displays.count) * 215.0, 520)))

            Divider()

            // Footer bar (Virtual Dummy creation & Utilities)
            HStack {
                Menu {
                    Button("1080p FHD (1920 × 1080, 16:9)") {
                        createDummy(width: 1920, height: 1080)
                    }
                    Button("1440p QHD (2560 × 1440, 16:9)") {
                        createDummy(width: 2560, height: 1440)
                    }
                    Button("4K UHD (3840 × 2160, 16:9)") {
                        createDummy(width: 3840, height: 2160)
                    }
                    Button("1600p MacBook (2560 × 1600, 16:10)") {
                        createDummy(width: 2560, height: 1600)
                    }
                    Button("Ultrawide UWQHD (3440 × 1440, 21:9)") {
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
        .frame(width: 380)
        .onAppear {
            refreshDisplays()
        }
        .onReceive(NotificationCenter.default.publisher(for: .displayBrightnessDidChange)) { notif in
            guard let dict = notif.userInfo,
                  let targetID = dict["displayID"] as? CGDirectDisplayID,
                  let newB = dict["brightness"] as? Double else { return }
            for i in 0..<displays.count {
                if displays[i].id.rawValue == targetID || (displays[i].isBuiltIn && targetID == CGMainDisplayID()) {
                    // Only update if not currently boosted past 1.0
                    if !displays[i].isXDRHeadroomBoosted && abs(displays[i].brightness - newB) > 0.005 {
                        displays[i].brightness = newB
                    }
                }
            }
        }
        .onReceive(syncTimer) { _ in
            for i in 0..<displays.count {
                if displays[i].isBuiltIn {
                    // Do not clobber boosted brightness with SDR hardware values
                    guard !displays[i].isXDRHeadroomBoosted && displays[i].brightness <= 1.0 else { continue }
                    if let hw = DisplayHardwareController.shared.getBrightness(for: displays[i].id.rawValue) {
                        if abs(displays[i].brightness - hw) > 0.02 {
                            displays[i].brightness = hw
                        }
                    }
                }
            }
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
