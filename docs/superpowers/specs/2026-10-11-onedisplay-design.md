# OneDisplay — Design Specification

**Date:** 2026-10-11  
**Project:** OneDisplay  
**Target Platform:** macOS 26.3+ (Xcode 27.2 SDK / Swift 5.9+)  
**Architecture:** Standalone, privacy-first native macOS display management architecture  

---

## 1. Executive Summary & Goals

OneDisplay is a lightweight, high-performance, privacy-first macOS menu bar utility for complete display management. It delivers core display control features while completely eliminating all cloud dependencies, commercial licensing frameworks, and telemetry trackers.

### Included Features
- **(A) Display Hardware & DDC/CI Control**: Direct IOKit MCCS communication for hardware backlight, contrast, volume, RGB gain, and input switching.
- **(B) Apple Silicon HDMI-CEC Tunneling**: DisplayPort AUX DPCD CEC tunneling for TV/AVR standby, volume, and input switching.
- **(C) Brightness, XDR & Sub-Zero Dimming**: Combined hardware + software slider, XDR brightness boost up to 1,600 nits, sub-zero software dimming, and ambient light sensor synchronization.
- **(D) Resolution & Flexible HiDPI Scaling**: HiDPI modes on external non-Retina displays, custom resolution list generation, and refresh rate control.
- **(E) Virtual Screens & Dummies**: `CGVirtualDisplay` creation with custom aspect ratios, and internal display disconnection on Apple Silicon Macs.
- **(F) Picture-in-Picture (PiP) & Screen Streaming**: `ScreenCaptureKit` floating stream window with crop, rotation, and real-time shader filters.
- **(H) Display Layout & Protection Modes**: Desktop coordinate positioning, mirror sets, and resolution/layout protection policies.
- **(I) Automation, CLI & Local REST API**: Embedded HTTP REST server (`/command/*` and `/stream` SSE on port `8969`), CLI commands (`onedisplay`), and URL scheme.

### Excluded / Removed Components
- ❌ **Commercial Licensing**: No Paddle.framework, activation keys, trial timeouts, or payment prompts.
- ❌ **Analytics & Telemetry**: No Sentry SDK, crash reporting, or network logging.
- ❌ **Update Checking**: No Sparkle.framework or remote appcast polling.
- ❌ **Vendor Cloud TV Protocols**: No LG webOS, Samsung SmartView, or third-party cloud integrations.

---

## 2. System Architecture & Package Structure

OneDisplay is structured as a modular Swift Package Manager project:

```
OneDisplay/
├── Package.swift
├── Sources/
│   ├── OneDisplayCore/             # Hardware control, protocols & engine library
│   │   ├── DDC/                    # IOKit DDC/CI frame builder & I2C transactions
│   │   │   ├── DDCController.swift
│   │   │   └── MCCSCommand.swift
│   │   ├── CEC/                    # DPCD AUX HDMI-CEC tunneling (Apple Silicon)
│   │   │   ├── CECController.swift
│   │   │   └── CECFrame.swift
│   │   ├── Brightness/             # Combined brightness curve & gamma/Metal dimming
│   │   │   ├── BrightnessManager.swift
│   │   │   ├── XDRManager.swift
│   │   │   └── AmbientLightSensor.swift
│   │   ├── Resolution/             # CoreDisplay mode enumeration & HiDPI switching
│   │   │   ├── DisplayModeManager.swift
│   │   │   └── DisplayMode.swift
│   │   ├── VirtualDisplay/         # CGVirtualDisplay manager & dummy screens
│   │   │   └── VirtualDisplayManager.swift
│   │   ├── Streaming/              # ScreenCaptureKit PiP capture & Metal shader pipeline
│   │   │   ├── StreamPipeline.swift
│   │   │   └── VideoFilter.swift
│   │   ├── Layout/                 # Display mirroring & coordinate management
│   │   │   └── DisplayLayoutManager.swift
│   │   ├── Models/                 # Display identity, state & settings models
│   │   │   ├── DisplayItem.swift
│   │   │   └── DisplayID.swift
│   │   └── Server/                 # Embedded HTTP REST server & SSE event stream
│   │       ├── HTTPServer.swift
│   │       ├── HTTPRequest.swift
│   │       └── HTTPResponse.swift
│   ├── OneDisplayApp/              # SwiftUI Menu Bar Application Target
│   │   ├── OneDisplayApp.swift     # App entry point (@main, NSApplicationDelegateAdaptor)
│   │   ├── MenuBar/                # Popover views (AppMenuView, DisplayCard, Sliders)
│   │   │   ├── AppMenuView.swift
│   │   │   ├── DisplayCardView.swift
│   │   │   └── AppSliderView.swift
│   │   └── Settings/               # Streamlined preferences window
│   │       ├── SettingsView.swift
│   │       ├── DisplaysSettingsTab.swift
│   │       ├── VirtualDisplaySettingsTab.swift
│   │       └── AutomationSettingsTab.swift
│   └── OneDisplayCLI/              # Command-line utility target (`onedisplay`)
│       └── main.swift
└── Tests/
    └── OneDisplayCoreTests/
        ├── DDCTests.swift
        ├── BrightnessTests.swift
        └── ServerTests.swift
```

