# SnapMark

A lightweight native macOS screenshot annotation tool that lives in your menu bar.

**Cmd+Shift+2** → select a region → annotate → copy or save.

## Features

- **Instant capture** — global hotkey dims the screen, crosshair lets you drag a region
- **Annotation tools** — Arrow, Rectangle, Text, Highlight
- **8-color palette** + 3 stroke thickness levels (persisted across sessions)
- **Undo** (Cmd+Z)
- **Export** — Cmd+C to copy, Cmd+S to save, Cmd+Return for both
- **Escape** to cancel at any point — during region selection or annotation
- No Electron, no subscription, no telemetry — pure AppKit

## Requirements

- macOS 13 Ventura or later
- Xcode Command Line Tools (`xcode-select --install`)
- Screen Recording permission (prompted on first use)

## Install from source

```bash
git clone https://github.com/sbagio/SnapMark.git
cd SnapMark
make setup     # one-time: creates a self-signed "SnapMark Dev" signing cert
make install   # builds and copies SnapMark.app to /Applications
```

Then open **System Settings → Privacy & Security → Screen Recording** and enable SnapMark. Restart the app once after granting permission.

From then on, **Cmd+Shift+2** from anywhere triggers a capture.

## Build targets

| Command | What it does |
|---|---|
| `make build` | Release build (no install) |
| `make install` | Build + copy to /Applications |
| `make run` | Build + install + launch |
| `make clean` | Remove build artifacts |
| `make uninstall` | Remove from /Applications |

## Architecture

- Pure AppKit — no SwiftUI, no Electron
- SwiftPM for the build system, no Xcode required
- No external Swift dependencies
- Self-signed cert for stable Screen Recording TCC identity across rebuilds

## License

MIT
