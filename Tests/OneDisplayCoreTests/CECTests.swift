import XCTest
@testable import OneDisplayCore

final class CECTests: XCTestCase {
    func testCECStandbyFrame() {
        let frame = CECFrame.makeStandby(destination: .tv)
        XCTAssertEqual(frame.destination, .tv)
        XCTAssertEqual(frame.opcode, .standby)
        XCTAssertTrue(frame.parameters.isEmpty)
        XCTAssertEqual(frame.rawBytes, [0x40, 0x36])
    }

    func testCECActiveSourceFrame() {
        let frame = CECFrame.makeActiveSource(physicalAddress: [0x1, 0x0, 0x0, 0x0])
        XCTAssertEqual(frame.opcode, .activeSource)
        XCTAssertEqual(frame.parameters, [0x1, 0x0, 0x0, 0x0])
        XCTAssertEqual(frame.rawBytes, [0x4F, 0x82, 0x1, 0x0, 0x0, 0x0])
    }

    func testCECControllerVolumeAndPower() {
        let mockBackend = MockCECBackend()
        let controller = CECController(backend: mockBackend)
        let displayID = DisplayID(1)

        XCTAssertTrue(controller.sendPower(displayID: displayID, on: true))
        XCTAssertEqual(mockBackend.sentFrames.count, 1)
        XCTAssertEqual(mockBackend.sentFrames.first?.frame.opcode, .imageViewOn)

        XCTAssertTrue(controller.sendVolumeStep(displayID: displayID, up: true))
        XCTAssertEqual(mockBackend.sentFrames.count, 3) // power + volume pressed + volume released
    }
}
