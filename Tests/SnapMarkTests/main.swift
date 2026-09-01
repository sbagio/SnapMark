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

// ─── CaptureGeometry ────────────────────────────────────────────────────────────

section("CaptureGeometry")
do {
    // Primary display, 1x (non-Retina): screen origin at AppKit (0,0).
    let frame1x = CGRect(x: 0, y: 0, width: 1000, height: 800)
    // Selection 200 wide, 100 tall, whose top edge is 50pt below the screen top.
    // In AppKit Y-up: top edge y = 800 - 50 = 750, so origin.y = 750 - 100 = 650.
    let sel = CGRect(x: 100, y: 650, width: 200, height: 100)
    let px1x = CaptureGeometry.pixelRect(for: sel, screenFrame: frame1x, backingScale: 1)
    check("1x: x maps to local x",        px1x.origin.x == 100)
    check("1x: y flips to top-down (50)", px1x.origin.y == 50)
    check("1x: width preserved",          px1x.width  == 200)
    check("1x: height preserved",         px1x.height == 100)

    // Same selection on a 2x (Retina) display → pixel rect scales by 2.
    let px2x = CaptureGeometry.pixelRect(for: sel, screenFrame: frame1x, backingScale: 2)
    check("2x: x scaled",      px2x.origin.x == 200)
    check("2x: y scaled",      px2x.origin.y == 100)
    check("2x: width scaled",  px2x.width  == 400)
    check("2x: height scaled", px2x.height == 200)

    // Non-primary display whose frame is offset in AppKit space.
    let frameOffset = CGRect(x: 1000, y: 200, width: 1000, height: 800)
    let selOffset = CGRect(x: 1100, y: 850, width: 200, height: 100)
    // local x = 1100 - 1000 = 100; local y (top-down) = frame.maxY(1000) - sel.maxY(950) = 50
    let pxOff = CaptureGeometry.pixelRect(for: selOffset, screenFrame: frameOffset, backingScale: 1)
    check("offset display: x is display-local",  pxOff.origin.x == 100)
    check("offset display: y is display-local",  pxOff.origin.y == 50)

    // localRect is the point-space (unscaled) source of pixelRect — the shared
    // flip used by both live capture and frozen cropping.
    let local = CaptureGeometry.localRect(for: sel, screenFrame: frame1x)
    check("localRect: x display-local", local.origin.x == 100)
    check("localRect: y flipped",       local.origin.y == 50)
    check("localRect: size preserved",  local.width == 200 && local.height == 100)
    check("localRect == pixelRect at 1x",
          CaptureGeometry.pixelRect(for: sel, screenFrame: frame1x, backingScale: 1) == local)

    // End-to-end crop against a real bitmap with a known pattern:
    // top-left quadrant white, rest black, in a 100x100 (1x) image.
    let cs = CGColorSpaceCreateDeviceRGB()
    let bmp = CGContext(data: nil, width: 100, height: 100, bitsPerComponent: 8,
                        bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // CGContext is Y-up; fill whole black then a white square at the TOP-LEFT.
    bmp.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1)); bmp.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
    bmp.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1)); bmp.fill(CGRect(x: 0, y: 50, width: 50, height: 50)) // top-left in Y-up
    let fullImage = bmp.makeImage()!
    // Screen frame 100x100 at origin 0,0. Select the top-left 50x50 region.
    // Top-left in a top-down bitmap = AppKit rect with maxY at screen top (100),
    // so origin.y = 50, height 50; origin.x = 0.
    let cropRect = CGRect(x: 0, y: 50, width: 50, height: 50)
    let cropped = CaptureGeometry.crop(fullImage, to: cropRect,
                                       screenFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                       backingScale: 1)
    check("crop: returns an image",    cropped != nil)
    check("crop: correct pixel size",  cropped?.width == 50 && cropped?.height == 50)
    // Sample the center pixel of the crop — it should be white (the top-left quadrant).
    if let c = cropped {
        let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(c, in: CGRect(x: -24, y: -24, width: 50, height: 50)) // center pixel of the 50x50 crop
        let p = ctx.data!.bindMemory(to: UInt8.self, capacity: 4)
        check("crop: extracted the white top-left region", p[0] > 200 && p[1] > 200 && p[2] > 200)
    }
}

// ─── ExportService / AnnotationRenderer ─────────────────────────────────────────

section("ExportService / AnnotationRenderer")
do {
    func solidImage(_ w: Int, _ h: Int, white: CGFloat) -> CGImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                            bytesPerRow: 0, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: white, green: white, blue: white, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()!
    }

    // compositeImage must preserve the base image's NATIVE pixel dimensions even
    // when the logical canvas size is smaller (Retina), so exports stay sharp.
    let base = solidImage(200, 160, white: 1)   // 200×160 px
    let canvas = CGSize(width: 100, height: 80)  // 100×80 pt (2x)
    let composed = ExportService.compositeImage(baseImage: base, annotations: [], canvasSize: canvas)
    let rep = composed.representations.first as? NSBitmapImageRep
    check("composite: preserves native pixel width",  rep?.pixelsWide == 200)
    check("composite: preserves native pixel height", rep?.pixelsHigh == 160)

    // A filled highlight over the whole canvas must change the center pixel
    // away from the white base.
    let hl = AnnotationItem.highlight(.init(rect: CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height),
                                            color: .red))
    let drawn = ExportService.compositeImage(baseImage: base, annotations: [hl], canvasSize: canvas)
    let drawnRep = drawn.representations.first as? NSBitmapImageRep
    let center = drawnRep?.colorAt(x: 100, y: 80)
    check("composite: annotation changes pixels",
          (center?.greenComponent ?? 1.0) < 0.95)

    // A degenerate (tail == head) arrow must not crash and still produce output.
    let dot = CGPoint(x: 50, y: 40)
    let degenerate = AnnotationItem.arrow(.init(tail: dot, head: dot, color: .red, strokeWidth: 3))
    let safe = ExportService.compositeImage(baseImage: base, annotations: [degenerate], canvasSize: canvas)
    check("composite: zero-length arrow doesn't crash",
          (safe.representations.first as? NSBitmapImageRep)?.pixelsWide == 200)

    // saveToDisk writes a timestamped PNG into an injectable directory.
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapMarkExportTests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let img = NSImage(cgImage: base, size: canvas)
    if let url = try? ExportService.saveToDisk(img, directory: dir) {
        check("saveToDisk: writes into the given directory",
              url.deletingLastPathComponent().standardizedFileURL == dir.standardizedFileURL)
        check("saveToDisk: PNG extension",        url.pathExtension == "png")
        check("saveToDisk: SnapMark- prefix",     url.lastPathComponent.hasPrefix("SnapMark-"))
        check("saveToDisk: file exists on disk",  FileManager.default.fileExists(atPath: url.path))
    } else {
        check("saveToDisk: succeeded", false)
    }
}

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

do {
    let store = AnnotationStore()
    var toolChanges = 0
    store.onToolChanged = { toolChanges += 1 }
    store.currentTool = .text
    check("onToolChanged fires on tool change", toolChanges == 1)
    store.currentTool = .text  // same value still fires didSet
    check("onToolChanged fires again on reassign", toolChanges == 2)
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
