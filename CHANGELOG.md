# Changelog

All notable changes to SnapMark are documented in this file.

## [1.2.1] - 2026-09-16

### Fixed
- ⌘C (and ⌘S / ⌘↩) did nothing immediately after a capture on macOS 27; the editor
  window appeared but never took keyboard focus, so the shortcut went to whatever
  app was still frontmost and the Copy button had to be clicked instead.
  SnapMark dropped back to `.accessory` when the selection overlay closed and only
  then opened the editor — and macOS 27 refuses an activation request from an
  `.accessory` app. Activation policy is now owned in one place and stays
  `.regular` for as long as SnapMark has a window on screen.
- `swift build` failed after the macOS 27 upgrade: SwiftPM tried to run `actool`
  over the app bundle's asset catalog. Those resources are assembled by
  `scripts/build-app.sh`, so they are now excluded from the SwiftPM target.

### Changed
- Logging moved from `NSLog` to `os.Logger` (`Log.capture` / `Log.storage`,
  subsystem `com.snapmark.app`). On macOS 27 `NSLog` reaches only stderr, which is
  nowhere for an app launched from Finder, so every error path — failed saves,
  failed crops, denied permissions — was silent in practice.
- Replaced the deprecated `activate(ignoringOtherApps:)` with `NSApp.activate()`.

## [1.2.0] - 2026-09-01

### Added
- Configurable save folder. **Default Save Folder…** in the menu-bar glyph menu opens a
  folder picker; screenshots are written there instead of `~/Screenshots`. A
  **Reset Save Folder to Default** item appears once a custom folder is set.
  The default is used when nothing is chosen, and also when a previously chosen
  folder has been moved or deleted — a save never fails because of a stale setting.
- `ROADMAP.md`: feature backlog ranked against the native macOS screenshot stack.

## [1.1.0] - 2026-07-07

### Added
- Freeze-frame capture: ⌘⇧2 now grabs the screen the instant the hotkey fires,
  before the selection overlay appears, and crops the selection from that frozen
  bitmap. Transient UI that would otherwise vanish — open dropdowns/menus, a live
  screen share mid-frame — is preserved in the capture even though the live UI
  changes once the overlay takes focus.
- `CaptureGeometry` in SnapMarkCore: unit-tested crop geometry (AppKit Y-up →
  display-local Y-down + Retina scaling) shared by the capture pipeline.

### Changed
- Permission handling no longer preflights `CGPreflightScreenCaptureAccess` — that
  flag reads stale after each re-sign and falsely prompted when rights were fine.
  Capture is attempted directly and the alert (with a Settings deep link) shows
  only on a genuine failure.

## [1.0.2] - 2026-05-11

### Fixed
- Exported/clipboard images now use full Retina resolution instead of being
  downscaled to 1x. On 2x displays, exported PNGs are now twice the resolution.
- History items opened in editor at correct logical size instead of 2x pixel
  dimensions on Retina displays.
- HistoryStore no longer silently swallows save failures — errors are logged.
- Capture and save failures now show user-facing alert dialogs instead of
  failing silently.

### Changed
- Consolidated duplicate export logic in AnnotationViewController.
- Replaced force-unwrap on application support directory with safe fallback.

## [1.0.1] - 2026-05-11

### Fixed
- Screenshot capture offset on non-primary displays. On multi-monitor setups where
  displays have different heights (e.g. MacBook 16" + external 1080p), captures were
  shifted upward due to a coordinate system mismatch between SCDisplay.frame (CG coords)
  and NSScreen.frame (AppKit coords).
- Replaced full-display capture + manual crop with SCStreamConfiguration.sourceRect
  for simpler, more reliable region capture.
- Use actual NSScreen.backingScaleFactor instead of hardcoded 2x multiplier.

## [1.0.0] - 2026-04-10

### Added
- Initial release of SnapMark.
- Global hotkey (Cmd+Shift+2) for screen region capture.
- Annotation tools: arrow, rectangle, highlight, text.
- Copy to clipboard (Cmd+C), save to disk (Cmd+S), or both (Cmd+Return).
- Capture history in the menu bar.
- Multi-display support with per-screen dimming overlay.

### Fixed
- Double-click required to start selection on external displays.
- History menu: inline items, filename display, extension-safe truncation.
- generate-icon.swift: use relative path instead of hardcoded absolute path.
