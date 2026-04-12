#!/usr/bin/env swift

import AppKit
import Foundation

// Bootstrap AppKit so off-screen rendering works without a display
let app = NSApplication.shared

let outputDir = "<project-root>/SnapMark/Resources/Assets.xcassets/AppIcon.appiconset"

let sizes: [(Int, String)] = [
    (16,   "app-16.png"),
    (32,   "app-32.png"),
    (64,   "app-64.png"),
    (128,  "app-128.png"),
    (256,  "app-256.png"),
    (512,  "app-512.png"),
    (1024, "app-1024.png"),
]

func generateIcon(size: Int) -> NSBitmapImageRep {
    let s = CGFloat(size)

    let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: bitmapRep)!
    NSGraphicsContext.current = ctx

    // ── Background: rounded rect with top-to-bottom gradient ──────────────────
    let cornerRadius = s * 0.22
    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let roundedPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)
    roundedPath.setClip()

    // Gradient drawn top→bottom in CG Y-up coords: top = high Y, bottom = low Y
    let topColor    = NSColor(red: 0.93, green: 0.95, blue: 0.97, alpha: 1.0)
    let bottomColor = NSColor(red: 0.82, green: 0.86, blue: 0.90, alpha: 1.0)
    let gradient = NSGradient(starting: bottomColor, ending: topColor)!
    // angle 90° draws from bottom (low Y) to top (high Y), which in screen terms
    // is top of the image → bottom, matching the spec (top light, bottom darker).
    gradient.draw(in: bgRect, angle: 90)

    // ── Camera viewfinder ─────────────────────────────────────────────────────
    let padding      = s * 0.20
    let lineWidth    = s * 0.025
    let armLen       = s * 0.12
    let innerLeft    = padding
    let innerRight   = s - padding
    let innerBottom  = padding
    let innerTop     = s - padding

    let viewfinderColor = NSColor(white: 0.25, alpha: 0.85)
    viewfinderColor.setStroke()

    let vfPath = NSBezierPath()
    vfPath.lineWidth    = lineWidth
    vfPath.lineCapStyle = .round

    // Helper: draw one L-shaped corner bracket
    // cornerX/Y is the corner point of the inner rect; hDir/vDir are ±1
    func addBracket(cx: CGFloat, cy: CGFloat, hDir: CGFloat, vDir: CGFloat) {
        // horizontal arm
        vfPath.move(to: NSPoint(x: cx + hDir * armLen, y: cy))
        vfPath.line(to: NSPoint(x: cx, y: cy))
        // vertical arm
        vfPath.line(to: NSPoint(x: cx, y: cy + vDir * armLen))
    }

    // Bottom-left corner (CG Y-up: low X, low Y)
    addBracket(cx: innerLeft,  cy: innerBottom, hDir:  1, vDir:  1)
    // Bottom-right corner
    addBracket(cx: innerRight, cy: innerBottom, hDir: -1, vDir:  1)
    // Top-left corner
    addBracket(cx: innerLeft,  cy: innerTop,    hDir:  1, vDir: -1)
    // Top-right corner
    addBracket(cx: innerRight, cy: innerTop,    hDir: -1, vDir: -1)

    // Crosshair at center
    let cx = s * 0.5
    let cy = s * 0.5
    let crossLen = s * 0.05
    vfPath.move(to: NSPoint(x: cx - crossLen, y: cy))
    vfPath.line(to: NSPoint(x: cx + crossLen, y: cy))
    vfPath.move(to: NSPoint(x: cx, y: cy - crossLen))
    vfPath.line(to: NSPoint(x: cx, y: cy + crossLen))

    vfPath.stroke()

    // ── Claude-style asterisk badge ───────────────────────────────────────────
    // Center at (size*0.68, size*0.68) in CG Y-up coords
    let badgeCX     = s * 0.68
    let badgeCY     = s * 0.68
    let outerRadius = s * 0.18
    let innerRadius = s * 0.04
    let armWidth    = s * 0.042
    let numArms     = 8
    let badgeColor  = NSColor(red: 0.859, green: 0.467, blue: 0.337, alpha: 1.0)
    badgeColor.setFill()

    let asteriskPath = NSBezierPath()
    for i in 0..<numArms {
        let angle = CGFloat(i) * (2.0 * .pi / CGFloat(numArms))

        // Arm: a rounded rectangle radiating outward, approximated as a
        // quadrilateral with half-width perpendicular to the radial direction.
        let perpAngle = angle + .pi / 2.0
        let halfW = armWidth / 2.0

        let innerPt = CGPoint(
            x: badgeCX + innerRadius * cos(angle),
            y: badgeCY + innerRadius * sin(angle)
        )
        let outerPt = CGPoint(
            x: badgeCX + outerRadius * cos(angle),
            y: badgeCY + outerRadius * sin(angle)
        )

        let p1 = CGPoint(
            x: innerPt.x + halfW * cos(perpAngle),
            y: innerPt.y + halfW * sin(perpAngle)
        )
        let p2 = CGPoint(
            x: outerPt.x + halfW * cos(perpAngle),
            y: outerPt.y + halfW * sin(perpAngle)
        )
        let p3 = CGPoint(
            x: outerPt.x - halfW * cos(perpAngle),
            y: outerPt.y - halfW * sin(perpAngle)
        )
        let p4 = CGPoint(
            x: innerPt.x - halfW * cos(perpAngle),
            y: innerPt.y - halfW * sin(perpAngle)
        )

        asteriskPath.move(to: p1)
        asteriskPath.line(to: p2)
        asteriskPath.line(to: p3)
        asteriskPath.line(to: p4)
        asteriskPath.close()
    }
    asteriskPath.fill()

    // Small filled center circle
    let centerCircle = NSBezierPath(
        ovalIn: CGRect(
            x: badgeCX - innerRadius,
            y: badgeCY - innerRadius,
            width:  innerRadius * 2,
            height: innerRadius * 2
        )
    )
    centerCircle.fill()

    NSGraphicsContext.restoreGraphicsState()

    return bitmapRep
}

for (size, filename) in sizes {
    let rep = generateIcon(size: size)
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        print("ERROR: Could not create PNG data for \(filename)")
        exit(1)
    }
    let outPath = "\(outputDir)/\(filename)"
    do {
        try pngData.write(to: URL(fileURLWithPath: outPath))
        print("Wrote \(outPath)  (\(size)×\(size)px)")
    } catch {
        print("ERROR writing \(outPath): \(error)")
        exit(1)
    }
}

print("Done — all icon files generated.")
