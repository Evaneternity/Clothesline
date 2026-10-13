import AppKit
import Foundation

@main
struct MacIntegrationTests {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let defaults = UserDefaults.standard
        let keys = ["dismissedFiles", "attachedFolderBookmarks", "alwaysShowLine", "recentFileBookmarks"]
        let saved = keys.map { defaults.object(forKey: $0) }
        for key in keys { defaults.removeObject(forKey: key) }
        defer {
            for (key, old) in zip(keys, saved) {
                if let old { defaults.set(old, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
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
        let directory = folder.appendingPathComponent("attached-folder", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let child = directory.appendingPathComponent("child.txt")
        try bytes.write(to: child)
        try line.attachFolder(directory)
        precondition(line.items.count == 1 && line.items[0].file.isDirectory, "manual folder on rope")
        let restoredFolders = Line()
        restoredFolders.adopt([])
        precondition(restoredFolders.items.count == 1, "attached folder survives restart")
        line.dismiss(line.items[0].id)
        precondition(FileManager.default.fileExists(atPath: child.path), "take down preserves folder contents")
        try line.attachFolder(directory)
        let folderID = line.items[0].id
        let trashedDirectory = try line.moveToTrash(folderID)
        precondition(!FileManager.default.fileExists(atPath: directory.path), "folder moved out of original location")
        let trashedChild = try Data(contentsOf: trashedDirectory.appendingPathComponent("child.txt"))
        precondition(trashedChild == bytes && line.items.isEmpty, "folder contents recoverable in Trash")
        try FileManager.default.moveItem(at: trashedDirectory, to: directory)
        line.resetDismissed()
        line.adopt(try DownloadIndex.scan(folder).filter { !$0.isDirectory })
        let fileID = line.items[0].id
        // A changed file must not be deleted using an old card's metadata.
        try Data("changed".utf8).write(to: file)
        do {
            try line.moveToTrash(fileID)
            preconditionFailure("stale file must be rejected")
        } catch {
            precondition(FileManager.default.fileExists(atPath: file.path) && line.items.count == 1,
                         "failed trash must preserve source and card")
        }
        line.adopt(try DownloadIndex.scan(folder).filter { !$0.isDirectory })
        let trashedFile = try line.moveToTrash(line.items[0].id)
        precondition(!FileManager.default.fileExists(atPath: file.path) && line.items.isEmpty, "file trashed and card removed")
        let recovered = try Data(contentsOf: trashedFile)
        precondition(recovered == Data("changed".utf8), "file recoverable in Trash")
        try FileManager.default.moveItem(at: trashedFile, to: file)
        let delegate = AppDelegate()
        delegate.setAlwaysVisible(true)
        precondition(delegate.pinned && AppDelegate().pinned, "always show persists across app instances")
        delegate.setAlwaysVisible(false)
        precondition(!AppDelegate().pinned, "auto hide persists across app instances")
        let dragPayload = GrabView.filePasteboardItem(file)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        precondition(board.writeObjects([dragPayload]), "write drag payload")
        let dropped = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        precondition(dropped?.first?.standardizedFileURL.path == file.standardizedFileURL.path,
                     "drop target must decode real file URL")
        precondition(board.propertyList(forType: GrabView.filenamesType) as? [String] == [file.standardizedFileURL.path],
                     "legacy desktop drop target must decode file paths")
        let dragLine = Line()
        dragLine.adopt(try DownloadIndex.scan(folder).filter { !$0.isDirectory })
        let originalID = dragLine.items[0].id
        dragLine.pressedID = originalID
        dragLine.adopt([])
        precondition(dragLine.items.first?.id == originalID, "press must retain drag source across scan")
        dragLine.draggingID = originalID
        dragLine.pressedID = nil
        dragLine.updateVisibleItems()
        precondition(dragLine.items.first?.id == originalID, "drag must retain source until session ends")
        dragLine.draggingID = nil
        dragLine.updateVisibleItems()
        precondition(dragLine.items.isEmpty, "pending scan applied after drag")
        let suite = "Clothesline-Multi-\(UUID())"
        let isolatedDefaults = UserDefaults(suiteName: suite)!
        defer { isolatedDefaults.removePersistentDomain(forName: suite) }
        let secondFolder = folder.appendingPathComponent("second-watch", isDirectory: true)
        try FileManager.default.createDirectory(at: secondFolder, withIntermediateDirectories: false)
        let secondFile = secondFolder.appendingPathComponent("second.txt")
        try bytes.write(to: secondFile)
        var merged: [DownloadFile] = []
        let multi = FolderMonitors(defaults: isolatedDefaults) { merged = $0 }
        multi.start()
        defer { multi.stop() }
        try multi.add(folder)
        try multi.add(secondFolder)
        try multi.add(folder)
        precondition(multi.folders.count == 3, "Downloads plus two distinct monitors")
        for _ in 0..<16 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.5))
            if merged.contains(where: { $0.path == file.standardizedFileURL.path }) &&
                merged.contains(where: { $0.path == secondFile.standardizedFileURL.path }) { break }
        }
        precondition(merged.contains { $0.path == file.standardizedFileURL.path } &&
                     merged.contains { $0.path == secondFile.standardizedFileURL.path }, "both folders deliver files")
        precondition(Set(merged.map(\.path)).count == merged.count, "merged paths deduplicated")
        multi.stop()
        let restarted = FolderMonitors(defaults: isolatedDefaults) { _ in }
        restarted.start()
        precondition(restarted.folders.count == 3, "monitors survive restart with default Downloads")
        restarted.stop()
        let drag = GrabView()
        precondition(drag.draggingSession(NSDraggingSession(), sourceOperationMaskFor: .outsideApplication) == .copy)
        // New features use only files in the temporary acceptance directory.
        let manualA = folder.appendingPathComponent("manual-one.txt")
        let manualB = folder.appendingPathComponent("manual-two.pdf")
        try bytes.write(to: manualA); try bytes.write(to: manualB)
        let staging = Line()
        try staging.attachFiles([manualA, manualB, manualA])
        precondition(staging.items.filter { $0.url == manualA }.count == 1, "attach deduplicates files")
        let afterRestart = Line(); afterRestart.adopt([])
        precondition(afterRestart.items.contains { $0.url.resolvingSymlinksInPath().path == manualB.resolvingSymlinksInPath().path }, "manual files persist")
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.writeObjects([manualA as NSURL, manualB as NSURL])
        precondition(FileDropView.urls(from: pasteboard).count == 2, "Finder multi-file payload")
        let renameID = staging.items.first { $0.url == manualB }!.id
        try staging.rename(renameID, stem: "manual-one")
        let pdfURL = staging.items.first { $0.url.pathExtension == "pdf" }!.url
        let collision = folder.appendingPathComponent("occupied.pdf")
        try bytes.write(to: collision)
        let pdfID = staging.items.first { $0.url == pdfURL }!.id
        var rejected = false
        do { try staging.rename(pdfID, stem: "occupied") } catch { rejected = true }
        precondition(rejected, "rename refuses same-extension conflict")
        try staging.rename(pdfID, stem: "renamed-document")
        let renamed = folder.appendingPathComponent("renamed-document.pdf")
        precondition(FileManager.default.fileExists(atPath: renamed.path), "extension retained")
        let renamedBytes = try Data(contentsOf: renamed)
        precondition(renamedBytes == bytes, "rename preserves bytes")
        precondition(staging.recentFiles(matching: "RENAMED-DOCUMENT").count == 1, "case insensitive recent search")
        let renamedCard = staging.items.first { $0.url == renamed }!
        staging.dismiss(renamedCard.id)
        precondition(staging.recentFiles(matching: "renamed-document").count == 1, "drawer retains hidden files")
        try staging.attachFiles([renamed])
        precondition(staging.items.contains { $0.url == renamed }, "drawer can rehang hidden file")
        let screenshotURL = folder.appendingPathComponent("Screenshot test.png")
        try bytes.write(to: screenshotURL)
        let screenshot = try DownloadIndex.read(screenshotURL)!
        precondition(ScreenshotMonitor.isScreenshot(screenshot), "screenshot naming fallback")
        let ordinaryFile = try DownloadIndex.read(manualA)!
        precondition(!ScreenshotMonitor.isScreenshot(ordinaryFile), "ordinary file excluded")
        let screenMonitor = ScreenshotMonitor(defaults: isolatedDefaults) { _ in }
        precondition(!screenMonitor.enabled, "screenshots opt in")
        try screenMonitor.chooseFolder(folder)
        precondition(screenMonitor.enabled && screenMonitor.folder.resolvingSymlinksInPath().path == folder.resolvingSymlinksInPath().path, "screenshot preference retained")
        screenMonitor.setEnabled(false)
        precondition(!ScreenshotMonitor(defaults: isolatedDefaults) { _ in }.enabled, "screenshot switch persists")
        print("PASS: attach multiple files, persistent references, rename collision/extension, recent search/rehang, screenshot opt-in")
        print("PASS: macOS live watcher, temporary rename, actual rope URL, dismissal/restart/clear and source bytes, copy-only drag, attached folders, recoverable file/folder trash, stale deletion rejection, display persistence")
    }
}
