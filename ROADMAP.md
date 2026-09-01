# SnapMark Roadmap

Derived from a feature-by-feature review of the native macOS screenshot stack — `screencapture`
flags verified on macOS 26.6.2, plus the ⌘⇧5 Screenshot UI and Markup toolbar. Ranked by value to
SnapMark, not by how macOS groups things.

**The short version:** SnapMark covers the one path that matters — region capture, annotate, copy or
save — and beats the native tool on freeze-frame, history and copy-and-save. The gaps that hurt are
not exotic features; they are the small selection habits carried over from ⌘⇧4, and the absence of
anything to hide sensitive content.

## Legend

| | Type | | Status | | Size |
|---|---|---|---|---|---|
| 🎯 | Capture — what gets grabbed | ✅ | Shipped | `S` | Contained change, one file |
| ✂️ | Selection — the marquee interaction | 🔍 | In review | `M` | A few files, new UI |
| ✏️ | Annotate — the editor | 🟠 | Partial | `L` | New subsystem |
| 📤 | Output — where it ends up | ⬜ | Planned | | |
| | | ⛔ | Won't do | | |

---

## 🔥 Now — build these next

Daily-use interactions where the gap is felt on almost every capture, or where muscle memory from
the native tool actively fights SnapMark. All are contained changes to code that already exists.

| # | Feature | Type | Status | Size | Description |
|---|---------|------|--------|------|-------------|
| 1 | Reposition selection mid-drag | ✂️ | ⬜ | `S` | Hold <kbd>Space</kbd> while dragging to move the marquee instead of resizing it. The most-missed native habit — today a mis-started selection means release and redraw. Lives entirely in `SelectionOverlayView`. |
| 2 | Window / menu capture mode | 🎯 | ⬜ | `M` | Press <kbd>Space</kbd> to switch from marquee to window picking, then click a window to capture it exactly. SnapMark already enumerates windows via `SCShareableContent`. |
| 3 | Redact / blur region | ✏️ | ⬜ | `M` | Draw a box to permanently obscure content before sharing. Native pushes you to Preview for this, so a first-class tool is an outright win — and it is the one you keep needing for finance and ticket screenshots. |
| 4 | Constrain & centre the marquee | ✂️ | ⬜ | `S` | <kbd>⇧</kbd> locks to one axis, <kbd>⌥</kbd> resizes from the centre. Same file as #1 — ship them together. |
| 5 | Crop after capture | ✏️ | ⬜ | `M` | Trim the image in the editor, removing the cancel-and-recapture loop when the selection was slightly off. |
| 6 | Redo | ✏️ | ⬜ | `S` | <kbd>⌘⇧Z</kbd> to reapply an undone annotation. Undo already runs on a real `UndoManager`, so this is close to free and its absence is conspicuous. |
| 7 | Reuse last selection | ✂️ | ⬜ | `S` | Recall the previous marquee rect for repeat captures of the same panel — which is most documentation work. |
| 8 | Configurable save folder | 📤 | 🟠 | `S` | Currently hard-coded to `~/Screenshots`. `saveToDisk` already takes an injectable directory; only the preference UI is missing. |

## 📋 Next — worth having

Real gaps, but either less frequent or more work per unit of benefit. Sensible once **Now** lands.

| # | Feature | Type | Status | Size | Description |
|---|---------|------|--------|------|-------------|
| 9 | Full-screen capture | 🎯 | ⬜ | `S` | A second hotkey that skips selection entirely. Trivial — the freeze already grabs the whole display. |
| 10 | Drag result into another app | 📤 | ⬜ | `M` | Drag from the editor straight into Slack or Jira, bypassing clipboard and disk. Native's floating-thumbnail trick, done better. |
| 11 | Line & ellipse shapes | ✏️ | 🟠 | `S` | Arrow, rectangle, text and highlight exist. Ellipse and plain line are the two most-reached-for additions. |
| 12 | Timer delay | 🎯 | ⬜ | `S` | Capture after 5s/10s. Largely obviated by freeze-frame for transient UI — which is why it is not in **Now** — but still useful for staged states. |
| 13 | Include cursor in capture | 🎯 | ⬜ | `S` | Show the pointer in the image for click-path documentation. `SCStreamConfiguration.showsCursor` is a one-line toggle. |
| 14 | Text styling | ✏️ | 🟠 | `S` | One hard-coded 16pt semibold. Size control is the meaningful half; font and alignment are optional. |
| 15 | Freehand draw | ✏️ | ⬜ | `M` | Pen tool for circling and scribbling. Native layers shape-recognition on top; plain freehand covers most use. |
| 16 | Selection across displays | 🎯 | 🟠 | `L` | Deliberately clamped to the cursor's screen. A real constraint on wide multi-monitor setups, but the coordinate work is non-trivial. |
| 17 | Output format choice | 📤 | 🟠 | `S` | PNG only. PNG is the right default; JPEG matters only when an upload has a size limit. |

