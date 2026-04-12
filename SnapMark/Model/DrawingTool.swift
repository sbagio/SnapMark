import Foundation

enum DrawingTool: String, CaseIterable {
    case arrow
    case rectangle
    case text
    case highlight
}

enum StrokeThickness: String, CaseIterable {
    case thin   = "thin"
    case medium = "medium"
    case thick  = "thick"

    var lineWidth: CGFloat {
        switch self {
        case .thin:   return 1.5
        case .medium: return 3.0
        case .thick:  return 5.5
        }
    }

    var label: String {
        switch self {
        case .thin:   return "Thin"
        case .medium: return "Medium"
        case .thick:  return "Thick"
        }
    }
}
