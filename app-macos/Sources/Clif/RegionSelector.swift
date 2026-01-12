import Cocoa

/// Custom window that can become key even when borderless
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Result of a region selection
struct SelectedRegion {
    let rect: CGRect
    let screenID: CGDirectDisplayID
}

/// Handles the region selection overlay UI
final class RegionSelector {
    static let shared = RegionSelector()

    private var overlayWindows: [OverlayWindow] = []
    private var completion: ((SelectedRegion?) -> Void)?
    private var selectionView: RegionSelectionView?
    private var eventMonitor: Any?

    private init() {}

    /// Start region selection mode
    /// - Parameter completion: Called with the selected region, or nil if cancelled
    func startSelection(completion: @escaping (SelectedRegion?) -> Void) {
        self.completion = completion

        Log.info("Starting region selection", subsystem: .capture)

        // Create overlay windows for all screens
        for screen in NSScreen.screens {
            let window = createOverlayWindow(for: screen)
            overlayWindows.append(window)
        }

        // Set up key monitoring for Esc
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc key
                self?.cancelSelection()
                return nil
            }
            return event
        }
    }

    private func createOverlayWindow(for screen: NSScreen) -> OverlayWindow {
        let window = OverlayWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = RegionSelectionView(frame: screen.frame)
        view.delegate = self
        window.contentView = view

        // Track which screen this view is on
        if let displayID = screen.displayID {
            view.displayID = displayID
        }

        // Make window key to receive events
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)

        // Make first window's view the active selection view
        if selectionView == nil {
            selectionView = view
        }

        return window
    }

    private func cancelSelection() {
        Log.info("Region selection cancelled", subsystem: .capture)
        cleanup()
        completion?(nil)
    }

    private func finishSelection(rect: CGRect, displayID: CGDirectDisplayID) {
        Log.info("Region selected: \(rect) on display \(displayID)", subsystem: .capture)
        let region = SelectedRegion(rect: rect, screenID: displayID)
        let callback = completion
        cleanup()
        callback?(region)
    }

    private func cleanup() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        selectionView = nil
        completion = nil
    }
}

// MARK: - RegionSelectionViewDelegate

extension RegionSelector: RegionSelectionViewDelegate {
    func regionSelectionView(_ view: RegionSelectionView, didSelectRect rect: CGRect) {
        finishSelection(rect: rect, displayID: view.displayID)
    }

    func regionSelectionViewDidCancel(_ view: RegionSelectionView) {
        cancelSelection()
    }
}

// MARK: - NSScreen extension

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(screenNumber.uint32Value)
    }
}
