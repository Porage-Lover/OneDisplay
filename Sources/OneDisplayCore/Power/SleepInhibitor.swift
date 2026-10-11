import Foundation
import IOKit.pwr_mgt

public final class SleepInhibitor: @unchecked Sendable {
    public static let shared = SleepInhibitor()
    private var assertionID: IOPMAssertionID = 0
    public private(set) var isSleepPrevented: Bool = false
    private let lock = NSLock()

    public init() {}

    @discardableResult
    public func toggle() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if isSleepPrevented {
            disableInternal()
        } else {
            enableInternal()
        }
        return isSleepPrevented
    }

    public func enable() {
        lock.lock()
        defer { lock.unlock() }
        enableInternal()
    }

    public func disable() {
        lock.lock()
        defer { lock.unlock() }
        disableInternal()
    }

    private func enableInternal() {
        guard !isSleepPrevented else { return }
        let reason = "OneDisplay Display Sleep Prevention" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        if result == kIOReturnSuccess {
            isSleepPrevented = true
        }
    }

    private func disableInternal() {
        guard isSleepPrevented else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isSleepPrevented = false
    }
}
