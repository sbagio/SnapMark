import AppKit
import SnapMarkCore

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
        let screenFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let nativeW = screenRect.width
        let nativeH = screenRect.height
        let winSize = WindowSizing.compute(
            captureSize: CGSize(width: nativeW, height: nativeH),
            screenFrame: screenFrame
        )
        let originX = screenFrame.minX + (screenFrame.width  - winSize.width)  / 2
        let originY = screenFrame.minY + (screenFrame.height - winSize.height) / 2
        let windowRect = CGRect(origin: CGPoint(x: originX, y: originY), size: winSize)

        let win = AnnotationWindow(contentRect: windowRect)
        win.minSize = CGSize(width: WindowSizing.minWidth, height: WindowSizing.minHeight)
        win.title = "SnapMark  —  \(Int(nativeW)) × \(Int(nativeH))"

        let vc = AnnotationViewController(image: image, logicalSize: CGSize(width: nativeW, height: nativeH))
        win.contentViewController = vc

        super.init(window: win)

        win.delegate = self
        // Origin above already centers on the visible frame (menu-bar/Dock aware);
        // NSWindow.center() would override it with a less-correct placement.
    }

    required init?(coder: NSCoder) { fatalError() }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        // activate(ignoringOtherApps:) is deprecated and, from macOS 27, refused for
        // an .accessory app: the window appeared but never became key, so ⌘C went to
        // whatever app was still frontmost. AppDelegate keeps us .regular while an
        // editor is open, which is what gives this request standing.
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

extension AnnotationWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
