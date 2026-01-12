import Cocoa

/// Orchestrates the recording flow
final class RecordingController {
    static let shared = RecordingController()

    private let recorder = ScreenRecorder()
    private let hud = RecordingHUD()
    private let frame = RecordingFrame()
    private var isRecording = false

    private init() {
        hud.onStopRequested = { [weak self] in
            self?.stopRecording()
        }
    }

    /// Start recording the specified region
    func startRecording(region: SelectedRegion, completion: @escaping (Result<RecordingResult, Error>) -> Void) {
        guard !isRecording else {
            Log.warning("Already recording, ignoring start request", subsystem: .capture)
            return
        }

        // Permission is checked at app launch, so we proceed directly
        isRecording = true
        hud.show()

        // Show frame around recording region
        if let screen = screenForDisplay(region.screenID) {
            frame.show(around: region.rect, on: screen)
        }

        recorder.startRecording(region: region.rect, displayID: region.screenID) { [weak self] result in
            self?.frame.hide()
            self?.hud.hide()
            self?.isRecording = false
            completion(result)
        }
    }

    /// Stop the current recording
    func stopRecording() {
        guard isRecording else { return }
        recorder.stopRecording()
    }

    private func screenForDisplay(_ displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { $0.displayID == displayID }
    }
}
