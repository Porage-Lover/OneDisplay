# OneDisplay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `OneDisplay`, a clean, standalone, privacy-first macOS display control suite (Swift package with Core library, SwiftUI Menu Bar app, and CLI utility) implementing DDC/CI, DPCD CEC, combined & sub-zero brightness, HiDPI resolution scaling, virtual displays, ScreenCaptureKit PiP streaming, display layout protection, and a local HTTP REST server.

**Architecture:** A modular Swift package containing `OneDisplayCore` (headless hardware, protocol, streaming, and REST server library), `OneDisplayApp` (native SwiftUI menu bar app with streamlined display cards and settings), and `OneDisplayCLI` (command-line utility `onedisplay`).

**Tech Stack:** Swift 5.9+, SwiftUI, IOKit, ScreenCaptureKit, CoreDisplay/SkyLight, Network.framework / Foundation.

**Spec:** `docs/superpowers/specs/2026-10-11-onedisplay-design.md`

## Global Constraints

- Platform version floor: macOS 26.3+ (built and validated with Swift 5.9+ / Xcode 27+ toolchain on macOS 27).
- Zero third-party cloud SDKs: No Paddle.framework, no Sentry SDK, no Sparkle updates.
- All network capabilities are strictly local: HTTP server bound to `127.0.0.1` by default on port `8969`.
- Pure Swift Package Manager layout (`Package.swift`) building with standard `swift build` and `swift test`.

## Review Focus

- Invalid or missing DDC response from unsupported monitor (fallback gracefully without UI freeze).
- Combined brightness slider values under hardware threshold (sub-zero dimming must smoothly darken via gamma/software without clipping).
- Virtual screen creation with extreme aspect ratios (aspect math must clamp to valid GPU coordinate limits).
- ScreenCaptureKit permission denial (PiP must handle missing screen recording permission gracefully).
- HTTP REST request with invalid/malformed parameters (server must return structured HTTP 400 error without crash).

---

### Task 1: Package Scaffolding & Shared Data Models

**Files:**
- Create: `Package.swift`
- Create: `Sources/OneDisplayCore/Models/DisplayID.swift`
- Create: `Sources/OneDisplayCore/Models/DisplayItem.swift`
- Create: `Sources/OneDisplayCore/Models/DisplayMode.swift`
- Create: `Tests/OneDisplayCoreTests/ModelTests.swift`

**Interfaces:**
- Consumes: None (foundational task)
- Produces:
  - `DisplayID(rawValue: CGDirectDisplayID)`
  - `DisplayItem(id: DisplayID, name: String, isBuiltIn: Bool, isVirtual: Bool, brightness: Double, contrast: Double, volume: Double)`
  - `DisplayMode(width: Int, height: Int, scale: Double, refreshRate: Double, isHiDPI: Bool)`

- [x] **Step 1: Write failing tests for models in `Tests/OneDisplayCoreTests/ModelTests.swift`**
```swift
import XCTest
@testable import OneDisplayCore

final class ModelTests: XCTestCase {
    func testDisplayItemInitialization() {
        let id = DisplayID(rawValue: 1)
        let item = DisplayItem(id: id, name: "Dell 4K", isBuiltIn: false, isVirtual: false, brightness: 0.8, contrast: 0.5, volume: 0.6)
        XCTAssertEqual(item.id.rawValue, 1)
        XCTAssertEqual(item.name, "Dell 4K")
        XCTAssertFalse(item.isBuiltIn)
    }

    func testDisplayModeHiDPI() {
        let mode = DisplayMode(width: 3840, height: 2160, scale: 2.0, refreshRate: 60.0, isHiDPI: true)
        XCTAssertTrue(mode.isHiDPI)
        XCTAssertEqual(mode.aspectRatioString, "16:9")
    }
}
```

- [x] **Step 2: Run test to verify it fails**
Run: `swift test --filter ModelTests`
Expected: FAIL (types not defined)

- [x] **Step 3: Implement `Package.swift` and models in `Sources/OneDisplayCore/Models/`**
Implement `Package.swift` declaring products `OneDisplayCore`, `OneDisplayApp`, `OneDisplayCLI`, and target dependencies. Implement `DisplayID.swift`, `DisplayItem.swift`, and `DisplayMode.swift`.

- [x] **Step 4: Run test to verify it passes**
Run: `swift test --filter ModelTests`
Expected: PASS

- [x] **Step 5: Commit**
```bash
git add Package.swift Sources/OneDisplayCore/Models/ Tests/OneDisplayCoreTests/
git commit -m "feat(core): setup package structure and core display models"
```

---

