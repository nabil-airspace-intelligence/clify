import Cocoa
import ScreenCaptureKit
import AVFoundation

/// Result of a recording session
struct RecordingResult {
    let videoURL: URL
    let duration: TimeInterval
    let region: CGRect
}

/// Records a region of the screen to MP4
final class ScreenRecorder: NSObject {
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var isRecording = false
    private var startTime: CMTime?
    private var outputURL: URL?
    private var recordedRegion: CGRect?

    private var completion: ((Result<RecordingResult, Error>) -> Void)?

    enum RecorderError: LocalizedError {
        case alreadyRecording
        case notRecording
        case noDisplayFound
        case setupFailed(String)
        case recordingFailed(String)

        var errorDescription: String? {
            switch self {
            case .alreadyRecording: return "Already recording"
            case .notRecording: return "Not recording"
            case .noDisplayFound: return "No display found for the selected region"
            case .setupFailed(let msg): return "Setup failed: \(msg)"
            case .recordingFailed(let msg): return "Recording failed: \(msg)"
            }
        }
    }

    /// Start recording the specified region
    func startRecording(region: CGRect, displayID: CGDirectDisplayID, completion: @escaping (Result<RecordingResult, Error>) -> Void) {
        guard !isRecording else {
            completion(.failure(RecorderError.alreadyRecording))
            return
        }

        self.completion = completion
        self.recordedRegion = region

        Task {
            do {
                try await setupAndStartCapture(region: region, displayID: displayID)
            } catch {
                await MainActor.run {
                    self.completion?(.failure(error))
                    self.cleanup()
                }
            }
        }
    }

    /// Stop recording and finalize the video
    func stopRecording() {
        guard isRecording else { return }

        Log.info("Stopping recording", subsystem: .capture)
        isRecording = false

        stream?.stopCapture { [weak self] error in
            if let error = error {
                Log.error("Error stopping capture: \(error)", subsystem: .capture)
            }
            self?.finalizeRecording()
        }
    }

    private func setupAndStartCapture(region: CGRect, displayID: CGDirectDisplayID) async throws {
        // Get shareable content
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        // Find the display
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw RecorderError.noDisplayFound
        }

        // Create content filter for the display
        let filter = SCContentFilter(display: display, excludingWindows: [])

        // Configure stream for the selected region
        let config = SCStreamConfiguration()
        config.sourceRect = region
        config.width = Int(region.width) * 2  // 2x for Retina
        config.height = Int(region.height) * 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30) // 30 fps
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true

        // Scale down if region is very large
        let maxDimension: CGFloat = 1920
        if region.width > maxDimension || region.height > maxDimension {
            let scale = min(maxDimension / region.width, maxDimension / region.height)
            config.width = Int(region.width * scale)
            config.height = Int(region.height * scale)
        }

        // Set up output file
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "clif_\(ISO8601DateFormatter().string(from: Date())).mp4"
            .replacingOccurrences(of: ":", with: "-")
        outputURL = tempDir.appendingPathComponent(filename)

        guard let outputURL = outputURL else {
            throw RecorderError.setupFailed("Could not create output URL")
        }

        // Remove existing file if any
        try? FileManager.default.removeItem(at: outputURL)

        // Set up AVAssetWriter
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: config.width,
            AVVideoHeightKey: config.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 8_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: config.width,
            kCVPixelBufferHeightKey as String: config.height
        ]

        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        assetWriter?.add(videoInput!)
        assetWriter?.startWriting()
        assetWriter?.startSession(atSourceTime: .zero)

        // Create and start the stream
        stream = SCStream(filter: filter, configuration: config, delegate: self)

        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInitiated))

        try await stream?.startCapture()

        await MainActor.run {
            self.isRecording = true
            Log.info("Recording started: \(config.width)x\(config.height) @ 30fps", subsystem: .capture)
        }
    }

    private func finalizeRecording() {
        videoInput?.markAsFinished()

        assetWriter?.finishWriting { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if let error = self.assetWriter?.error {
                    Log.error("Asset writer error: \(error)", subsystem: .capture)
                    self.completion?(.failure(RecorderError.recordingFailed(error.localizedDescription)))
                } else if let url = self.outputURL, let region = self.recordedRegion {
                    let duration = self.calculateDuration()
                    Log.info("Recording saved: \(url.path), duration: \(duration)s", subsystem: .capture)
                    self.completion?(.success(RecordingResult(
                        videoURL: url,
                        duration: duration,
                        region: region
                    )))
                }
                self.cleanup()
            }
        }
    }

    private func calculateDuration() -> TimeInterval {
        guard let start = startTime else { return 0 }
        let now = CMClockGetTime(CMClockGetHostTimeClock())
        return CMTimeGetSeconds(CMTimeSubtract(now, start))
    }

    private func cleanup() {
        stream = nil
        assetWriter = nil
        videoInput = nil
        pixelBufferAdaptor = nil
        startTime = nil
        completion = nil
        isRecording = false
    }
}

// MARK: - SCStreamDelegate

extension ScreenRecorder: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        Log.error("Stream stopped with error: \(error)", subsystem: .capture)
        DispatchQueue.main.async {
            self.completion?(.failure(RecorderError.recordingFailed(error.localizedDescription)))
            self.cleanup()
        }
    }
}

// MARK: - SCStreamOutput

extension ScreenRecorder: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard isRecording, type == .screen else { return }
        guard let videoInput = videoInput, videoInput.isReadyForMoreMediaData else { return }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Set start time on first frame
        if startTime == nil {
            startTime = timestamp
        }

        // Calculate relative timestamp
        let relativeTime = CMTimeSubtract(timestamp, startTime!)

        // Get pixel buffer and append to video
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        pixelBufferAdaptor?.append(pixelBuffer, withPresentationTime: relativeTime)
    }
}
