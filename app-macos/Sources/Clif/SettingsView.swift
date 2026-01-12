import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            HotkeySettingsView()
                .tabItem {
                    Label("Hotkey", systemImage: "keyboard")
                }
        }
        .frame(width: 400, height: 200)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("saveMP4") private var saveMP4 = true
    @AppStorage("maxDuration") private var maxDuration = 20

    var body: some View {
        Form {
            Toggle("Also save MP4 alongside GIF", isOn: $saveMP4)

            Picker("Max recording duration", selection: $maxDuration) {
                Text("10 seconds").tag(10)
                Text("20 seconds").tag(20)
                Text("30 seconds").tag(30)
                Text("60 seconds").tag(60)
            }
        }
        .padding()
    }
}

struct HotkeySettingsView: View {
    var body: some View {
        VStack {
            Text("Global Hotkey")
                .font(.headline)

            Text("Default: ⌃⌥⌘G")
                .foregroundColor(.secondary)

            // TODO: M5 - Add MASShortcut picker view here
            Text("Hotkey customization coming soon")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
    }
}