### Task 2: DDC/CI & MCCS Protocol Engine

**Files:**
- Create: `Sources/OneDisplayCore/DDC/MCCSCommand.swift`
- Create: `Sources/OneDisplayCore/DDC/DDCController.swift`
- Test: `Tests/OneDisplayCoreTests/DDCTests.swift`

**Interfaces:**
- Consumes: `DisplayID` from Task 1
- Produces:
  - `enum MCCSOpcode: UInt8`: `luminance = 0x10`, `contrast = 0x12`, `audioVolume = 0x62`, `audioMute = 0x8D`, `inputSource = 0x60`, `powerMode = 0xD6`
  - `struct DDCFrame`: `makeWriteFrame(opcode: MCCSOpcode, value: UInt16) -> [UInt8]`, `makeReadFrame(opcode: MCCSOpcode) -> [UInt8]`
  - `class DDCController`: `write(displayID: DisplayID, opcode: MCCSOpcode, value: UInt16) -> Bool`, `read(displayID: DisplayID, opcode: MCCSOpcode) -> UInt16?`

- [x] **Step 1: Write failing tests in `Tests/OneDisplayCoreTests/DDCTests.swift`**
```swift
import XCTest
@testable import OneDisplayCore

final class DDCTests: XCTestCase {
    func testDDCWriteFrameGeneration() {
        // Opcode 0x10 (brightness), value 50 (0x0032)
        // Packet: [0x51, 0x84, 0x03, opcode, hi, lo, xor_checksum]
        let frame = DDCFrame.makeWriteFrame(opcode: .luminance, value: 50)
        XCTAssertEqual(frame[0], 0x51)
        XCTAssertEqual(frame[1], 0x84)
        XCTAssertEqual(frame[2], 0x03)
        XCTAssertEqual(frame[3], 0x10)
        XCTAssertEqual(frame[4], 0x00)
        XCTAssertEqual(frame[5], 0x32)
        // Verify XOR checksum
        var xor: UInt8 = 0x6E // Initial DDC write address 0x6E
        for b in frame.dropLast() { xor ^= b }
        XCTAssertEqual(frame.last, xor)
    }

    func testDDCReadFrameGeneration() {
        let frame = DDCFrame.makeReadFrame(opcode: .luminance)
        XCTAssertEqual(frame[0], 0x51)
        XCTAssertEqual(frame[1], 0x82)
        XCTAssertEqual(frame[2], 0x01)
        XCTAssertEqual(frame[3], 0x10)
    }
}
```

- [x] **Step 2: Run test to verify it fails**
Run: `swift test --filter DDCTests`
Expected: FAIL (DDCFrame not defined)

- [x] **Step 3: Implement `MCCSCommand.swift` and `DDCController.swift`**
Implement MCCS opcode enum, frame builder with XOR checksum, and `DDCController` using `IOI2CInterface` with mockable dispatch for headless testing.

- [x] **Step 4: Run test to verify it passes**
Run: `swift test --filter DDCTests`
Expected: PASS

- [x] **Step 5: Commit**
```bash
git add Sources/OneDisplayCore/DDC/ Tests/OneDisplayCoreTests/DDCTests.swift
git commit -m "feat(core): implement DDC/CI MCCS frame builder and controller"
```

---

### Task 3: Apple Silicon HDMI-CEC Engine

**Files:**
- Create: `Sources/OneDisplayCore/CEC/CECFrame.swift`
- Create: `Sources/OneDisplayCore/CEC/CECController.swift`
- Test: `Tests/OneDisplayCoreTests/CECTests.swift`

**Interfaces:**
- Consumes: None (independent hardware protocol)
- Produces:
  - `enum CECDestionation: UInt8`: `tv = 0x0`, `audioSystem = 0x5`, `broadcast = 0xF`
  - `enum CECOpcode: UInt8`: `imageViewOn = 0x04`, `standby = 0x36`, `userControlPressed = 0x44`, `userControlReleased = 0x45`, `activeSource = 0x82`
  - `class CECController`: `sendPower(displayID: DisplayID, on: Bool)`, `sendVolumeStep(displayID: DisplayID, up: Bool)`, `switchInput(displayID: DisplayID, physicalAddress: [UInt8])`

