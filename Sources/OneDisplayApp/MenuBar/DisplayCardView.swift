import SwiftUI
import OneDisplayCore

public struct DisplayCardView: View {
    @Binding var display: DisplayItem
    let allDisplays: [DisplayItem]
    let onBrightnessChange: (Double, Bool) -> Void
    let onContrastChange: (Double, Bool) -> Void
    let onDestroyVirtual: (DisplayID) -> Void

    private let modeManager = DisplayModeManager()
    private let layoutManager = DisplayLayoutManager.shared
    private let brightnessManager = BrightnessManager()

    public init(
        display: Binding<DisplayItem>,
        allDisplays: [DisplayItem] = [],
        onBrightnessChange: @escaping (Double, Bool) -> Void = { _, _ in },
        onContrastChange: @escaping (Double, Bool) -> Void = { _, _ in },
        onDestroyVirtual: @escaping (DisplayID) -> Void = { _ in }
    ) {
        self._display = display
        self.allDisplays = allDisplays
        self.onBrightnessChange = onBrightnessChange
        self.onContrastChange = onContrastChange
        self.onDestroyVirtual = onDestroyVirtual
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Icon + Name + Badges + Dummy Delete Action
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: display.isBuiltIn ? "laptopcomputer" : (display.isVirtual ? "display.trianglebadge.exclamationmark" : "display"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(display.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)

                        Text("\(Int(round(display.brightness * 100)))%")
                            .font(.system(size: 11, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(display.isXDRHeadroomBoosted ? .yellow : .accentColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background((display.isXDRHeadroomBoosted ? Color.yellow : Color.accentColor).opacity(0.15))
                            .cornerRadius(4)
                    }

                    if !display.currentModeString.isEmpty {
                        Text(display.currentModeString)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if display.isVirtual {
                    Button(action: { onDestroyVirtual(display.id) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Disconnect & Delete Virtual Dummy")

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

            // 1. Unified Brightness Control (Sub-Zero Dimming < 0.2, Hardware 0.2..1.0, XDR Boost 1.0..1.6)
            AppSliderView(
                title: "Brightness",
                icon: "sun.max.fill",
                value: $display.brightness,
                maxValue: display.isXDRHeadroomBoosted ? 1.6 : 1.0,
                isSubZeroSupported: true,
                onValueChange: { newBrightness in
                    onBrightnessChange(newBrightness, display.isBuiltIn)
                }
            )

            // 2. Hardware / Software Contrast Slider (Feature A / C)
            AppSliderView(
                title: "Contrast",
                icon: "circle.righthalf.filled",
                value: $display.contrast,
                maxValue: 1.0,
                isSubZeroSupported: false,
                onValueChange: { newContrast in
                    onContrastChange(newContrast, display.isBuiltIn)
                }
            )

            // 3. Feature Actions Grid (Resolution, Rotation, Mirroring, Inputs, XDR Boost, PiP)
            HStack(spacing: 6) {
                // Resolution Mode Menu (Feature D)
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
                        HStack(spacing: 3) {
                            Image(systemName: "rectangle.dashed")
                                .font(.system(size: 10))
                            Text("Resolution")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                // Rotation Menu (Feature H)
                Menu {
                    Button(action: { setRotation(0) }) {
                        HStack {
                            Text("Standard (0°)")
                            if display.rotation == 0 { Image(systemName: "checkmark") }
                        }
                    }
                    Button(action: { setRotation(90) }) {
                        HStack {
                            Text("90° (Portrait)")
                            if display.rotation == 90 { Image(systemName: "checkmark") }
                        }
                    }
                    Button(action: { setRotation(180) }) {
                        HStack {
                            Text("180° (Inverted)")
                            if display.rotation == 180 { Image(systemName: "checkmark") }
                        }
                    }
                    Button(action: { setRotation(270) }) {
                        HStack {
                            Text("270° (Inverted Portrait)")
                            if display.rotation == 270 { Image(systemName: "checkmark") }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "rotate.right")
                            .font(.system(size: 10))
                        Text(display.rotation == 0 ? "Rotation" : "\(display.rotation)°")
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // Mirroring Menu (Feature H)
                Menu {
                    Button(action: { setMirror(master: nil) }) {
                        HStack {
                            Text("Stop Mirroring")
                            if !display.isMirrored { Image(systemName: "checkmark") }
                        }
                    }
                    Divider()
                    ForEach(allDisplays.filter { $0.id != display.id }) { other in
                        Button(action: { setMirror(master: other.id) }) {
                            Text("Mirror: \(other.name)")
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: display.isMirrored ? "rectangle.2.swap" : "rectangle.on.rectangle")
                            .font(.system(size: 10))
                        Text(display.isMirrored ? "Mirrored" : "Mirror")
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // Input Source Switcher (Feature A: DDC VCP 0x60)
                if !display.isBuiltIn && !display.isVirtual {
                    Menu {
                        Button("HDMI 1") { switchInput(0x11) }
                        Button("HDMI 2") { switchInput(0x12) }
                        Button("DisplayPort 1") { switchInput(0x0F) }
                        Button("DisplayPort 2") { switchInput(0x10) }
                        Button("USB-C") { switchInput(0x1B) }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "cable.connector")
                                .font(.system(size: 10))
                            Text("Input")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                Spacer()

                // XDR Boost Toggle (for XDR screens)
                if display.isBuiltIn {
                    Button(action: toggleXDRBoost) {
                        HStack(spacing: 3) {
                            Image(systemName: display.isXDRHeadroomBoosted ? "bolt.fill" : "bolt")
                                .font(.system(size: 10))
                                .foregroundColor(display.isXDRHeadroomBoosted ? .yellow : .secondary)
                            Text("XDR")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(display.isXDRHeadroomBoosted ? .primary : .secondary)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(display.isXDRHeadroomBoosted ? Color.yellow.opacity(0.18) : Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Boost peak SDR headroom to full XDR brightness without color distortion")
                }

                // Launch Picture-in-Picture (Feature F)
                Button(action: launchPIP) {
                    HStack(spacing: 3) {
                        Image(systemName: "pip.enter")
                            .font(.system(size: 10))
                        Text("PiP")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 5)
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

    private func setRotation(_ angle: Int) {
        if layoutManager.setRotation(for: display.id, angle: angle) {
            display.rotation = angle
        }
    }

    private func setMirror(master: DisplayID?) {
        if layoutManager.setMirror(target: display.id, master: master) {
            display.isMirrored = (master != nil)
        }
    }

    private func switchInput(_ source: UInt16) {
        brightnessManager.switchInputSource(displayID: display.id, source: source)
    }

    private func toggleXDRBoost() {
        display.isXDRHeadroomBoosted.toggle()
        let mult = display.isXDRHeadroomBoosted ? 1.6 : 1.0
        XDRManager.shared.setEDRHeadroom(displayID: display.id, multiplier: mult)
        if display.isXDRHeadroomBoosted {
            if display.brightness < 1.0 {
                display.brightness = 1.0
            }
            onBrightnessChange(display.brightness, display.isBuiltIn)
        } else {
            if display.brightness > 1.0 {
                display.brightness = 1.0
            }
            onBrightnessChange(display.brightness, display.isBuiltIn)
        }
    }

    private func launchPIP() {
        PIPWindowController.shared.showPIP(for: display.id, name: display.name)
    }
}
