import Cocoa

protocol RegionSelectionViewDelegate: AnyObject {
    func regionSelectionView(_ view: RegionSelectionView, didSelectRect rect: CGRect)
    func regionSelectionViewDidCancel(_ view: RegionSelectionView)
}

final class RegionSelectionView: NSView {
    weak var delegate: RegionSelectionViewDelegate?
    var displayID: CGDirectDisplayID = 0

    private var selectionStart: NSPoint?
    private var selectionRect: NSRect?
    private var isSelecting = false

    private let dimColor = NSColor.black.withAlphaComponent(0.3)
    private let selectionBorderColor = NSColor.white
    private let selectionFillColor = NSColor.white.withAlphaComponent(0.1)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
    }

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

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw dim overlay
        dimColor.setFill()
        bounds.fill()

        // If we have a selection, cut it out and draw border
        if let selection = selectionRect {
            // Clear the selection area (show through to screen)
            NSColor.clear.setFill()
            selection.fill(using: .copy)

            // Draw selection border
            selectionBorderColor.setStroke()
            let borderPath = NSBezierPath(rect: selection)
            borderPath.lineWidth = 2
            borderPath.stroke()

            // Draw subtle fill
            selectionFillColor.setFill()
            selection.fill()

            // Draw size indicator
            drawSizeIndicator(for: selection)
        }
    }

    private func drawSizeIndicator(for rect: NSRect) {
        let width = Int(rect.width)
        let height = Int(rect.height)
        let text = "\(width) × \(height)"

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7)
        ]

        let size = text.size(withAttributes: attributes)
        let padding: CGFloat = 4

        // Position below selection, or above if not enough room
        var labelOrigin = NSPoint(
            x: rect.midX - size.width / 2 - padding,
            y: rect.minY - size.height - padding * 3
        )

        if labelOrigin.y < 0 {
            labelOrigin.y = rect.maxY + padding
        }

        let labelRect = NSRect(
            x: labelOrigin.x,
            y: labelOrigin.y,
            width: size.width + padding * 2,
            height: size.height + padding
        )

        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 4, yRadius: 4).fill()

        text.draw(
            at: NSPoint(x: labelRect.minX + padding, y: labelRect.minY + padding / 2),
            withAttributes: attributes
        )
    }

    // MARK: - Mouse handling

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        selectionStart = point
        selectionRect = NSRect(origin: point, size: .zero)
        isSelecting = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isSelecting, let start = selectionStart else { return }

        let current = convert(event.locationInWindow, from: nil)

        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let width = abs(current.x - start.x)
        let height = abs(current.y - start.y)

        selectionRect = NSRect(x: x, y: y, width: width, height: height)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isSelecting, let rect = selectionRect else { return }

        isSelecting = false

        // Require minimum selection size
        if rect.width >= 10 && rect.height >= 10 {
            let screenRect = convertToScreenCoordinates(rect)
            delegate?.regionSelectionView(self, didSelectRect: screenRect)
        } else {
            selectionRect = nil
            needsDisplay = true
        }
    }

    private func convertToScreenCoordinates(_ rect: NSRect) -> CGRect {
        guard let window = window else { return rect }

        let windowRect = convert(rect, to: nil)
        let screenRect = window.convertToScreen(windowRect)

        // Flip Y coordinate for CGRect (screen coordinates are flipped)
        guard let screen = window.screen else { return screenRect }
        let flippedY = screen.frame.maxY - screenRect.maxY

        return CGRect(
            x: screenRect.origin.x,
            y: flippedY,
            width: screenRect.width,
            height: screenRect.height
        )
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            delegate?.regionSelectionViewDidCancel(self)
        } else {
            super.keyDown(with: event)
        }
    }
}
