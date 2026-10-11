import Foundation
import CoreGraphics

public final class DisplayHardwareController: @unchecked Sendable {
    public static let shared = DisplayHardwareController()

    private typealias SetBrightnessFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias GetBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32

    private var setBrightnessFunc: SetBrightnessFunc?
    private var getBrightnessFunc: GetBrightnessFunc?
    private let lock = NSLock()

    public init() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY) {
            if let sym = dlsym(handle, "DisplayServicesSetBrightness") {
                self.setBrightnessFunc = unsafeBitCast(sym, to: SetBrightnessFunc.self)
            }
            if let sym = dlsym(handle, "DisplayServicesGetBrightness") {
                self.getBrightnessFunc = unsafeBitCast(sym, to: GetBrightnessFunc.self)
            }
        }
    }

    public func getBrightness(for displayID: CGDirectDisplayID) -> Double? {
        lock.lock()
        defer { lock.unlock() }

        if let getFunc = getBrightnessFunc {
            var val: Float = 0
            if getFunc(displayID, &val) == 0 {
                return Double(val)
            }
        }
        return nil
    }

    @discardableResult
    public func setBrightness(for displayID: CGDirectDisplayID, value: Double) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if let setFunc = setBrightnessFunc {
            let clamped = Float(max(0.0, min(1.0, value)))
            return setFunc(displayID, clamped) == 0
        }
        return false
    }
}
