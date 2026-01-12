import Cocoa

/// Main controller for the Clif workflow
/// Handles: region selection -> recording -> GIF encoding -> clipboard + library
final class ClifController {
    static let shared = ClifController()

    private let gifEncoder = GifEncoder()
    private(set) var lastClifMetadata: ClifMetadata?

    private init() {}

    /// Re-copy the last clif to clipboard
    func recopyLastClif() {
        guard let metadata = lastClifMetadata else {
            ToastWindow.showError("No recent clif to copy")
            return
        }

        let gifURL = LibraryManager.folderURL(for: metadata.createdAt)
            .appendingPathComponent(metadata.gifFilename)

        if ClipboardManager.copyGifToClipboard(gifURL) {
            ToastWindow.showSuccess("Clif copied to clipboard!")
        } else {
            ToastWindow.showError("Could not find clif file")
        }
    }

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
                    self.lastClifMetadata = metadata
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

        ToastWindow.showSuccess("Clif copied to clipboard!")
    }

    private func showError(_ error: Error) {
        NSSound.beep()
        ToastWindow.showError(error.localizedDescription)
    }
}
