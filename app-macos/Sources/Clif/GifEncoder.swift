import AVFoundation
import AppKit
import Foundation

/// Converts MP4 videos to GIF using gifski
/// Extracts frames via AVFoundation, then passes PNGs to gifski
final class GifEncoder {

    enum GifEncoderError: LocalizedError {
        case gifskiNotFound
        case conversionFailed(String)
        case outputNotCreated
        case frameExtractionFailed(String)

        var errorDescription: String? {
            switch self {
            case .gifskiNotFound:
                return "gifski not found. Install with: brew install gifski"
            case .conversionFailed(let msg):
                return "GIF conversion failed: \(msg)"
            case .outputNotCreated:
                return "GIF file was not created"
            case .frameExtractionFailed(let msg):
                return "Frame extraction failed: \(msg)"
            }
        }
    }

    /// Path to gifski binary
    private var gifskiPath: String {
        // Check bundled location first
        if let bundledPath = Bundle.main.path(forResource: "gifski", ofType: nil) {
            return bundledPath
        }
        // Fall back to homebrew (Apple Silicon)
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/gifski") {
            return "/opt/homebrew/bin/gifski"
        }
        // Fall back to homebrew (Intel)
        return "/usr/local/bin/gifski"
    }

    /// Convert MP4 to GIF
    func convert(
        videoURL: URL,
        outputURL: URL? = nil,
        fps: Int = 15,
        width: Int = 640
    ) async throws -> URL {
        Log.info("Using gifski at: \(gifskiPath)", subsystem: .encoding)

        guard FileManager.default.fileExists(atPath: gifskiPath) else {
            Log.error("gifski not found at: \(gifskiPath)", subsystem: .encoding)
            throw GifEncoderError.gifskiNotFound
        }

        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            Log.error("Input video not found: \(videoURL.path)", subsystem: .encoding)
            throw GifEncoderError.conversionFailed("Input video not found")
        }

        if let attrs = try? FileManager.default.attributesOfItem(atPath: videoURL.path),
           let size = attrs[.size] as? Int64 {
            Log.info("Input video size: \(size / 1024)KB", subsystem: .encoding)
        }

        let gifURL = outputURL ?? videoURL.deletingPathExtension().appendingPathExtension("gif")
        try? FileManager.default.removeItem(at: gifURL)

        // Create temp directory for frames
        let framesDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("clif-frames-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: framesDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: framesDir)
        }

        // Extract frames
        Log.info("Extracting frames at \(fps) fps...", subsystem: .encoding)
        let framePaths = try await extractFrames(from: videoURL, to: framesDir, fps: fps)

        guard !framePaths.isEmpty else {
            throw GifEncoderError.frameExtractionFailed("No frames extracted")
        }

        Log.info("Extracted \(framePaths.count) frames", subsystem: .encoding)

        // Run gifski with PNG frames
        Log.info("Converting frames to GIF...", subsystem: .encoding)
        try runGifski(framePaths: framePaths, outputURL: gifURL, fps: fps, width: width)

        guard FileManager.default.fileExists(atPath: gifURL.path) else {
            throw GifEncoderError.outputNotCreated
        }

        let fileSize = try FileManager.default.attributesOfItem(atPath: gifURL.path)[.size] as? Int64 ?? 0
        Log.info("GIF created: \(gifURL.lastPathComponent) (\(fileSize / 1024)KB)", subsystem: .encoding)

        return gifURL
    }

    /// Extract frames from video using AVFoundation
    private func extractFrames(from videoURL: URL, to directory: URL, fps: Int) async throws -> [String] {
        let asset = AVAsset(url: videoURL)

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw GifEncoderError.frameExtractionFailed("No video track found")
        }

        let duration = try await asset.load(.duration)
        let naturalSize = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)

        // Account for video rotation
        let videoSize = naturalSize.applying(transform)
        let videoWidth = abs(videoSize.width)
        let videoHeight = abs(videoSize.height)

        Log.info("Video: \(Int(videoWidth))x\(Int(videoHeight)), duration: \(String(format: "%.2f", duration.seconds))s", subsystem: .encoding)

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let totalFrames = Int(duration.seconds * Double(fps))
        var framePaths: [String] = []

        for frameIndex in 0..<totalFrames {
            let time = CMTime(seconds: Double(frameIndex) / Double(fps), preferredTimescale: 600)

            do {
                let (cgImage, _) = try await generator.image(at: time)
                let framePath = directory.appendingPathComponent(String(format: "frame_%05d.png", frameIndex))

                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                guard let tiffData = nsImage.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmap.representation(using: .png, properties: [:]) else {
                    continue
                }

                try pngData.write(to: framePath)
                framePaths.append(framePath.path)
            } catch {
                Log.warning("Failed to extract frame \(frameIndex): \(error.localizedDescription)", subsystem: .encoding)
            }
        }

        return framePaths
    }

    /// Run gifski with PNG frame inputs
    private func runGifski(framePaths: [String], outputURL: URL, fps: Int, width: Int) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gifskiPath)
        process.arguments = [
            "--fps", String(fps),
            "--width", String(width),
            "--quality", "90",
            "--output", outputURL.path
        ] + framePaths

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            Log.error("gifski exited with code \(process.terminationStatus): \(errorMessage)", subsystem: .encoding)
            throw GifEncoderError.conversionFailed(errorMessage)
        }
    }
}