---

## 3. Core Component Specifications

### 3.1 DDC/CI & MCCS Engine (`OneDisplayCore/DDC`)
- **Transport**: Communicates via `IOKit` `IOI2CInterface` matching service class `IOFramebuffer` and `IOMobileFramebuffer`.
- **MCCS Framing**:
  - Write Packet: `[0x51, 0x84, 0x03, opcode, val_hi, val_lo, checksum]`
  - Read Request: `[0x51, 0x82, 0x01, opcode, checksum]`
  - OpCodes:
    - Luminance (Backlight): `0x10`
    - Contrast: `0x12`
    - Audio Volume: `0x62`
    - Audio Mute: `0x8D` (1 = Mute, 2 = Unmute)
    - Input Source: `0x60` (DisplayPort 1/2, HDMI 1/2, USB-C)
    - Power State: `0xD6` (0x01 = On, 0x04 = Standby, 0x05 = Suspend)
    - RGB Gains: `0x16` (Red), `0x18` (Green), `0x1A` (Blue)

### 3.2 Apple Silicon HDMI-CEC Engine (`OneDisplayCore/CEC`)
- **Transport**: Uses DisplayPort Configuration Data (DPCD) AUX register access via private CoreDisplay/SkyLight entrypoints.
- **CEC Commands**:
  - Destination Logical Address: `0x0` (TV), `0x5` (Audio System).
  - Standby: Opcode `0x36`.
  - Image View On: Opcode `0x04`.
  - Active Source: Opcode `0x82` followed by physical address bytes.
  - Volume Up/Down: Opcode `0x44` with parameter `0x41` (Volume Up) / `0x42` (Volume Down).

### 3.3 Brightness, XDR & Sub-Zero Dimming (`OneDisplayCore/Brightness`)
- **Combined Brightness Algorithm**:
  - Normalized slider range `0.0 ... 1.0`.
  - Hardware threshold `T_hw` (default `0.2`):
    - For `slider >= T_hw`: Backlight hardware level is mapped to `((slider - T_hw) / (1.0 - T_hw)) * 100%`. Software dimming factor is `1.0`.
    - For `slider < T_hw`: Hardware backlight stays at `0%` (or minimum safe level). Software dimming factor decreases from `1.0` to `0.0`, adjusting GPU gamma tables (`CGSetDisplayTransferByTable`) or rendering a calibrated transparent black Metal overlay.
- **XDR Headroom Boost**:
  - Unlocks extra brightness up to 1,600 nits peak on Apple Liquid Retina XDR displays using CoreBrightness EDR headroom control.
- **Ambient Light Sensor**:
  - Subscribes to ambient light sensor updates via `CoreBrightness` and interpolates target brightness along an adjustable response curve.

