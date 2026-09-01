import AppKit
import SnapMarkCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let hotkeyManager = HotkeyManager()
    private let captureService = ScreenCaptureService()
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

    // MARK: - Permission

    /// Modal alert shown ONLY when a capture genuinely fails on permission —
    /// never as a preflight. Preflight flags (CGPreflightScreenCaptureAccess)
    /// read stale after every re-sign and falsely nag when rights are fine, so
    /// we attempt the capture and react to the actual result instead.
    private func presentPermissionAlert() {
        // An accessory app isn't active, so an alert can open behind other
        // windows. Briefly activate so it's visible, then restore.
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Needed"
        alert.informativeText = """
        SnapMark needs Screen Recording permission to capture screenshots.

        1. Click "Open System Settings" below.
        2. Enable SnapMark under Screen Recording.
        3. Quit and reopen SnapMark — the permission only takes effect after a restart.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            ScreenRecordingPermission.openSystemSettings()
        }
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

        // No permission preflight: we just attempt the capture below. Preflight
        // flags go stale after every re-sign and falsely nag when rights are
        // fine. If the capture actually throws, THEN we show the alert.

        let mouseLocation = NSEvent.mouseLocation
        // `NSScreen.screens` can be empty (all displays asleep/locked) — the very
        // case the fallback chain exists to survive — so never force-index it.
        guard let cursorScreen = NSScreen.screens.first(where: {
            $0.frame.contains(mouseLocation)
        }) ?? NSScreen.main ?? NSScreen.screens.first else {
            NSLog("SnapMark: No active display available for capture")
            return
        }

        Task { @MainActor in
            // Freeze the screen BEFORE presenting any overlay, so the bitmap
            // captures the state at hotkey time (open dropdowns included).
            let frozenImage: CGImage
            do {
                frozenImage = try await self.captureService.captureImage(cgRect: cursorScreen.frame)
            } catch {
                NSLog("SnapMark: Freeze capture failed: %@", "\(error)")
                self.presentPermissionAlert()
                return
            }

            let controller = OverlayWindowController(
                frozenImage: frozenImage,
                captureScreen: cursorScreen
            )
            self.overlayController = controller

            controller.onCaptureComplete = { [weak self] cgImage, screenRect in
                guard let self else { return }
                self.overlayController = nil
                self.openInEditor(cgImage: cgImage, screenRect: screenRect)
            }

            controller.present()
        }
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
        else {
            NSLog("SnapMark: Could not open history item at %@", url.path)
            let alert = NSAlert()
            alert.messageText = "Couldn't Open Screenshot"
            alert.informativeText = "The file may have been moved or deleted:\n\(url.lastPathComponent)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        // Use NSImage.size (logical points) not cgImage.width/height (pixels)
        // so the editor window is correctly sized on Retina displays.
        let size = nsImage.size
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