- [x] **Step 1: Write failing tests in `Tests/OneDisplayCoreTests/CECTests.swift`**
```swift
import XCTest
@testable import OneDisplayCore

final class CECTests: XCTestCase {
    func testCECStandbyFrame() {
        let frame = CECFrame.makeStandby(destination: .tv)
        XCTAssertEqual(frame.destination, .tv)
        XCTAssertEqual(frame.opcode, .standby)
        XCTAssertTrue(frame.parameters.isEmpty)
    }

    func testCECActiveSourceFrame() {
        let frame = CECFrame.makeActiveSource(physicalAddress: [0x1, 0x0, 0x0, 0x0])
        XCTAssertEqual(frame.opcode, .activeSource)
        XCTAssertEqual(frame.parameters, [0x1, 0x0, 0x0, 0x0])
    }
}
```

- [x] **Step 2: Run test to verify it fails**
Run: `swift test --filter CECTests`
Expected: FAIL (CECFrame not defined)

- [x] **Step 3: Implement `CECFrame.swift` and `CECController.swift`**
Implement frame structure and DPCD AUX packet builders.

- [x] **Step 4: Run test to verify it passes**
Run: `swift test --filter CECTests`
Expected: PASS

- [x] **Step 5: Commit**
```bash
git add Sources/OneDisplayCore/CEC/ Tests/OneDisplayCoreTests/CECTests.swift
git commit -m "feat(core): implement DPCD AUX HDMI-CEC frame builder and controller"
```

---

### Task 4: Brightness, XDR & Sub-Zero Dimming Engine

**Files:**
- Create: `Sources/OneDisplayCore/Brightness/BrightnessManager.swift`
- Create: `Sources/OneDisplayCore/Brightness/XDRManager.swift`
- Create: `Sources/OneDisplayCore/Brightness/AmbientLightSensor.swift`
- Test: `Tests/OneDisplayCoreTests/BrightnessTests.swift`

**Interfaces:**
- Consumes: `DisplayID`, `DDCController`
- Produces:
  - `struct BrightnessLevel`: `sliderValue: Double`, `hardwareLevel: Double`, `softwareDimmingFactor: Double`
  - `class BrightnessManager`: `calculateLevels(sliderValue: Double, hardwareMin: Double) -> BrightnessLevel`, `applyBrightness(displayID: DisplayID, sliderValue: Double)`
  - `class XDRManager`: `setEDRHeadroom(displayID: DisplayID, multiplier: Double)`

- [x] **Step 1: Write failing tests in `Tests/OneDisplayCoreTests/BrightnessTests.swift`**
```swift
import XCTest
@testable import OneDisplayCore

final class BrightnessTests: XCTestCase {
    func testCombinedBrightnessNormalRange() {
        let manager = BrightnessManager()
        // Hardware min = 0.2. Slider at 0.6 -> halfway in hardware range, software dimming 1.0
        let level = manager.calculateLevels(sliderValue: 0.6, hardwareMin: 0.2)
        XCTAssertEqual(level.softwareDimmingFactor, 1.0, accuracy: 0.001)
        XCTAssertEqual(level.hardwareLevel, 0.5, accuracy: 0.001) // (0.6 - 0.2) / 0.8 = 0.5
    }

    func testCombinedBrightnessSubZeroRange() {
        let manager = BrightnessManager()
        // Slider at 0.1 (< hardwareMin 0.2) -> hardware at 0.0, software dimming factor = 0.5 (0.1 / 0.2)
        let level = manager.calculateLevels(sliderValue: 0.1, hardwareMin: 0.2)
        XCTAssertEqual(level.hardwareLevel, 0.0, accuracy: 0.001)
        XCTAssertEqual(level.softwareDimmingFactor, 0.5, accuracy: 0.001)
    }
}
```

- [x] **Step 2: Run test to verify it fails**
Run: `swift test --filter BrightnessTests`
Expected: FAIL (BrightnessManager not defined)

- [x] **Step 3: Implement `BrightnessManager.swift`, `XDRManager.swift`, `AmbientLightSensor.swift`**
Implement the combined curve calculation, `CGSetDisplayTransferByTable` gamma curve calculation, and XDR EDR headroom adjustment.

- [x] **Step 4: Run test to verify it passes**
Run: `swift test --filter BrightnessTests`
Expected: PASS

- [x] **Step 5: Commit**
```bash
git add Sources/OneDisplayCore/Brightness/ Tests/OneDisplayCoreTests/BrightnessTests.swift
git commit -m "feat(core): implement combined brightness, sub-zero dimming, and XDR manager"
```

---

### Task 5: Resolution, Flexible HiDPI & Virtual Displays

**Files:**
- Create: `Sources/OneDisplayCore/Resolution/DisplayModeManager.swift`
- Create: `Sources/OneDisplayCore/VirtualDisplay/VirtualDisplayManager.swift`
- Test: `Tests/OneDisplayCoreTests/ResolutionAndVirtualDisplayTests.swift`

