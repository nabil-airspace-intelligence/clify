import Cocoa

/// Handles copying GIFs to the clipboard
enum ClipboardManager {

    /// Copy a GIF file to the clipboard
    /// - Parameter gifURL: Path to the GIF file
    /// - Returns: true if successful
    @discardableResult
    static func copyGifToClipboard(_ gifURL: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: gifURL.path) else {
            Log.error("GIF file not found: \(gifURL.path)", subsystem: .storage)
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Write file URL - this preserves the GIF animation when pasting
        // Apps like Slack handle file URLs better for animated content
        pasteboard.writeObjects([gifURL as NSURL])

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: gifURL.path)[.size] as? Int64) ?? 0
        Log.info("GIF copied to clipboard (\(fileSize / 1024)KB)", subsystem: .storage)
        return true
    }
}
