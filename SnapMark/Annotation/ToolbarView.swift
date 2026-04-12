import SwiftUI
import AppKit

struct ToolbarView: View {
    @ObservedObject var store: AnnotationStore
    @State private var showColorPopover = false

    static let palette: [NSColor] = [
        NSColor(red: 1.00, green: 0.27, blue: 0.23, alpha: 1), // Red
        NSColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1), // Green
        NSColor(red: 0.00, green: 0.48, blue: 1.00, alpha: 1), // Blue
        NSColor(red: 1.00, green: 0.18, blue: 0.33, alpha: 1), // Pink
        NSColor(red: 1.00, green: 0.84, blue: 0.04, alpha: 1), // Yellow
        NSColor(red: 1.00, green: 0.58, blue: 0.00, alpha: 1), // Orange
        NSColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1), // Purple
        NSColor(red: 0.64, green: 0.52, blue: 0.37, alpha: 1), // Brown
    ]

    var body: some View {
        HStack(spacing: 10) {
            // Tool buttons
            ToolButton(icon: "arrow.up.right", label: "Arrow",     isSelected: store.currentTool == .arrow)     { store.currentTool = .arrow }
            ToolButton(icon: "rectangle",      label: "Rectangle", isSelected: store.currentTool == .rectangle) { store.currentTool = .rectangle }
            ToolButton(icon: "text.cursor",    label: "Text",      isSelected: store.currentTool == .text)      { store.currentTool = .text }
            ToolButton(icon: "highlighter",    label: "Highlight", isSelected: store.currentTool == .highlight) { store.currentTool = .highlight }

            Divider().frame(height: 22)

            // Color swatch — opens fixed palette, no full color wheel
            Button { showColorPopover.toggle() } label: {
                Circle()
                    .fill(Color(store.currentColor))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color.primary.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Color")
            .popover(isPresented: $showColorPopover, arrowEdge: .bottom) {
                ColorPalettePopover(store: store, palette: Self.palette) {
                    showColorPopover = false
                }
            }

            // Stroke thickness dropdown
            Menu {
                ForEach(StrokeThickness.allCases, id: \.self) { t in
                    Button { store.strokeThickness = t } label: {
                        HStack {
                            Text(t.label)
                            if store.strokeThickness == t { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle").font(.system(size: 16))
                    Text(store.strokeThickness.label).font(.system(size: 12))
                }
                .foregroundStyle(Color.primary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Stroke thickness")

            Divider().frame(height: 22)

            // Undo
            Button(action: { store.undo() }) {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .disabled(!store.undoManager.canUndo)
            .help("Undo  ⌘Z")
            .keyboardShortcut("z", modifiers: .command)

            Spacer()

            // Keyboard shortcut buttons — clickable, same action as the shortcut
            HStack(spacing: 12) {
                ShortcutButton(key: "⌘C",  label: "Copy")   { store.onCopy?() }
                ShortcutButton(key: "⌘S",  label: "Save")   { store.onSave?() }
                ShortcutButton(key: "⌘↩",  label: "Both")   { store.onCopyAndSave?() }
                ShortcutButton(key: "Esc", label: "Cancel")  { store.onCancel?() }
            }
            .padding(.trailing, 6)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(.regularMaterial)
    }
}

// MARK: - Color palette popover

private struct ColorPalettePopover: View {
    @ObservedObject var store: AnnotationStore
    let palette: [NSColor]
    let onSelect: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 32), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(palette.enumerated()), id: \.offset) { _, nsColor in
                let selected = store.currentColor.isEqual(nsColor)
                Circle()
                    .fill(Color(nsColor))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle().stroke(
                            selected ? Color.primary : Color.primary.opacity(0.15),
                            lineWidth: selected ? 2.5 : 1
                        )
                    )
                    .scaleEffect(selected ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: selected)
                    .onTapGesture {
                        store.currentColor = nsColor
                        onSelect()
                    }
            }
        }
        .padding(12)
        .frame(width: 168)
    }
}

// MARK: - Subviews

private struct ToolButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 32, height: 32)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(label)
    }
}

private struct ShortcutButton: View {
    let key: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(key)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.primary.opacity(0.2), lineWidth: 0.5))
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help("\(label)  \(key)")
    }
}
