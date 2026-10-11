import XCTest
import CoreGraphics
import CoreImage
@testable import OneDisplayCore

final class StreamingTests: XCTestCase {
    func testStreamConfigCropValidation() {
        let validConfig = StreamConfig(cropRect: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8), rotation: 90)
        XCTAssertEqual(validConfig.rotation, 90)
        XCTAssertEqual(validConfig.cropRect?.width, 0.8)
    }

    func testVideoFilterTransformations() {
        let filter = VideoFilter()
        let colorImage = CIImage(color: CIColor.red).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
        let config = StreamConfig(cropRect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5), rotation: 180, isFlippedHorizontal: true)
        let processed = filter.apply(to: colorImage, config: config)
        XCTAssertNotNil(processed)
        XCTAssertEqual(processed.extent.width, 50, accuracy: 0.1)
        XCTAssertEqual(processed.extent.height, 50, accuracy: 0.1)
    }

    func testStreamPipelineLifecycle() async {
        let pipeline = StreamPipeline()
        XCTAssertFalse(pipeline.isStreaming)
        try? await pipeline.startStream(sourceDisplayID: DisplayID(1)) { _ in }
        XCTAssertTrue(pipeline.isStreaming)
        pipeline.stopStream()
        XCTAssertFalse(pipeline.isStreaming)
    }
}
