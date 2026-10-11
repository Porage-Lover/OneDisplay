import SwiftUI
import AppKit
import OneDisplayCore

public struct AppMenuView: View {
    @State private var displays: [DisplayItem] = [
        DisplayItem(id: DisplayID(1), name: "Built-in Liquid Retina XDR", isBuiltIn: true, isVirtual: false, brightness: 0.7, contrast: 0.5, volume: 0.5),
        DisplayItem(id: DisplayID(2), name: "External 4K Monitor", isBuiltIn: false, isVirtual: false, brightness: 0.8, contrast: 0.5, volume: 0.6)
    ]
    @State private var isSleepInhibited: Bool = false

    private let brightnessManager = BrightnessManager()
    private let ddcController = DDCController()
    private let virtualManager = VirtualDisplayManager()

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("OneDisplay")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Toggle(isOn: $isSleepInhibited) {
                    Image(systemName: isSleepInhibited ? "cup.and.saucer.fill" : "cup.and.saucer")
                        .foregroundColor(isSleepInhibited ? .orange : .secondary)
                }
                .toggleStyle(.button)
                .help("Prevent Display Sleep (Caffeine mode)")
            }
            .padding(.horizontal, 4)

            Divider()

            ScrollView {
                VStack(spacing: 8) {
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
            }
            .frame(maxHeight: 320)

            Divider()

            HStack {
                Button(action: addVirtualDisplay) {
                    Label("Add Virtual Dummy", systemImage: "plus.rectangle.on.rectangle")
                }
                .buttonStyle(.borderless)

                Spacer()

                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Settings")

                Button(action: quitApp) {
                    Image(systemName: "power")
                }
                .buttonStyle(.borderless)
                .help("Quit OneDisplay")
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .frame(width: 340)
    }

    private func addVirtualDisplay() {
        let count = displays.filter { $0.isVirtual }.count + 1
        let id = virtualManager.createVirtualDisplay(name: "Virtual Dummy \(count)", width: 1920, height: 1080)
        let newItem = DisplayItem(id: id, name: "Virtual Dummy \(count)", isBuiltIn: false, isVirtual: true, brightness: 1.0, contrast: 0.5, volume: 0.5)
        displays.append(newItem)
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
