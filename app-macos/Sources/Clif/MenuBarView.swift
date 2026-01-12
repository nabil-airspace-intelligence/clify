import SwiftUI

struct MenuBarView: View {
    var body: some View {
        Button("New Clif...") {
            Log.info("New Clif triggered from menu", subsystem: .app)
            startNewClif()
        }
        .keyboardShortcut("g", modifiers: [.control, .option, .command])

        Divider()

        Button("Open Library") {
            Log.info("Open Library triggered", subsystem: .app)
            openLibrary()
        }

        Divider()

        Button("Preferences...") {
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit") {
            Log.info("Quit triggered", subsystem: .app)
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func startNewClif() {
        RegionSelector.shared.startSelection { region in
            if let region = region {
                Log.info("Selection complete: \(region.rect)", subsystem: .capture)
                ClifController.shared.startRecording(region: region)
            } else {
                Log.info("Selection cancelled", subsystem: .capture)
            }
        }
    }

    private func openLibrary() {
        let libraryPath = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent("Clif/Clifs")

        if let path = libraryPath {
            try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
            NSWorkspace.shared.open(path)
        }
    }

    private func openSettings() {
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
