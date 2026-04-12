import AppKit

/// A full-screen borderless window that dims a single screen.
/// One instance is created per NSScreen.
final class DimmingOverlayWindow: NSWindow {

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Sit just above normal app windows and the menu bar
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isReleasedWhenClosed = false

        // Move window to the exact screen frame (setFrame respects screen coords)
        setFrame(screen.frame, display: false)
    }

    // Borderless windows return false by default; override so keyboard events
    // (e.g. Escape) are delivered to the first responder.
    override var canBecomeKey: Bool { true }
}
