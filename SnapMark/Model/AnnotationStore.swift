import AppKit
import Combine

@MainActor
final class AnnotationStore: ObservableObject {
    @Published var annotations: [AnnotationItem] = []
    @Published var currentTool: DrawingTool = .arrow
    @Published var currentColor: NSColor = .red
    @Published var strokeThickness: StrokeThickness = {
        let raw = UserDefaults.standard.string(forKey: "snapmark.strokeThickness") ?? "medium"
        return StrokeThickness(rawValue: raw) ?? .medium
    }() {
        didSet { UserDefaults.standard.set(strokeThickness.rawValue, forKey: "snapmark.strokeThickness") }
    }

    var strokeWidth: CGFloat { strokeThickness.lineWidth }

    let undoManager = UndoManager()

    /// Called on the main actor whenever annotations change.
    /// Used by CanvasView to trigger redraws without Combine.
    var onAnnotationsChanged: (() -> Void)?

    // Action hooks wired by AnnotationViewController so the toolbar buttons
    // can trigger the same export actions as the keyboard shortcuts.
    var onCopy:        (() -> Void)?
    var onSave:        (() -> Void)?
    var onCopyAndSave: (() -> Void)?
    var onCancel:      (() -> Void)?

    func add(_ annotation: AnnotationItem) {
        undoManager.registerUndo(withTarget: self) { store in
            store.removeLast()
        }
        undoManager.setActionName("Add Annotation")
        annotations.append(annotation)
        onAnnotationsChanged?()
    }

    private func removeLast() {
        guard !annotations.isEmpty else { return }
        let removed = annotations.removeLast()
        undoManager.registerUndo(withTarget: self) { store in
            store.annotations.append(removed)
        }
        undoManager.setActionName("Add Annotation")
        onAnnotationsChanged?()
    }

    func undo() {
        undoManager.undo()
    }

    func clear() {
        annotations.removeAll()
        undoManager.removeAllActions()
        onAnnotationsChanged?()
    }
}
