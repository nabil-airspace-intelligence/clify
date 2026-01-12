import Cocoa
import Carbon.HIToolbox
import MASShortcut

final class HotkeyManager {
    static let shared = HotkeyManager()

    private var registeredShortcut: MASShortcut?

    private init() {}

    func registerDefaultHotkey() {
        let shortcut = MASShortcut(
            keyCode: Int(kVK_ANSI_G),
            modifierFlags: [.control, .option, .command]
        )

        debugLog("Attempting to register hotkey...")

        guard let monitor = MASShortcutMonitor.shared() else {
            debugLog("ERROR: Failed to get MASShortcutMonitor")
            return
        }

        debugLog("Got monitor, registering shortcut...")

        let registered = monitor.register(shortcut, withAction: { [weak self] in
            debugLog("Hotkey triggered!")
            self?.hotkeyTriggered()
        })

        if registered {
            registeredShortcut = shortcut
            debugLog("Global hotkey registered successfully: ⌃⌥⌘G")
        } else {
            debugLog("ERROR: Failed to register global hotkey")
        }
    }

    private func hotkeyTriggered() {
        Log.info("Hotkey triggered", subsystem: .hotkey)

        RegionSelector.shared.startSelection { region in
            if let region = region {
                Log.info("Selection complete: \(region.rect)", subsystem: .capture)
                ClifController.shared.startRecording(region: region)
            } else {
                Log.info("Selection cancelled", subsystem: .capture)
            }
        }
    }
}
