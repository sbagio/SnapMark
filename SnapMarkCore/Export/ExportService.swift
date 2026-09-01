import AppKit
import CoreGraphics

@MainActor
public struct ExportService {

    // MARK: - Composite

    public static func compositeImage(
        baseImage: CGImage,
        annotations: [AnnotationItem],
        canvasSize: CGSize
    ) -> NSImage {
        // Use the captured image's native resolution so Retina captures
        // export at full quality instead of being downscaled to 1x.
        let pixelWidth = baseImage.width
        let pixelHeight = baseImage.height
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        ) else {
            return NSImage(cgImage: baseImage, size: canvasSize)
        }
        // Setting logical size different from pixel dimensions makes
        // NSGraphicsContext apply the backing scale automatically.
        rep.size = canvasSize

        NSGraphicsContext.saveGraphicsState()
        guard let gc = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            return NSImage(cgImage: baseImage, size: canvasSize)
        }
        NSGraphicsContext.current = gc
        let ctx = gc.cgContext

        let nsImage = NSImage(cgImage: baseImage, size: canvasSize)
        nsImage.draw(in: CGRect(origin: .zero, size: canvasSize))

        ctx.saveGState()
        ctx.translateBy(x: 0, y: canvasSize.height)
        ctx.scaleBy(x: 1, y: -1)
        for item in annotations {
            AnnotationRenderer.draw(item, in: ctx)
        }
        ctx.restoreGState()

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: canvasSize)
        image.addRepresentation(rep)
        return image
    }

    // MARK: - Clipboard

    public static func copyToClipboard(_ image: NSImage) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
    }

    // MARK: - Save to Disk

    /// Default save location: ~/Screenshots. `directory` is injectable so the
    /// save + encoding-failure paths are testable without touching the home dir.
    /// Nonisolated: it only reads FileManager, and `Preferences` needs it off the
    /// main actor to resolve its fallback.
    nonisolated public static func defaultDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Screenshots")
    }

    @discardableResult
    public static func saveToDisk(
        _ image: NSImage,
        directory: URL = ExportService.defaultDirectory()
    ) throws -> URL {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let url = directory.appendingPathComponent(ScreenshotFilename.timestamped())

        guard let png = image.pngData() else {
            throw ExportError.encodingFailed
        }

        try png.write(to: url)
        return url
    }

    public enum ExportError: Error, LocalizedError {
        case encodingFailed

        public var errorDescription: String? { "Failed to encode image as PNG." }
    }
}
