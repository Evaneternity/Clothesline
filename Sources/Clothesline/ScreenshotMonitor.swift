import Foundation
import Darwin

@MainActor
final class ScreenshotMonitor {
    private var watcher: DownloadsWatcher?
    private let defaults: UserDefaults
    private let onUpdate: ([DownloadFile]) -> Void
    private var scoped: URL?
    private(set) var failure: String?
    var enabled: Bool { defaults.bool(forKey: "screenshotMonitoring") }
    var folder: URL {
        if let data = defaults.data(forKey: "screenshotFolderBookmark") {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) { return url }
        }
        if let path = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    }
    init(defaults: UserDefaults = .standard, onUpdate: @escaping ([DownloadFile]) -> Void) {
        self.defaults = defaults; self.onUpdate = onUpdate
    }
    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: "screenshotMonitoring")
        restart()
    }
    func chooseFolder(_ url: URL) throws {
        let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(data, forKey: "screenshotFolderBookmark")
        setEnabled(true)
    }
    static func isScreenshot(_ file: DownloadFile) -> Bool {
        guard !file.isDirectory else { return false }
        let marked = file.path.withCString { path in
            getxattr(path, "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, 0) > 0
        }
        if marked { return true }
        let name = file.url.lastPathComponent.lowercased()
        return ["png", "jpg", "jpeg", "heic", "tiff"].contains(file.url.pathExtension.lowercased()) &&
            ["screenshot", "screen shot", "截屏", "屏幕快照", "屏幕截图"].contains(where: { name.hasPrefix($0) })
    }
    func restart() {
        stop(); onUpdate([]); failure = nil
        guard enabled else { return }
        let url = folder
        if url.startAccessingSecurityScopedResource() { scoped = url }
        watcher = DownloadsWatcher(folder: url, onUpdate: { [weak self] files in
            self?.onUpdate(files.filter(Self.isScreenshot))
        }, onFailure: { [weak self] in self?.failure = $0 })
        watcher?.start()
    }
    func stop() {
        watcher?.stop(); watcher = nil
        scoped?.stopAccessingSecurityScopedResource(); scoped = nil
    }
}
