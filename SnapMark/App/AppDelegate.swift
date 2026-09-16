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
        NSApp.activate()

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
            Log.capture.error("No active display available for capture")
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            // Freeze the screen BEFORE presenting any overlay, so the bitmap
            // captures the state at hotkey time (open dropdowns included).
            let frozenImage: CGImage
            do {
                frozenImage = try await self.captureService.captureImage(cgRect: cursorScreen.frame)
            } catch {
                Log.capture.error("Freeze capture failed: \(error.localizedDescription, privacy: .public)")
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
                self.updateActivationPolicy()
            }
            controller.onCancel = { [weak self] in
                guard let self else { return }
                self.overlayController = nil
                self.updateActivationPolicy()
            }

            // Promote before presenting and stay promoted through the handoff to the
            // editor; see updateActivationPolicy.
            self.updateActivationPolicy()
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
            guard let self else { return }
            self.annotationControllers.removeAll { $0 === annotationController }
            self.updateActivationPolicy()
        }
        annotationController.showWindow(nil)
    }

    // MARK: - Activation Policy

    /// SnapMark is a menu-bar app, so it sits at `.accessory` at rest. It must be
    /// `.regular` whenever it owns an on-screen window: macOS 27 refuses an
    /// activation request from an `.accessory` app, which left the editor visible
    /// but never key — ⌘C went to whatever app was still frontmost instead.
    ///
    /// Policy is owned here, in one place, because the bug was caused by demoting
    /// in the gap between the overlay closing and the editor opening.
    private func updateActivationPolicy() {
        let ownsWindows = overlayController != nil || !annotationControllers.isEmpty
        let desired: NSApplication.ActivationPolicy = ownsWindows ? .regular : .accessory
        guard NSApp.activationPolicy() != desired else { return }
        NSApp.setActivationPolicy(desired)
    }

    // MARK: - Save Folder

    @objc private func chooseSaveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = Preferences.saveFolder()
        panel.message = "Choose where SnapMark saves screenshots."
        panel.prompt = "Choose"

        // An accessory app is never the active app, so the panel would open behind
        // whatever is in front unless we activate first.
        NSApp.activate()

        guard panel.runModal() == .OK, let url = panel.url else { return }
        Preferences.setSaveFolder(url)
        Log.storage.info("Save folder set to \(url.path, privacy: .public)")
    }

    @objc private func resetSaveFolder() {
        Preferences.resetSaveFolder()
        Log.storage.info("Save folder reset to \(Preferences.saveFolder().path, privacy: .public)")
    }

    // MARK: - Open History Item

    @objc private func openHistoryItem(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        guard
            let data    = try? Data(contentsOf: url),
            let nsImage = NSImage(data: data),
            let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            Log.storage.error("Could not open history item at \(url.path, privacy: .public)")
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

        let folder = Preferences.saveFolder()
        let folderItem = NSMenuItem(
            title: "Default Save Folder\u{2026}",
            action: #selector(chooseSaveFolder),
            keyEquivalent: ""
        )
        folderItem.target = self
        // The path is long and changes; a tooltip shows it without widening the menu.
        folderItem.toolTip = folder.path
        menu.addItem(folderItem)

        if Preferences.hasCustomSaveFolder() {
            let resetItem = NSMenuItem(
                title: "Reset Save Folder to Default",
                action: #selector(resetSaveFolder),
                keyEquivalent: ""
            )
            resetItem.target = self
            menu.addItem(resetItem)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit SnapMark",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
    }
}
