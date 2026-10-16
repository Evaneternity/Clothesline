import AppKit

@MainActor
func testDisplayExpiration() throws {
    let defaults = UserDefaults.standard
    let keys = ["attachedFolderBookmarks", "pinnedFiles", "recentFileBookmarks", "dismissedFiles"]
    let saved = keys.map { defaults.object(forKey: $0) }
    keys.forEach { defaults.removeObject(forKey: $0) }
    defer {
        for (key, value) in zip(keys, saved) {
            if let value { defaults.set(value, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }
    }
    let suite = "Clothesline-Expiration-\(UUID())"
    let isolated = UserDefaults(suiteName: suite)!
    defer { isolated.removePersistentDomain(forName: suite) }
    let preferences = DisplayPreferences(defaults: isolated)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("Clothesline-expiration-\(UUID())")
    let shortFolder = root.appendingPathComponent("short")
    let longFolder = root.appendingPathComponent("long")
    try FileManager.default.createDirectory(at: shortFolder, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: longFolder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let first = shortFolder.appendingPathComponent("download.txt")
    let directory = shortFolder.appendingPathComponent("download-folder")
    let second = longFolder.appendingPathComponent("other.txt")
    let bytes = Data("Expiration keeps source contents".utf8)
    try bytes.write(to: first)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    try bytes.write(to: directory.appendingPathComponent("child.txt"))
    try bytes.write(to: second)
    preferences.setLifetime(60, for: shortFolder)
    preferences.setLifetime(3600, for: longFolder)
    let line = Line()
    var delivered: [DownloadFile] = []
    let monitors = FolderMonitors(defaults: isolated) { delivered = $0 }
    try monitors.add(shortFolder)
    try monitors.add(longFolder)
    defer { monitors.stop() }
    for _ in 0..<16 {
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        if delivered.count == 3 { break }
    }
    precondition(delivered.count == 3, "both monitored folders publish real files and directories")
    line.adopt(delivered, expiration: monitors.expirationPolicy)
    precondition(line.items.count == 3, "recent downloads initially visible")
    let future = Date().addingTimeInterval(120)
    let originalID = line.items.first { $0.file.path == first.standardizedFileURL.path }!.id
    line.pressedID = originalID
    line.updateVisibleItems(now: future)
    precondition(line.items.contains { $0.id == originalID }, "expiration preserves pressed source")
    line.pressedID = nil
    line.draggingID = originalID
    line.updateVisibleItems(now: future)
    precondition(line.items.contains { $0.id == originalID }, "expiration preserves dragged source")
    line.draggingID = nil
    line.updateVisibleItems(now: future)
    precondition(line.items.count == 1 && line.items[0].file.path == second.standardizedFileURL.path,
                 "files and folders expire together; other folder keeps its own lifetime")
    precondition(line.recentFiles(matching: "", now: future).map(\.path) == [second.standardizedFileURL.path],
                 "recent drawer also filters expired automatic entries")
    let firstBytes = try Data(contentsOf: first)
    let childBytes = try Data(contentsOf: directory.appendingPathComponent("child.txt"))
    precondition(firstBytes == bytes && childBytes == bytes, "expiration never touches original bytes")
    preferences.setLifetime(3600, for: shortFolder)
    monitors.refresh()
    line.adopt(delivered, expiration: monitors.expirationPolicy)
    line.updateVisibleItems(now: future)
    precondition(line.items.count == 3, "increasing lifetime restores items without clearing dismissal records")

    preferences.setLifetime(60, for: shortFolder)
    line.adopt(delivered, expiration: monitors.expirationPolicy)
    let pinnedID = line.items.first { $0.file.path == first.standardizedFileURL.path }!.id
    line.togglePin(pinnedID)
    line.updateVisibleItems(now: future)
    precondition(line.items.contains { $0.file.path == first.standardizedFileURL.path && $0.pinned }, "explicit pin survives expiration")
    line.togglePin(pinnedID)
    line.updateVisibleItems(now: future)
    precondition(!line.items.contains { $0.file.path == first.standardizedFileURL.path }, "unpin respects expiration")
    try line.attachFolder(directory)
    line.updateVisibleItems(now: future)
    precondition(line.items.contains { $0.file.path == directory.standardizedFileURL.path }, "manual attachment survives expiration")
    let restarted = Line()
    restarted.adopt(delivered, expiration: monitors.expirationPolicy)
    restarted.updateVisibleItems(now: future)
    precondition(!restarted.items.contains { $0.file.path == first.standardizedFileURL.path } && restarted.items.contains { $0.file.path == directory.standardizedFileURL.path },
                 "restart does not renew download age; manual attachments persist")

    // Missing-source retention must not keep an automatic card forever.
    line.adopt(delivered, expiration: monitors.expirationPolicy)
    try FileManager.default.removeItem(at: first)
    line.updateVisibleItems(now: future)
    precondition(!line.items.contains { $0.file.path == first.standardizedFileURL.path }, "expired missing source is not resurrected")
    try bytes.write(to: first)
    let fresh = try DownloadIndex.scan(shortFolder)
    line.adopt(fresh, expiration: monitors.expirationPolicy)
    let firstCard = line.items.first { $0.file.path == first.standardizedFileURL.path }!
    line.dismiss(firstCard.id)
    preferences.setLifetime(0, for: shortFolder)
    line.adopt(fresh, expiration: monitors.expirationPolicy)
    precondition(!line.items.contains { $0.file.path == first.standardizedFileURL.path }, "never-expire does not undo explicit dismissal")

    let settings = SettingsWindow()
    settings.show(preferences: preferences, folders: monitors.folders, onChange: {})
    precondition(settings.window?.isVisible == true && settings.window?.contentView != nil,
                 "native settings window opens with watched folders")
    settings.window?.close()
    print("PASS: live multi-folder expiration, source safety, drag deferral, restore/unlimited, pins/manual/restart and settings window construction")
}
