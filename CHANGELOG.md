# Changelog

All notable changes to SnapMark are documented in this file.

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
