import SwiftUI

/// Library viewer showing recent clifs
struct LibraryView: View {
    @State private var clifs: [ClifItem] = []
    @State private var selectedClif: ClifItem?

    var body: some View {
        Group {
            if clifs.isEmpty {
                emptyState
            } else {
                clifGrid
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            loadClifs()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No clifs yet")
                .font(.headline)
            Text("Press \u{2303}\u{21e7}\u{2318}C to create your first clif")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var clifGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200))], spacing: 16) {
                ForEach(clifs) { clif in
                    ClifThumbnailView(clif: clif, isSelected: selectedClif?.id == clif.id)
                        .onTapGesture {
                            selectedClif = clif
                            copyClif(clif)
                        }
                }
            }
            .padding()
        }
    }

    private func loadClifs() {
        clifs = LibraryManager.loadAllClifs()
    }

    private func copyClif(_ clif: ClifItem) {
        if ClipboardManager.copyGifToClipboard(clif.gifURL) {
            ToastWindow.showSuccess("clif copied to clipboard!")
        }
    }
}

/// A single clif item for display
struct ClifItem: Identifiable {
    let id: String
    let createdAt: Date
    let durationMs: Int
    let gifURL: URL
    let thumbnailImage: NSImage?

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    var formattedDuration: String {
        let seconds = Double(durationMs) / 1000.0
        return String(format: "%.1fs", seconds)
    }
}

/// Thumbnail view for a single clif
struct ClifThumbnailView: View {
    let clif: ClifItem
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail
            ZStack {
                if let image = clif.thumbnailImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 100)
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 100)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        )
                }
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )

            // Info
            VStack(spacing: 2) {
                Text(clif.formattedDate)
                    .font(.caption)
                    .lineLimit(1)
                Text(clif.formattedDuration)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - LibraryManager Extension

extension LibraryManager {
    /// Load all clifs from the library
    static func loadAllClifs() -> [ClifItem] {
        var items: [ClifItem] = []

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: libraryURL.path) else {
            return []
        }

        // Find all JSON metadata files
        let enumerator = fileManager.enumerator(
            at: libraryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "json" else { continue }

            do {
                let data = try Data(contentsOf: url)
                let metadata = try decoder.decode(ClifMetadata.self, from: data)

                let folder = url.deletingLastPathComponent()
                let gifURL = folder.appendingPathComponent(metadata.gifFilename)

                // Load thumbnail (first frame of GIF)
                let thumbnail = NSImage(contentsOf: gifURL)

                let item = ClifItem(
                    id: metadata.id,
                    createdAt: metadata.createdAt,
                    durationMs: metadata.durationMs,
                    gifURL: gifURL,
                    thumbnailImage: thumbnail
                )
                items.append(item)
            } catch {
                Log.warning("Failed to load clif metadata: \(error)", subsystem: .storage)
            }
        }

        // Sort by date, newest first
        items.sort { $0.createdAt > $1.createdAt }

        return items
    }
}
