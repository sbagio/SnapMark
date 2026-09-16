import AppKit
import SnapMarkCore

/// Manages one DimmingOverlayWindow per screen plus a SelectionOverlayView
/// on the screen that contains the cursor. Crops the final selection from the
/// frozen bitmap captured at hotkey time (never the live screen).
@MainActor
final class OverlayWindowController: SelectionOverlayViewDelegate {

    var onCaptureComplete: ((CGImage, CGRect) -> Void)?
    /// Called when the overlay closes without producing a capture, so the app can
    /// drop back to being a menu-bar-only accessory.
    var onCancel: (() -> Void)?

    private var dimmingWindows: [DimmingOverlayWindow] = []
    private var escapeMonitor: Any?

    /// The frozen bitmap and the screen it covers, captured at hotkey time.
    private let frozenImage: CGImage
    private let captureScreen: NSScreen

    init(frozenImage: CGImage, captureScreen: NSScreen) {
        self.frozenImage = frozenImage
        self.captureScreen = captureScreen
    }

    // MARK: - Present

    func present() {
        for screen in NSScreen.screens {
            let win = DimmingOverlayWindow(screen: screen)

            if screen == captureScreen {
                // Interactive selection view seeded with the frozen capture.
                let overlayView = SelectionOverlayView(frame: screen.frame, frozenImage: frozenImage)
                overlayView.delegate = self
                win.contentView = overlayView
                win.makeKeyAndOrderFront(nil)
                win.makeFirstResponder(overlayView)
            } else {
                let dimView = NSView(frame: screen.frame)
                dimView.wantsLayer = true
                dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(DimmingOverlayWindow.dimAlpha).cgColor
                win.contentView = dimView
                win.ignoresMouseEvents = true
                win.orderFront(nil)
            }

            dimmingWindows.append(win)
        }

        // The app is already .regular by the time we get here — AppDelegate owns
        // the activation policy for the whole capture, because demoting between the
        // overlay and the editor is what loses the editor its keyboard focus.
        NSApp.activate()

        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.selectionDidCancel()
                return nil // consume
            }
            return event
        }
    }

    // MARK: - Dismiss

    func dismiss() {
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
        dimmingWindows.forEach { $0.orderOut(nil) }
        dimmingWindows.removeAll()
    }

    // MARK: - SelectionOverlayViewDelegate

    nonisolated func selectionDidComplete(screenRect: CGRect) {
        Task { @MainActor in
            self.dismiss()

            // Crop from the frozen bitmap — no live capture, so no race with
            // the screen changing.
            guard let cropped = CaptureGeometry.crop(
                self.frozenImage,
                to: screenRect,
                screenFrame: self.captureScreen.frame,
                backingScale: self.captureScreen.backingScaleFactor
            ) else {
                Log.capture.error("Crop failed for rect \(String(describing: screenRect), privacy: .public)")
                let alert = NSAlert()
                alert.messageText = "Capture Failed"
                alert.informativeText = "Failed to crop the captured image."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
                return
            }
            self.onCaptureComplete?(cropped, screenRect)
        }
    }

    nonisolated func selectionDidCancel() {
        Task { @MainActor in
            self.dismiss()
            self.onCancel?()
        }
    }
}
