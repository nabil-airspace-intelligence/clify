import Cocoa
import ApplicationServices

enum PermissionManager {

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

    private static func showAccessibilityPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "Clif needs Accessibility permission to register global hotkeys.\n\nClick 'Open System Settings' and add Clif to the list."
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
