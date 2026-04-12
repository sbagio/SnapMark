import CoreGraphics
import AppKit

enum AnnotationItem {
    case arrow(ArrowAnnotation)
    case rectangle(RectAnnotation)
    case text(TextAnnotation)
    case highlight(HighlightAnnotation)

    struct ArrowAnnotation {
        var tail: CGPoint
        var head: CGPoint
        var color: NSColor
        var strokeWidth: CGFloat
    }

    struct RectAnnotation {
        var rect: CGRect
        var color: NSColor
        var strokeWidth: CGFloat
    }

    struct TextAnnotation {
        var origin: CGPoint
        var content: String
        var color: NSColor
        var fontSize: CGFloat
    }

    struct HighlightAnnotation {
        var rect: CGRect
        var color: NSColor
    }
}
