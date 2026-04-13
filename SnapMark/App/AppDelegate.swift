import AppKit
import SnapMarkCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let hotkeyManager = HotkeyManager()
    private var overlayController: OverlayWindowController?
    private var annotationControllers: [AnnotationWindowController] = []
    private var menu: NSMenu!

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

        menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        // Populated fresh each open via menuNeedsUpdate
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
            let data    = try? Data(contentsOf: url),
            let nsImage = NSImage(data: data),
            let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return }

        let size = CGSize(width: cgImage.width, height: cgImage.height)
        openInEditor(cgImage: cgImage, screenRect: CGRect(origin: .zero, size: size))
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        // Capture
        let captureItem = NSMenuItem(title: "Capture  ⌘⇧2", action: #selector(startCapture), keyEquivalent: "")
        captureItem.target = self
        menu.addItem(captureItem)

        // History items — inline, no submenu
        let history = HistoryStore.shared.loadItems()
        if !history.isEmpty {
            menu.addItem(.separator())
            for item in history {
                let name = item.url.lastPathComponent
                let ext  = item.url.pathExtension
                let stem = item.url.deletingPathExtension().lastPathComponent
                let maxLen = 30   // fits "SnapMark-2026-04-10-184621.png"
                let title: String
                if name.count <= maxLen {
                    title = name
                } else {
                    let extPart  = ext.isEmpty ? "" : ".\(ext)"
                    let stemMax  = maxLen - extPart.count - 1   // 1 for "…"
                    title = String(stem.prefix(stemMax)) + "…" + extPart
                }
                let menuItem = NSMenuItem(title: title, action: #selector(openHistoryItem(_:)), keyEquivalent: "")
                menuItem.target = self
                menuItem.representedObject = item.url
                menu.addItem(menuItem)
            }
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit SnapMark",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
    }
}
