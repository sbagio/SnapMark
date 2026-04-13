import CoreGraphics
import AppKit

public enum AnnotationItem {
    case arrow(ArrowAnnotation)
    case rectangle(RectAnnotation)
    case text(TextAnnotation)
    case highlight(HighlightAnnotation)

    public struct ArrowAnnotation {
        public var tail: CGPoint
        public var head: CGPoint
        public var color: NSColor
        public var strokeWidth: CGFloat
        public init(tail: CGPoint, head: CGPoint, color: NSColor, strokeWidth: CGFloat) {
            self.tail = tail; self.head = head; self.color = color; self.strokeWidth = strokeWidth
        }
    }

    public struct RectAnnotation {
        public var rect: CGRect
        public var color: NSColor
        public var strokeWidth: CGFloat
        public init(rect: CGRect, color: NSColor, strokeWidth: CGFloat) {
            self.rect = rect; self.color = color; self.strokeWidth = strokeWidth
        }
    }

    public struct TextAnnotation {
        public var origin: CGPoint
        public var content: String
        public var color: NSColor
        public var fontSize: CGFloat
        public init(origin: CGPoint, content: String, color: NSColor, fontSize: CGFloat) {
            self.origin = origin; self.content = content; self.color = color; self.fontSize = fontSize
        }
    }

    public struct HighlightAnnotation {
        public var rect: CGRect
        public var color: NSColor
        public init(rect: CGRect, color: NSColor) {
            self.rect = rect; self.color = color
        }
    }
}
