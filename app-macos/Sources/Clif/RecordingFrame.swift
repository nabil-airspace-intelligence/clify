import Cocoa

/// Shows a border around the region being recorded
final class RecordingFrame {
    private var window: NSWindow?

    func show(around rect: CGRect, on screen: NSScreen) {
        guard window == nil else { return }

        // Convert CGRect (top-left origin) to NSRect (bottom-left origin)
        let flippedY = screen.frame.maxY - rect.origin.y - rect.height
        let nsRect = NSRect(x: rect.origin.x, y: flippedY, width: rect.width, height: rect.height)

        // Expand slightly for the border
        let borderWidth: CGFloat = 3
        let frameRect = nsRect.insetBy(dx: -borderWidth, dy: -borderWidth)

        let frameWindow = NSWindow(
            contentRect: frameRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        frameWindow.level = .screenSaver
        frameWindow.isOpaque = false
        frameWindow.backgroundColor = .clear
        frameWindow.ignoresMouseEvents = true
        frameWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let frameView = RecordingFrameView(frame: NSRect(origin: .zero, size: frameRect.size))
        frameWindow.contentView = frameView

        frameWindow.orderFront(nil)
        window = frameWindow
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
    }
}

/// View that draws just a border
private final class RecordingFrameView: NSView {
    private let borderColor = NSColor.systemRed
    private let borderWidth: CGFloat = 3

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let path = NSBezierPath(rect: bounds.insetBy(dx: borderWidth / 2, dy: borderWidth / 2))
        path.lineWidth = borderWidth

        borderColor.setStroke()
        path.stroke()
    }
}
