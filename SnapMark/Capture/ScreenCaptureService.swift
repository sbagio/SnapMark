import ScreenCaptureKit
import CoreGraphics
import AppKit

/// Captures a single-frame screenshot of a CGRect region.
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
        // 1. Get shareable content (also triggers permission prompt on first use)
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
        } catch {
            throw CaptureError.permissionDenied
        }

        // 2. Find the display that contains the selection
        guard let display = content.displays.first(where: { $0.frame.intersects(cgRect) })
              ?? content.displays.first else {
            throw CaptureError.noDisplay
        }

        // 3. Find the matching NSScreen for coordinate conversion.
        //    cgRect is in AppKit screen coordinates (Y-up), but sourceRect
        //    needs display-local Y-down coordinates. We MUST use NSScreen.frame
        //    (AppKit coords) — not SCDisplay.frame (CG coords) — because the
        //    two differ in Y origin on non-primary displays.
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(cgRect) }) else {
            throw CaptureError.noDisplay
        }
        let screenFrame = screen.frame
        let backingScale = screen.backingScaleFactor

        // 4. Convert selection from AppKit screen coordinates (Y-up) to
        //    display-local coordinates (Y-down, origin at top-left of display).
        let localX = cgRect.origin.x - screenFrame.origin.x
        let localY = screenFrame.maxY - cgRect.maxY
        let sourceRect = CGRect(x: localX, y: localY,
                                width: cgRect.width, height: cgRect.height)

        // 5. Configure capture to grab only the selected region
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = sourceRect
        config.width = Int(cgRect.width * backingScale)
        config.height = Int(cgRect.height * backingScale)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.captureResolution = .best
        config.scalesToFit = false

        // 6. Capture — ScreenCaptureKit crops to sourceRect internally,
        //    so no manual CGImage.cropping(to:) needed.
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        return image
    }
}
