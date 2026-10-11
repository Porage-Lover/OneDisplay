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
