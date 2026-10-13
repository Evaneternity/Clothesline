import AppKit
import SwiftUI

/// Explicit click-through information window: independent of system tooltip tracking.
@MainActor
final class FileIdentityPanel {
    private var panel: NSPanel?
    private var pending: DispatchWorkItem?
    private(set) var currentID: UUID?
    private(set) var displayedText = ""

    func update(id: UUID?, description: String = "", anchor: NSRect = .zero, screen: NSScreen? = nil) {
        guard let id else { hide(); return }
        if currentID == id {
            if panel?.isVisible == true { present(description, anchor: anchor, screen: screen) }
            return
        }
        hide()
        currentID = id
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.currentID == id else { return }
            self.present(description, anchor: anchor, screen: screen)
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }
    private func present(_ description: String, anchor: NSRect, screen: NSScreen?) {
        if panel == nil {
            let window = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
            window.isOpaque = false; window.backgroundColor = .clear
            window.hasShadow = true; window.hidesOnDeactivate = false
            window.ignoresMouseEvents = true
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel = window
        }
        guard let panel else { return }
        if displayedText != description || panel.contentView == nil {
            let view = NSHostingView(rootView: Text(description)
                .font(.system(size: 12)).textSelection(.disabled)
                .frame(width: 320, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                .padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)))
            panel.contentView = view
            displayedText = description
            panel.setContentSize(view.fittingSize)
        }
        let bounds = (screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = panel.frame.size
        let x = min(max(bounds.minX + 8, anchor.midX - size.width / 2), bounds.maxX - size.width - 8)
        let y = max(bounds.minY + 8, min(anchor.minY - size.height - 8, bounds.maxY - size.height - 8))
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFrontRegardless()
    }
    func hide() {
        pending?.cancel(); pending = nil
        currentID = nil; displayedText = ""
        panel?.orderOut(nil)
    }
}
