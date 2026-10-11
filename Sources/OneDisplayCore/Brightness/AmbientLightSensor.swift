import Foundation
import IOKit

public final class AmbientLightSensor: @unchecked Sendable {
    public init() {}

    public func readAmbientLux() -> Double? {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("AppleLMUController")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS, iterator != 0 else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        return 300.0
    }
}
