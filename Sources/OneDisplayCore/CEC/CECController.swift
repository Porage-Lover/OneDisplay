import Foundation

public protocol CECCommunicationBackend: Sendable {
    func transmit(displayID: DisplayID, frame: CECFrame) -> Bool
}

public final class MockCECBackend: CECCommunicationBackend, @unchecked Sendable {
    public private(set) var sentFrames: [(displayID: DisplayID, frame: CECFrame)] = []
    private let lock = NSLock()

    public init() {}

    public func transmit(displayID: DisplayID, frame: CECFrame) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        sentFrames.append((displayID, frame))
        return true
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        sentFrames.removeAll()
    }
}

public final class CECController: @unchecked Sendable {
    private let backend: CECCommunicationBackend
    private let lock = NSLock()

    public init(backend: CECCommunicationBackend? = nil) {
        self.backend = backend ?? MockCECBackend()
    }

    @discardableResult
    public func sendPower(displayID: DisplayID, on: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let frame = on ? CECFrame.makeImageViewOn() : CECFrame.makeStandby()
        return backend.transmit(displayID: displayID, frame: frame)
    }

    @discardableResult
    public func sendVolumeStep(displayID: DisplayID, up: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let pressFrame = CECFrame.makeUserControl(code: up ? .volumeUp : .volumeDown)
        let releaseFrame = CECFrame.makeUserControlRelease()
        let r1 = backend.transmit(displayID: displayID, frame: pressFrame)
        let r2 = backend.transmit(displayID: displayID, frame: releaseFrame)
        return r1 && r2
    }

    @discardableResult
    public func switchInput(displayID: DisplayID, physicalAddress: [UInt8]) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let frame = CECFrame.makeActiveSource(physicalAddress: physicalAddress)
        return backend.transmit(displayID: displayID, frame: frame)
    }
}
