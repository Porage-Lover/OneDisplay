# XDR Brightness Boost Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement true physical XDR Brightness boost (100%–160% / up to 1600 nits) for Liquid Retina XDR displays in OneDisplay using a full-screen Metal CAMetalLayer multiply blend mode overlay, eliminating crashes, gamma clipping, and color distortion.

**Architecture:** Replace the dummy 4x4 window in `XDRManager` with an `EDROverlayController` managing a full-screen borderless `NSWindow` backed by a `CAMetalLayer` with `multiplyBlendMode`, `wantsExtendedDynamicRangeContent = true`, and `extendedLinearDisplayP3` colorspace. When brightness exceeds 1.0 (up to 1.6), the Metal layer renders a clear pass with multiplier values, scaling SDR desktop luminance into EDR headroom to command the mini-LED backlight to max physical nits while keeping pure blacks at 0 nits; wire `BrightnessManager`, `DisplayCardView`, and `AppSliderView` with safe range bounds and real-time percentage indicators.

**Tech Stack:** Swift 5.9+, AppKit (`NSWindow`, `NSScreen`), Metal (`MTLDevice`, `MTLCommandQueue`, `MTLRenderPassDescriptor`), QuartzCore (`CAMetalLayer`, `multiplyBlendMode`), SwiftUI.

**Spec:** `docs/superpowers/specs/2026-10-11-onedisplay-design.md`

## Global Constraints

- Platform version floor: macOS 14.0+ / tested on macOS 26.3+ Apple Silicon.
- Toolchain: Xcode developer directory (`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`).
- Zero gamma distortion or color clamping: Gamma LUTs must never be modified above 1.0; pure blacks must remain 0 nits.
- Pass-through window behavior: Full-screen overlay must ignore mouse events (`ignoresMouseEvents = true`) and remain non-activating (`canBecomeKey = false`, `canBecomeMain = false`).
- Zero crashes on toggle: SwiftUI slider bounds and state transitions must be strictly clamped before updating ranges.

## Review Focus

- Multiplier transition to <= 1.0 (must immediately order out overlay window and release Metal drawables without leaking resources).
- Display reconfiguration / screen resolution change (overlay window frame must immediately resize to match updated `screen.frame`).
- Non-XDR displays or external monitors (headroom calculation must detect capability via `maximumPotentialExtendedDynamicRangeColorComponentValue` and disallow unsupported boost).
- Rapid toggling of XDR button in Menu Bar (SwiftUI slider must not crash with range lowerBound > upperBound assertions).
- Zero clipping of deep blacks (multiply blend identity: `0.0 * multiplier = 0.0` ensures local dimming zones remain completely off for black pixels).

---

### Task 1: Core EDR Metal Overlay & Window Management in `XDRManager`

**Files:**
- Modify: `Sources/OneDisplayCore/Brightness/XDRManager.swift`
- Test: `Tests/OneDisplayCoreTests/BrightnessTests.swift`

**Interfaces:**
- Consumes: `DisplayID`
- Produces:
  - `class XDRManager`:
    - `maxEDRHeadroom(for displayID: DisplayID) -> Double`
    - `setEDRHeadroom(displayID: DisplayID, multiplier: Double) -> Bool`
    - `getHeadroom(for displayID: DisplayID) -> Double`
    - `isBoosted(for displayID: DisplayID) -> Bool`
    - `tearDownAll()`

- [ ] **Step 1: Write the failing tests in `Tests/OneDisplayCoreTests/BrightnessTests.swift`**

```swift
func testXDRHeadroomCalculationAndClamping() {
    let xdr = XDRManager.shared
    let testID = DisplayID(1)
    
    // Default headroom when not boosted should be 1.0
    XCTAssertEqual(xdr.getHeadroom(for: testID), 1.0)
    XCTAssertFalse(xdr.isBoosted(for: testID))
    
    // Setting headroom to 1.4 should reflect as boosted
    xdr.setEDRHeadroom(displayID: testID, multiplier: 1.4)
    XCTAssertEqual(xdr.getHeadroom(for: testID), 1.4)
    XCTAssertTrue(xdr.isBoosted(for: testID))
    
    // Setting headroom back to 1.0 should reset boosted state
    xdr.setEDRHeadroom(displayID: testID, multiplier: 1.0)
    XCTAssertEqual(xdr.getHeadroom(for: testID), 1.0)
    XCTAssertFalse(xdr.isBoosted(for: testID))
}
```

