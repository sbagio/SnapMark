import AppKit
import CoreGraphics
import SnapMarkCore

@MainActor
final class CanvasView: NSView, NSTextFieldDelegate {

    private let baseImage: CGImage
    private let store: AnnotationStore

    /// Text-tool geometry. `fontSize`/`fieldSize` drive the live NSTextField;
    /// the commit maps the field's centered text to the renderer's baseline
    /// so committed text lands exactly where it was typed.
    private static let textFontSize: CGFloat = 16
    private static let textFieldSize = CGSize(width: 200, height: 30)
    /// Left content inset of a borderless NSTextField, in points.
    private static let textFieldInset: CGFloat = 2

    // In-progress drawing state
    private var inProgressStart: CGPoint?
    private var inProgressCurrent: CGPoint?

    // Active text field for text tool
    private var activeTextField: NSTextField?

    init(frame: NSRect, store: AnnotationStore, baseImage: CGImage) {
        self.store = store
        self.baseImage = baseImage
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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
        let nsImage = NSImage(cgImage: baseImage, size: bounds.size)
        nsImage.draw(in: bounds)

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
        let field = NSTextField(frame: NSRect(origin: point, size: Self.textFieldSize))
        field.isBezeled = false
        field.drawsBackground = true
        field.backgroundColor = NSColor.black.withAlphaComponent(0.35)
        field.textColor = store.currentColor
        field.font = .systemFont(ofSize: Self.textFontSize, weight: .semibold)
        field.placeholderAttributedString = NSAttributedString(
            string: "Type label…",
            attributes: [
                .foregroundColor: NSColor.white.withAlphaComponent(0.6),
                .font: NSFont.systemFont(ofSize: Self.textFontSize, weight: .semibold),
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
                origin: textBaselineOrigin(for: field),
                content: content,
                color: store.currentColor,
                fontSize: Self.textFontSize
            )))
        }

        field.removeFromSuperview()
        activeTextField = nil
        needsDisplay = true
        window?.makeFirstResponder(self)
    }

    /// The renderer draws text with its baseline at the stored origin, but an
    /// NSTextField vertically centers text within its frame and insets it from
    /// the left. Map the field's on-screen text position to that baseline
    /// origin so the committed render matches what the user saw while typing.
    private func textBaselineOrigin(for field: NSTextField) -> CGPoint {
        let font = field.font ?? .systemFont(ofSize: Self.textFontSize, weight: .semibold)
        let lineHeight = font.ascender - font.descender   // descender is negative
        let baselineFromTop = (field.frame.height - lineHeight) / 2 + font.ascender
        return CGPoint(
            x: field.frame.origin.x + Self.textFieldInset,
            y: field.frame.origin.y + baselineFromTop
        )
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
