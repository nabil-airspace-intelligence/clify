# Claude.md

This repo builds a **macOS app** (Swift / SwiftUI) backed by **Rust core libraries** (performance-critical logic, data processing, simulation, etc.).  
Claude should prioritize correctness, maintainability, and clean boundaries between Swift UI + orchestration and Rust core + algorithms.

When you identify working patterns or patterns to avoid - suggest changes back intot his document to keep relevant context fresh across sessions.

!! IMPORTANT GUIDANCE !!

- Be concise! All contributions back to claude.md or other documentation should be extremely concise
- Prefer simple approaches!
- Take small attempts, build core foundational components and then build up from there - don't try to do too much at once!

## Technical Goals

- Native macOS UX (SwiftUI/AppKit where needed)
- Rust for:
  - CPU-heavy computation
  - deterministic state machines / simulation
  - parsing / validation / business rules
  - data structures and performance-sensitive code
- A stable, well-tested **FFI boundary** between Swift and Rust
- Repeatable builds in CI

## Technical Non-goals (unless explicitly requested):

- iOS support
- cross-platform GUI
- shipping a plugin system

# Product spec: “clif” (clipboard GIFs from screen recordings)

### One-liner

Press a hotkey → drag to select region → record → hit Esc to stop → **GIF is in clipboard** + **saved in local library**.

### Target users

People who ship software / write docs / communicate in Slack and want **fast visual snippets** without opening a heavyweight recorder.

### Core goals

- **Fast**: from hotkey to recording in < 300ms.
- **Zero-config**: no onboarding wizard, no “project creation”, no prompts beyond required permissions.
- **Predictable**: Esc always ends and copies.
- **Low-friction library**: auto-saves with timestamps, searchable later (later can be v2).

### Non-goals (v1)

- Audio recording
- Webcam / picture-in-picture
- Cloud sync
- Editing suite (trim is optional; nice-to-have if cheap)
- Complex export settings

---

## UX flow

### Global hotkey flow (primary)

1. User hits hotkey (default: `⌃⌥⌘G`).
2. Screen dims; crosshair cursor appears.
3. User click-drag selects a rectangle.
4. Recording starts immediately (optional: tiny 3..2..1 overlay, but default OFF).
5. Small unobtrusive HUD: timer + “Esc to stop”.
6. User presses Esc.
7. App:

   - Finalizes recording
   - Encodes to GIF
   - Writes GIF to clipboard
   - Saves into library directory
   - Shows toast: “Clif copied to clipboard” + “Open Library” button

### Library access (secondary)

- Menu bar icon (always available)

  - “New Clif…”
  - “Open Library”
  - “Preferences…” (minimal)
  - “Quit”

### Preferences (minimal v1)

- Hotkey picker (required)
- Output framerate: Auto / 10 / 15 / 24 (default Auto -> target ~12–15)
- Max GIF dimensions: Auto / 800 / 1000 / 1200 (default Auto)
- “Also save MP4 alongside GIF” (default ON if you want quality-preserving masters)
- “Copy as GIF” toggle (default ON)

---

## Technical constraints & macOS realities

### Permissions you’ll need

- **Screen Recording** permission (mandatory): user must grant in System Settings → Privacy & Security → Screen Recording.
- **Accessibility** permission (likely): for reliable **global hotkeys** and/or event taps. Some hotkey libraries avoid this, but plan for it.

**Important**: macOS requires the app to handle “permission not granted” gracefully:

- If Screen Recording not allowed: show a single clean dialog with a button to open System Settings to the right pane.

### Recording API choice

On macOS 12.3+ Apple introduced **ScreenCaptureKit** (modern, performant, better than old CGDisplayStream).

- Prefer **ScreenCaptureKit** for capture.
- Encode to **MP4 (H.264)** as an intermediate quickly, then convert to GIF. (Direct-to-GIF in realtime is possible, but harder to keep smooth.)

### GIF encoding reality

GIF is limited + big. The “quality trick” is:

- capture frames → optionally downscale
- palette quantization + dithering
- frame timing optimization

Pragmatic plan:

- Save an MP4 (or a frame stream) first.
- Convert using either:

  - embedded library (Rust) for quantization, or
  - bundle ffmpeg / gifski (very pragmatic, proven quality, but packaging/licensing complexity).

---

## Architecture proposal (Rust-first, sane macOS integration)

### High-level components

1. **App shell (macOS native)**

   - Menu bar app
   - Global hotkey registration
   - Overlay selection UI (region picker)
   - Permission prompts + settings deep links

2. **Capture engine**

   - ScreenCaptureKit session scoped to selected region
   - Produces frame stream or writes to MP4

3. **Transcode pipeline**

   - MP4 → GIF (or frames → GIF)
   - Adaptive settings: cap FPS, downscale, limit duration (optional)

4. **Clipboard**

   - Write GIF bytes to NSPasteboard as `public.gif`

5. **Library**

   - Store files in `~/Library/Application Support/Clif/Clifs/`
   - Maintain index in SQLite or a simple JSONL (v1 can be JSON; SQLite later)

6. **Telemetry/logging**

   - Local only in v1; structured logs for debugging

### UI technology approach

**SwiftUI app + Rust core (recommended)**

- Swift/SwiftUI handles:

  - overlay selection
  - menu bar UI
  - ScreenCaptureKit integration (Swift is easiest here)

