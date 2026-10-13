import Foundation
import CoreGraphics

public final class DisplayLayoutManager: @unchecked Sendable {
    public static let shared = DisplayLayoutManager()

    private typealias SLSSetDisplayRotationFunc = @convention(c) (CGDirectDisplayID, Int32) -> Int32
    private var setRotationFunc: SLSSetDisplayRotationFunc?
    private let lock = NSLock()

    public init() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY) {
            if let sym = dlsym(handle, "SLSSetDisplayRotation") {
                self.setRotationFunc = unsafeBitCast(sym, to: SLSSetDisplayRotationFunc.self)
            }
        }
    }

    public func getRotation(for displayID: DisplayID) -> Int {
        return Int(round(CGDisplayRotation(displayID.rawValue)))
    }

    @discardableResult
    public func setRotation(for displayID: DisplayID, angle: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if let fn = setRotationFunc {
            let res = fn(displayID.rawValue, Int32(angle))
            return res == 0
        }
        return false
    }

    public func isMirrored(displayID: DisplayID) -> Bool {
        return CGDisplayIsInMirrorSet(displayID.rawValue) != 0
    }

    @discardableResult
    public func setMirror(target: DisplayID, master: DisplayID?) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let cfg = config else {
            return false
        }

        if let m = master {
            CGConfigureDisplayMirrorOfDisplay(cfg, target.rawValue, m.rawValue)
        } else {
            CGConfigureDisplayMirrorOfDisplay(cfg, target.rawValue, kCGNullDirectDisplay)
        }

        let result = CGCompleteDisplayConfiguration(cfg, .permanently)
        return result == .success
    }
}
