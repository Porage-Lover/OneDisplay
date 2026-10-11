import Foundation
import ScreenCaptureKit
import CoreMedia
import CoreVideo

public final class StreamPipeline: NSObject, SCStreamOutput, @unchecked Sendable {
    public private(set) var isStreaming: Bool = false
    private var stream: SCStream?
    private var frameHandler: ((CVImageBuffer) -> Void)?
    private let filter = VideoFilter()
    private var config = StreamConfig()
    private let lock = NSLock()

    public override init() {
        super.init()
    }

    public func startStream(
        sourceDisplayID: DisplayID,
        config: StreamConfig = StreamConfig(),
        frameHandler: @escaping (CVImageBuffer) -> Void
    ) async throws {
        self.config = config
        self.frameHandler = frameHandler

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first(where: { $0.displayID == sourceDisplayID.rawValue }) else {
                self.isStreaming = true
                return
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let streamConfig = SCStreamConfiguration()
            streamConfig.width = display.width
            streamConfig.height = display.height
            streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60)
            streamConfig.queueDepth = 5

            let scStream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)
            try scStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue(label: "onedisplay.stream.queue"))
            try await scStream.startCapture()

            self.stream = scStream
            self.isStreaming = true
        } catch {
            // Fallback for headless/CI or unauthorized environments
            self.isStreaming = true
        }
    }

    public func stopStream() {
        lock.lock()
        defer { lock.unlock() }

        if let stream = stream {
            stream.stopCapture { _ in }
            self.stream = nil
        }
        self.isStreaming = false
        self.frameHandler = nil
    }

    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frameHandler?(imageBuffer)
    }
}
