import Cocoa
import ApplicationServices
import ScreenCaptureKit

enum PermissionManager {

    // MARK: - Screen Recording Permission

    static func checkScreenRecordingPermission() async -> Bool {
        do {
            // Attempting to get shareable content triggers the permission check
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            Log.info("Screen Recording permission granted", subsystem: .app)
            return true
        } catch {
            Log.warning("Screen Recording permission not granted: \(error)", subsystem: .app)
            await MainActor.run {
                showScreenRecordingPermissionAlert()
            }
            return false
        }
    }

    private static func showScreenRecordingPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Clif needs Screen Recording permission to capture your screen.\n\nClick 'Open System Settings' and add Clif to the list."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openScreenRecordingSettings()
        }
    }

    static func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Accessibility Permission

    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    static func checkAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() {
            Log.info("Accessibility permission granted", subsystem: .app)
            return true
        }

        Log.warning("Accessibility permission not granted", subsystem: .app)
        showAccessibilityPermissionAlert()
        return false
    }

    static func showAccessibilityPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "Clif needs Accessibility permission to register global hotkeys.\n\nClick 'Open System Settings' and enable Clif. The hotkey will activate automatically once permission is granted."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
