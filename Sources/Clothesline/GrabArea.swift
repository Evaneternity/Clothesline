import AppKit
import SwiftUI

/// An AppKit bridge lets a real file URL be dragged into Finder and other apps.
/// Only COPY is offered by default, never delete or a surprising move.
struct GrabArea: NSViewRepresentable {
    let item: Pegged
    let line: Line

    func makeNSView(context: Context) -> GrabView {
        let view = GrabView()
        configure(view)
        return view
    }
    func updateNSView(_ nsView: GrabView, context: Context) { configure(nsView) }

    private func configure(_ view: GrabView) {
        let id = item.id
        view.file = item.url
        view.dragImage = item.thumb
        view.onClick = { line.quickLook(id) }
        view.onDoubleClick = { line.open(id) }
        view.onDismiss = { line.dismiss(id) }
        view.onPressChange = {
            line.pressedID = $0 ? id : nil
            if !$0 { line.updateVisibleItems() }
        }
        view.onDragChange = {
            line.draggingID = $0 ? id : nil
            if !$0 { line.updateVisibleItems() }
        }
        view.menuProvider = {
            let menu = NSMenu()
            menu.addItem(ClosureMenuItem("快速预览") { line.quickLook(id) })
            menu.addItem(ClosureMenuItem("打开文件") { line.open(id) })
            menu.addItem(ClosureMenuItem("在 Finder 中显示") { line.reveal(id) })
            menu.addItem(ClosureMenuItem("复制文件") { line.copy(id) })
            menu.addItem(.separator())
            menu.addItem(ClosureMenuItem("从晾衣绳取下（保留原文件）") { line.dismiss(id) })
            menu.addItem(ClosureMenuItem("移到废纸篓…") { line.requestTrash(id) })
            return menu
        }
    }
}

final class GrabView: NSView, NSDraggingSource {
    static let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")

    static func filePasteboardItem(_ url: URL) -> NSPasteboardItem {
        let item = NSPasteboardItem()
        let file = url.standardizedFileURL
        item.setString(file.absoluteString, forType: .fileURL)
        // Some desktop drop targets still ask for Finder's legacy path array.
        item.setPropertyList([file.path], forType: filenamesType)
        return item
    }
    var file: URL?
    var dragImage: NSImage?
    var onClick: () -> Void = {}
    var onDoubleClick: () -> Void = {}
    var onDismiss: () -> Void = {}
    var onPressChange: (Bool) -> Void = { _ in }
    var onDragChange: (Bool) -> Void = { _ in }
    var menuProvider: () -> NSMenu = { NSMenu() }
    private var downPoint: NSPoint?
    private var dragging = false
    private var pressedCross = false
    private var pendingSingleClick: DispatchWorkItem?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func isCross(_ event: NSEvent) -> Bool {
        let p = convert(event.locationInWindow, from: nil)
        return p.x >= 0 && p.x < 28 && p.y >= bounds.height - 28
    }

    override func mouseDown(with event: NSEvent) {
        downPoint = event.locationInWindow
        pressedCross = isCross(event)
        onPressChange(true)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = downPoint, !dragging, !pressedCross, let file else { return }
        let point = event.locationInWindow
        guard hypot(point.x - start.x, point.y - start.y) > 5 else { return }
        dragging = true
        pendingSingleClick?.cancel()
        onDragChange(true)
        onPressChange(false)
        let dragged = NSDraggingItem(pasteboardWriter: Self.filePasteboardItem(file))
        // A subtle, system-native drag image (file thumbnail/icon).
        dragged.setDraggingFrame(bounds, contents: dragImage)
        let session = beginDraggingSession(with: [dragged], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    override func mouseUp(with event: NSEvent) {
        onPressChange(false)
        defer { downPoint = nil; pressedCross = false }
        guard downPoint != nil, !dragging else { return }
        if pressedCross {
            pendingSingleClick?.cancel()
            onDismiss()
        } else if event.clickCount >= 2 {
            pendingSingleClick?.cancel()
            onDoubleClick()
        } else {
            // Quick Look takes focus. Defer single-click so a double-click
            // is able to open the default app rather than launch Quick Look.
            pendingSingleClick?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.onClick() }
            pendingSingleClick = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        NSMenu.popUpContextMenu(menuProvider(), with: event, for: self)
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy] : []
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }

    func draggingSession(_ session: NSDraggingSession,
                         endedAt screenPoint: NSPoint,
                         operation: NSDragOperation) {
        dragging = false
        downPoint = nil
        onPressChange(false)
        onDragChange(false)
    }
}

final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void
    init(_ title: String, action: @escaping () -> Void) {
        handler = action
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }
    required init(coder: NSCoder) { fatalError("init(coder:) not supported") }
    @objc private func fire() { handler() }
}
