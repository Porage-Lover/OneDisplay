import Foundation

public enum CECDestination: UInt8, CaseIterable, Sendable {
    case tv = 0x0
    case recordingDevice1 = 0x1
    case recordingDevice2 = 0x2
    case tuner1 = 0x3
    case playbackDevice1 = 0x4
    case audioSystem = 0x5
    case broadcast = 0xF
}

public enum CECOpcode: UInt8, CaseIterable, Sendable {
    case imageViewOn = 0x04
    case textWait = 0x05
    case standby = 0x36
    case userControlPressed = 0x44
    case userControlReleased = 0x45
    case giveOSDName = 0x46
    case setOSDName = 0x47
    case systemAudioModeRequest = 0x70
    case giveAudioStatus = 0x71
    case setSystemAudioMode = 0x72
    case reportAudioStatus = 0x7A
    case giveSystemAudioModeStatus = 0x7D
    case systemAudioModeStatus = 0x7E
    case activeSource = 0x82
    case givePhysicalAddress = 0x83
    case reportPhysicalAddress = 0x84
    case requestActiveSource = 0x85
    case setStreamPath = 0x86
    case deviceVendorID = 0x87
    case vendorCommand = 0x89
    case giveDeviceVendorID = 0x8C
    case giveDevicePowerStatus = 0x8F
    case reportPowerStatus = 0x90
    case getMenuLanguage = 0x91
    case inactiveSource = 0x9D
    case cecVersion = 0x9E
    case getCECVersion = 0x9F
    case abort = 0xFF
}

public enum CECUserControlCode: UInt8, Sendable {
    case volumeUp = 0x41
    case volumeDown = 0x42
    case mute = 0x43
    case power = 0x40
    case powerToggle = 0x6B
    case powerOn = 0x6D
    case powerOff = 0x6C
}

public struct CECFrame: Equatable, Sendable {
    public let source: CECDestination
    public let destination: CECDestination
    public let opcode: CECOpcode
    public let parameters: [UInt8]

    public init(
        source: CECDestination = .playbackDevice1,
        destination: CECDestination,
        opcode: CECOpcode,
        parameters: [UInt8] = []
    ) {
        self.source = source
        self.destination = destination
        self.opcode = opcode
        self.parameters = parameters
    }

    public var header: UInt8 {
        return ((source.rawValue & 0x0F) << 4) | (destination.rawValue & 0x0F)
    }

    public var rawBytes: [UInt8] {
        var bytes = [header, opcode.rawValue]
        bytes.append(contentsOf: parameters)
        return bytes
    }

    public static func makeStandby(destination: CECDestination = .tv) -> CECFrame {
        return CECFrame(destination: destination, opcode: .standby)
    }

    public static func makeActiveSource(physicalAddress: [UInt8]) -> CECFrame {
        return CECFrame(destination: .broadcast, opcode: .activeSource, parameters: physicalAddress)
    }

    public static func makeImageViewOn(destination: CECDestination = .tv) -> CECFrame {
        return CECFrame(destination: destination, opcode: .imageViewOn)
    }

    public static func makeUserControl(code: CECUserControlCode, destination: CECDestination = .tv) -> CECFrame {
        return CECFrame(destination: destination, opcode: .userControlPressed, parameters: [code.rawValue])
    }

    public static func makeUserControlRelease(destination: CECDestination = .tv) -> CECFrame {
        return CECFrame(destination: destination, opcode: .userControlReleased)
    }
}
