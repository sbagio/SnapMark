import AppKit

@MainActor
public final class HistoryStore {

    public static let shared = HistoryStore()

    private let maxItems = 10
    public let historyDir: URL

    public init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        historyDir = appSupport.appendingPathComponent("SnapMark/History")
        try? FileManager.default.createDirectory(
            at: historyDir, withIntermediateDirectories: true
        )
    }

    /// For testing — supply a temp directory instead of the default app-support dir.
    public init(historyDir: URL) {
        self.historyDir = historyDir
        try? FileManager.default.createDirectory(
            at: historyDir, withIntermediateDirectories: true
        )
    }

    // MARK: - Save

    public func save(_ image: NSImage) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let filename = "SnapMark-\(formatter.string(from: Date())).png"
        let url = historyDir.appendingPathComponent(filename)

        guard
            let tiff   = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png    = bitmap.representation(using: .png, properties: [:])
        else { return }

        try? png.write(to: url)
        pruneOldItems()
    }

    // MARK: - Load

    public struct HistoryItem {
        public let url: URL
        public let date: Date
    }

    public func loadItems() -> [HistoryItem] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: historyDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )) ?? []

        return files
            .filter { $0.pathExtension == "png" }
            .compactMap { url -> HistoryItem? in
                let date = (try? url.resourceValues(
                    forKeys: [.creationDateKey]
                ))?.creationDate ?? Date.distantPast
                return HistoryItem(url: url, date: date)
            }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Helpers

    private func pruneOldItems() {
        let items = loadItems()
        guard items.count > maxItems else { return }
        for item in items.suffix(from: maxItems) {
            try? FileManager.default.removeItem(at: item.url)
        }
    }

    public func formattedDate(_ date: Date) -> String {
        let cal = Calendar.current
        let timeStr = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
        if cal.isDateInToday(date)     { return "Today at \(timeStr)" }
        if cal.isDateInYesterday(date) { return "Yesterday at \(timeStr)" }
        let dayStr = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
        return "\(dayStr) at \(timeStr)"
    }
}
