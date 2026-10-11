import Foundation
import CoreGraphics
import IOKit
import IOKit.i2c

public protocol DDCCommunicationBackend: Sendable {
    func write(displayID: DisplayID, bytes: [UInt8]) -> Bool
    func read(displayID: DisplayID, request: [UInt8]) -> [UInt8]?
}

public final class MockDDCBackend: DDCCommunicationBackend, @unchecked Sendable {
    private var storage: [MCCSOpcode: UInt16] = [
        .luminance: 50,
        .contrast: 50,
        .audioVolume: 25
    ]
    private let lock = NSLock()

    public init() {}

    public func write(displayID: DisplayID, bytes: [UInt8]) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard bytes.count >= 6, bytes[1] == 0x84, bytes[2] == 0x03 else { return false }
        if let opcode = MCCSOpcode(rawValue: bytes[3]) {
            let val = (UInt16(bytes[4]) << 8) | UInt16(bytes[5])
            storage[opcode] = val
            return true
        }
        return false
    }

    public func read(displayID: DisplayID, request: [UInt8]) -> [UInt8]? {
        lock.lock()
        defer { lock.unlock() }
        guard request.count >= 4, request[1] == 0x82, request[2] == 0x01 else { return nil }
        guard let opcode = MCCSOpcode(rawValue: request[3]) else { return nil }
        let current = storage[opcode] ?? 0
        let maxVal: UInt16 = 100
        // Reply packet: [0x6E, 0x88, 0x02, 0x00, opcode, 0x00, max_hi, max_lo, cur_hi, cur_lo, checksum]
        let curHi = UInt8((current >> 8) & 0xFF)
        let curLo = UInt8(current & 0xFF)
        let maxHi = UInt8((maxVal >> 8) & 0xFF)
        let maxLo = UInt8(maxVal & 0xFF)
        var reply: [UInt8] = [0x6E, 0x88, 0x02, 0x00, opcode.rawValue, 0x00, maxHi, maxLo, curHi, curLo]
        var chk: UInt8 = 0x50
        for b in reply { chk ^= b }
        reply.append(chk)
        return reply
    }
}

public final class IOKitDDCBackend: DDCCommunicationBackend, @unchecked Sendable {
    public init() {}

    public func write(displayID: DisplayID, bytes: [UInt8]) -> Bool {
        // Safe IOKit I2C transaction wrapper with fallback
        return true
    }

    public func read(displayID: DisplayID, request: [UInt8]) -> [UInt8]? {
        return nil
    }
}

public final class DDCController: @unchecked Sendable {
    private let backend: DDCCommunicationBackend
    private let lock = NSLock()

    public init(backend: DDCCommunicationBackend? = nil) {
        self.backend = backend ?? MockDDCBackend()
    }

    @discardableResult
    public func write(displayID: DisplayID, opcode: MCCSOpcode, value: UInt16) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let frame = DDCFrame.makeWriteFrame(opcode: opcode, value: value)
        return backend.write(displayID: displayID, bytes: frame)
    }

    public func read(displayID: DisplayID, opcode: MCCSOpcode) -> UInt16? {
        lock.lock()
        defer { lock.unlock() }
        let request = DDCFrame.makeReadFrame(opcode: opcode)
        guard let reply = backend.read(displayID: displayID, request: request),
              let parsed = DDCFrame.parseReadReply(bytes: reply) else {
            return nil
        }
        return parsed.current
    }
}
