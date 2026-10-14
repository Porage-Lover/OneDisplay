import SwiftUI

public struct AppSliderView: View {
    let title: String
    let icon: String
    @Binding var value: Double
    var maxValue: Double = 1.0
    var isSubZeroSupported: Bool = false
    let onValueChange: (Double) -> Void

    public init(
        title: String,
        icon: String,
        value: Binding<Double>,
        maxValue: Double = 1.0,
        isSubZeroSupported: Bool = false,
        onValueChange: @escaping (Double) -> Void = { _ in }
    ) {
        self.title = title
        self.icon = icon
        self._value = value
        self.maxValue = max(1.0, maxValue)
        self.isSubZeroSupported = isSubZeroSupported
        self.onValueChange = onValueChange
    }

    private var safeMax: Double {
        max(1.0, maxValue)
    }

    private var safeSliderBinding: Binding<Double> {
        Binding(
            get: {
                max(0.0, min(safeMax, value))
            },
            set: { newValue in
                let clamped = max(0.0, min(safeMax, newValue))
                value = clamped
                onValueChange(clamped)
            }
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(value > 1.0 ? .yellow : .accentColor)
                    .frame(width: 16)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if value > 1.0 {
                    Text("XDR Boost")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.yellow.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                } else if isSubZeroSupported && value < 0.05 {
                    Text("Sub-Zero")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(4)
                }
                Text("\(Int(round(value * 100)))%")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(value > 1.0 ? .orange : .secondary)
            }
            Slider(value: safeSliderBinding, in: 0.0...safeMax)
                .controlSize(.small)
        }
        .padding(.vertical, 2)
    }
}