**Interfaces:**
- Consumes: `DisplayID`, `DisplayMode`
- Produces:
  - `class DisplayModeManager`: `getModes(for: DisplayID) -> [DisplayMode]`, `setMode(for: DisplayID, mode: DisplayMode) -> Bool`
  - `class VirtualDisplayManager`: `createVirtualDisplay(name: String, width: Int, height: Int, hiDPI: Bool) -> DisplayID?`, `destroy(id: DisplayID)`

- [x] **Step 1: Write failing tests in `Tests/OneDisplayCoreTests/ResolutionAndVirtualDisplayTests.swift`**
```swift
import XCTest
@testable import OneDisplayCore

final class ResolutionAndVirtualDisplayTests: XCTestCase {
    func testVirtualResolutionListGeneration() {
        let manager = VirtualDisplayManager()
        let modes = manager.generateModes(aspectWidth: 16, aspectHeight: 9, maxDimension: 3840)
        XCTAssertTrue(modes.contains { $0.width == 1920 && $0.height == 1080 })
        XCTAssertTrue(modes.contains { $0.width == 3840 && $0.height == 2160 })
    }
}
```

- [x] **Step 2: Run test to verify it fails**
Run: `swift test --filter ResolutionAndVirtualDisplayTests`
Expected: FAIL (VirtualDisplayManager not defined)

- [x] **Step 3: Implement `DisplayModeManager.swift` and `VirtualDisplayManager.swift`**
Implement resolution mode enumeration and `CGVirtualDisplay` allocation with mock fallback for CI environments.

- [x] **Step 4: Run test to verify it passes**
Run: `swift test --filter ResolutionAndVirtualDisplayTests`
Expected: PASS

- [x] **Step 5: Commit**
```bash
git add Sources/OneDisplayCore/Resolution/ Sources/OneDisplayCore/VirtualDisplay/ Tests/OneDisplayCoreTests/
git commit -m "feat(core): implement display mode manager and virtual display dummy creation"
```

---

### Task 6: ScreenCaptureKit Picture-in-Picture (PiP) Stream Pipeline

**Files:**
- Create: `Sources/OneDisplayCore/Streaming/VideoFilter.swift`
- Create: `Sources/OneDisplayCore/Streaming/StreamPipeline.swift`
- Test: `Tests/OneDisplayCoreTests/StreamingTests.swift`

**Interfaces:**
- Consumes: `DisplayID`
- Produces:
  - `struct StreamConfig`: `cropRect: CGRect?`, `rotation: Int`, `isFlippedHorizontal: Bool`, `isFlippedVertical: Bool`
  - `class StreamPipeline`: `startStream(sourceDisplayID: DisplayID, config: StreamConfig, frameHandler: @escaping (CVPixelBuffer) -> Void)`, `stopStream()`

- [x] **Step 1: Write failing tests in `Tests/OneDisplayCoreTests/StreamingTests.swift`**
```swift
import XCTest
@testable import OneDisplayCore

final class StreamingTests: XCTestCase {
    func testStreamConfigCropValidation() {
        let validConfig = StreamConfig(cropRect: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8), rotation: 90)
        XCTAssertEqual(validConfig.rotation, 90)
        XCTAssertEqual(validConfig.cropRect?.width, 0.8)
    }
}
```

- [x] **Step 2: Run test to verify it fails**
Run: `swift test --filter StreamingTests`
Expected: FAIL

- [x] **Step 3: Implement `VideoFilter.swift` and `StreamPipeline.swift`**
Implement `ScreenCaptureKit` stream wrapper and frame transform configuration.

- [x] **Step 4: Run test to verify it passes**
Run: `swift test --filter StreamingTests`
Expected: PASS

- [x] **Step 5: Commit**
```bash
git add Sources/OneDisplayCore/Streaming/ Tests/OneDisplayCoreTests/StreamingTests.swift
git commit -m "feat(core): implement ScreenCaptureKit stream pipeline and filter configuration"
```

---

### Task 7: Embedded Local HTTP REST Server & CLI Executable

**Files:**
- Create: `Sources/OneDisplayCore/Server/HTTPRequest.swift`
- Create: `Sources/OneDisplayCore/Server/HTTPResponse.swift`
- Create: `Sources/OneDisplayCore/Server/HTTPServer.swift`
- Create: `Sources/OneDisplayCLI/main.swift`
- Test: `Tests/OneDisplayCoreTests/ServerTests.swift`

**Interfaces:**
- Consumes: All `OneDisplayCore` controllers
- Produces:
  - `class HTTPServer`: `start(port: UInt16, token: String?)`, `stop()`
  - CLI binary `onedisplay` with verbs `get`, `set`, `list`, `virtual-display`, `pip`

