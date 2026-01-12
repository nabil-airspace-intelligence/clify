import Cocoa

/// Main controller for the Clif workflow
/// Handles: region selection -> recording -> GIF encoding -> clipboard + library
final class ClifController {
    static let shared = ClifController()

    private let gifEncoder = GifEncoder()

    private init() {}

    /// Start recording a selected region
    func startRecording(region: SelectedRegion) {
        Log.info("Starting Clif recording for region: \(region.rect)", subsystem: .capture)

        RecordingController.shared.startRecording(region: region) { result in
            switch result {
            case .success(let recording):
                Log.info("Recording complete: \(recording.videoURL.path)", subsystem: .capture)
                self.processRecording(recording)

            case .failure(let error):
                Log.error("Recording failed: \(error.localizedDescription)", subsystem: .capture)
                self.showError(error)
            }
        }
    }

    private func processRecording(_ recording: RecordingResult) {
        Task {
            do {
                // Convert to GIF
                Log.info("Converting to GIF...", subsystem: .encoding)
                let tempGifURL = try await gifEncoder.convert(videoURL: recording.videoURL)

                // Save to library first (this moves the files)
                let saveMP4 = UserDefaults.standard.object(forKey: "saveMP4") as? Bool ?? true
                let metadata = try LibraryManager.saveClif(
                    gifURL: tempGifURL,
                    mp4URL: recording.videoURL,
                    recording: recording,
                    saveMP4: saveMP4
                )

                // Get the saved GIF path and copy to clipboard
                let savedGifURL = LibraryManager.folderURL(for: metadata.createdAt)
                    .appendingPathComponent(metadata.gifFilename)
                ClipboardManager.copyGifToClipboard(savedGifURL)

                await MainActor.run {
                    self.showSuccess(metadata)
                }

            } catch {
                await MainActor.run {
                    Log.error("Processing failed: \(error.localizedDescription)", subsystem: .encoding)
                    self.showError(error)
                }
            }
        }
    }

    private func showSuccess(_ metadata: ClifMetadata) {
        // Play success sound
        if let sound = NSSound(named: "Glass") {
            sound.play()
        } else {
            NSSound.beep()
        }

        // Show brief notification (TODO: replace with toast)
        let alert = NSAlert()
        alert.messageText = "Clif Copied!"
        alert.informativeText = "GIF is in your clipboard and saved to library.\n\nDuration: \(metadata.durationMs / 1000)s"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open Library")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            let folder = LibraryManager.folderURL(for: metadata.createdAt)
            NSWorkspace.shared.open(folder)
        }
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Clif Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
