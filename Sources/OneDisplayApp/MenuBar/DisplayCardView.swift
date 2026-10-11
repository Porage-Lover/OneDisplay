import SwiftUI
import OneDisplayCore

public struct DisplayCardView: View {
    @Binding var display: DisplayItem
    let onBrightnessChange: (Double) -> Void
    let onVolumeChange: (Double) -> Void

    public init(
        display: Binding<DisplayItem>,
        onBrightnessChange: @escaping (Double) -> Void = { _ in },
        onVolumeChange: @escaping (Double) -> Void = { _ in }
    ) {
        self._display = display
        self.onBrightnessChange = onBrightnessChange
        self.onVolumeChange = onVolumeChange
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: display.isBuiltIn ? "laptopcomputer" : (display.isVirtual ? "display.trianglebadge.exclamationmark" : "display"))
                    .font(.headline)
                    .foregroundColor(.accentColor)
                Text(display.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if display.isVirtual {
                    Text("Virtual")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                } else if display.isBuiltIn {
                    Text("Built-in")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundColor(.secondary)
                        .cornerRadius(4)
                }
            }

            Divider()

            AppSliderView(
                title: "Brightness",
                icon: "sun.max.fill",
                value: $display.brightness,
                isSubZeroSupported: true,
                onEditingChanged: { _ in
                    onBrightnessChange(display.brightness)
                }
            )

            if !display.isVirtual {
                AppSliderView(
                    title: "Volume",
                    icon: "speaker.wave.2.fill",
                    value: $display.volume,
                    isSubZeroSupported: false,
                    onEditingChanged: { _ in
                        onVolumeChange(display.volume)
                    }
                )
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}
