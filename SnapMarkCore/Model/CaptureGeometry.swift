import CoreGraphics

/// Pure geometry for translating a selection between coordinate spaces.
/// No ScreenCaptureKit / Carbon dependency, so it lives in Core and is tested.
public enum CaptureGeometry {

    /// The pixel rect (top-left origin, Y-down) within a full-screen bitmap
    /// that corresponds to `screenRect` given in AppKit screen coordinates
    /// (Y-up). `screenFrame` is the captured screen's frame in the same AppKit
    /// space; `backingScale` is its `backingScaleFactor`.
    ///
    /// This mirrors the `sourceRect` math used when capturing a live region,
    /// so a frozen-bitmap crop lands on exactly the same pixels.
    public static func pixelRect(
        for screenRect: CGRect,
        screenFrame: CGRect,
        backingScale: CGFloat
    ) -> CGRect {
        let localX = screenRect.origin.x - screenFrame.origin.x
        let localY = screenFrame.maxY - screenRect.maxY
        return CGRect(
            x: localX * backingScale,
            y: localY * backingScale,
            width: screenRect.width * backingScale,
            height: screenRect.height * backingScale
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
