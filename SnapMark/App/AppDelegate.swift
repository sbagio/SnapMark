import AppKit
import SnapMarkCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let hotkeyManager = HotkeyManager()
    private var overlayController: OverlayWindowController?
    private var annotationControllers: [AnnotationWindowController] = []

    // Kept as a property so NSMenuDelegate can update it
    private var historyMenu: NSMenu!

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        menu.delegate = self

        let captureItem = NSMenuItem(
            title: "Capture  ⌘⇧2",
            action: #selector(startCapture),
            keyEquivalent: ""
        )
        captureItem.target = self
        menu.addItem(captureItem)

        menu.addItem(.separator())

        // Recent Screenshots submenu — rebuilt each time the menu opens
        let recentItem = NSMenuItem(title: "Recent Screenshots", action: nil, keyEquivalent: "")
        historyMenu = NSMenu()
        recentItem.submenu = historyMenu
        menu.addItem(recentItem)

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
        overlayController?.dismiss()
        overlayController = nil

        let controller = OverlayWindowController()
        overlayController = controller

        controller.onCaptureComplete = { [weak self] cgImage, screenRect in
            guard let self else { return }
            self.overlayController = nil
            self.openInEditor(cgImage: cgImage, screenRect: screenRect)
        }

        controller.present()
    }

    // MARK: - Open in Editor

    private func openInEditor(cgImage: CGImage, screenRect: CGRect) {
        let annotationController = AnnotationWindowController(
            image: cgImage,
            screenRect: screenRect
        )
        annotationControllers.append(annotationController)
        annotationController.onClose = { [weak self, weak annotationController] in
            self?.annotationControllers.removeAll { $0 === annotationController }
        }
        annotationController.showWindow(nil)
    }

    // MARK: - Open History Item

    @objc private func openHistoryItem(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        guard
            let data     = try? Data(contentsOf: url),
            let nsImage  = NSImage(data: data),
            let cgImage  = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return }

        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let screenRect = CGRect(origin: .zero, size: size)
        openInEditor(cgImage: cgImage, screenRect: screenRect)
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Only rebuild the history submenu
        guard menu === historyMenu else { return }

        historyMenu.removeAllItems()

        let items = HistoryStore.shared.loadItems()
        if items.isEmpty {
            let empty = NSMenuItem(title: "No recent screenshots", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            historyMenu.addItem(empty)
            return
        }

        for item in items {
            let title = HistoryStore.shared.formattedDate(item.date)
            let menuItem = NSMenuItem(title: title, action: #selector(openHistoryItem(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = item.url
            historyMenu.addItem(menuItem)
        }
    }
}
