import AppKit

@MainActor final class AreaSelectionController {
    private var panel: NSPanel?
    private var completion: ((Region?) -> Void)?
    func select(displayID: CGDirectDisplayID, language: String, completion: @escaping (Region?) -> Void) {
        guard let screen = NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID }) else { completion(nil); return }
        self.completion = completion
        let panel = SelectionPanel(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        panel.level = .screenSaver; panel.isOpaque = false; panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false; panel.sharingType = .none
        let view = SelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.language = language
        view.finish = { [weak self] region in self?.finish(region) }
        panel.contentView = view
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil); panel.makeFirstResponder(view)
    }
    private func finish(_ region: Region?) {
        panel?.orderOut(nil); panel?.close(); panel = nil
        let callback = completion; completion = nil
        // Let WindowServer remove the overlay before any preview capture.
        Task { try? await Task.sleep(for: .milliseconds(250)); callback?(region) }
    }
}
private final class SelectionPanel: NSPanel { override var canBecomeKey: Bool { true } }
private final class SelectionView: NSView {
    override var acceptsFirstResponder: Bool { true }
    var language = "ru"
    var finish: ((Region?) -> Void)?
    private var rect: CGRect = .zero
    private var anchor: CGPoint = .zero
    private var original: CGRect = .zero
    private var moving = false
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.32).setFill(); bounds.fill()
        if rect.width > 0 {
            NSColor.white.withAlphaComponent(0.10).setFill(); rect.fill()
            NSColor.white.setStroke(); let path = NSBezierPath(rect: rect); path.lineWidth = 2; path.stroke()
            for p in [CGPoint(x:rect.minX,y:rect.minY), CGPoint(x:rect.maxX,y:rect.minY), CGPoint(x:rect.minX,y:rect.maxY), CGPoint(x:rect.maxX,y:rect.maxY)] {
                NSColor.white.setFill(); CGRect(x:p.x-3,y:p.y-3,width:6,height:6).fill()
            }
        }
        let message = rect.width >= 8 ? L10n.format("%ld × %ld pt  ·  Drag inside to move  ·  Drag outside to redraw  ·  Return to confirm  ·  Esc to cancel", Int(rect.width), Int(rect.height), language: language) : L10n.text("Drag to select an area  ·  Esc to cancel", language: language)
        let style: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14, weight: .medium), .foregroundColor: NSColor.white]
        let text = NSAttributedString(string: message, attributes: style)
        let size = text.size()
        text.draw(at: CGPoint(x: max(20,(bounds.width-size.width)/2), y: bounds.height-70))
    }
    override func mouseDown(with event: NSEvent) {
        anchor = convert(event.locationInWindow, from: nil); original = rect; moving = rect.contains(anchor)
        if !moving { rect = CGRect(origin: anchor, size: .zero) }; needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if moving {
            rect.origin = CGPoint(x: min(max(0,original.minX+point.x-anchor.x),bounds.width-rect.width), y: min(max(0,original.minY+point.y-anchor.y),bounds.height-rect.height))
        } else {
            rect = CGRect(x: min(anchor.x,point.x), y: min(anchor.y,point.y), width: abs(point.x-anchor.x), height: abs(point.y-anchor.y)).intersection(bounds)
        }
        needsDisplay = true
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { finish?(nil) }
        else if event.keyCode == 36, rect.width >= 8, rect.height >= 8 {
            // AppKit uses bottom-left coordinates; ScreenCaptureKit sourceRect is top-left local.
            finish?(RegionGeometry.fromLocalAppKit(rect, displaySize: bounds.size))
        }
    }
}
