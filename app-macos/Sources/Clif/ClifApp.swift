import SwiftUI
import ApplicationServices

@main
struct ClifyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Clify", systemImage: "record.circle") {
            MenuBarView()
        }

        Window("Clify Library", id: "library") {
            LibraryView()
        }
        .defaultSize(width: 600, height: 400)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager?
    private var permissionCheckTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.info("Clify launched", subsystem: .app)

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
        Log.info("Clify terminating", subsystem: .app)
    }
}