- [ ] **Step 2: Run test to verify it fails or exposes lack of cleanup**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter BrightnessTests`
Expected: Passes or fails based on existing basic mock, but lacks overlay controller.

- [ ] **Step 3: Implement `EDRMetalView`, `EDROverlayWindow`, and `XDRManager` in `Sources/OneDisplayCore/Brightness/XDRManager.swift`**

Implement:
1. `EDRMetalView`: Subclass of `NSView` using `CAMetalLayer` with `pixelFormat = .rgba16Float`, `wantsExtendedDynamicRangeContent = true`, `colorspace = extendedLinearDisplayP3`, `compositingFilter = "multiplyBlendMode"`, and `presentsWithTransaction = true`. `render(multiplier: Double)` draws a clear pass with `clearColor = MTLClearColor(red: v, green: v, blue: v, alpha: 1.0)`.
2. `EDROverlayWindow`: Subclass of `NSWindow` with style `.borderless`, `level = .screenSaver`, `backgroundColor = .clear`, `ignoresMouseEvents = true`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]`.
3. `XDRManager`: Manages overlay windows per `DisplayID` on `DispatchQueue.main`. Dispatches render on multiplier change. When multiplier $\le 1.001$, orders out and removes window. Observes `NSApplication.didChangeScreenParametersNotification` to update frame to `screen.frame`.

