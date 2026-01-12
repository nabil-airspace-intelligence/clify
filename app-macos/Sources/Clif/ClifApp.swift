import SwiftUI
import ApplicationServices

@main
struct ClifApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Clif", systemImage: "record.circle") {
            MenuBarView()
        }

        Window("Clif Library", id: "library") {
            LibraryView()
        }
        .defaultSize(width: 600, height: 400)

        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager?
    private var permissionCheckTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.info("Clif launched", subsystem: .app)

        // Use AXIsProcessTrustedWithOptions to check AND prompt if needed
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if trusted {
            Log.info("Accessibility permission granted, registering hotkey", subsystem: .hotkey)
            registerHotkey()
        } else {
            Log.info("Accessibility permission not granted, polling for permission", subsystem: .hotkey)
            startPermissionPolling()
        }
    }

    private func registerHotkey() {
        hotkeyManager = HotkeyManager.shared
        hotkeyManager?.registerDefaultHotkey()
    }

    private func startPermissionPolling() {
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            if AXIsProcessTrusted() {
                Log.info("Accessibility permission granted via polling", subsystem: .hotkey)
                timer.invalidate()
                self?.permissionCheckTimer = nil
                self?.registerHotkey()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionCheckTimer?.invalidate()
        Log.info("Clif terminating", subsystem: .app)
    }
}
