import AppKit

/// Non-activating, transparent overlay over the active screen's usable top edge.
final class LinePanel: NSPanel {
    init(content: NSView) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isMovable = false
        becomesKeyOnlyIfNeeded = true
        ignoresMouseEvents = true
        contentView = content
    }
    var onScroll: ((NSEvent) -> Void)?
    override func sendEvent(_ event: NSEvent) {
        if event.type == .scrollWheel, let onScroll { onScroll(event) }
        else { super.sendEvent(event) }
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    static func screenUnderPointer() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main ?? NSScreen.screens.first
    }

    func placeOnScreen(_ screen: NSScreen? = nil) {
        guard let frame = (screen ?? Self.screenUnderPointer())?.visibleFrame else { return }
        let target = NSRect(x: frame.minX, y: frame.maxY - Layout.panelHeight,
                            width: frame.width, height: Layout.panelHeight)
        if self.frame != target { setFrame(target, display: true) }
    }
}