- [ ] **Step 4: Run test to verify it passes**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter BrightnessTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/OneDisplayCore/Brightness/XDRManager.swift Tests/OneDisplayCoreTests/BrightnessTests.swift
git commit -m "feat(core): implement full-screen EDR CAMetalLayer multiply blend overlay in XDRManager"
```

---

### Task 2: Coordinate EDR Boost & Backlight Routing in `BrightnessManager`

**Files:**
- Modify: `Sources/OneDisplayCore/Brightness/BrightnessManager.swift`
- Test: `Tests/OneDisplayCoreTests/BrightnessTests.swift`

**Interfaces:**
- Consumes: `XDRManager`, `DisplayHardwareController`
- Produces:
  - `BrightnessManager.applyBrightness(displayID:sliderValue:hardwareMin:isBuiltIn:) -> BrightnessLevel`

- [ ] **Step 1: Write failing tests for boosted brightness routing and teardown**

```swift
func testBuiltInBrightnessRoutingBoostAndReset() {
    let bm = BrightnessManager()
    let displayID = DisplayID(1)
    
    // Slider at 1.4: should set hardware to 1.0 and EDR headroom to 1.4
    let boostedLevel = bm.applyBrightness(displayID: displayID, sliderValue: 1.4, isBuiltIn: true)
    XCTAssertEqual(boostedLevel.hardwareLevel, 1.0)
    XCTAssertEqual(boostedLevel.softwareDimmingFactor, 1.4)
    XCTAssertTrue(XDRManager.shared.isBoosted(for: displayID))
    
    // Slider reduced to 0.8: should reset EDR headroom to 1.0
    let normalLevel = bm.applyBrightness(displayID: displayID, sliderValue: 0.8, isBuiltIn: true)
    XCTAssertEqual(normalLevel.hardwareLevel, 0.8)
    XCTAssertEqual(normalLevel.softwareDimmingFactor, 1.0)
    XCTAssertFalse(XDRManager.shared.isBoosted(for: displayID))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter BrightnessTests`
Expected: FAIL because slider <= 1.0 did not reset `XDRManager.shared.setEDRHeadroom(multiplier: 1.0)`.

- [ ] **Step 3: Update `applyBrightness` in `Sources/OneDisplayCore/Brightness/BrightnessManager.swift`**

When `isBuiltIn` is true:
- If `sliderValue > 1.0`: set hardware to 1.0, alpha to 0.0, set EDR headroom to `sliderValue`.
- If `sliderValue <= 1.0`: if `XDRManager.shared.isBoosted(for: displayID)`, call `XDRManager.shared.setEDRHeadroom(displayID: displayID, multiplier: 1.0)`. Set hardware to `clamped`. Handle sub-zero dimming if `< 0.05`.

- [ ] **Step 4: Run test to verify it passes**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter BrightnessTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/OneDisplayCore/Brightness/BrightnessManager.swift Tests/OneDisplayCoreTests/BrightnessTests.swift
git commit -m "feat(core): coordinate EDR boost and reset lifecycle in BrightnessManager"
```

---

### Task 3: Crash-Proof Menu Bar UI & Percentage Sync in `DisplayCardView` and `AppSliderView`

**Files:**
- Modify: `Sources/OneDisplayApp/MenuBar/AppSliderView.swift`
- Modify: `Sources/OneDisplayApp/MenuBar/DisplayCardView.swift`
- Modify: `Sources/OneDisplayApp/MenuBar/AppMenuView.swift`

**Interfaces:**
- Consumes: `XDRManager`, `BrightnessManager`
- Produces:
  - Crash-free XDR button toggle.
  - Dynamically clamped slider with custom safe binding.
  - Header brightness % badge (`100%`, `130%`, `160%`) with gold accent during boost.

- [ ] **Step 1: Write safe bounds clamp in `AppSliderView.swift`**

Prevent SwiftUI Slider `preconditionFailure` when `maxValue` transitions dynamically:
Wrap `$value` in a safe binding that clamps `min(max(value, 0.0), safeMax)` where `safeMax = max(1.0, maxValue)`.
Update badge formatting to display accurate percentage up to 160% (and orange highlight when > 1.0).

- [ ] **Step 2: Fix `toggleXDRBoost` and state synchronization in `DisplayCardView.swift`**

In `DisplayCardView`:
- Clamp `display.brightness` before altering bounds.
- When toggling ON: set `isXDRHeadroomBoosted = true`, determine target brightness (e.g. `max(display.brightness, 1.2)`), set `setEDRHeadroom`, and trigger `onBrightnessChange`.
- When toggling OFF: clamp `display.brightness = min(1.0, display.brightness)`, set `isXDRHeadroomBoosted = false`, set `setEDRHeadroom(multiplier: 1.0)`, and trigger `onBrightnessChange`.
- Update card header badge to display `\(Int(round(display.brightness * 100)))%` with yellow highlight when `isXDRHeadroomBoosted && brightness > 1.0`.

- [ ] **Step 3: Protect sync timer in `AppMenuView.swift`**

Ensure `syncTimer` never overwrites `display.brightness` with SDR hardware values (0.0..1.0) when `isXDRHeadroomBoosted` is true.

- [ ] **Step 4: Build release app and verify compilation**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/build_app.sh`
Expected: Build succeeds with code sign complete.

- [ ] **Step 5: Commit**

```bash
git add Sources/OneDisplayApp/MenuBar/AppSliderView.swift Sources/OneDisplayApp/MenuBar/DisplayCardView.swift Sources/OneDisplayApp/MenuBar/AppMenuView.swift
git commit -m "feat(app): fix XDR boost toggle crash, bind slider bounds safely, and display accurate boost percentage"
```

---

### Task 4: Integration Verification on macOS

**Files:**
- Verification only

**Interfaces:**
- Consumes: Installed `/Applications/OneDisplay.app`
- Produces: Physical verification on display

- [ ] **Step 1: Install built app into `/Applications/OneDisplay.app`**

```bash
cp -R dist/OneDisplay.app /Applications/OneDisplay.app
```

- [ ] **Step 2: Launch and verify process running cleanly**

```bash
pkill -f OneDisplay || true
open /Applications/OneDisplay.app
```

- [ ] **Step 3: Verify hardware/EDR headroom and absence of crashes**

Verify through log inspection or test execution that:
- Moving slider 100% to 160% engages full-screen CAMetalLayer multiply overlay.
- Clicking XDR toggle does not crash the app.
- Percentage reads 100%..160%.
- Display colors remain pristine with pure blacks (no gamma blowout / deep fried mess).

- [ ] **Step 4: Final commit and cleanup**

```bash
git status
```
