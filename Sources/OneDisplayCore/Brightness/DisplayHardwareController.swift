import Foundation
import CoreGraphics

extension Notification.Name {
    public static let displayBrightnessDidChange = Notification.Name("OneDisplay.displayBrightnessDidChange")
}

public final class DisplayHardwareController: @unchecked Sendable {
    public static let shared = DisplayHardwareController()

    private typealias SetBrightnessFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias GetBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias NotificationCallback = @convention(c) (CGDirectDisplayID, UnsafeRawPointer?) -> Void
    private typealias RegisterNotificationFunc = @convention(c) (CGDirectDisplayID, UnsafeRawPointer?, NotificationCallback) -> Int32
    private typealias UnregisterNotificationFunc = @convention(c) (CGDirectDisplayID, NotificationCallback) -> Int32

    private var setBrightnessFunc: SetBrightnessFunc?
    private var getBrightnessFunc: GetBrightnessFunc?
    private var registerNotificationFunc: RegisterNotificationFunc?
    private var unregisterNotificationFunc: UnregisterNotificationFunc?

    private let lock = NSLock()
    private var registeredDisplays = Set<CGDirectDisplayID>()

    public init() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY) {
            if let sym = dlsym(handle, "DisplayServicesSetBrightness") {
                self.setBrightnessFunc = unsafeBitCast(sym, to: SetBrightnessFunc.self)
            }
            if let sym = dlsym(handle, "DisplayServicesGetBrightness") {
                self.getBrightnessFunc = unsafeBitCast(sym, to: GetBrightnessFunc.self)
            }
            if let sym = dlsym(handle, "DisplayServicesRegisterForBrightnessChangeNotifications") {
                self.registerNotificationFunc = unsafeBitCast(sym, to: RegisterNotificationFunc.self)
            }
            if let sym = dlsym(handle, "DisplayServicesUnregisterForBrightnessChangeNotifications") {
                self.unregisterNotificationFunc = unsafeBitCast(sym, to: UnregisterNotificationFunc.self)
            }
        }

        registerForBrightnessNotifications(for: CGMainDisplayID())
    }

    public func registerForBrightnessNotifications(for displayID: CGDirectDisplayID) {
        lock.lock()
        defer { lock.unlock() }

        guard !registeredDisplays.contains(displayID), let regFunc = registerNotificationFunc else { return }

        let callback: NotificationCallback = { dispID, _ in
            let targetID = dispID == 0 ? CGMainDisplayID() : dispID
            if let current = DisplayHardwareController.shared.getBrightness(for: targetID) {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .displayBrightnessDidChange,
                        object: nil,
                        userInfo: ["displayID": targetID, "brightness": current]
                    )
                }
            }
        }

        if regFunc(displayID, nil, callback) == 0 {
            registeredDisplays.insert(displayID)
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
