import AppKit

/// Manages one DimmingOverlayWindow per screen plus a SelectionOverlayView
/// on the screen that contains the cursor. Coordinates the capture pipeline.
@MainActor
final class OverlayWindowController: SelectionOverlayViewDelegate {

    var onCaptureComplete: ((CGImage, CGRect) -> Void)?

    private var dimmingWindows: [DimmingOverlayWindow] = []
    private let captureService = ScreenCaptureService()
    private var escapeMonitor: Any?

    // MARK: - Present

    func present() {
        // Find the screen that currently contains the cursor
        let mouseLocation = NSEvent.mouseLocation
        let primaryScreen = NSScreen.screens.first(where: {
            $0.frame.contains(mouseLocation)
        }) ?? NSScreen.main ?? NSScreen.screens[0]

        for screen in NSScreen.screens {
            let win = DimmingOverlayWindow(screen: screen)

            if screen == primaryScreen {
                // Place the interactive selection view on this window
                let overlayView = SelectionOverlayView(frame: screen.frame)
                overlayView.delegate = self
                win.contentView = overlayView
                win.makeKeyAndOrderFront(nil)
                win.makeFirstResponder(overlayView)
            } else {
                // Secondary screens: plain dim, no interaction
                let dimView = NSView(frame: screen.frame)
                dimView.wantsLayer = true
                dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.50).cgColor
                win.contentView = dimView
                win.ignoresMouseEvents = true
                win.orderFront(nil)
            }

            dimmingWindows.append(win)
        }

        // Promote to .regular so the system routes keyboard events to us.
        // .accessory apps don't fully become the active app, so local event
        // monitors and keyDown never fire. We restore .accessory on dismiss.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.selectionDidCancel()
                return nil // consume the event
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
        // Restore menubar-only presence after overlay is gone
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - SelectionOverlayViewDelegate

    nonisolated func selectionDidComplete(screenRect: CGRect) {
        Task { @MainActor in
            self.dismiss()

            // Small delay so the dimming windows fully disappear before capture
            try? await Task.sleep(for: .milliseconds(80))

            do {
                let image = try await self.captureService.captureImage(cgRect: screenRect)
                self.onCaptureComplete?(image, screenRect)
            } catch {
                NSLog("SnapMark: Capture failed: \(error)")
            }
        }
    }

    nonisolated func selectionDidCancel() {
        Task { @MainActor in
            self.dismiss()
        }
    }
}
