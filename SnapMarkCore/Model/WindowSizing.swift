import CoreGraphics

/// Pure window-sizing logic extracted so it can be unit tested
/// independently of AppKit windows.
public enum WindowSizing {

    public static let minWidth:  CGFloat = 420
    public static let minHeight: CGFloat = 200
    /// Captures narrower than this use the compact (dropdown) toolbar.
    public static let compactThreshold: CGFloat = 650
    /// Height of the editor's action toolbar, in points.
    public static let toolbarHeight: CGFloat = 44
    /// Editor window is capped at this fraction of the visible screen.
    public static let screenFitFactor: CGFloat = 0.95

    /// Compute the editor window size for a given capture rect and screen.
    public static func compute(
        captureSize: CGSize,
        screenFrame: CGRect,
        toolbarHeight: CGFloat = WindowSizing.toolbarHeight
    ) -> CGSize {
        let maxW = screenFrame.width  * screenFitFactor
        let maxH = screenFrame.height * screenFitFactor - toolbarHeight
        let scale = min(1.0, min(maxW / captureSize.width, maxH / captureSize.height))
        let w = max(minWidth,  (captureSize.width  * scale).rounded())
        let h = max(minHeight, (captureSize.height * scale + toolbarHeight).rounded())
        return CGSize(width: w, height: h)
    }

    public static func isCompact(captureWidth: CGFloat) -> Bool {
        captureWidth < compactThreshold
    }
}
