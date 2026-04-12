import AppKit
import CoreGraphics

@MainActor
struct ExportService {

    // MARK: - Composite

    static func compositeImage(
        baseImage: CGImage,
        annotations: [AnnotationItem],
        canvasSize: CGSize
    ) -> NSImage {
        // Create offscreen bitmap at 1× logical resolution
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(canvasSize.width),
            pixelsHigh: Int(canvasSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        ) else {
            // Fallback: return NSImage from CGImage
            return NSImage(cgImage: baseImage, size: canvasSize)
        }
        rep.size = canvasSize

        NSGraphicsContext.saveGraphicsState()
        guard let gc = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            return NSImage(cgImage: baseImage, size: canvasSize)
        }
        NSGraphicsContext.current = gc
        let ctx = gc.cgContext

        // Draw base screenshot using NSImage — coordinate-system-aware, renders
        // correctly in both Y-up (bitmap) and Y-down (flipped) contexts.
        let nsImage = NSImage(cgImage: baseImage, size: canvasSize)
        nsImage.draw(in: CGRect(origin: .zero, size: canvasSize))

        // Annotations are stored in canvas Y-down coordinates (origin top-left).
        // The bitmap context is Y-up by default, so flip it before drawing them.
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

    static func copyToClipboard(_ image: NSImage) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
    }

    // MARK: - Save to Disk

    @discardableResult
    static func saveToDisk(_ image: NSImage) throws -> URL {
        let screenshotsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Screenshots")
        try FileManager.default.createDirectory(
            at: screenshotsDir,
            withIntermediateDirectories: true
        )

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let filename = "SnapMark-\(formatter.string(from: Date())).png"
        let url = screenshotsDir.appendingPathComponent(filename)

        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            throw ExportError.encodingFailed
        }

        try png.write(to: url)
        return url
    }

    enum ExportError: Error, LocalizedError {
        case encodingFailed

        var errorDescription: String? { "Failed to encode image as PNG." }
    }
}
