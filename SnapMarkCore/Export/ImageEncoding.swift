import AppKit

public extension NSImage {
    /// PNG-encodes the image, or returns nil if it has no bitmap representation.
    /// Shared by HistoryStore and ExportService so the encode path lives once.
    func pngData() -> Data? {
        guard
            let tiff   = tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

/// Builds the timestamped `SnapMark-…​.png` filename used for both saved
/// screenshots and history items.
public enum ScreenshotFilename {
    public static func timestamped(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "SnapMark-\(formatter.string(from: date)).png"
    }
}
