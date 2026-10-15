import AppKit
import SwiftUI
import Quartz
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let line = Line()
    private let identityPanel = FileIdentityPanel()
    private var panel: LinePanel!
    private var statusItem: NSStatusItem!
    private var monitors: FolderMonitors?
    private var clipboard: ClipboardMonitor?
    private let recentDrawer = RecentDrawer()
    private var hotkey: HotKey?
    private var pointerTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private(set) var pinned = UserDefaults.standard.bool(forKey: "alwaysShowLine")
    private var lastInside = Date.distantPast
    private var currentScreen: NSScreen?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = LinePanel(content: FileDropView(line: line))
        line.showRecent = { [weak self] in
            guard let self else { return }; self.recentDrawer.show(line: self.line)
        }
        panel.placeOnScreen()
        panel.onScroll = { [weak self] event in
            self?.line.scroll(by: event.scrollingDeltaY + event.scrollingDeltaX)
        }
        panel.orderFrontRegardless()
        currentScreen = LinePanel.screenUnderPointer()
        recalculateCapacity()
        line.revealed = pinned

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🧺"
        if let url = Bundle.main.url(forResource: "Clothesline", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            icon.size = NSSize(width: 18, height: 18)
            statusItem.button?.title = ""
            statusItem.button?.image = icon
        }
        statusItem.button?.toolTip = "Clothesline · 晾衣绳"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        monitors = FolderMonitors { [weak self] in self?.line.adopt($0) }
        clipboard = ClipboardMonitor { [weak self] content, manual in
            try self?.line.attachClipboard(content, manual: manual)
        }
        clipboard?.start()
        monitors?.start()
        hotkey = HotKey { [weak self] in self?.togglePinned() }
        pointerTimer = Timer.scheduledTimer(withTimeInterval: 0.10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollPointer() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.monitors?.wake() }
            }
    }

    func applicationWillTerminate(_ notification: Notification) {
        identityPanel.hide()
        monitors?.stop()
        clipboard?.stop()
        line.clearClipboardStorage()
        pointerTimer?.invalidate()
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
    }

    private func addMonitoredFolders() {
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = true
        picker.prompt = "添加监控文件夹"
        picker.message = "新文件夹与 Downloads 同时监控，不会替换已有监控。"
        picker.directoryURL = FolderMonitors.downloads
        NSApp.activate(ignoringOtherApps: true)
        guard picker.runModal() == .OK else { return }
        for url in picker.urls {
            do { try monitors?.add(url) }
            catch { NSAlert(error: error).runModal() }
        }
    }

    private func recalculateCapacity() {
        let usable = max(200, panel.frame.width - 200)
        let fit = max(3, min(12, Int(usable / Layout.spacing)))
        line.visibleCount = fit
        line.maxItems = max(fit, Line.keepOnLine ?? fit)
        line.updateVisibleItems()
    }

    private func pollPointer() {
        // AppKit owns mouse tracking from mouseDown through the drag session.
        // Do not turn the source window click-through, hide/reposition it, or
        // move it to another screen while that tracking is in progress.
        if line.pressedID != nil || line.draggingID != nil || line.interactionHeld {
            identityPanel.hide()
            lastInside = Date()
            panel.ignoresMouseEvents = false
            return
        }
        guard let screen = LinePanel.screenUnderPointer() else { return }
        if screen.frame != currentScreen?.frame {
            currentScreen = screen
            panel.placeOnScreen(screen)
            recalculateCapacity()
        }
        let mouse = NSEvent.mouseLocation
        let top = screen.visibleFrame.maxY
        let atTop = mouse.y >= top - 4 && mouse.y <= screen.frame.maxY + 1
        // Convert AppKit's bottom-up screen coordinates to SwiftUI's top-down
        // hosting-view coordinates, as used by HitRectsKey.
        let local = CGPoint(x: mouse.x - panel.frame.minX,
                            y: panel.frame.maxY - mouse.y)
        let overCard = line.hitRects.values.contains { $0.insetBy(dx: -4, dy: -4).contains(local) }
        let hovered = line.items.first { item in
            line.hitRects[item.id]?.contains(local) == true
        }
        let externalDragging = NSEvent.pressedMouseButtons & 1 != 0
        if line.revealed, !externalDragging, let item = hovered, let rect = line.hitRects[item.id] {
            let anchor = NSRect(x: panel.frame.minX + rect.minX,
                                y: panel.frame.maxY - rect.maxY,
                                width: rect.width, height: rect.height)
            identityPanel.update(id: item.id, description: line.identityDescription(item), anchor: anchor, screen: screen)
        } else { identityPanel.hide() }
        let overPanel = panel.frame.contains(mouse)

        if atTop || (line.revealed && (overPanel || overCard)) {
            lastInside = Date()
        }
        let shouldReveal = (pinned || Date().timeIntervalSince(lastInside) < 0.75)
        if shouldReveal != line.revealed { line.revealed = shouldReveal }
        // During an external mouse drag, expose the full rope as a drop target.
        let externalDrag = NSEvent.pressedMouseButtons & 1 != 0 && line.draggingID == nil
        panel.ignoresMouseEvents = !shouldReveal || (!overCard && !externalDrag)
    }

    func setAlwaysVisible(_ enabled: Bool) {
        pinned = enabled
        UserDefaults.standard.set(enabled, forKey: "alwaysShowLine")
        if pinned {
            panel?.placeOnScreen()
            line.revealed = true
        } else {
            lastInside = Date.distantPast
            line.revealed = false
        }
    }

    private func togglePinned() { setAlwaysVisible(!pinned) }

    private func attachFolder() {
        let picker = NSOpenPanel()
        picker.canChooseFiles = true
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = true
        picker.prompt = "挂上晾衣绳"
        picker.message = "挂上文件或文件夹快捷入口，保留在原位置。Downloads 监听仍然继续。"
        NSApp.activate(ignoringOtherApps: true)
        guard picker.runModal() == .OK else { return }
        for url in picker.urls {
            do { try line.attachFolder(url) }
            catch { NSAlert(error: error).runModal() }
        }
    }

    // Dynamic menu. No app menu or Dock icon is required.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let header = NSMenuItem(title: "晾衣绳 · Clothesline", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for folder in monitors?.folders ?? [] {
            let name = NSMenuItem(title: "监控：\(folder.lastPathComponent)", action: nil, keyEquivalent: "")
            name.isEnabled = false
            name.toolTip = folder.path
            menu.addItem(name)
            if let failure = monitors?.failures[folder.standardizedFileURL.path] {
                let problem = NSMenuItem(title: "⚠ \(failure)", action: nil, keyEquivalent: "")
                problem.isEnabled = false
                menu.addItem(problem)
            }
        }
        menu.addItem(.separator())
        let show = ClosureMenuItem("一直显示晾衣绳") { [weak self] in self?.togglePinned() }
        show.state = pinned ? .on : .off
        menu.addItem(show)
        let autoHide = ClosureMenuItem("自动隐藏晾衣绳") { [weak self] in self?.setAlwaysVisible(false) }
        autoHide.state = pinned ? .off : .on
        menu.addItem(autoHide)
        menu.addItem(ClosureMenuItem("挂上文件或文件夹…") { [weak self] in self?.attachFolder() })
        menu.addItem(ClosureMenuItem("最近文件…") { [weak self] in
            guard let self else { return }; self.recentDrawer.show(line: self.line)
        })
        let clipboardMenu = NSMenu(title: "剪贴板挂载")
        let images = ClosureMenuItem("自动挂上图片 / 截图") { [weak self] in
            guard let self else { return }
            self.clipboard?.setImagesEnabled(!(self.clipboard?.imagesEnabled ?? false))
        }
        images.state = clipboard?.imagesEnabled == true ? .on : .off
        clipboardMenu.addItem(images)
        let text = ClosureMenuItem("自动挂上文字便签") { [weak self] in
            guard let self else { return }
            self.clipboard?.setTextEnabled(!(self.clipboard?.textEnabled ?? false))
        }
        text.state = clipboard?.textEnabled == true ? .on : .off
        clipboardMenu.addItem(text)
        clipboardMenu.addItem(.separator())
        clipboardMenu.addItem(ClosureMenuItem("清空剪贴板挂载内容") { [weak self] in
            self?.line.clearClipboardStorage()
        })
        if let failure = clipboard?.failure {
            let errorItem = NSMenuItem(title: "⚠ \(failure)", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false; clipboardMenu.addItem(errorItem)
        }
        let clipboardItem = NSMenuItem(title: "剪贴板挂载", action: nil, keyEquivalent: "")
        clipboardItem.submenu = clipboardMenu
        menu.addItem(clipboardItem)
        menu.addItem(ClosureMenuItem("打开下载文件夹") {
            NSWorkspace.shared.open(FolderMonitors.downloads)
        })
        menu.addItem(ClosureMenuItem("添加监控文件夹…") { [weak self] in self?.addMonitoredFolders() })
        menu.addItem(.separator())

        let keepSubmenu = NSMenu(title: "保留文件数量")
        for choice in [0, 25, 50, 100] {
            let title = choice == 0 ? "屏幕可容纳数量" : "\(choice) 个文件"
            let item = ClosureMenuItem(title) { [weak self] in
                Line.keepOnLine = choice == 0 ? nil : choice
                self?.recalculateCapacity()
            }
            item.state = (Line.keepOnLine ?? 0) == choice ? .on : .off
            keepSubmenu.addItem(item)
        }
        let keepItem = NSMenuItem(title: "保留文件数量", action: nil, keyEquivalent: "")
        keepItem.submenu = keepSubmenu
        menu.addItem(keepItem)

        let sizeSubmenu = NSMenu(title: "卡片尺寸")
        for size in Layout.Size.allCases {
            let title: String
            switch size { case .small: title = "小"; case .medium: title = "中"; case .large: title = "大" }
            let item = ClosureMenuItem(title) { [weak self] in
                Layout.size = size
                self?.panel.placeOnScreen()
                self?.recalculateCapacity()
            }
            item.state = Layout.size == size ? .on : .off
            sizeSubmenu.addItem(item)
        }
        let sizeItem = NSMenuItem(title: "卡片尺寸", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeSubmenu
        menu.addItem(sizeItem)

        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("清空晾衣绳（不删除文件）") { [weak self] in self?.line.dismissAll() })
        menu.addItem(ClosureMenuItem("重新显示已取下的文件") { [weak self] in self?.line.resetDismissed() })
        menu.addItem(.separator())
        let hotkey = NSMenuItem(title: "快捷键：⌃⌥T", action: nil, keyEquivalent: "")
        hotkey.isEnabled = false
        menu.addItem(hotkey)
        menu.addItem(ClosureMenuItem("退出 Clothesline") { NSApp.terminate(nil) })
    }

    // Quick Look delegates are asked through the application responder chain.
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        QuickLook.shared.take(panel)
    }
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        QuickLook.shared.release(panel)
    }
}
