import ScreenCaptureKit
import CoreGraphics
import AppKit

/// Wraps SCScreenshotManager for single-frame capture of a CGRect region.
actor ScreenCaptureService {

    enum CaptureError: Error, LocalizedError {
        case noDisplay
        case cropFailed
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .noDisplay: return "No display found for the selected region."
            case .cropFailed: return "Failed to crop the captured image."
            case .permissionDenied: return "Screen recording permission denied."
            }
        }
    }

    func captureImage(cgRect: CGRect) async throws -> CGImage {
        // 1. Get shareable content
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
        } catch {
            throw CaptureError.permissionDenied
        }

        // 2. Find the display that best contains the selection rect
        // NSScreen uses Y-up; SCDisplay.frame also uses Y-up (screen coordinates)
        guard let display = content.displays.first(where: { display in
            let df = display.frame
            return df.intersects(cgRect)
        }) ?? content.displays.first else {
            throw CaptureError.noDisplay
        }

        // 3. Configure content filter for full display
        let filter = SCContentFilter(display: display, excludingWindows: [])

        // 4. Configure stream — capture at native resolution
        let config = SCStreamConfiguration()
        config.width = display.width * 2       // 2× for Retina
        config.height = display.height * 2
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.captureResolution = .best
        config.scalesToFit = false

        // 5. Capture full display frame
        let fullImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        // 6. Crop to the requested CGRect
        // cgRect is in global screen coordinates: Y-up, origin at bottom-left of main screen
        // SCDisplay.frame is also in screen coordinates (Y-up)
        let displayFrame = display.frame  // in screen coords (Y-up)
        let imageWidth = CGFloat(fullImage.width)
        let imageHeight = CGFloat(fullImage.height)
        let displayPixelWidth = CGFloat(display.width) * 2
        let displayPixelHeight = CGFloat(display.height) * 2

        let scaleX = imageWidth / displayPixelWidth
        let scaleY = imageHeight / displayPixelHeight
        let pixelScaleX = displayPixelWidth / displayFrame.width
        let pixelScaleY = displayPixelHeight / displayFrame.height

        // Map cgRect (screen Y-up) → image rect (Y-down, pixel space)
        let cropX = (cgRect.origin.x - displayFrame.origin.x) * pixelScaleX * scaleX
        let cropY = (displayFrame.maxY - cgRect.maxY) * pixelScaleY * scaleY
        let cropW = cgRect.width * pixelScaleX * scaleX
        let cropH = cgRect.height * pixelScaleY * scaleY

        let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
        guard let cropped = fullImage.cropping(to: cropRect) else {
            throw CaptureError.cropFailed
        }

        return cropped
    }
}
