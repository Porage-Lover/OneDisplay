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
        
        // Teardown should clean up
        xdr.tearDownAll()
        XCTAssertFalse(xdr.isBoosted(for: testID))
    }

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

        XDRManager.shared.tearDownAll()
    }
}
