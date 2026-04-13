import AppKit
import SwiftUI
import SnapMarkCore

@MainActor
final class AnnotationViewController: NSViewController {

    let store = AnnotationStore()

    private let image: CGImage
    private let logicalSize: CGSize
    private var keyMonitor: Any?

    private var canvasView: CanvasView!

    init(image: CGImage, logicalSize: CGSize) {
        self.image = image
        self.logicalSize = logicalSize
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    private var isCompact: Bool { WindowSizing.isCompact(captureWidth: logicalSize.width) }

    override var preferredContentSize: CGSize {
        get { CGSize(width: max(WindowSizing.minWidth, logicalSize.width), height: logicalSize.height + 44) }
        set { }
    }

    // MARK: - View Lifecycle

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Toolbar (SwiftUI hosted)
        let toolbarView = ToolbarView(store: store, isCompact: isCompact)
        let hostingView = NSHostingView(rootView: toolbarView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingView)

        // Canvas at fixed logical size — never stretches regardless of window size.
        // Wrapped in a scroll view so the user can resize freely.
        canvasView = CanvasView(frame: NSRect(origin: .zero, size: logicalSize))
        canvasView.store = store
        canvasView.baseImage = image

        let scrollView = NSScrollView()
        scrollView.documentView = canvasView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = NSColor(white: 0.12, alpha: 1)
scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingView.heightAnchor.constraint(equalToConstant: 44),

            scrollView.topAnchor.constraint(equalTo: hostingView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Trigger canvas redraws when annotations change
        // (no Combine — direct callback avoids Swift 6 actor-crossing issues)
        store.onAnnotationsChanged = { [weak self] in
            self?.canvasView.needsDisplay = true
            self?.canvasView.resetCursorRects()
        }
        store.onCopy        = { [weak self] in self?.handleCopy() }
        store.onSave        = { [weak self] in self?.handleSave() }
        store.onCopyAndSave = { [weak self] in self?.handleCopyAndSave() }
        store.onCancel      = { [weak self] in self?.closeWindow() }

        installKeyMonitor()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(canvasView)
    }

    // MARK: - UndoManager routing

    override var undoManager: UndoManager? { store.undoManager }

    // Escape key via responder chain (cancelOperation is the standard AppKit mechanism)
    override func cancelOperation(_ sender: Any?) {
        closeWindow()
    }

    // MARK: - Key Handling

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.handleKeyEquivalent(event) { return nil }
            return event
        }
    }

    /// Returns true if the event was consumed.
    func handleKeyEquivalent(_ event: NSEvent) -> Bool {
        // Escape: cancel without saving
        if event.keyCode == 53 {
            closeWindow()
            return true
        }

        let cmd = event.modifierFlags.contains(.command)
        guard cmd else { return false }

        switch event.keyCode {
        case 8:   // c
            handleCopy()
            return true
        case 1:   // s
            handleSave()
            return true
        case 36:  // Return
            handleCopyAndSave()
            return true
        default:
            return false
        }
    }

    // MARK: - Export Actions

    private func compositeImage() -> NSImage {
        return ExportService.compositeImage(
            baseImage: image,
            annotations: store.annotations,
            canvasSize: logicalSize
        )
    }

    private func handleCopy() {
        let img = compositeImage()
        ExportService.copyToClipboard(img)
        HistoryStore.shared.save(img)
        closeWindow()
    }

    private func handleSave() {
        let img = compositeImage()
        HistoryStore.shared.save(img)
        do {
            let url = try ExportService.saveToDisk(img)
            NSLog("SnapMark: Saved to %@", url.path)
        } catch {
            NSLog("SnapMark: Save failed: %@", error.localizedDescription)
        }
        closeWindow()
    }

    private func handleCopyAndSave() {
        let img = compositeImage()
        ExportService.copyToClipboard(img)
        HistoryStore.shared.save(img)
        do {
            let url = try ExportService.saveToDisk(img)
            NSLog("SnapMark: Saved to %@", url.path)
        } catch {
            NSLog("SnapMark: Save failed: %@", error.localizedDescription)
        }
        closeWindow()
    }

    private func closeWindow() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        view.window?.close()
    }
}
