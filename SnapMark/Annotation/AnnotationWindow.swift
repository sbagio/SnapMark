import AppKit
import SnapMarkCore

final class AnnotationWindow: NSWindow {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        title = "SnapMark"
        isReleasedWhenClosed = false
        minSize = NSSize(width: 200, height: 150)
    }

    // Route Cmd+Z to our custom undoManager
    override var undoManager: UndoManager? {
        (contentViewController as? AnnotationViewController)?.store.undoManager
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Let the view controller handle Cmd+C / Cmd+S / Cmd+Return
        if let vc = contentViewController as? AnnotationViewController {
            if vc.handleKeyEquivalent(event) { return true }
        }
        return super.performKeyEquivalent(with: event)
    }
}
