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

        guard let monitor = MASShortcutMonitor.shared() else {
            Log.error("Failed to get MASShortcutMonitor", subsystem: .hotkey)
            return
        }

        let registered = monitor.register(shortcut, withAction: { [weak self] in
            self?.hotkeyTriggered()
        })

        if registered {
            registeredShortcut = shortcut
            Log.info("Global hotkey registered: ⌃⌥⌘G", subsystem: .hotkey)
        } else {
            Log.error("Failed to register global hotkey", subsystem: .hotkey)
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
