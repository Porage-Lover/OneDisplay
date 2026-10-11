import Foundation
import CoreGraphics
import CoreImage

public struct StreamConfig: Equatable, Sendable {
    public var cropRect: CGRect?
    public var rotation: Int // 0, 90, 180, 270
    public var isFlippedHorizontal: Bool
    public var isFlippedVertical: Bool

    public init(
        cropRect: CGRect? = nil,
        rotation: Int = 0,
        isFlippedHorizontal: Bool = false,
        isFlippedVertical: Bool = false
    ) {
        self.cropRect = cropRect
        self.rotation = rotation
        self.isFlippedHorizontal = isFlippedHorizontal
        self.isFlippedVertical = isFlippedVertical
    }
}

public final class VideoFilter: Sendable {
    public init() {}

    public func apply(to image: CIImage, config: StreamConfig) -> CIImage {
        var result = image

        if let crop = config.cropRect {
            let extent = result.extent
            let cropBox = CGRect(
                x: extent.origin.x + crop.origin.x * extent.width,
                y: extent.origin.y + crop.origin.y * extent.height,
                width: crop.width * extent.width,
                height: crop.height * extent.height
            )
            result = result.cropped(to: cropBox)
        }

        if config.isFlippedHorizontal {
            result = result.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
        }

        if config.isFlippedVertical {
            result = result.transformed(by: CGAffineTransform(scaleX: 1, y: -1))
        }

        if config.rotation != 0 {
            let radians = CGFloat(config.rotation) * .pi / 180.0
            result = result.transformed(by: CGAffineTransform(rotationAngle: radians))
        }

        return result
    }
}
