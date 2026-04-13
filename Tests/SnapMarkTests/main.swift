// SnapMark unit test runner.
// Plain Swift executable — no test framework required.
// Swift 6 top-level code runs on @MainActor, so actor-isolated types
// (AnnotationStore, HistoryStore) are directly testable here.

import Foundation
import CoreGraphics
import AppKit
import SnapMarkCore

// ─── Minimal assertion harness ────────────────────────────────────────────────

var passCount = 0
var failCount = 0

@MainActor
func check(_ name: String, _ condition: Bool, file: StaticString = #file, line: UInt = #line) {
    if condition {
        print("  ✓ \(name)")
        passCount += 1
    } else {
        print("  ✗ FAIL: \(name)  (\(file):\(line))")
        failCount += 1
    }
}

@MainActor
func section(_ name: String) { print("\n\(name)") }

// ─── DrawingTool ──────────────────────────────────────────────────────────────

section("StrokeThickness")
check("thin lineWidth == 1.5",   StrokeThickness.thin.lineWidth   == 1.5)
check("medium lineWidth == 3.0", StrokeThickness.medium.lineWidth == 3.0)
check("thick lineWidth == 5.5",  StrokeThickness.thick.lineWidth  == 5.5)
check("lineWidths strictly increasing",
      StrokeThickness.thin.lineWidth < StrokeThickness.medium.lineWidth &&
      StrokeThickness.medium.lineWidth < StrokeThickness.thick.lineWidth)
check("thin label",   StrokeThickness.thin.label   == "Thin")
check("medium label", StrokeThickness.medium.label == "Medium")
check("thick label",  StrokeThickness.thick.label  == "Thick")
for t in StrokeThickness.allCases {
    check("rawValue round-trip \(t.rawValue)", StrokeThickness(rawValue: t.rawValue) == t)
}

section("DrawingTool")
check("all 4 tools present", DrawingTool.allCases.count == 4)
check("contains .arrow",     DrawingTool.allCases.contains(.arrow))
check("contains .rectangle", DrawingTool.allCases.contains(.rectangle))
check("contains .text",      DrawingTool.allCases.contains(.text))
check("contains .highlight", DrawingTool.allCases.contains(.highlight))

// ─── WindowSizing ─────────────────────────────────────────────────────────────

section("WindowSizing")
let screen = CGRect(x: 0, y: 0, width: 2560, height: 1440)

let small = WindowSizing.compute(captureSize: CGSize(width: 100, height: 50), screenFrame: screen)
check("small capture: width >= minWidth",  small.width  >= WindowSizing.minWidth)
check("small capture: height >= minHeight", small.height >= WindowSizing.minHeight)

let huge = WindowSizing.compute(captureSize: CGSize(width: 5000, height: 3000), screenFrame: screen)
check("huge capture: width <= 96% screen",  huge.width  <= screen.width  * 0.96)
check("huge capture: height <= 96% screen", huge.height <= screen.height * 0.96)

let moderate = WindowSizing.compute(captureSize: CGSize(width: 800, height: 600), screenFrame: screen)
check("moderate capture: native width preserved",   moderate.width  == 800)
check("moderate capture: toolbar height included",  moderate.height == 600 + 44)

check("isCompact(649) == true",  WindowSizing.isCompact(captureWidth: 649))
check("isCompact(0) == true",    WindowSizing.isCompact(captureWidth: 0))
check("isCompact(650) == false", !WindowSizing.isCompact(captureWidth: 650))
check("isCompact(1000) == false",!WindowSizing.isCompact(captureWidth: 1000))
check("compactThreshold == 650", WindowSizing.compactThreshold == 650)

// ─── AnnotationStore ──────────────────────────────────────────────────────────

section("AnnotationStore")
do {
    let store = AnnotationStore()
    store.add(.arrow(.init(tail: .zero, head: CGPoint(x: 10, y: 10), color: .red, strokeWidth: 2)))
    check("add: appends annotation",  store.annotations.count == 1)
    check("add: registers undo",      store.undoManager.canUndo)

    store.add(.rectangle(.init(rect: .zero, color: .blue, strokeWidth: 1)))
    check("add: count is 2 after second add", store.annotations.count == 2)

    store.undo()
    check("undo: removes last annotation", store.annotations.count == 1)
    store.undo()
    check("undo: stack empties correctly",  store.annotations.count == 0)

    store.undo() // no-op on empty
    check("undo on empty: no crash", store.annotations.count == 0)

    store.add(.rectangle(.init(rect: .zero, color: .red, strokeWidth: 1)))
    store.add(.rectangle(.init(rect: .zero, color: .red, strokeWidth: 1)))
    store.clear()
    check("clear: removes all",       store.annotations.count == 0)
    check("clear: disables undo",     !store.undoManager.canUndo)
}

do {
    let store = AnnotationStore()
    var callCount = 0
    store.onAnnotationsChanged = { callCount += 1 }
    store.add(.highlight(.init(rect: .zero, color: .yellow)))
    check("onAnnotationsChanged fires on add",   callCount == 1)
    store.clear()
    check("onAnnotationsChanged fires on clear", callCount == 2)
}

// ─── HistoryStore ─────────────────────────────────────────────────────────────

section("HistoryStore")
do {
    func makeImage() -> NSImage {
        NSImage(size: NSSize(width: 10, height: 10), flipped: false) { rect in
            NSColor.red.setFill(); rect.fill(); return true
        }
    }

    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapMarkTests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = HistoryStore(historyDir: dir)

    store.save(makeImage())
    let items = store.loadItems()
    check("save: writes PNG to disk",           items.count == 1)
    check("save: file has .png extension",      items.first?.url.pathExtension == "png")
    check("save: filename has SnapMark- prefix",
          items.first?.url.lastPathComponent.hasPrefix("SnapMark-") == true)

    // Ordering: save a second file after a deliberate delay
    Thread.sleep(forTimeInterval: 1.1)
    store.save(makeImage())
    let ordered = store.loadItems()
    check("loadItems: sorted newest first",
          ordered.count == 2 && ordered[0].date > ordered[1].date)

    // Pruning
    let dir2 = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapMarkTests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir2) }
    let store2 = HistoryStore(historyDir: dir2)
    for _ in 0..<12 {
        store2.save(makeImage())
        Thread.sleep(forTimeInterval: 1.1)
    }
    check("prune: keeps max 10 items", store2.loadItems().count == 10)

    // formattedDate
    let todayResult = store.formattedDate(Date())
    check("formattedDate: today starts with 'Today at'", todayResult.hasPrefix("Today at "))

    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    let ydResult = store.formattedDate(yesterday)
    check("formattedDate: yesterday starts with 'Yesterday at'", ydResult.hasPrefix("Yesterday at "))

    let older = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
    let oldResult = store.formattedDate(older)
    check("formattedDate: older contains ' at '",     oldResult.contains(" at "))
    check("formattedDate: older doesn't say Today",   !oldResult.hasPrefix("Today"))
    check("formattedDate: older doesn't say Yesterday", !oldResult.hasPrefix("Yesterday"))
}

// ─── Results ──────────────────────────────────────────────────────────────────

print("\n────────────────────────────────")
if failCount == 0 {
    print("✓ All \(passCount) tests passed.")
} else {
    print("✗ \(failCount) test(s) failed, \(passCount) passed.")
    exit(1)
}
