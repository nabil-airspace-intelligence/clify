import Foundation

/// Metadata for a saved clif
struct ClifMetadata: Codable {
    let id: String
    let createdAt: Date
    let durationMs: Int
    let width: Int
    let height: Int
    let region: ClifRegion
    let gifFilename: String
    let mp4Filename: String?

    struct ClifRegion: Codable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        let displayID: UInt32
    }
}

/// Manages the clif library storage
enum LibraryManager {

    /// Base library directory: ~/Library/Application Support/Clify/clifs/
    static var libraryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Clify/clifs")
    }

    /// Get the folder for a specific date (YYYY/MM/)
    static func folderURL(for date: Date) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM"
        let path = formatter.string(from: date)
        return libraryURL.appendingPathComponent(path)
    }

    /// Generate a unique filename base for a new clif
    static func generateFilename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: date)
        let hash = String(UUID().uuidString.prefix(6))
        return "\(timestamp)_\(hash)"
    }

    /// Save a clif to the library
    /// - Parameters:
    ///   - gifURL: Source GIF file (will be moved)
    ///   - mp4URL: Source MP4 file (will be moved if saveMP4 is true)
    ///   - recording: Recording metadata
    ///   - saveMP4: Whether to also save the MP4 (default true)
    /// - Returns: The saved clif metadata
    static func saveClif(
        gifURL: URL,
        mp4URL: URL,
        recording: RecordingResult,
        saveMP4: Bool = true
    ) throws -> ClifMetadata {
        let now = Date()
        let folder = folderURL(for: now)
        let basename = generateFilename(for: now)

        // Create folder if needed
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        // Move GIF to library
        let gifFilename = "\(basename).gif"
        let destGifURL = folder.appendingPathComponent(gifFilename)
        try FileManager.default.moveItem(at: gifURL, to: destGifURL)

        // Optionally move MP4
        var mp4Filename: String? = nil
        if saveMP4 {
            mp4Filename = "\(basename).mp4"
            let destMp4URL = folder.appendingPathComponent(mp4Filename!)
            try FileManager.default.moveItem(at: mp4URL, to: destMp4URL)
        } else {
            // Clean up temp MP4
            try? FileManager.default.removeItem(at: mp4URL)
        }

        // Create metadata
        let metadata = ClifMetadata(
            id: UUID().uuidString,
            createdAt: now,
            durationMs: Int(recording.duration * 1000),
            width: Int(recording.region.width),
            height: Int(recording.region.height),
            region: ClifMetadata.ClifRegion(
                x: recording.region.origin.x,
                y: recording.region.origin.y,
                width: recording.region.width,
                height: recording.region.height,
                displayID: 0 // TODO: pass display ID through
            ),
            gifFilename: gifFilename,
            mp4Filename: mp4Filename
        )

        // Save metadata JSON
        let metadataURL = folder.appendingPathComponent("\(basename).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(metadata)
        try jsonData.write(to: metadataURL)

        Log.info("clif saved to library: \(destGifURL.path)", subsystem: .storage)

        return metadata
    }
}
