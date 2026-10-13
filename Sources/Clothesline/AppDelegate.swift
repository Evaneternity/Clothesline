import AppKit
import SwiftUI
import Quartz
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let line = Line()
    private var panel: LinePanel!
    private var statusItem: NSStatusItem!
    private var watcher: DownloadsWatcher?
    private var hotkey: HotKey?
    private var pointerTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var selectedFolder: URL!
    private var scopedAccess = false
    private var pinned = false
    private var lastInside = Date.distantPast
    private var watchFailure: String?
    private var currentScreen: NSScreen?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = LinePanel(content: NSHostingView(rootView: LineView(line: line)))
        panel.placeOnScreen()
        panel.onScroll = { [weak self] event in
            self?.line.scroll(by: event.scrollingDeltaY + event.scrollingDeltaX)
        }
        panel.orderFrontRegardless()
        currentScreen = LinePanel.screenUnderPointer()
        recalculateCapacity()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🧺"
        statusItem.button?.toolTip = "Clothesline · 晾衣绳"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        let chosen = restoreFolder() ?? Self.defaultFolder
        switchToFolder(chosen, alreadyScoped: scopedAccess)
        hotkey = HotKey { [weak self] in self?.togglePinned() }
        pointerTimer = Timer.scheduledTimer(withTimeInterval: 0.10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollPointer() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.watcher?.wake() }
            }
    }

    func applicationWillTerminate(_ notification: Notification) {
        watcher?.stop()
        pointerTimer?.invalidate()
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        if scopedAccess { selectedFolder?.stopAccessingSecurityScopedResource() }
    }

    private static var defaultFolder: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
    }

    private func restoreFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: "folderBookmark") else { return nil }
        var stale = false
        if let url = (try? URL(resolvingBookmarkData: data,
                             options: [.withSecurityScope], relativeTo: nil,
                             bookmarkDataIsStale: &stale)) ?? (try? URL(resolvingBookmarkData: data,
                             options: [], relativeTo: nil, bookmarkDataIsStale: &stale)) {
            scopedAccess = url.startAccessingSecurityScopedResource()
            return url
        }
        return nil
    }

    private func switchToFolder(_ url: URL, alreadyScoped: Bool = false) {
        watcher?.stop()
        if scopedAccess { selectedFolder?.stopAccessingSecurityScopedResource() }
        selectedFolder = url
        scopedAccess = alreadyScoped
        watcher = DownloadsWatcher(folder: url,
            onUpdate: { [weak self] files in
                self?.line.adopt(files)
            },
            onFailure: { [weak self] message in
                self?.watchFailure = message
            })
        watcher?.start()
    }

    private func chooseFolder() {
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = false
        picker.prompt = "监控此文件夹"
        picker.message = "选择下载目录。Clothesline 只读取文件信息与预览，不移动或删除原文件。"
        picker.directoryURL = selectedFolder
        NSApp.activate(ignoringOtherApps: true)
        guard picker.runModal() == .OK, let url = picker.url else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        // For ad-hoc/non-sandboxed local builds, withSecurityScope might not
        // be available. A chosen URL still works in that situation.
        if let data = try? url.bookmarkData(options: [.withSecurityScope],
                                            includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: "folderBookmark")
        } else {
            // Store a normal bookmark as a best-effort fallback.
            if let data = try? url.bookmarkData(options: [],
                                                includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(data, forKey: "folderBookmark")
            }
        }
        switchToFolder(url, alreadyScoped: scoped)
    }

    private func recalculateCapacity() {
        let usable = max(200, panel.frame.width - 200)
        let fit = max(3, min(12, Int(usable / Layout.spacing)))
        line.visibleCount = fit
        line.maxItems = max(fit, Line.keepOnLine ?? fit)
        line.updateVisibleItems()
    }

    private func pollPointer() {
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
        let overPanel = panel.frame.contains(mouse)

        if atTop || (line.revealed && (overPanel || overCard)) {
            lastInside = Date()
        }
        let shouldReveal = (pinned || Date().timeIntervalSince(lastInside) < 0.75)
        if shouldReveal != line.revealed { line.revealed = shouldReveal }
        panel.ignoresMouseEvents = !shouldReveal || !overCard
    }

    private func togglePinned() {
        pinned.toggle()
        if pinned {
            panel.placeOnScreen()
            line.revealed = true
        } else {
            lastInside = Date.distantPast
            line.revealed = false
        }
    }

    // Dynamic menu. No app menu or Dock icon is required.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let path = selectedFolder?.path ?? "Downloads"
        let header = NSMenuItem(title: "晾衣绳 · Clothesline", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        let folderName = NSMenuItem(title: "监控：\(selectedFolder?.lastPathComponent ?? "Downloads")",
                                   action: nil, keyEquivalent: "")
        folderName.isEnabled = false
        folderName.toolTip = path
        menu.addItem(folderName)
        if let watchFailure {
            let problem = NSMenuItem(title: "⚠ \(watchFailure)", action: nil, keyEquivalent: "")
            problem.isEnabled = false
            menu.addItem(problem)
        }
        menu.addItem(.separator())
        let show = ClosureMenuItem(pinned ? "取消固定显示" : "固定显示晾衣绳") { [weak self] in self?.togglePinned() }
        show.state = pinned ? .on : .off
        menu.addItem(show)
        menu.addItem(ClosureMenuItem("打开下载文件夹") { [weak self] in
            guard let self else { return }
            NSWorkspace.shared.open(self.selectedFolder)
        })
        menu.addItem(ClosureMenuItem("选择监控文件夹…") { [weak self] in self?.chooseFolder() })
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