- [x] **Step 1: Write failing tests in `Tests/OneDisplayCoreTests/ServerTests.swift`**
```swift
import XCTest
@testable import OneDisplayCore

final class ServerTests: XCTestCase {
    func testHTTPRequestParsing() {
        let raw = "GET /command/set?brightness=80%&display=1 HTTP/1.1\r\nHost: localhost:8969\r\n\r\n"
        let req = HTTPRequest.parse(raw: raw)
        XCTAssertEqual(req?.method, "GET")
        XCTAssertEqual(req?.path, "/command/set")
        XCTAssertEqual(req?.queryParameters["brightness"], "80%")
        XCTAssertEqual(req?.queryParameters["display"], "1")
    }

    func testHTTPResponseFormatting() {
        let res = HTTPResponse(statusCode: 200, statusText: "OK", body: "{\"status\":\"ok\"}")
        let raw = res.formattedResponse()
        XCTAssertTrue(raw.contains("HTTP/1.1 200 OK"))
        XCTAssertTrue(raw.contains("Content-Length: 15"))
    }
}
```

- [x] **Step 2: Run test to verify it fails**
Run: `swift test --filter ServerTests`
Expected: FAIL

- [x] **Step 3: Implement `HTTPRequest.swift`, `HTTPResponse.swift`, `HTTPServer.swift`, and `OneDisplayCLI/main.swift`**
Implement the socket listener on `127.0.0.1:8969`, `/command` dispatch, SSE `/stream`, and CLI argument handler.

- [x] **Step 4: Run test to verify it passes**
Run: `swift test --filter ServerTests`
Expected: PASS

- [x] **Step 5: Commit**
```bash
git add Sources/OneDisplayCore/Server/ Sources/OneDisplayCLI/ Tests/OneDisplayCoreTests/ServerTests.swift
git commit -m "feat(server,cli): implement embedded HTTP REST server and onedisplay CLI utility"
```

---

### Task 8: Streamlined SwiftUI Menu Bar Frontend (`OneDisplayApp`)

**Files:**
- Create: `Sources/OneDisplayApp/OneDisplayApp.swift`
- Create: `Sources/OneDisplayApp/MenuBar/AppSliderView.swift`
- Create: `Sources/OneDisplayApp/MenuBar/DisplayCardView.swift`
- Create: `Sources/OneDisplayApp/MenuBar/AppMenuView.swift`
- Create: `Sources/OneDisplayApp/Settings/SettingsView.swift`

**Interfaces:**
- Consumes: All `OneDisplayCore` controllers and models
- Produces: Executable app `OneDisplayApp` rendering MenuBarExtra status item, popover, and settings sheet.

- [x] **Step 1: Implement `AppSliderView.swift`**
Custom smooth macOS slider with tick marks, icon prefix, percentage label, and sub-zero indicator.

- [x] **Step 2: Implement `DisplayCardView.swift`**
Card view rendering display title, connection type, combined brightness slider, contrast/volume sliders, resolution mode picker, and quick rotation/mirror buttons.

- [x] **Step 3: Implement `AppMenuView.swift` & `SettingsView.swift`**
Popover container listing connected displays, virtual dummy creation button, PiP launcher, sleep inhibitor toggle, and Settings window with Hardware, Virtual Displays, and API tabs.

- [x] **Step 4: Implement `OneDisplayApp.swift`**
`@main` struct with `NSApplicationDelegateAdaptor` and `MenuBarExtra`.

- [x] **Step 5: Verify building application target**
Run: `swift build --target OneDisplayApp`
Expected: Build succeeds with 0 errors.

- [x] **Step 6: Commit**
```bash
git add Sources/OneDisplayApp/
git commit -m "feat(app): implement streamlined SwiftUI menu bar app and settings views"
```

---

### Task 9: End-to-End Build & CLI Smoke Test

**Files:**
- Modify: `README.md` (installation & CLI usage guide)

- [x] **Step 1: Run complete package build**
Run: `swift build -c release`
Expected: Success, produces `.build/release/OneDisplayApp` and `.build/release/onedisplay`

- [x] **Step 2: Run all unit tests**
Run: `swift test`
Expected: All tests PASS

- [x] **Step 3: Smoke test CLI utility**
Run: `.build/release/onedisplay --help`
Expected: Prints CLI options (`get`, `set`, `list`, `virtual-display`, `pip`) with exit code 0.

- [x] **Step 4: Create README and commit**
```bash
git add README.md
git commit -m "docs: add OneDisplay architecture, CLI usage, and API guide"
```