## 🗄️ Later & won't do

Present in the native stack but outside what SnapMark is for, tied to obsolete hardware, or served
well enough by the OS that duplicating them buys nothing.

| # | Feature | Type | Status | Size | Description |
|---|---------|------|--------|------|-------------|
| 18 | Screen recording | 🎯 | ⛔ | `L` | A different product. Video, audio routing, encoding and file management dwarf the current codebase. |
| 19 | Recording audio & click display | 🎯 | ⛔ | `M` | Follows recording; irrelevant without it. |
| 20 | Open in Preview / Mail / app | 📤 | ⛔ | `S` | Copy-and-save already covers the handoff. Drag-out (#10) is the better version of this. |
| 21 | Live Text / OCR | ✏️ | ⛔ | `M` | The OS already does this on the saved file; duplicating it adds little. |
| 22 | Signature, magnifier, polygon, star, speech bubble | ✏️ | ⛔ | `M` | Document-markup heritage, not screenshot annotation. Would dilute a deliberately tight toolbar. |
| 23 | Window shadow control | 🎯 | ⬜ | `S` | Include or drop the drop-shadow. Only meaningful once window capture (#2) exists — bundle it there. |
| 24 | HDR capture | 📤 | ⬜ | `M` | Needs HDR content, an HDR display, and a viewer that honours it. Narrow. |
| 25 | Touch Bar capture | 🎯 | ⛔ | `S` | Discontinued hardware. |
| 26 | Command-line interface | 📤 | ⬜ | `M` | Scriptable rect/window/display capture. `screencapture` already serves this well. |

## ✅ Shipped

What SnapMark already does. The first five have no native equivalent — they are the reasons to reach
for SnapMark over ⌘⇧4 at all, and are worth protecting in any redesign.

| Feature | Type | Status | Description |
|---------|------|--------|-------------|
| Freeze-frame capture | 🎯 | 🔍 | The screen is grabbed the instant the hotkey fires, so open dropdowns, menus and live shares survive into the image. No native equivalent. *(PR #1)* |
| Copy **and** save in one action | 📤 | ✅ | <kbd>⌘↩</kbd> does both. Native forces the choice up front — clipboard or file, never both. |
| Capture history | 📤 | ✅ | The last 10 captures reopen straight into the editor from the menu bar. Native has no history; you go hunting in Finder. |
| Annotation without a detour | ✏️ | ✅ | The editor opens immediately on capture — no floating thumbnail to catch before it expires. |
| Live coordinates during selection | ✂️ | ✅ | Full-screen crosshair with a running X, Y readout alongside W × H. Native shows dimensions only. |
| Region capture | 🎯 | ✅ | <kbd>⌘⇧2</kbd> drag-to-select, with <kbd>Esc</kbd> to cancel. |
| Arrow, rectangle, text, highlight | ✏️ | ✅ | Four annotation tools, 8-colour palette, three stroke widths. |
| Undo | ✏️ | ✅ | <kbd>⌘Z</kbd>, backed by a real `UndoManager`. |
| Retina-resolution export | 📤 | ✅ | Exports at the display's native backing scale, not downscaled to 1x. |
| Multi-display dimming | 🎯 | ✅ | All screens dim during selection; capture targets the cursor's display. |
| Silent capture, correct DPI | 📤 | ✅ | No shutter sound, and PNGs carry the right scale metadata. |

---

## Sequencing note

Ship **#1 and #4 together** — they are the same file and the same muscle memory. **#2** unlocks
**#23**. **#3** and **#5** both add a region-select interaction to the editor canvas, so whichever
goes first makes the second cheaper.

Explicitly not worth it: screen recording and the Markup document tools. Together they would cost
more than everything in **Now** and **Next** combined, and pull SnapMark away from being a fast
annotate-and-paste tool.
