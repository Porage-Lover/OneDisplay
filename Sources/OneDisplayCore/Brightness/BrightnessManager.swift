import Foundation
import CoreGraphics

public struct BrightnessLevel: Equatable, Sendable {
    public let sliderValue: Double
    public let hardwareLevel: Double
    public let softwareDimmingFactor: Double

    public init(sliderValue: Double, hardwareLevel: Double, softwareDimmingFactor: Double) {
        self.sliderValue = sliderValue
        self.hardwareLevel = hardwareLevel
        self.softwareDimmingFactor = softwareDimmingFactor
    }
}

public protocol GammaTableApplier: Sendable {
    func setDisplayGamma(displayID: DisplayID, factor: Double) -> Bool
}

public final class CoreGraphicsGammaApplier: GammaTableApplier, @unchecked Sendable {
    public init() {}

    public func setDisplayGamma(displayID: DisplayID, factor: Double) -> Bool {
        let tableCapacity: UInt32 = 256
        let clampedFactor = Float(max(0.01, min(1.0, factor)))
        var redTable = [Float](repeating: 0, count: Int(tableCapacity))
        var greenTable = [Float](repeating: 0, count: Int(tableCapacity))
        var blueTable = [Float](repeating: 0, count: Int(tableCapacity))

        for i in 0..<Int(tableCapacity) {
            let normalized = Float(i) / Float(tableCapacity - 1)
            let dimmed = normalized * clampedFactor
            redTable[i] = dimmed
            greenTable[i] = dimmed
            blueTable[i] = dimmed
        }

        let result = CGSetDisplayTransferByTable(
            displayID.rawValue,
            tableCapacity,
            &redTable,
            &greenTable,
            &blueTable
        )
        return result == .success
    }
}

public final class BrightnessManager: @unchecked Sendable {
    private let ddcController: DDCController
    private let gammaApplier: GammaTableApplier
    private let lock = NSLock()

    public init(
        ddcController: DDCController = DDCController(),
        gammaApplier: GammaTableApplier = CoreGraphicsGammaApplier()
    ) {
        self.ddcController = ddcController
        self.gammaApplier = gammaApplier
    }

    public func calculateLevels(sliderValue: Double, hardwareMin: Double = 0.2) -> BrightnessLevel {
        let clampedSlider = max(0.0, min(1.0, sliderValue))
        let clampedMin = max(0.0, min(1.0, hardwareMin))

        if clampedSlider >= clampedMin {
            let denominator = 1.0 - clampedMin
            let hw = denominator > 0 ? (clampedSlider - clampedMin) / denominator : 1.0
            return BrightnessLevel(
                sliderValue: clampedSlider,
                hardwareLevel: max(0.0, min(1.0, hw)),
                softwareDimmingFactor: 1.0
            )
        } else {
            let sw = clampedMin > 0 ? clampedSlider / clampedMin : 0.0
            return BrightnessLevel(
                sliderValue: clampedSlider,
                hardwareLevel: 0.0,
                softwareDimmingFactor: max(0.0, min(1.0, sw))
            )
        }
    }

    @discardableResult
    public func applyBrightness(
        displayID: DisplayID,
        sliderValue: Double,
        hardwareMin: Double = 0.2
    ) -> BrightnessLevel {
        lock.lock()
        defer { lock.unlock() }

        let levels = calculateLevels(sliderValue: sliderValue, hardwareMin: hardwareMin)
        let hwInt = UInt16(round(levels.hardwareLevel * 100.0))
        ddcController.write(displayID: displayID, opcode: .luminance, value: hwInt)
        _ = gammaApplier.setDisplayGamma(displayID: displayID, factor: levels.softwareDimmingFactor)
        return levels
    }
}
