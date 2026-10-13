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
        // Gentle periodic gusts without keeping the CPU busy for animation.
        Timer.scheduledTimer(withTimeInterval: 16, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.gust &+= 1 }
        }
    }

    func adopt(_ files: [DownloadFile]) {
        latest = files
        // No unbounded buildup of fingerprints for files that no longer exist.
        let current = Set(files.map(\.fingerprint))
        dismissed.formIntersection(current)
        updateVisibleItems()
    }

    func updateVisibleItems() {
        let selected = Array(latest.filter { !dismissed.contains($0.fingerprint) }.prefix(maxItems).reversed())
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
