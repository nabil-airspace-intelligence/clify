import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("New Clif...") {
            startNewClif()
        }
        .keyboardShortcut("c", modifiers: [.control, .shift, .command])

        Divider()

        Button("Open Library") {
            openWindow(id: "library")
        }

        Button("Open in Finder") {
            openLibraryInFinder()
        }

        Button("Copy Last Clif") {
            ClifController.shared.recopyLastClif()
        }
        .keyboardShortcut("c", modifiers: [.control, .option, .command])

        Divider()

        Button("Quit") {
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

    private func openLibraryInFinder() {
        let libraryPath = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent("Clif/Clifs")

        if let path = libraryPath {
            try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
            NSWorkspace.shared.open(path)
        }
    }

}
