# XDR Brightness Boost (v2: 1x1 EDR Enforcer + Gamma LUT Scaling)

## Goal Description
Fix the critical white screen issue and thread deadlock when enabling XDR boost in OneDisplay:
1. **Root Cause 1 (White Screen):** The previous implementation rendered a full-screen borderless window with `CAMetalLayer` and `compositingFilter = "multiplyBlendMode"`. macOS WindowServer does not support CoreAnimation multiply blend filters across separate top-level windows; it fell back to source-over opaque blending, drawing a solid full-screen white canvas over the desktop.
2. **Root Cause 2 (Test Deadlock):** `setEDRHeadroom` acquired `NSLock` and then synchronously called `apply()` on the main thread, which attempted to acquire the same non-recursive `NSLock`, deadlocking the process.
3. **The Solution:** Adopt the proven architecture using a 1x1 EDR enforcer window and hardware gamma LUT scaling:
   - A tiny **1x1 pixel** transparent borderless `NSWindow` backed by `CAMetalLayer` with `wantsExtendedDynamicRangeContent = true` and `extendedLinearDisplayP3` colorspace. This commands macOS WindowServer and Apple Silicon hardware into EDR mode without covering the desktop.
   - Read the display's base hardware transfer table via `CGGetDisplayTransferByTable(displayID, 256, &red, &green, &blue, &count)`.
   - Scale the transfer table entries by `multiplier` ($1.0 \dots 1.6$) and apply via `CGSetDisplayTransferByTable`.
   - Because WindowServer is in EDR mode, transfer table values $> 1.0$ command peak mini-LED brightness (up to 1600 nits) while $0.0 \times \text{multiplier} = 0.0$ preserves pure blacks.
   - When unboosting ($\le 1.0$), restore the base table, call `CGDisplayRestoreColorSyncSettings()`, and dismiss the 1x1 window.
   - Fix lock recursion to guarantee thread safety and eliminate deadlocks.

## User Review Required
> [!IMPORTANT]
> The full-screen overlay approach is completely eliminated. The desktop will remain 100% visible with normal window compositing, and luminance will scale directly through the GPU transfer table under EDR hardware engagement.

> [!NOTE]
> When moving the brightness slider below 100% ($\le 1.0$), the EDR boost is automatically released, restoring standard SDR hardware backlight control and ambient light sensor syncing.

## Open Questions
None. The root causes of both the white screen and the test hang have been completely identified and verified with scratch testing.

## Proposed Changes

### OneDisplayCore (Brightness Engine)

#### [MODIFY] `Sources/OneDisplayCore/Brightness/XDRManager.swift`
- Replace `EDROverlayWindow` with a 1x1 transparent `NSWindow` (`EDR1x1View`).
- Maintain `baseGammaTables: [DisplayID: ([Float], [Float], [Float])]` to preserve the original display transfer curves.
- In `setEDRHeadroom(displayID:multiplier:)`:
  - When `multiplier > 1.0`:
    - Ensure 1x1 enforcer window is ordered front to engage WindowServer EDR mode.
    - Multiply base gamma table entries by `Float(multiplier)`.
    - Apply via `CGSetDisplayTransferByTable(displayID.rawValue, 256, &boostedR, &boostedG, &boostedB)`.
  - When `multiplier <= 1.001`:
    - Restore original table via `CGSetDisplayTransferByTable`.
    - Order out 1x1 window.
    - Call `CGDisplayRestoreColorSyncSettings()`.
- Fix locking: remove duplicate lock acquisition in `apply` closure.
- Fix `maxEDRHeadroom`: return `1.0` if `pot <= 1.0` or display is non-XDR.

```swift
// Example snippet of non-deadlocking apply:
let (baseR, baseG, baseB): ([Float], [Float], [Float])
lock.lock()
if baseGammaTables[displayID] == nil {
    var sampleCount: UInt32 = 0
    var r = [Float](repeating: 0, count: 256)
    var g = [Float](repeating: 0, count: 256)
    var b = [Float](repeating: 0, count: 256)
    if CGGetDisplayTransferByTable(displayID.rawValue, 256, &r, &g, &b, &sampleCount) == .success && sampleCount == 256 {
        baseGammaTables[displayID] = (r, g, b)
    } else {
        let linear = (0..<256).map { Float($0) / 255.0 }
        baseGammaTables[displayID] = (linear, linear, linear)
    }
}
baseR = baseGammaTables[displayID]!.0
baseG = baseGammaTables[displayID]!.1
baseB = baseGammaTables[displayID]!.2
lock.unlock()
```

---

### OneDisplayApp (Menu Bar UI)

#### [MODIFY] `Sources/OneDisplayApp/MenuBar/DisplayCardView.swift`
- When user scrubs the brightness slider $\le 1.0$, set `display.isXDRHeadroomBoosted = false`.
- Consolidate `toggleXDRBoost` to route purely through `onBrightnessChange`, preventing duplicate calls and ensuring UI badge updates cleanly.

---

### OneDisplayCoreTests

#### [MODIFY] `Tests/OneDisplayCoreTests/BrightnessTests.swift`
- Update `testBuiltInBrightnessRoutingBoostAndReset` to verify non-blocking execution and proper teardown.
- Add `testNonXDRHeadroomDisallowed` to verify non-XDR displays return `1.0`.

## Verification Plan

### Automated Tests
Run unit tests with timeout to guarantee no hangs:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter BrightnessTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

### Manual Verification
1. Build release app:
   ```bash
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/build_app.sh
   cp -R dist/OneDisplay.app /Applications/OneDisplay.app
   open /Applications/OneDisplay.app
   ```
2. In the Menu Bar UI:
   - Click the "XDR" button: Verify the screen brightness increases to 125% without ANY white screen or window covering the desktop.
   - Drag slider between 100% and 160%: Verify smooth physical luminance increase up to 1600 nits.
   - Verify blacks remain completely black (local dimming zones stay off).
   - Drag slider below 100%: Verify smooth transition back to SDR backlight control and XDR boost releases.