- Rust handles:

  - pipeline control
  - GIF encoding (or orchestrating subprocess)
  - file organization, indexing

- Bridge via:

  - `uniffi` (nice) or
  - C FFI

This is the “least suffering” path on macOS.

---

## Data model & storage

### Files

- Directory: `~/Library/Application Support/Clif/Clifs/YYYY/MM/`
- Filenames: `YYYY-MM-DD_HH-mm-ss_<hash>.gif` (+ `.mp4` optional)
- Metadata sidecar: `… .json` (v1) containing:

  - duration_ms
  - fps
  - width/height
  - region (x,y,w,h)
  - created_at
  - source_display_id

### Library index

v1: single `index.jsonl` append-only records
v2: SQLite for search and tagging

---

## Edge cases & acceptance criteria

### Recording behavior

- Esc ends recording **always**, even if overlay loses focus.
- If user hits Esc during region selection, cancel cleanly.
- If permission missing:

  - no crash
  - show explanation + deep-link button

- If GIF encoding fails:

  - fallback: copy MP4 to clipboard? (optional) and show error toast

- If user records > N seconds:

  - v1 default limit: 20s (configurable later)
  - or allow longer but automatically reduce FPS/resolution

### Clipboard acceptance tests

- After stop: clipboard contains a valid GIF (test by pasting into Preview/Slack)
- The saved gif file matches clipboard bytes (or at least identical content)

---

## Milestone plan (what Claude Code should implement)

### Milestone 0 — skeleton & plumbing

- Menu bar app
- Preferences window stub
- Hotkey registration stub
- Logs + local config file

### Milestone 1 — region selection overlay

- Dimming overlay on all displays
- Drag rectangle selection
- Return selected rect in screen coordinates

### Milestone 2 — capture to MP4

- ScreenCaptureKit session recording selected rect
- Stop on Esc
- Output MP4 in temp dir

### Milestone 3 — MP4 → GIF + clipboard

- Convert MP4 to GIF
- Write to clipboard
- Save into library folder
- Toast notification

### Milestone 4 — library viewer (basic)

- “Open Library” opens Finder at directory
- Optional: simple SwiftUI grid view of last N clifs

### Milestone 5 — polish

- Hotkey customization
- Better defaults for FPS/scale based on region size
- Quick “re-copy last clif” menu item

---

## Suggested repo layout

```
clif/
  README.md
  claude.md
  spec/
    PRODUCT.md
    ACCEPTANCE_TESTS.md
  app-macos/                 # SwiftUI shell
    ClifApp/
      Sources/
      Resources/
  core/                      # Rust library
    Cargo.toml
    src/
      lib.rs
      pipeline/
      gif/
      storage/
  tools/                     # build scripts, packaging
```

---

# Clif (macOS) - Claude Code Instructions

You are working in a mono-repo with:

- `app-macos/` (SwiftUI macOS app shell)
- `core/` (Rust library for pipeline/storage/encoding)

## Product goal

Hotkey → select region → record → Esc to stop → GIF in clipboard + saved in library.
Zero-config. Fast. Minimal UI.

## Non-goals (v1)

No audio, no cloud sync, no editor suite.

## Hard requirements

1. Esc always stops recording and copies GIF.
2. Works on macOS 13+.
3. Uses ScreenCaptureKit for capture.
4. Saved clifs stored under:
   `~/Library/Application Support/Clif/Clifs/YYYY/MM/`
5. Clipboard contains `public.gif` pasteboard type after stop.
6. If Screen Recording permission missing:
   show a single dialog explaining and offering deep link to Settings.

## Implementation guidelines

- Prefer simple, boring solutions. Optimize for shipping.
- Build vertical slices: UI → capture → encode → clipboard → storage.
- Keep the Swift layer thin: UI + macOS APIs.
- Keep Rust responsible for: pipeline orchestration, file naming/storage, encoding (or invoking encoder).

## Code quality bar

- No TODOs in shipped paths.
- Add small integration tests where possible (Rust unit tests for storage/indexing).
- Add a manual test checklist in `spec/ACCEPTANCE_TESTS.md`.
- Structured logging in both Swift and Rust (tagged by subsystem).

## Milestones

M0: menu bar + hotkey stub
M1: region picker overlay
M2: record selected region to MP4 using ScreenCaptureKit
M3: convert to GIF, copy to clipboard, save to library
M4: Open Library + recent list
M5: preferences polish

## Definition of done for M3

- User can create a clif end-to-end.
- Pasting into Slack produces an animated GIF.
- The GIF is present in the library folder with metadata JSON.

## Practical build choices (so you don’t get stuck)

### Hotkey library (Swift side)

- Use a known macOS hotkey helper (there are several; pick one you trust).
- If you hit permission issues, fall back to Accessibility prompt.

### Encoding choice (recommended path)

If you want the **fastest path to a high-quality GIF**:

- Record MP4 via ScreenCaptureKit
- Convert using a bundled encoder tool (common approach)
- Later you can replace with pure-Rust if you want

If you want “pure Rust” from day 1:

- You’ll need a good quantizer + GIF encoder pipeline and frame extraction.
- It’s doable, but it’s where projects die.

My blunt advice: **ship with a pragmatic encoder, then optimize**.
