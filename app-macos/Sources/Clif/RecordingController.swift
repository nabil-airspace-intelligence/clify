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

        Task {
            // Check screen recording permission first
            let hasPermission = await PermissionManager.checkScreenRecordingPermission()
            guard hasPermission else {
                await MainActor.run {
                    completion(.failure(ScreenRecorder.RecorderError.setupFailed("Screen Recording permission not granted")))
                }
                return
            }

            await MainActor.run {
                self.isRecording = true
                self.hud.show()

                // Show frame around recording region
                if let screen = self.screenForDisplay(region.screenID) {
                    self.frame.show(around: region.rect, on: screen)
                }

                self.recorder.startRecording(region: region.rect, displayID: region.screenID) { [weak self] result in
                    self?.frame.hide()
                    self?.hud.hide()
                    self?.isRecording = false
                    completion(result)
                }
            }
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
