import os

/// Unified-logging channels for SnapMark.
///
/// NSLog is not a usable channel: on macOS 27 it reaches only stderr, which goes
/// nowhere for an app launched from Finder, so every error path here was silent in
/// practice. os.Logger is retrievable with:
///
///     log show --predicate 'subsystem == "com.snapmark.app"' --last 30m
///
/// Interpolated values are marked `.public` deliberately. os.Logger redacts
/// non-literals as `<private>` by default, which would leave the messages present
/// but useless — the same blindness in a different form. Nothing logged here is
/// sensitive: file paths the user chose, error descriptions, and geometry.
public enum Log {
    private static let subsystem = "com.snapmark.app"

    /// Hotkey registration, screen capture, selection overlay.
    public static let capture = Logger(subsystem: subsystem, category: "capture")
    /// Saving, history, export destinations.
    public static let storage = Logger(subsystem: subsystem, category: "storage")
}
