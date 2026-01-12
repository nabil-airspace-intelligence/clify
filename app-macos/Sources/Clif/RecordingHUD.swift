import Cocoa

/// Small floating HUD shown during recording
final class RecordingHUD {
    private var window: NSWindow?
    private var timerLabel: NSTextField?
    private var displayTimer: Timer?
    private var startTime: Date?
    private var globalEscMonitor: Any?
    private var localEscMonitor: Any?

    var onStopRequested: (() -> Void)?

    func show() {
        guard window == nil else { return }

        startTime = Date()

        // Create window
        let hudWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 50),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        hudWindow.level = .floating
        hudWindow.isOpaque = false
        hudWindow.backgroundColor = .clear
        hudWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
        hudWindow.isMovableByWindowBackground = true

        // Create content view
        let contentView = NSView(frame: hudWindow.contentRect(forFrameRect: hudWindow.frame))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        contentView.layer?.cornerRadius = 10

        // Recording indicator (red dot)
        let indicator = NSView(frame: NSRect(x: 12, y: 18, width: 12, height: 12))
        indicator.wantsLayer = true
        indicator.layer?.backgroundColor = NSColor.systemRed.cgColor
        indicator.layer?.cornerRadius = 6
        contentView.addSubview(indicator)

        // Pulse animation for indicator
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.4
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        indicator.layer?.add(pulse, forKey: "pulse")

        // Timer label
        let label = NSTextField(labelWithString: "0:00")
        label.frame = NSRect(x: 30, y: 15, width: 60, height: 20)
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        label.textColor = .white
        label.alignment = .left
        contentView.addSubview(label)
        timerLabel = label

        // Esc hint
        let hint = NSTextField(labelWithString: "Esc to stop")
        hint.frame = NSRect(x: 90, y: 17, width: 65, height: 14)
        hint.font = NSFont.systemFont(ofSize: 10)
        hint.textColor = NSColor.white.withAlphaComponent(0.6)
        contentView.addSubview(hint)

        hudWindow.contentView = contentView

        // Position at top-right of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - hudWindow.frame.width - 20
            let y = screenFrame.maxY - hudWindow.frame.height - 20
            hudWindow.setFrameOrigin(NSPoint(x: x, y: y))
        }

        hudWindow.orderFront(nil)
        window = hudWindow

        // Start timer updates
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }

        // Monitor for Esc key - need both global (other apps) and local (our windows)
        globalEscMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc
                self?.onStopRequested?()
            }
        }

        localEscMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc
                self?.onStopRequested?()
                return nil // Consume the event
            }
            return event
        }

        Log.info("Recording HUD shown", subsystem: .capture)
    }

    func hide() {
        displayTimer?.invalidate()
        displayTimer = nil

        if let monitor = globalEscMonitor {
            NSEvent.removeMonitor(monitor)
            globalEscMonitor = nil
        }

        if let monitor = localEscMonitor {
            NSEvent.removeMonitor(monitor)
            localEscMonitor = nil
        }

        window?.orderOut(nil)
        window = nil
        timerLabel = nil
        startTime = nil

        Log.info("Recording HUD hidden", subsystem: .capture)
    }

    private func updateTimer() {
        guard let start = startTime else { return }

        let elapsed = Date().timeIntervalSince(start)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60

        timerLabel?.stringValue = String(format: "%d:%02d", minutes, seconds)
    }
}
