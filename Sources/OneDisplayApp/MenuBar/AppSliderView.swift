import SwiftUI

public struct AppSliderView: View {
    let title: String
    let icon: String
    @Binding var value: Double
    var isSubZeroSupported: Bool = false
    let onEditingChanged: (Bool) -> Void

    public init(
        title: String,
        icon: String,
        value: Binding<Double>,
        isSubZeroSupported: Bool = false,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.title = title
        self.icon = icon
        self._value = value
        self.isSubZeroSupported = isSubZeroSupported
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 16)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if isSubZeroSupported && value < 0.2 {
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
                    .foregroundColor(.secondary)
            }
            Slider(value: $value, in: 0.0...1.0, onEditingChanged: onEditingChanged)
                .controlSize(.small)
        }
        .padding(.vertical, 2)
    }
}
