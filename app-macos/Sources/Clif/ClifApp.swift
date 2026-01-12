import SwiftUI
import ApplicationServices

// Debug logging to file (visible regardless of launch method)
func debugLog(_ message: String) {
    let logFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("clif-debug.log")
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)\n"

    if let handle = try? FileHandle(forWritingTo: logFile) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()
    } else {
        try? line.write(to: logFile, atomically: true, encoding: .utf8)
    }

    // Also print for terminal users
    print("[Clif] \(message)")
}

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
    private var permissionCheckTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.info("Clif launched", subsystem: .app)
        debugLog("App launched - checking accessibility permission...")

        // Use AXIsProcessTrustedWithOptions to check AND prompt if needed
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        debugLog("AXIsProcessTrustedWithOptions() = \(trusted)")

        if trusted {
            debugLog("Permission already granted, registering hotkey...")
            registerHotkey()
        } else {
            debugLog("Permission not granted - system prompt shown, starting polling...")
            // System prompt is non-blocking, so start polling immediately
            startPermissionPolling()
        }
    }

    private func registerHotkey() {
        hotkeyManager = HotkeyManager.shared
        hotkeyManager?.registerDefaultHotkey()
    }

    private func startPermissionPolling() {
        debugLog("Starting permission polling (every 1 second)...")
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            if AXIsProcessTrusted() {
                debugLog("Permission granted! Registering hotkey...")
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
