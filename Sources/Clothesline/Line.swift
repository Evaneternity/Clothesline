import AppKit
import Combine
import QuickLookThumbnailing

struct Pegged: Identifiable, Equatable {
    let id: UUID
    let file: DownloadFile
    var thumb: NSImage
    let tilt: Double
    var falling = false
    var flying = false
    var url: URL { file.url }
    var isRecording: Bool {
        ["mov", "mp4", "m4v", "avi", "webm", "mkv"].contains(url.pathExtension.lowercased())
    }
    static func == (lhs: Pegged, rhs: Pegged) -> Bool {
        lhs.id == rhs.id && lhs.thumb === rhs.thumb && lhs.falling == rhs.falling
    }
}

@MainActor
final class Line: ObservableObject {
    @Published private(set) var items: [Pegged] = []
    @Published var draggingID: UUID?
    @Published var pressedID: UUID?
    @Published var copiedID: UUID?
    @Published var revealed = false
    @Published var gust = 0
    @Published var scroll: CGFloat = 0

    var maxItems = 8
    var visibleCount = 8
    var hitRects: [UUID: CGRect] = [:]

    private var latest: [DownloadFile] = []
    private var attachedFolders: [URL] = []
    private static let foldersKey = "attachedFolderBookmarks"
    private var dismissed: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "dismissedFiles") ?? [])
    private static let dismissalKey = "dismissedFiles"
    static let keepChoices = [25, 50, 100]
    static var keepOnLine: Int? {
        get {
            let n = UserDefaults.standard.integer(forKey: "keepOnLine")
            return keepChoices.contains(n) ? n : nil
        }
        set { UserDefaults.standard.set(newValue ?? 0, forKey: "keepOnLine") }
    }

    init() {
        attachedFolders = (UserDefaults.standard.array(forKey: Self.foldersKey) as? [Data] ?? []).compactMap {
            var stale = false
            return try? URL(resolvingBookmarkData: $0, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        }
        // Gentle periodic gusts without keeping the CPU busy for animation.
        Timer.scheduledTimer(withTimeInterval: 16, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.gust &+= 1 }
        }
    }

    func adopt(_ files: [DownloadFile]) {
        latest = files
        // A completion scan can temporarily be empty at startup or while a
        // file changes. It is not evidence that dismissed files were deleted.
        updateVisibleItems()
    }

    func updateVisibleItems() {
        // Preserve the AppKit drag source even when the Downloads scan changes.
        guard pressedID == nil, draggingID == nil else { return }
        let attached = attachedFolders.compactMap { try? DownloadIndex.read($0) }
        let attachedPaths = Set(attached.map(\.path))
        let combined = attached + latest.filter { !attachedPaths.contains($0.path) }
        let selected = Array(combined.filter { !dismissed.contains($0.fingerprint) }.prefix(maxItems).reversed())
        let previous = Dictionary(uniqueKeysWithValues: items.map { ($0.file.fingerprint, $0) })
        var newItems: [Pegged] = []
        for file in selected {
            if let existing = previous[file.fingerprint] {
                newItems.append(existing)
            } else {
                let image = NSWorkspace.shared.icon(forFile: file.path)
                image.size = NSSize(width: 120, height: 120)
                let item = Pegged(id: UUID(), file: file, thumb: image,
                                  tilt: Double.random(in: -2.5...2.5))
                newItems.append(item)
                requestThumbnail(for: item)
            }
        }
        if items.map(\.id) != newItems.map(\.id) { scroll = 0 }
        if items != newItems { items = newItems }
    }

    private func requestThumbnail(for item: Pegged) {
        guard !item.file.isDirectory else { return }
        let request = QLThumbnailGenerator.Request(fileAt: item.url,
            size: CGSize(width: 240, height: 220), scale: 2,
            representationTypes: [.thumbnail, .lowQualityThumbnail])
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            guard let image = representation?.nsImage else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, let index = self.items.firstIndex(where: { $0.id == item.id }) else { return }
                self.items[index].thumb = image
            }
        }
    }

    func dismiss(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        dismissed.insert(item.file.fingerprint)
        UserDefaults.standard.set(Array(dismissed), forKey: Self.dismissalKey)
        updateVisibleItems()
    }

    func dismissAll() {
        for item in items { dismissed.insert(item.file.fingerprint) }
        UserDefaults.standard.set(Array(dismissed), forKey: Self.dismissalKey)
        updateVisibleItems()
    }

    func resetDismissed() {
        dismissed.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.dismissalKey)
        updateVisibleItems()
    }

    func attachFolder(_ url: URL) throws {
        guard let file = try DownloadIndex.read(url), file.isDirectory else {
            throw NSError(domain: "Clothesline", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "请选择可访问的文件夹。"])
        }
        if !attachedFolders.contains(where: { $0.standardizedFileURL.path == file.path }) {
            // Prepare persistence before changing the display. Normal bookmarks
            // suit the current non-sandboxed local build and survive renames.
            _ = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            attachedFolders.insert(url, at: 0)
            saveAttachedFolders()
        }
        dismissed.remove(file.fingerprint)
        UserDefaults.standard.set(Array(dismissed), forKey: Self.dismissalKey)
        updateVisibleItems()
    }

    private func saveAttachedFolders() {
        let bookmarks = attachedFolders.compactMap {
            try? $0.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        UserDefaults.standard.set(bookmarks, forKey: Self.foldersKey)
    }

    /// The explicit delete command uses Trash. Taking down a card never calls this.
    @discardableResult
    func moveToTrash(_ id: UUID) throws -> URL {
        guard let item = items.first(where: { $0.id == id }),
              let current = try DownloadIndex.read(item.url),
              current.fingerprint == item.file.fingerprint else {
            throw NSError(domain: "Clothesline", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "文件已改变或不存在，请等待刷新后重试。"])
        }
        var result: NSURL?
        try FileManager.default.trashItem(at: item.url, resultingItemURL: &result)
        latest.removeAll { $0.path == item.file.path }
        attachedFolders.removeAll { $0.standardizedFileURL.path == item.file.path }
        saveAttachedFolders()
        updateVisibleItems()
        return (result as URL?) ?? item.url
    }

    func requestTrash(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = "将“\(item.url.lastPathComponent)”移到废纸篓？"
        alert.informativeText = item.file.isDirectory
            ? "文件夹及其内容会从原位置移到废纸篓，可在 Finder 中恢复。若只想隐藏卡片，请选择“从晾衣绳取下”。"
            : "原文件会移到废纸篓，可在 Finder 中恢复。若只想隐藏卡片，请选择“从晾衣绳取下”。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "移到废纸篓")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        do { try moveToTrash(id) }
        catch { NSAlert(error: error).runModal() }
    }

    func open(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        NSWorkspace.shared.open(item.url)
    }

    func reveal(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func copy(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([item.url as NSURL])
        copiedID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            if self?.copiedID == id { self?.copiedID = nil }
        }
    }

    func quickLook(_ id: UUID) {
        let active = items.map(\.url)
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        QuickLook.shared.show(active, at: index)
    }

    func scroll(by distance: CGFloat) {
        let limit = CGFloat(max(0, items.count - visibleCount)) * Layout.spacing
        scroll = min(limit, max(0, scroll + distance))
    }
}
