import AppKit
import Foundation

@main
struct MacIntegrationTests {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let defaults = UserDefaults.standard
        let old = defaults.object(forKey: "dismissedFiles")
        defaults.removeObject(forKey: "dismissedFiles")
        defer {
            if let old { defaults.set(old, forKey: "dismissedFiles") }
            else { defaults.removeObject(forKey: "dismissedFiles") }
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Clothesline-acceptance-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("real-download.txt")
        let partial = folder.appendingPathComponent("real-download.txt.crdownload")
        let bytes = Data("Clothesline real file acceptance\n".utf8)
        let line = Line()
        var observed = false
        var failure: String?
        let watcher = DownloadsWatcher(folder: folder, onUpdate: { files in
            line.adopt(files)
            if files.contains(where: { $0.path == file.path }) { observed = true }
        }, onFailure: { failure = $0 })
        watcher.start()
        defer { watcher.stop() }
        try bytes.write(to: partial)
        RunLoop.main.run(until: Date().addingTimeInterval(3))
        precondition(line.items.isEmpty, "temporary download must stay off rope")
        try FileManager.default.moveItem(at: partial, to: file)
        for _ in 0..<12 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.5))
            if observed { break }
        }
        precondition(observed && failure == nil, "watcher must publish completed real file")
        precondition(line.items.count == 1 && line.items[0].file.path == file.standardizedFileURL.path, "rope must use actual URL")
        line.dismiss(line.items[0].id)
        precondition(line.items.isEmpty, "take down must hide card")
        line.adopt([])
        let files = try DownloadIndex.scan(folder)
        line.adopt(files)
        precondition(line.items.isEmpty, "empty scan must not lose dismissal")
        let restored = Line()
        restored.adopt(files)
        precondition(restored.items.isEmpty, "dismissal must survive restart")
        line.resetDismissed()
        precondition(line.items.count == 1, "reset must restore card")
        line.dismissAll()
        precondition(line.items.isEmpty, "clear must hide card")
        let remainingBytes = try Data(contentsOf: file)
        precondition(remainingBytes == bytes, "dismiss/clear must preserve original bytes")
        let drag = GrabView()
        precondition(drag.draggingSession(NSDraggingSession(), sourceOperationMaskFor: .outsideApplication) == .copy)
        print("PASS: macOS live watcher, temporary rename, actual rope URL, dismissal/restart/clear and source bytes, copy-only drag")
    }
}
