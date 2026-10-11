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
