# OneDisplay

**OneDisplay** is a clean, native, privacy-first macOS display control suite built in Swift. It provides unified hardware display control (DDC/CI & Apple Silicon HDMI-CEC), smooth combined & sub-zero brightness dimming, virtual dummy screens, ScreenCaptureKit Picture-in-Picture streaming, display sleep management, and an embedded local REST API and CLI.

> **Privacy Guarantee**: OneDisplay contains **zero third-party tracking, analytics, or licensing frameworks** (no Paddle, Sentry, or Sparkle). All networking is strictly bound to `127.0.0.1` for local automation.

---

## Features

- **DDC/CI Hardware Control (Feature A)**: Controls brightness, contrast, audio volume, and input sources on external monitors via standard VESA MCCS opcodes over I2C/IOKit.
- **Apple Silicon HDMI-CEC (Feature B)**: Native CEC command frames tunneled via DPCD AUX channels for AV receivers and smart displays.
- **Combined & Sub-Zero Brightness (Feature C)**: Seamless single-slider brightness control that drives hardware DDC down to a hardware minimum (default 20%), transitioning smoothly into GPU gamma-table dimming for pitch-black environments. Includes XDR EDR headroom boosting.
- **Resolution & Flexible HiDPI Scaling (Feature D)**: Custom resolution list generator and mode switcher supporting 16:9, 16:10, 21:9, and ultra-wide screens.
- **Virtual Displays / Dummies (Feature E)**: Native virtual screen creation for headless Macs, remote access streaming targets, and custom resolution mirrors.
- **Picture-in-Picture Pipeline (Feature F)**: Low-latency display streaming via `ScreenCaptureKit` with customizable cropping, rotation, and horizontal/vertical mirroring.
- **Sleep Management & Layout Protection (Feature H)**: Quick menu bar toggle to inhibit system display sleep (caffeine mode).
- **Embedded Local HTTP Server & CLI (Feature I)**: Local REST server listening on `127.0.0.1:8969` with SSE event stream, accompanied by the `onedisplay` command-line utility.

---

## Architecture & Project Structure

The codebase is organized as a modular Swift Package Manager project:

```text
OneDisplay/
├── Package.swift
├── Sources/
│   ├── OneDisplayCore/             # Headless engine library
│   │   ├── Models/                 # DisplayID, DisplayItem, DisplayMode
│   │   ├── DDC/                    # MCCSCommand, DDCFrame, DDCController
│   │   ├── CEC/                    # CECFrame, CECController
│   │   ├── Brightness/             # BrightnessManager, XDRManager, AmbientLightSensor
│   │   ├── Resolution/             # DisplayModeManager
│   │   ├── VirtualDisplay/         # VirtualDisplayManager
│   │   ├── Streaming/              # VideoFilter, StreamPipeline (ScreenCaptureKit)
│   │   └── Server/                 # HTTPRequest, HTTPResponse, HTTPServer
│   ├── OneDisplayApp/              # SwiftUI Menu Bar application
│   │   ├── OneDisplayApp.swift     # @main entry point with MenuBarExtra
│   │   ├── MenuBar/                # AppMenuView, DisplayCardView, AppSliderView
│   │   └── Settings/               # SettingsView (Hardware, Virtual Displays, API)
│   └── OneDisplayCLI/              # Command-line utility
│       └── main.swift              # `onedisplay` CLI executable
└── Tests/
    └── OneDisplayCoreTests/        # Complete XCTest suite
```

---

## Build & Test

### Prerequisites
- macOS 14.0+ (Tested up to macOS 27)
- Xcode 15+ / Swift 5.9+

### Building
Build release binaries:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build -c release
```

Binaries will be created in:
- `.build/release/OneDisplayApp` (Menu Bar App)
- `.build/release/onedisplay` (CLI Utility)

### Running Tests
Execute the entire test suite:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

---

## CLI Usage (`onedisplay`)

```bash
# List all connected and virtual displays
.build/release/onedisplay list

# Query current brightness and volume of Display 1
.build/release/onedisplay get --display 1 --brightness --volume

# Set brightness to 75%
.build/release/onedisplay set --display 1 --brightness 75%

# Set volume to 50%
.build/release/onedisplay set --display 1 --volume 50%

# Create a 4K 16:9 virtual display
.build/release/onedisplay virtual-display create --name "Desk 4K" --width 3840 --height 2160

# Start local HTTP REST server on port 8969
.build/release/onedisplay server start --port 8969
```

---

## Local HTTP REST API

The local server listens on `127.0.0.1:8969`:

| Method | Endpoint | Query Parameters | Description |
|---|---|---|---|
| `GET` | `/command/list` | None | Returns JSON list of active displays |
| `GET` | `/command/get` | `display=<id>&brightness` | Reads current display brightness |
| `GET` | `/command/get` | `display=<id>&volume` | Reads current display volume |
| `GET` | `/command/set` | `display=<id>&brightness=80%` | Sets combined/sub-zero brightness |
| `GET` | `/command/set` | `display=<id>&volume=60%` | Sets hardware volume |
| `GET` | `/stream` | None | Server-Sent Events (SSE) notification stream |

---

## License
MIT License.
