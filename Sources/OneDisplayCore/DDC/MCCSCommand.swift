import Foundation

public enum MCCSOpcode: UInt8, CaseIterable, Sendable {
    case luminance = 0x10
    case contrast = 0x12
    case audioVolume = 0x62
    case audioMute = 0x8D
    case inputSource = 0x60
    case powerMode = 0xD6
    case factoryReset = 0x04
}

public struct DDCFrame: Sendable {
    public static let ddcWriteAddress: UInt8 = 0x6E
    public static let ddcReadAddress: UInt8 = 0x6F
    public static let packetSourceAddress: UInt8 = 0x51

    public static func makeWriteFrame(opcode: MCCSOpcode, value: UInt16) -> [UInt8] {
        let hi = UInt8((value >> 8) & 0xFF)
        let lo = UInt8(value & 0xFF)
        var frame: [UInt8] = [
            packetSourceAddress,
            0x84,
            0x03,
            opcode.rawValue,
            hi,
            lo
        ]
        
        var checksum: UInt8 = ddcWriteAddress
        for b in frame {
            checksum ^= b
        }
        frame.append(checksum)
        return frame
    }

    public static func makeReadFrame(opcode: MCCSOpcode) -> [UInt8] {
        var frame: [UInt8] = [
            packetSourceAddress,
            0x82,
            0x01,
            opcode.rawValue
        ]
        var checksum: UInt8 = ddcWriteAddress
        for b in frame {
            checksum ^= b
        }
        frame.append(checksum)
        return frame
    }

    public static func parseReadReply(bytes: [UInt8]) -> (current: UInt16, max: UInt16)? {
        guard bytes.count >= 10 else { return nil }
        let maxVal = (UInt16(bytes[6]) << 8) | UInt16(bytes[7])
        let curVal = (UInt16(bytes[8]) << 8) | UInt16(bytes[9])
        return (current: curVal, max: maxVal)
    }
}
