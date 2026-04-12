import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let hotkeyManager = HotkeyManager()
    private var overlayController: OverlayWindowController?
    // Keep annotation controllers alive while their windows are open
    private var annotationControllers: [AnnotationWindowController] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Suppress Dock icon (belt + suspenders alongside LSUIElement)
        NSApp.setActivationPolicy(.accessory)

        setupMenuBar()

        hotkeyManager.onFire = { [weak self] in
            self?.startCapture()
        }
        hotkeyManager.register()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "camera.viewfinder",
                accessibilityDescription: "SnapMark"
            )
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        let captureItem = NSMenuItem(
            title: "Capture  ⌘⇧2",
            action: #selector(startCapture),
            keyEquivalent: ""
        )
        captureItem.target = self
        menu.addItem(captureItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit SnapMark",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu
    }

    // MARK: - Capture Flow

    @objc func startCapture() {
        // Dismiss any existing overlay before starting a new one
        overlayController?.dismiss()
        overlayController = nil

        let controller = OverlayWindowController()
        overlayController = controller

        controller.onCaptureComplete = { [weak self] cgImage, screenRect in
            guard let self else { return }
            self.overlayController = nil

            let annotationController = AnnotationWindowController(
                image: cgImage,
                screenRect: screenRect
            )
            self.annotationControllers.append(annotationController)
            annotationController.onClose = { [weak self, weak annotationController] in
                self?.annotationControllers.removeAll { $0 === annotationController }
            }
            annotationController.showWindow(nil)
        }

        controller.present()
    }
}
