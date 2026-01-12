import Foundation

/// Converts MP4 videos to GIF using gifski
final class GifEncoder {

    enum GifEncoderError: LocalizedError {
        case gifskiNotFound
        case conversionFailed(String)
        case outputNotCreated

        var errorDescription: String? {
            switch self {
            case .gifskiNotFound:
                return "gifski not found. Install with: brew install gifski"
            case .conversionFailed(let msg):
                return "GIF conversion failed: \(msg)"
            case .outputNotCreated:
                return "GIF file was not created"
            }
        }
    }

    /// Path to gifski binary
    /// For development: use homebrew path
    /// For distribution: bundle with app
    private var gifskiPath: String {
        // Check bundled location first
        if let bundledPath = Bundle.main.path(forResource: "gifski", ofType: nil) {
            return bundledPath
        }
        // Fall back to homebrew
        return "/opt/homebrew/bin/gifski"
    }

    /// Convert MP4 to GIF
    /// - Parameters:
    ///   - videoURL: Path to input MP4
    ///   - outputURL: Path for output GIF (optional, will generate if nil)
    ///   - fps: Target frame rate (default 15)
    ///   - width: Max width (default 640, maintains aspect ratio)
    /// - Returns: URL to the generated GIF
    func convert(
        videoURL: URL,
        outputURL: URL? = nil,
        fps: Int = 15,
        width: Int = 640
    ) async throws -> URL {
        // Verify gifski exists
        guard FileManager.default.fileExists(atPath: gifskiPath) else {
            throw GifEncoderError.gifskiNotFound
        }

        // Generate output path if not provided
        let gifURL = outputURL ?? videoURL.deletingPathExtension().appendingPathExtension("gif")

        // Remove existing file
        try? FileManager.default.removeItem(at: gifURL)

        Log.info("Converting \(videoURL.lastPathComponent) to GIF", subsystem: .encoding)

        // Build gifski command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gifskiPath)
        process.arguments = [
            "--fps", String(fps),
            "--width", String(width),
            "--quality", "90",
            "--output", gifURL.path,
            videoURL.path
        ]

        let pipe = Pipe()
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw GifEncoderError.conversionFailed(error.localizedDescription)
        }

        // Check exit status
        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw GifEncoderError.conversionFailed(errorMessage)
        }

        // Verify output exists
        guard FileManager.default.fileExists(atPath: gifURL.path) else {
            throw GifEncoderError.outputNotCreated
        }

        let fileSize = try FileManager.default.attributesOfItem(atPath: gifURL.path)[.size] as? Int64 ?? 0
        Log.info("GIF created: \(gifURL.lastPathComponent) (\(fileSize / 1024)KB)", subsystem: .encoding)

        return gifURL
    }
}
