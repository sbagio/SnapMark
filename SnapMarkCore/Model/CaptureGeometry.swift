import CoreGraphics

/// Pure geometry for translating a selection between coordinate spaces.
/// No ScreenCaptureKit / Carbon dependency, so it lives in Core and is tested.
public enum CaptureGeometry {

    /// The point-space rect within a display, converting `screenRect` from
    /// AppKit screen coordinates (Y-up) to display-local coordinates (Y-down,
    /// origin at the display's top-left). `screenFrame` is the display's frame
    /// in the same AppKit space.
    ///
    /// This is the single source of truth for the capture coordinate flip —
    /// both live-region capture (`SCStreamConfiguration.sourceRect`) and
    /// frozen-bitmap cropping build on it, so they can't drift apart.
    public static func localRect(
        for screenRect: CGRect,
        screenFrame: CGRect
    ) -> CGRect {
        CGRect(
            x: screenRect.origin.x - screenFrame.origin.x,
            y: screenFrame.maxY - screenRect.maxY,
            width: screenRect.width,
            height: screenRect.height
        )
    }

    /// The pixel rect (top-left origin, Y-down) within a full-screen bitmap
    /// captured at `backingScale` that corresponds to `screenRect`.
    public static func pixelRect(
        for screenRect: CGRect,
        screenFrame: CGRect,
        backingScale: CGFloat
    ) -> CGRect {
        let local = localRect(for: screenRect, screenFrame: screenFrame)
        return CGRect(
            x: local.origin.x * backingScale,
            y: local.origin.y * backingScale,
            width: local.width * backingScale,
            height: local.height * backingScale
        )
    }

    /// Crops a frozen full-screen bitmap to a selection expressed in AppKit
    /// screen coordinates (Y-up). `image` must be the capture of `screenFrame`
    /// at `backingScale`. Returns nil if the region falls outside the image.
    public static func crop(
        _ image: CGImage,
        to screenRect: CGRect,
        screenFrame: CGRect,
        backingScale: CGFloat
    ) -> CGImage? {
        image.cropping(to: pixelRect(
            for: screenRect,
            screenFrame: screenFrame,
            backingScale: backingScale
        ))
    }
}
