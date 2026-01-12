import Cocoa

/// Main controller for the Clif workflow
/// Handles: region selection -> recording -> (M3: GIF encoding) -> (M3: clipboard)
final class ClifController {
    static let shared = ClifController()

    private init() {}

    /// Start recording a selected region
    func startRecording(region: SelectedRegion) {
        Log.info("Starting Clif recording for region: \(region.rect)", subsystem: .capture)

        RecordingController.shared.startRecording(region: region) { result in
            switch result {
            case .success(let recording):
                Log.info("Recording complete: \(recording.videoURL.path)", subsystem: .capture)
                self.handleRecordingComplete(recording)

            case .failure(let error):
                Log.error("Recording failed: \(error.localizedDescription)", subsystem: .capture)
                self.showError(error)
            }
        }
    }

    private func handleRecordingComplete(_ recording: RecordingResult) {
        // TODO: M3 - convert to GIF, copy to clipboard, save to library
        // For now, just beep and open in Finder for verification
        if let sound = NSSound(named: "Pop") {
            sound.play()
        } else {
            NSSound.beep()
        }

        // Open the recording in Finder (temporary, until M3 adds clipboard support)
        NSWorkspace.shared.selectFile(recording.videoURL.path, inFileViewerRootedAtPath: "")
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Recording Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
