import SwiftUI

public struct SettingsView: View {
    @AppStorage("hardwareMinBrightness") private var hardwareMinBrightness: Double = 0.2
    @AppStorage("httpServerPort") private var httpServerPort: Int = 8969
    @AppStorage("httpServerEnabled") private var httpServerEnabled: Bool = true
    @AppStorage("httpServerToken") private var httpServerToken: String = ""

    public init() {}

    public var body: some View {
        TabView {
            Form {
                Section(header: Text("Hardware & DDC/CI Control")) {
                    Slider(value: $hardwareMinBrightness, in: 0.05...0.40, step: 0.01) {
                        Text("Sub-Zero Threshold: \(Int(hardwareMinBrightness * 100))%")
                    }
                    Text("Hardware DDC minimum limit below which smooth GPU software dimming takes over.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .tabItem {
                Label("Hardware", systemImage: "display.2")
            }

            Form {
                Section(header: Text("Virtual Displays (Dummies)")) {
                    Text("Manage simulated display configurations and custom HiDPI scaling resolutions.")
                        .font(.subheadline)
                    Button("Create 16:9 4K Virtual Dummy") {
                        // Action handled in app state
                    }
                }
            }
            .padding()
            .tabItem {
                Label("Virtual Displays", systemImage: "tv")
            }

            Form {
                Section(header: Text("Local HTTP REST API & Stream")) {
                    Toggle("Enable Local REST Server", isOn: $httpServerEnabled)
                    TextField("Server Port", value: $httpServerPort, format: .number)
                        .frame(width: 120)
                    SecureField("API Bearer Token (Optional)", text: $httpServerToken)
                    Text("Allows CLI and local scripts (e.g. Raycast, Shortcuts) to query and set display controls at 127.0.0.1:\(httpServerPort). No external network access.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .tabItem {
                Label("Local API", systemImage: "network")
            }
        }
        .frame(width: 480, height: 280)
    }
}
