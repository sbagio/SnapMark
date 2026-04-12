import AppKit

@MainActor
protocol SelectionOverlayViewDelegate: AnyObject {
    func selectionDidComplete(screenRect: CGRect)
    func selectionDidCancel()
}

/// Full-screen NSView placed on the primary dimming window.
/// Before dragging: shows full-screen crosshair lines + cursor coordinates.
/// While dragging: shows the punch-through selection + size label.
@MainActor
final class SelectionOverlayView: NSView {

    weak var delegate: SelectionOverlayViewDelegate?

    private var startPoint: CGPoint?
    private var currentRect: CGRect?
    private var isDragging = false
    private var cursorPoint: CGPoint?   // tracks mouse at all times

    // MARK: - Setup

    override var isFlipped: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Required so mouseMoved events fire before the user starts dragging
        window?.acceptsMouseMovedEvents = true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // 1. Dim the whole screen
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.50).cgColor)
        ctx.fill(bounds)

        if isDragging, let rect = currentRect, rect.width > 2, rect.height > 2 {
            // ── Active selection ────────────────────────────────────────────
            ctx.clear(rect)
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
            ctx.setLineWidth(1.5)
            ctx.stroke(rect.insetBy(dx: 0.75, dy: 0.75))
            drawSizeLabel(for: rect, in: ctx)
        } else if let pos = cursorPoint {
            // ── Waiting for selection ───────────────────────────────────────
            drawCrosshair(at: pos, in: ctx)
            drawCoordinateLabel(at: pos, in: ctx)
        }
    }

    // Full-screen crosshair — thin white lines through the cursor
    private func drawCrosshair(at pos: CGPoint, in ctx: CGContext) {
        ctx.saveGState()
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.45).cgColor)
        ctx.setLineWidth(0.5)
        // Horizontal
        ctx.move(to: CGPoint(x: 0,            y: pos.y))
        ctx.addLine(to: CGPoint(x: bounds.maxX, y: pos.y))
        // Vertical
        ctx.move(to: CGPoint(x: pos.x, y: 0))
        ctx.addLine(to: CGPoint(x: pos.x, y: bounds.maxY))
        ctx.strokePath()
        ctx.restoreGState()
    }

    // Floating "X, Y" label that follows the cursor
    private func drawCoordinateLabel(at pos: CGPoint, in ctx: CGContext) {
        let label = "\(Int(pos.x)), \(Int(pos.y))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let str = NSAttributedString(string: label, attributes: attrs)
        let textSize = str.size()

        // Prefer right+below the cursor; flip if near an edge
        let offset: CGFloat = 14
        var lx = pos.x + offset
        var ly = pos.y + offset
        if lx + textSize.width + 10 > bounds.maxX { lx = pos.x - textSize.width - offset - 8 }
        if ly + textSize.height + 6 > bounds.maxY  { ly = pos.y - textSize.height - offset }
        lx = max(4, lx)
        ly = max(4, ly)

        drawPill(text: str, at: CGPoint(x: lx, y: ly), size: textSize, in: ctx)
    }

    // "W × H" label shown during drag
    private func drawSizeLabel(for rect: CGRect, in ctx: CGContext) {
        let label = "\(Int(rect.width)) × \(Int(rect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let str = NSAttributedString(string: label, attributes: attrs)
        let textSize = str.size()

        var lx = rect.midX - textSize.width / 2
        var ly = rect.maxY + 6
        lx = max(4, min(lx, bounds.maxX - textSize.width - 4))
        if ly + textSize.height > bounds.maxY - 4 { ly = rect.minY - textSize.height - 6 }

        drawPill(text: str, at: CGPoint(x: lx, y: ly), size: textSize, in: ctx)
    }

    // Shared dark-pill background + text draw helper
    private func drawPill(
        text: NSAttributedString, at origin: CGPoint,
        size textSize: CGSize, in ctx: CGContext
    ) {
        let p: CGFloat = 4
        let bgRect = CGRect(
            x: origin.x - p, y: origin.y - p / 2,
            width: textSize.width + p * 2, height: textSize.height + p
        ).insetBy(dx: -1, dy: -1)

        ctx.setFillColor(NSColor.black.withAlphaComponent(0.65).cgColor)
        ctx.addPath(CGPath(roundedRect: bgRect, cornerWidth: 4, cornerHeight: 4, transform: nil))
        ctx.fillPath()

        NSGraphicsContext.saveGraphicsState()
        text.draw(at: origin)
        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: - Mouse Events

    override func mouseMoved(with event: NSEvent) {
        cursorPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        cursorPoint = point
        startPoint  = point
        currentRect = nil
        isDragging  = false
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        isDragging = true
        let current = convert(event.locationInWindow, from: nil)
        cursorPoint = current
        currentRect = normalizedRect(from: start, to: current)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging, let rect = currentRect, rect.width > 5, rect.height > 5 else {
            startPoint  = nil
            currentRect = nil
            isDragging  = false
            needsDisplay = true
            delegate?.selectionDidCancel()
            return
        }

        let windowRect = convert(rect, to: nil)
        guard let win = window else { return }
        let screenRect = win.convertToScreen(windowRect)

        delegate?.selectionDidComplete(screenRect: screenRect)

        startPoint  = nil
        currentRect = nil
        isDragging  = false
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // Escape
            startPoint  = nil
            currentRect = nil
            isDragging  = false
            needsDisplay = true
            delegate?.selectionDidCancel()
        }
    }

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Helpers

    private func normalizedRect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x), y: min(a.y, b.y),
            width: abs(b.x - a.x), height: abs(b.y - a.y)
        )
    }
}
