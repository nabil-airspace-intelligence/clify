# Clify Development Learnings

Lessons learned during M0-M1 development.

## macOS Permissions

### Accessibility Permission
- `AXIsProcessTrusted()` checks if app has Accessibility permission
- Permission is cached by **code signature + bundle identifier**
- Ad-hoc signing (`codesign --force --deep --sign -`) preserves permission across rebuilds
- When running from Terminal, child processes inherit Terminal's accessibility trust
- For fresh permission testing, change bundle identifier or use `tccutil reset Accessibility`

### Permission Flow
- Check permission on app launch before registering global hotkeys
- Show alert with "Open System Settings" button linking to `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`

## Global Hotkeys (MASShortcut)

### Package Setup
- Use `https://github.com/cocoabits/MASShortcut.git` (not shpakovski)
- Requires `branch: "master"` in Package.swift (versioned tags don't have Package.swift)

### Registration
- Use `MASShortcutMonitor.shared()` directly for global hotkeys
- `MASShortcutBinder` is for UI integration with UserDefaults - doesn't work well for programmatic registration
- Key codes from `Carbon.HIToolbox` (e.g., `kVK_ANSI_G`)

```swift
let shortcut = MASShortcut(
    keyCode: Int(kVK_ANSI_G),
    modifierFlags: [.control, .option, .command]
)
MASShortcutMonitor.shared()?.register(shortcut, withAction: { ... })
```

## Overlay Windows

### Borderless Key Windows
- Standard `NSWindow` with `.borderless` style cannot become key by default
- Subclass NSWindow and override `canBecomeKey` and `canBecomeMain`:

```swift
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
```

### First Click Handling
- Borderless windows eat the first click to activate
- Override `acceptsFirstMouse(for:)` to receive clicks immediately:

```swift
override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
```

### Window Setup for Overlays
```swift
window.level = .screenSaver
window.isOpaque = false
window.backgroundColor = .clear
window.ignoresMouseEvents = false
window.acceptsMouseMovedEvents = true
window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
window.makeKeyAndOrderFront(nil)
window.makeFirstResponder(view)
```

## Custom Cursors

### What Doesn't Work
- `addCursorRect` in `resetCursorRects()` - unreliable for overlay windows
- `NSCursor.push()`/`pop()` - cursor reverts immediately

### What Works
Use tracking areas with `cursorUpdate`:

```swift
override func updateTrackingAreas() {
    super.updateTrackingAreas()
    for area in trackingAreas {
        removeTrackingArea(area)
    }
    let area = NSTrackingArea(
        rect: bounds,
        options: [.activeAlways, .mouseMoved, .cursorUpdate],
        owner: self,
        userInfo: nil
    )
    addTrackingArea(area)
}

override func cursorUpdate(with event: NSEvent) {
    NSCursor.crosshair.set()
}
```

## Coordinate Systems

### Screen Coordinates
- NSView/NSWindow use bottom-left origin (y increases upward)
- CGRect/ScreenCaptureKit use top-left origin (y increases downward)
- Convert with: `flippedY = screen.frame.maxY - rect.maxY`

### View to Screen Conversion
```swift
let windowRect = convert(rect, to: nil)
let screenRect = window.convertToScreen(windowRect)
let flippedY = screen.frame.maxY - screenRect.maxY
```

## SwiftUI Menu Bar Apps

### Settings Window (macOS 13+)
- `SettingsLink` requires macOS 14+
- For macOS 13 compatibility, use:

```swift
if #available(macOS 14.0, *) {
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
} else {
    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
}
```

## Logging

### os.log vs print
- `os.log` (via `Logger`) goes to system log, not visible in terminal
- Use `print()` for terminal debugging during development
- `Log.info()` wrapper for structured logging by subsystem

## Build System

### App Bundle from SPM
- SPM builds executable, need script to create .app bundle
- Copy executable to `Clif.app/Contents/MacOS/`
- Copy Info.plist to `Clif.app/Contents/`
- Ad-hoc sign to preserve permissions: `codesign --force --deep --sign - "$APP_BUNDLE"`
