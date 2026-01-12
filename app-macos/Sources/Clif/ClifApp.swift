import SwiftUI
import ApplicationServices
import ScreenCaptureKit

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
    private var hasAccessibility = false
    private var hasScreenRecording = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.info("Clify launched", subsystem: .app)
        checkPermissions()
    }

    private func checkPermissions() {
        // Check Accessibility (shows system prompt if needed)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        hasAccessibility = AXIsProcessTrustedWithOptions(options)

        if hasAccessibility {
            Log.info("Accessibility permission granted", subsystem: .app)
            registerHotkey()
        }

        // Check Screen Recording (triggers permission prompt)
        Task {
            await checkScreenRecordingPermission()
            await MainActor.run {
                startPermissionPollingIfNeeded()
            }
        }
    }

    private func checkScreenRecordingPermission() async {
        do {
            // This triggers the permission prompt if not granted
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            hasScreenRecording = true
            Log.info("Screen Recording permission granted", subsystem: .app)
        } catch {
            hasScreenRecording = false
            Log.info("Screen Recording permission not granted", subsystem: .app)
        }
    }

    private func startPermissionPollingIfNeeded() {
        guard !hasAccessibility || !hasScreenRecording else { return }

        Log.info("Polling for missing permissions...", subsystem: .app)
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }

            // Check Accessibility
            if !self.hasAccessibility && AXIsProcessTrusted() {
                self.hasAccessibility = true
                Log.info("Accessibility permission granted via polling", subsystem: .app)
                self.registerHotkey()
            }

            // Check Screen Recording
            if !self.hasScreenRecording {
                Task {
                    do {
                        _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                        await MainActor.run {
                            self.hasScreenRecording = true
                            Log.info("Screen Recording permission granted via polling", subsystem: .app)
                        }
                    } catch {
                        // Still not granted
                    }
                }
            }

            // Stop polling when both granted
            if self.hasAccessibility && self.hasScreenRecording {
                timer.invalidate()
                self.permissionCheckTimer = nil
                Log.info("All permissions granted", subsystem: .app)
            }
        }
    }

    private func registerHotkey() {
        hotkeyManager = HotkeyManager.shared
        hotkeyManager?.registerDefaultHotkey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionCheckTimer?.invalidate()
        Log.info("Clify terminating", subsystem: .app)
    }
}
