import Foundation

/// User-configurable settings, stored in `UserDefaults`.
///
/// SnapMark is not sandboxed, so a plain path round-trips fine — no security-scoped
/// bookmark is needed to keep access to a folder the user picked.
///
/// The `defaults` parameter exists so tests can use a throwaway suite instead of
/// writing to the real domain.
public enum Preferences {

    private static let saveFolderKey = "snapmark.saveFolder"

    /// Where screenshots are written. Falls back to `~/Screenshots` when the user
    /// has never chosen a folder, or when the one they chose no longer exists —
    /// a save should not fail because a folder was moved after it was picked.
    public static func saveFolder(defaults: UserDefaults = .standard) -> URL {
        guard let path = defaults.string(forKey: saveFolderKey) else {
            return ExportService.defaultDirectory()
        }
        let url = URL(fileURLWithPath: path)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return ExportService.defaultDirectory()
        }
        return url
    }

    public static func setSaveFolder(_ url: URL, defaults: UserDefaults = .standard) {
        defaults.set(url.path, forKey: saveFolderKey)
    }

    /// Clears the choice, restoring the `~/Screenshots` default.
    public static func resetSaveFolder(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: saveFolderKey)
    }

    /// True when the user has picked a folder that is still valid — the menu uses
    /// this to decide whether "Reset to Default" is worth offering.
    public static func hasCustomSaveFolder(defaults: UserDefaults = .standard) -> Bool {
        defaults.string(forKey: saveFolderKey) != nil
    }
}
