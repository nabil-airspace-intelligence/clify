import SwiftUI

@main
struct ClifApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Clif", systemImage: "record.circle") {
            MenuBarView()
        }

        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.info("Clif launched", subsystem: .app)

        // Check accessibility permission before registering hotkeys
        if PermissionManager.checkAccessibilityPermission() {
            hotkeyManager = HotkeyManager.shared
            hotkeyManager?.registerDefaultHotkey()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Log.info("Clif terminating", subsystem: .app)
    }
}
