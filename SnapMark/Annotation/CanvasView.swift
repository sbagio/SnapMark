import AppKit
import CoreGraphics
import SnapMarkCore

@MainActor
final class CanvasView: NSView, NSTextFieldDelegate {

    var baseImage: CGImage?
    var store: AnnotationStore!

    // In-progress drawing state
    private var inProgressStart: CGPoint?
    private var inProgressCurrent: CGPoint?

    // Active text field for text tool
    private var activeTextField: NSTextField?

    // MARK: - Setup

    override var isFlipped: Bool { true }  // Y=0 at top, matches CGImage

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        switch store.currentTool {
        case .arrow, .rectangle, .highlight:
            addCursorRect(bounds, cursor: .crosshair)
        case .text:
            addCursorRect(bounds, cursor: .iBeam)
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // 1. Draw base screenshot.
        // Must use NSImage.draw(in:) — NOT ctx.draw(cgImage, in:).
        // In a flipped NSView (isFlipped=true), CGContextDrawImage inverts the
        // image (row-0 ends up at the bottom), producing a 180° rotation.
        // NSImage.draw is coordinate-system-aware and renders correctly in any view.
        if let img = baseImage {
            let nsImage = NSImage(cgImage: img, size: bounds.size)
            nsImage.draw(in: bounds)
        }

        // 2. Draw committed annotations.
        // The CGContext CTM is Y-down (from isFlipped=true), matching stored coords.
        for item in store.annotations {
            AnnotationRenderer.draw(item, in: ctx)
        }

        // 3. Draw in-progress stroke
        drawInProgress(in: ctx)
    }

    private func drawInProgress(in ctx: CGContext) {
        guard let start = inProgressStart, let current = inProgressCurrent else { return }

        ctx.saveGState()
        let color = store.currentColor
        let width = store.strokeWidth

        switch store.currentTool {
        case .arrow:
            AnnotationRenderer.drawArrow(
                tail: start, head: current,
                color: color, strokeWidth: width, in: ctx
            )
        case .rectangle:
            let rect = normalizedRect(from: start, to: current)
            AnnotationRenderer.drawRect(rect, color: color, strokeWidth: width, in: ctx)
        case .highlight:
            let rect = normalizedRect(from: start, to: current)
            AnnotationRenderer.drawHighlight(rect, color: color, in: ctx)
        case .text:
            break  // Text handled by NSTextField subview
        }
        ctx.restoreGState()
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        // Commit any pending text field first
        if activeTextField != nil {
            window?.makeFirstResponder(self)
        }

        let point = convert(event.locationInWindow, from: nil)

        switch store.currentTool {
        case .arrow, .rectangle, .highlight:
            inProgressStart = point
            inProgressCurrent = point
        case .text:
            placeTextField(at: point)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard store.currentTool != .text else { return }
        let point = convert(event.locationInWindow, from: nil)
        inProgressCurrent = point
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard
            store.currentTool != .text,
            let start = inProgressStart,
            let current = inProgressCurrent
        else { return }

        defer {
            inProgressStart = nil
            inProgressCurrent = nil
            needsDisplay = true
        }

        let minDist: CGFloat = 3
        switch store.currentTool {
        case .arrow:
            let dx = current.x - start.x
            let dy = current.y - start.y
            guard sqrt(dx*dx + dy*dy) > minDist else { return }
            store.add(.arrow(AnnotationItem.ArrowAnnotation(
                tail: start, head: current,
                color: store.currentColor,
                strokeWidth: store.strokeWidth
            )))

        case .rectangle:
            let rect = normalizedRect(from: start, to: current)
            guard rect.width > minDist && rect.height > minDist else { return }
            store.add(.rectangle(AnnotationItem.RectAnnotation(
                rect: rect,
                color: store.currentColor,
                strokeWidth: store.strokeWidth
            )))

        case .highlight:
            let rect = normalizedRect(from: start, to: current)
            guard rect.width > minDist && rect.height > minDist else { return }
            store.add(.highlight(AnnotationItem.HighlightAnnotation(
                rect: rect,
                color: store.currentColor
            )))

        case .text:
            break
        }
    }

    // MARK: - Text Tool

    private func placeTextField(at point: CGPoint) {
        let field = NSTextField(frame: NSRect(x: point.x, y: point.y, width: 200, height: 30))
        field.isBezeled = false
        field.drawsBackground = true
        field.backgroundColor = NSColor.black.withAlphaComponent(0.35)
        field.textColor = store.currentColor
        field.font = .systemFont(ofSize: 16, weight: .semibold)
        field.placeholderAttributedString = NSAttributedString(
            string: "Type label…",
            attributes: [
                .foregroundColor: NSColor.white.withAlphaComponent(0.6),
                .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
            ]
        )
        field.delegate = self
        addSubview(field)
        window?.makeFirstResponder(field)
        activeTextField = field
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = activeTextField else { return }
        let content = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if !content.isEmpty {
            store.add(.text(AnnotationItem.TextAnnotation(
                origin: field.frame.origin,
                content: content,
                color: store.currentColor,
                fontSize: 16
            )))
        }

        field.removeFromSuperview()
        activeTextField = nil
        needsDisplay = true
        window?.makeFirstResponder(self)
    }

    // MARK: - Helpers

    private func normalizedRect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(b.x - a.x),
            height: abs(b.y - a.y)
        )
    }
}
