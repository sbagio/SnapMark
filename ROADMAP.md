# SnapMark Roadmap

Derived from a feature-by-feature review of the native macOS screenshot stack — `screencapture`
flags verified on macOS 26.6.2, plus the ⌘⇧5 Screenshot UI and Markup toolbar. Ranked by value to
SnapMark, not by how macOS groups things.

**The short version:** SnapMark covers the one path that matters — region capture, annotate, copy or
save — and beats the native tool on freeze-frame, history and copy-and-save. What remains is
breadth: more ways to start a capture, more ways to get the result out, and a couple more drawing
tools. None of it is load-bearing.

## Legend

| | Type | | Status | | Size |
|---|---|---|---|---|---|
| 🎯 | Capture — what gets grabbed | ✅ | Shipped | `S` | Contained change, one file |
| ✂️ | Selection — the marquee interaction | 🟠 | Partial | `M` | A few files, new UI |
| ✏️ | Annotate — the editor | ⬜ | Planned | `L` | New subsystem |
| 📤 | Output — where it ends up | ⛔ | Won't do | | |

---

## 📋 Next — ranked backlog

| # | Feature | Type | Status | Size | Description |
|---|---------|------|--------|------|-------------|
| 1 | Full-screen capture | 🎯 | ⬜ | `S` | A second hotkey that skips selection entirely. Trivial — the freeze already grabs the whole display. |
| 2 | Drag result into another app | 📤 | ⬜ | `M` | Drag from the editor straight into Slack or Jira, bypassing clipboard and disk. Native's floating-thumbnail trick, done better. |
| 3 | Line & ellipse shapes | ✏️ | 🟠 | `S` | Arrow, rectangle, text and highlight exist. Ellipse and plain line are the two most-reached-for additions. |
| 4 | Timer delay | 🎯 | ⬜ | `S` | Capture after 5s/10s. Largely obviated by freeze-frame for transient UI, but still useful for staged states. |
| 5 | Include cursor in capture | 🎯 | ⬜ | `S` | Show the pointer in the image for click-path documentation. `SCStreamConfiguration.showsCursor` is a one-line toggle. |
| 6 | Text styling | ✏️ | 🟠 | `S` | One hard-coded 16pt semibold. Size control is the meaningful half; font and alignment are optional. |
| 7 | Freehand draw | ✏️ | ⬜ | `M` | Pen tool for circling and scribbling. Native layers shape-recognition on top; plain freehand covers most use. |
| 8 | Selection across displays | 🎯 | 🟠 | `L` | Deliberately clamped to the cursor's screen. A real constraint on wide multi-monitor setups, but the coordinate work is non-trivial. |
| 9 | Output format choice | 📤 | 🟠 | `S` | PNG only. PNG is the right default; JPEG matters only when an upload has a size limit. |

## 🗄️ Later & won't do

Present in the native stack but outside what SnapMark is for, tied to obsolete hardware, or served
well enough by the OS that duplicating them buys nothing.

| # | Feature | Type | Status | Size | Description |
|---|---------|------|--------|------|-------------|
| 10 | Screen recording | 🎯 | ⛔ | `L` | A different product. Video, audio routing, encoding and file management dwarf the current codebase. |
| 11 | Recording audio & click display | 🎯 | ⛔ | `M` | Follows recording; irrelevant without it. |
| 12 | Open in Preview / Mail / app | 📤 | ⛔ | `S` | Copy-and-save already covers the handoff. Drag-out (#2) is the better version of this. |
| 13 | Live Text / OCR | ✏️ | ⛔ | `M` | The OS already does this on the saved file; duplicating it adds little. |
| 14 | Signature, magnifier, polygon, star, speech bubble | ✏️ | ⛔ | `M` | Document-markup heritage, not screenshot annotation. Would dilute a deliberately tight toolbar. |
| 15 | Window shadow control | 🎯 | ⛔ | `S` | Only meaningful alongside a window-capture mode, which is not planned. |
| 16 | HDR capture | 📤 | ⬜ | `M` | Needs HDR content, an HDR display, and a viewer that honours it. Narrow. |
| 17 | Touch Bar capture | 🎯 | ⛔ | `S` | Discontinued hardware. |
| 18 | Command-line interface | 📤 | ⬜ | `M` | Scriptable rect/window/display capture. `screencapture` already serves this well. |

## ✅ Shipped

The first five have no native equivalent — they are the reasons to reach for SnapMark over ⌘⇧4 at
all, and are worth protecting in any redesign.

| Feature | Type | Status | Description |
|---------|------|--------|-------------|
| Freeze-frame capture | 🎯 | ✅ | The screen is grabbed the instant the hotkey fires, so open dropdowns, menus and live shares survive into the image. No native equivalent. |
| Copy **and** save in one action | 📤 | ✅ | <kbd>⌘↩</kbd> does both. Native forces the choice up front — clipboard or file, never both. |
| Capture history | 📤 | ✅ | The last 10 captures reopen straight into the editor from the menu bar. Native has no history; you go hunting in Finder. |
| Annotation without a detour | ✏️ | ✅ | The editor opens immediately on capture — no floating thumbnail to catch before it expires. |
| Live coordinates during selection | ✂️ | ✅ | Full-screen crosshair with a running X, Y readout alongside W × H. Native shows dimensions only. |
| Configurable save folder | 📤 | ✅ | **Default Save Folder…** in the menu-bar glyph menu picks where screenshots are written; falls back to `~/Screenshots` if unset or if the folder goes missing. |
| Region capture | 🎯 | ✅ | <kbd>⌘⇧2</kbd> drag-to-select, with <kbd>Esc</kbd> to cancel. |
| Arrow, rectangle, text, highlight | ✏️ | ✅ | Four annotation tools, 8-colour palette, three stroke widths. |
| Undo | ✏️ | ✅ | <kbd>⌘Z</kbd>, backed by a real `UndoManager`. |
| Retina-resolution export | 📤 | ✅ | Exports at the display's native backing scale, not downscaled to 1x. |
| Multi-display dimming | 🎯 | ✅ | All screens dim during selection; capture targets the cursor's display. |
| Silent capture, correct DPI | 📤 | ✅ | No shutter sound, and PNGs carry the right scale metadata. |

---

## Sequencing note

Nothing in the backlog blocks anything else — each item stands alone, which is why it is a flat
ranking rather than a dependency graph. #3, #6 and #7 all touch the annotation toolbar, so batching
them costs less than doing them separately.

Explicitly not worth it: screen recording and the Markup document tools. Together they would cost
more than the entire backlog above, and pull SnapMark away from being a fast annotate-and-paste
tool.
