import AppKit
import CoreGraphics

/// Stateless drawing functions shared by CanvasView and ExportService.
/// All coordinates are in a Y-down (flipped) coordinate space matching CGImage layout.
enum AnnotationRenderer {

    static func draw(_ item: AnnotationItem, in ctx: CGContext) {
        ctx.saveGState()
        switch item {
        case .arrow(let a):
            drawArrow(tail: a.tail, head: a.head,
                      color: a.color, strokeWidth: a.strokeWidth, in: ctx)
        case .rectangle(let r):
            drawRect(r.rect, color: r.color, strokeWidth: r.strokeWidth, in: ctx)
        case .text(let t):
            drawText(t.content, at: t.origin, color: t.color, fontSize: t.fontSize, in: ctx)
        case .highlight(let h):
            drawHighlight(h.rect, color: h.color, in: ctx)
        }
        ctx.restoreGState()
    }

    // MARK: - Arrow

    static func drawArrow(
        tail: CGPoint,
        head: CGPoint,
        color: NSColor,
        strokeWidth: CGFloat,
        in ctx: CGContext
    ) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setFillColor(color.cgColor)
        ctx.setLineWidth(strokeWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        // Arrowhead geometry — computed first so the shaft can stop at the triangle base.
        let wingLength: CGFloat = max(14, strokeWidth * 5)
        let wingAngle: CGFloat = .pi * 25.0 / 180.0   // 25 degrees

        let dx = head.x - tail.x
        let dy = head.y - tail.y
        guard abs(dx) > 0.001 || abs(dy) > 0.001 else { return }
        let angle = atan2(dy, dx)

        // Stop the shaft at the base of the arrowhead so the rounded line cap
        // doesn't poke through the triangle tip.
        let baseSetback = wingLength * cos(wingAngle)
        let shaftEnd = CGPoint(
            x: head.x - baseSetback * cos(angle),
            y: head.y - baseSetback * sin(angle)
        )

        // Draw shaft
        ctx.move(to: tail)
        ctx.addLine(to: shaftEnd)
        ctx.strokePath()

        let wing1 = CGPoint(
            x: head.x - wingLength * cos(angle - wingAngle),
            y: head.y - wingLength * sin(angle - wingAngle)
        )
        let wing2 = CGPoint(
            x: head.x - wingLength * cos(angle + wingAngle),
            y: head.y - wingLength * sin(angle + wingAngle)
        )

        ctx.move(to: head)
        ctx.addLine(to: wing1)
        ctx.addLine(to: wing2)
        ctx.closePath()
        ctx.fillPath()
    }

    // MARK: - Highlight

    static func drawHighlight(_ rect: CGRect, color: NSColor, in ctx: CGContext) {
        ctx.setFillColor(color.withAlphaComponent(0.38).cgColor)
        ctx.fill(rect)
    }

    // MARK: - Rectangle

    static func drawRect(
        _ rect: CGRect,
        color: NSColor,
        strokeWidth: CGFloat,
        in ctx: CGContext
    ) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(strokeWidth)
        ctx.stroke(rect)
    }

    // MARK: - Text

    static func drawText(
        _ content: String,
        at origin: CGPoint,
        color: NSColor,
        fontSize: CGFloat,
        in ctx: CGContext
    ) {
        guard !content.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
        ]
        let str = NSAttributedString(string: content, attributes: attrs)
        let line = CTLineCreateWithAttributedString(str)

        ctx.saveGState()

        // CoreText always draws in Y-up space. Both our canvas (isFlipped=true)
        // and export contexts use a Y-down (flipped) CTM, so we compensate by
        // translating to the origin and flipping Y back before drawing.
        ctx.textMatrix = .identity
        ctx.translateBy(x: origin.x, y: origin.y)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textPosition = .zero

        CTLineDraw(line, ctx)

        ctx.restoreGState()
    }
}