### 3.4 Resolution & Virtual Displays (`OneDisplayCore/Resolution` & `VirtualDisplay`)
- **Display Modes**:
  - Queries `CGSConfigureDisplayMode` and `CGDisplayCopyAllDisplayModes`.
  - Exposes HiDPI @2x Retina scaling options for all external displays.
- **Virtual Display Manager**:
  - Uses `CGVirtualDisplay` (from `SkyLight.framework`) to allocate virtual framebuffers with user-selected aspect ratios (16:9, 16:10, 21:9, 32:9, 4:3, 1:1) up to 8K.
- **Internal Display Disconnection**:
  - Disconnects internal display on Apple Silicon without closing the MacBook lid, maintaining external displays as main.

### 3.5 Screen Streaming & Picture-in-Picture (`OneDisplayCore/Streaming`)
- **Engine**:
  - `SCStream` (`ScreenCaptureKit.framework`) captures selected display or window frames at up to 120 FPS.
  - Renders to a floating, borderless `NSPanel` (`PIPView`).
  - Supports click-through (`ignoresMouseEvents = true`), transparency, and percentage-based crop rectangles.

### 3.6 Local HTTP REST Server & CLI (`OneDisplayCore/Server` & `OneDisplayCLI`)
- **Port**: Default `8969` (TCP) bound to `127.0.0.1`.
- **Endpoints**:
  - `GET /command/get?<param>`: Query state (e.g. `/command/get?brightness=1`).
  - `GET /command/set?<param>=<val>`: Set state (e.g. `/command/set?brightness=80%&display=1`).
  - `GET /command/toggle?<param>`: Toggle feature (e.g. `/command/toggle?pip=1`).
  - `GET /stream`: Server-Sent Events (SSE) event stream (`text/event-stream`) publishing live display events.
- **CLI (`onedisplay`)**:
  - Commands: `onedisplay get`, `onedisplay set`, `onedisplay list`, `onedisplay virtual-display create`, `onedisplay pip start`.

---

## 4. Frontend & User Experience (`OneDisplayApp`)

Providing a clean, responsive native menu bar UI while eliminating clutter:

### 4.1 Menu Bar Popover (`AppMenuView`)
- **Compact Status Item**: Sits in macOS menu bar (`NSStatusItem`).
- **Display Cards**:
  - Header: Display icon, name, native resolution, connection type, main display badge.
  - Smooth Sliders (`AppSliderView`):
    - Combined Brightness (with sub-zero indicator)
    - Contrast
    - Volume
  - Quick Toggles:
    - HiDPI Resolution picker dropdown
    - Input Source picker (HDMI 1, HDMI 2, DP, USB-C)
    - Orientation (0°, 90°, 180°, 270°)
    - Mirroring / Disconnect
- **Virtual Screens & PiP Card**:
  - Button to spawn new dummy screen.
  - Button to launch PiP stream of any active display.
- **Footer**:
  - Sleep inhibitor toggle.
  - Settings icon to open full Preferences.

### 4.2 Streamlined Settings Window (`SettingsView`)
- **Tab 1: Displays**: DDC/CI enable, CEC enable, brightness curve minimums, ALS sync.
- **Tab 2: Virtual Displays**: Default aspect ratio, resolution list generator, auto-disconnect on sleep.
- **Tab 3: Automation & API**: HTTP Server toggle, port selection (default 8969), token protection.
- **Tab 4: General**: Launch at login (`SMAppService`), menu bar icon style, global keyboard shortcuts.

---

## 5. Security, Permissions & Build Targets

- **Sandboxing**: Disabled (standard for low-level system display utilities requiring IOKit I2C access, ScreenCaptureKit, and SkyLight display reconfiguration).
- **Entitlements**:
  - `com.apple.security.network.client`: true (local REST server & socket communication).
  - Screen Recording permission (prompted on first PiP launch for `ScreenCaptureKit`).
  - Accessibility permission (for global volume/brightness media key interception).
- **Zero Third-Party Privacy Impact**: No analytics, no license validation, no crash telemetry. All operations remain strictly offline on the local machine.
