import SwiftUI
import OneDisplayCore

public struct DisplayCardView: View {
    @Binding var display: DisplayItem
    let onBrightnessChange: (Double) -> Void
    private let modeManager = DisplayModeManager()
    private let xdrManager = XDRManager()

    public init(
        display: Binding<DisplayItem>,
        onBrightnessChange: @escaping (Double) -> Void = { _ in }
    ) {
        self._display = display
        self.onBrightnessChange = onBrightnessChange
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Icon + Name + Badges
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: display.isBuiltIn ? "laptopcomputer" : (display.isVirtual ? "display.trianglebadge.exclamationmark" : "display"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(display.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    if !display.currentModeString.isEmpty {
                        Text(display.currentModeString)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if display.isVirtual {
                    Text("Virtual")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                } else if display.isBuiltIn {
                    Text("Built-in")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundColor(.secondary)
                        .cornerRadius(4)
                }
            }

            Divider()

            // Brightness Control (Combined Hardware + Sub-Zero Dimming)
            AppSliderView(
                title: "Brightness",
                icon: "sun.max.fill",
                value: $display.brightness,
                isSubZeroSupported: true,
                onValueChange: { newBrightness in
                    onBrightnessChange(newBrightness)
                }
            )

            // Resolution & Display Actions Row
            HStack(spacing: 8) {
                // Resolution Mode Menu
                if !display.availableModes.isEmpty {
                    Menu {
                        ForEach(display.availableModes, id: \.self) { mode in
                            Button(action: { switchMode(mode) }) {
                                HStack {
                                    Text("\(mode.width) × \(mode.height)\(mode.isHiDPI ? " (HiDPI)" : "")")
                                    if display.currentModeString.contains("\(mode.width) × \(mode.height)") {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.dashed")
                                .font(.system(size: 11))
                            Text("Resolution")
                                .font(.system(size: 11))
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                // XDR Boost Toggle (for XDR displays)
                if display.isBuiltIn {
                    Button(action: toggleXDRBoost) {
                        HStack(spacing: 4) {
                            Image(systemName: display.isXDRHeadroomBoosted ? "bolt.fill" : "bolt")
                                .font(.system(size: 11))
                                .foregroundColor(display.isXDRHeadroomBoosted ? .yellow : .secondary)
                            Text("XDR Boost")
                                .font(.system(size: 11))
                                .foregroundColor(display.isXDRHeadroomBoosted ? .primary : .secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(display.isXDRHeadroomBoosted ? Color.yellow.opacity(0.15) : Color.clear)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Boost peak SDR headroom to full XDR brightness")
                }

                Spacer()

                // Launch Picture-in-Picture
                Button(action: launchPIP) {
                    HStack(spacing: 4) {
                        Image(systemName: "pip.enter")
                            .font(.system(size: 11))
                        Text("PiP")
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Launch Picture-in-Picture stream of this display")
            }
            .padding(.top, 2)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func switchMode(_ mode: DisplayMode) {
        if modeManager.setMode(for: display.id, mode: mode) {
            display.currentModeString = "\(mode.width) × \(mode.height)\(mode.refreshRate > 0 ? " @ \(Int(round(mode.refreshRate)))Hz" : "")"
        }
    }

    private func toggleXDRBoost() {
        display.isXDRHeadroomBoosted.toggle()
        let mult = display.isXDRHeadroomBoosted ? 1.6 : 1.0
        xdrManager.setEDRHeadroom(displayID: display.id, multiplier: mult)
    }

    private func launchPIP() {
        PIPWindowController.shared.showPIP(for: display.id, name: display.name)
    }
}
