# Clify

<p align="center">
  <img src="clify.png" width="128" height="128" alt="Clify icon">
</p>

<p align="center">
  <strong>Screenshots, but they're GIFs.</strong>
</p>

Clify is a lightweight macOS menu bar app for creating instant screen recording GIFs. Press a hotkey, select a region, record, and the GIF is automatically copied to your clipboard — ready to paste into Slack, GitHub, docs, or anywhere else.

## Usage

1. **Press `⌃⇧⌘C`** (Control + Shift + Command + C)
2. **Drag to select** the region you want to record
3. **Record** — a red border shows the recording area
4. **Press `Esc`** to stop
5. **Paste anywhere** — the GIF is in your clipboard

### Menu Bar

Click the Clify icon in your menu bar for:
- **New clif...** — start a new recording
- **Open Library** — view all your saved clifs
- **Open in Finder** — browse the clif files directly
- **Copy last clif** (`⌃⌥⌘C`) — re-copy the most recent clif

### Where are clifs saved?

```
~/Library/Application Support/Clify/clifs/YYYY/MM/
```

Each clif includes:
- `.gif` — the animated GIF (copied to clipboard)
- `.mp4` — high-quality source video (optional)
- `.json` — metadata (duration, dimensions, etc.)

## Installation

### From Release

1. Download `Clify.zip` from [Releases](https://github.com/nabil-airspace-intelligence/clify/releases)
2. Unzip and drag `Clify.app` to Applications
3. Right-click → "Open" on first launch (to bypass Gatekeeper)
4. Grant **Accessibility** and **Screen Recording** permissions when prompted

### Build from Source

Requires macOS 13+ and Xcode Command Line Tools.

```bash
# Clone the repo
git clone https://github.com/nabil-airspace-intelligence/clify.git
cd clify

# Build
./tools/build.sh

# Run
open build/Clify.app
```

**Note:** You'll need `gifski` installed for GIF encoding:
```bash
brew install gifski
```

## Requirements

- macOS 13.0 or later
- Accessibility permission (for global hotkey)
- Screen Recording permission (for capture)

## Future Items

- [ ] First-launch permissions wizard
- [ ] Preferences window (hotkey customization, output settings)
- [ ] Trim/edit before saving
- [ ] Adjustable FPS and quality settings
- [ ] Max recording duration setting
- [ ] Quick preview before copying

## License

MIT
