import Cocoa

/// A brief, non-modal toast notification
final class ToastWindow {
    private var window: NSWindow?
    private var hideTimer: Timer?

    /// Show a success toast
    static func showSuccess(_ message: String, duration: TimeInterval = 2.5) {
        shared.show(message: message, icon: "checkmark.circle.fill", color: .systemGreen, duration: duration)
    }

    /// Show an error toast
    static func showError(_ message: String, duration: TimeInterval = 4.0) {
        shared.show(message: message, icon: "xmark.circle.fill", color: .systemRed, duration: duration)
    }

    private static let shared = ToastWindow()

    private func show(message: String, icon: String, color: NSColor, duration: TimeInterval) {
        // Hide any existing toast
        hide()

        // Create window
        let toast = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 60),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        toast.level = .floating
        toast.isOpaque = false
        toast.backgroundColor = .clear
        toast.collectionBehavior = [.canJoinAllSpaces, .stationary]
        toast.ignoresMouseEvents = true

        // Create content view
        let contentView = NSView(frame: toast.contentRect(forFrameRect: toast.frame))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        contentView.layer?.cornerRadius = 12

        // Icon
        let iconView = NSImageView(frame: NSRect(x: 16, y: 16, width: 28, height: 28))
        if let image = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 24, weight: .medium)
            iconView.image = image.withSymbolConfiguration(config)
            iconView.contentTintColor = color
        }
        contentView.addSubview(iconView)

        // Message label
        let label = NSTextField(labelWithString: message)
        label.frame = NSRect(x: 52, y: 18, width: 212, height: 24)
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.lineBreakMode = .byTruncatingTail
        contentView.addSubview(label)

        toast.contentView = contentView

        // Position at top-center of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - toast.frame.width / 2
            let y = screenFrame.maxY - toast.frame.height - 40
            toast.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Animate in
        toast.alphaValue = 0
        toast.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            toast.animator().alphaValue = 1
        }

        window = toast

        // Auto-hide after duration
        hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    private func hide() {
        hideTimer?.invalidate()
        hideTimer = nil

        guard let toast = window else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            toast.animator().alphaValue = 0
        }, completionHandler: {
            toast.orderOut(nil)
        })

        window = nil
    }
}
