import AppKit

@MainActor
final class AnnotationWindowController: NSWindowController {

    var onClose: (() -> Void)?

    private let image: CGImage
    private let screenRect: CGRect

    init(image: CGImage, screenRect: CGRect) {
        self.image = image
        self.screenRect = screenRect

        // Size the window to match the captured selection (screenRect is in logical points).
        // Toolbar adds 44pt on top; 12pt padding on each side frames the image.
        // Cap at 95% of visible screen so it always fits.
        let toolbarHeight: CGFloat = 44
        let screenFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let nativeW = screenRect.width
        let nativeH = screenRect.height
        let maxW = screenFrame.width  * 0.95
        let maxH = screenFrame.height * 0.95 - toolbarHeight
        let scale = min(1.0, min(maxW / nativeW, maxH / nativeH))
        let windowW = (nativeW * scale).rounded()
        let windowH = (nativeH * scale + toolbarHeight).rounded()
        let originX = screenFrame.minX + (screenFrame.width  - windowW) / 2
        let originY = screenFrame.minY + (screenFrame.height - windowH) / 2
        let windowRect = CGRect(x: originX, y: originY, width: windowW, height: windowH)

        let win = AnnotationWindow(contentRect: windowRect)
        win.title = "SnapMark  —  \(Int(nativeW)) × \(Int(nativeH))"

        let vc = AnnotationViewController(image: image, logicalSize: CGSize(width: nativeW, height: nativeH))
        win.contentViewController = vc

        super.init(window: win)

        win.delegate = self
        win.center()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

extension AnnotationWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
