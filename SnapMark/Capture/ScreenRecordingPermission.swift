import AppKit

/// Screen-recording permission helper.
///
/// Deliberately exposes NO preflight/request call: `CGPreflightScreenCaptureAccess`
/// reads stale after every re-sign and would falsely nag when rights are fine.
/// We rely on the actual capture attempt to surface a genuine denial, and only
/// use this to deep-link the user to the right settings pane afterward.
enum ScreenRecordingPermission {

    /// Deep-links directly to the Screen Recording pane so the user doesn't
    /// have to hunt through System Settings.
    static func openSystemSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
