import XCTest
@testable import OneDisplayCore

final class ResolutionAndVirtualDisplayTests: XCTestCase {
    func testVirtualResolutionListGeneration() {
        let manager = VirtualDisplayManager()
        let modes = manager.generateModes(aspectWidth: 16, aspectHeight: 9, maxDimension: 3840)
        XCTAssertTrue(modes.contains { $0.width == 1920 && $0.height == 1080 })
        XCTAssertTrue(modes.contains { $0.width == 3840 && $0.height == 2160 })
    }

    func testVirtualDisplayCreationAndDestruction() {
        let manager = VirtualDisplayManager()
        let id = manager.createVirtualDisplay(name: "Test Dummy", width: 1920, height: 1080)
        XCTAssertEqual(manager.activeDisplays().count, 1)
        XCTAssertEqual(manager.activeDisplays().first?.name, "Test Dummy")

        let removed = manager.destroy(id: id)
        XCTAssertTrue(removed)
        XCTAssertEqual(manager.activeDisplays().count, 0)
    }
}
