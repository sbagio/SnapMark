import AppKit
import Combine

@MainActor
public final class AnnotationStore: ObservableObject {
    @Published public var annotations: [AnnotationItem] = []
    @Published public var currentTool: DrawingTool = .arrow
    @Published public var currentColor: NSColor = .red
    @Published public var strokeThickness: StrokeThickness = {
        let raw = UserDefaults.standard.string(forKey: "snapmark.strokeThickness") ?? "medium"
        return StrokeThickness(rawValue: raw) ?? .medium
    }() {
        didSet { UserDefaults.standard.set(strokeThickness.rawValue, forKey: "snapmark.strokeThickness") }
    }

    public var strokeWidth: CGFloat { strokeThickness.lineWidth }

    public let undoManager: UndoManager = {
        let m = UndoManager()
        m.groupsByEvent = false  // Each annotation is its own undo step
        return m
    }()

    public var onAnnotationsChanged: (() -> Void)?
    public var onCopy:        (() -> Void)?
    public var onSave:        (() -> Void)?
    public var onCopyAndSave: (() -> Void)?
    public var onCancel:      (() -> Void)?

    public init() {}

    public func add(_ annotation: AnnotationItem) {
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { store in
            store.removeLast()
        }
        undoManager.setActionName("Add Annotation")
        undoManager.endUndoGrouping()
        annotations.append(annotation)
        onAnnotationsChanged?()
    }

    private func removeLast() {
        guard !annotations.isEmpty else { return }
        let removed = annotations.removeLast()
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { store in
            store.annotations.append(removed)
        }
        undoManager.setActionName("Add Annotation")
        undoManager.endUndoGrouping()
        onAnnotationsChanged?()
    }

    public func undo() {
        undoManager.undo()
    }

    public func clear() {
        annotations.removeAll()
        undoManager.removeAllActions()
        onAnnotationsChanged?()
    }
}
