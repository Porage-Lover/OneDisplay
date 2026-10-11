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

    func testDDCControllerReadWrite() {
        let mockBackend = MockDDCBackend()
        let controller = DDCController(backend: mockBackend)
        let displayID = DisplayID(1)

        let initialBrightness = controller.read(displayID: displayID, opcode: .luminance)
        XCTAssertEqual(initialBrightness, 50)

        let writeSuccess = controller.write(displayID: displayID, opcode: .luminance, value: 85)
        XCTAssertTrue(writeSuccess)

        let updatedBrightness = controller.read(displayID: displayID, opcode: .luminance)
        XCTAssertEqual(updatedBrightness, 85)
    }
}
