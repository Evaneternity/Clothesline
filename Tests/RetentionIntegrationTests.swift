import AppKit

@MainActor
func testRetentionSettings() throws {
    testRetentionPreferences()
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
    let preferences = RetentionPreferences(defaults: isolated)
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
    preferences.retentionLifetime = 60
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
    precondition(line.items.isEmpty, "files and folders across all monitors expire together")
    precondition(line.recentFiles(matching: "", now: future).isEmpty,
                 "recent drawer also filters expired automatic entries")
    let firstBytes = try Data(contentsOf: first)
    let childBytes = try Data(contentsOf: directory.appendingPathComponent("child.txt"))
    precondition(firstBytes == bytes && childBytes == bytes, "expiration never touches original bytes")
    preferences.retentionLifetime = 3600
    monitors.refresh()
    line.adopt(delivered, expiration: monitors.expirationPolicy)
    line.updateVisibleItems(now: future)
    precondition(line.items.count == 3, "increasing lifetime restores items without clearing dismissal records")

    preferences.retentionLifetime = 60
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
    preferences.retentionLifetime = 0
    line.adopt(fresh, expiration: monitors.expirationPolicy)
    precondition(!line.items.contains { $0.file.path == first.standardizedFileURL.path }, "never-expire does not undo explicit dismissal")

    let settings = RetentionSettingsWindow()
    settings.show(preferences: preferences, onChange: {})
    precondition(settings.window?.isVisible == true && settings.window?.title ==
                 AppLanguage.text("保留文件时间", "Item Retention Time"))
    settings.window?.close()
    let delegate = AppDelegate()
    let menu = NSMenu()
    let savedLanguage = AppLanguage.current
    for language in AppLanguage.allCases {
        AppLanguage.current = language
        delegate.menuNeedsUpdate(menu)
        let index = menu.items.firstIndex { $0.title == AppLanguage.translate("保留文件数量") }!
        precondition(menu.items[index + 1].title == AppLanguage.translate("保留文件时间…"))
    }
    AppLanguage.current = savedLanguage
    // A session containing only clipboard items obeys the same display controls.
    defaults.removeObject(forKey: "attachedFolderBookmarks")
    defaults.removeObject(forKey: "dismissedFiles")
    let clipboardLine = Line()
    clipboardLine.setExpirationPolicy(ItemExpirationPolicy(lifetime: 60))
    let board = NSPasteboard.withUniqueName()
    defer { clipboardLine.clearClipboardStorage(); board.releaseGlobally() }
    var capturedAt = Date().addingTimeInterval(-30)
    let firstCapture = capturedAt
    let intake = ClipboardMonitor(pasteboard: board, defaults: isolated) { content, manual in
        try clipboardLine.attachClipboard(content, manual: manual, now: capturedAt)
    }
    intake.setTextEnabled(true)
    intake.setImagesEnabled(true)
    board.clearContents(); board.setString("clipboard timing note", forType: .string)
    intake.poll()
    precondition(clipboardLine.items.count == 1,
                 "automatic notes enter the retention model")
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.setColor(.blue, atX: 0, y: 0)
    let png = bitmap.representation(using: .png, properties: [:])!
    board.clearContents(); board.setData(png, forType: .png)
    intake.poll()
    precondition(clipboardLine.items.count == 2,
                 "automatic images enter the retention model")
    let ownedURLs = clipboardLine.items.map(\.url)
    let clipboardVersion = board.changeCount
    clipboardLine.maxItems = 1; clipboardLine.updateVisibleItems()
    precondition(clipboardLine.items.count == 1, "item count applies to clipboard content")
    clipboardLine.maxItems = 8; clipboardLine.updateVisibleItems()
    let noteID = clipboardLine.items.first { $0.noteText != nil }!.id

    clipboardLine.refreshExpiration(now: firstCapture.addingTimeInterval(59))
    precondition(clipboardLine.items.count == 2, "clipboard items remain before boundary")
    clipboardLine.pressedID = noteID
    clipboardLine.refreshExpiration(now: firstCapture.addingTimeInterval(60))
    precondition(clipboardLine.items.count == 2, "clipboard expiry retains pressed source")
    clipboardLine.pressedID = nil; clipboardLine.draggingID = noteID
    clipboardLine.refreshExpiration(now: firstCapture.addingTimeInterval(60))
    precondition(clipboardLine.items.count == 2, "clipboard expiry retains dragged source")
    clipboardLine.draggingID = nil
    clipboardLine.refreshExpiration(now: firstCapture.addingTimeInterval(60))
    precondition(clipboardLine.items.isEmpty, "expired clipboard-only rope has no remaining cards")
    precondition(board.changeCount == clipboardVersion && board.data(forType: .png) == png,
                 "expiration does not change the system-equivalent pasteboard")
    precondition(ownedURLs.allSatisfy { FileManager.default.fileExists(atPath: $0.path) },
                 "expiration hides session files so increasing retention can restore them")
    clipboardLine.setExpirationPolicy(ItemExpirationPolicy(lifetime: 120))
    clipboardLine.refreshExpiration(now: firstCapture.addingTimeInterval(60))
    precondition(clipboardLine.items.count == 2, "longer lifetime restores clipboard items")
    clipboardLine.setExpirationPolicy(ItemExpirationPolicy())
    clipboardLine.refreshExpiration(now: firstCapture.addingTimeInterval(100000))
    precondition(clipboardLine.items.count == 2, "unlimited applies to clipboard items")
    clipboardLine.setExpirationPolicy(ItemExpirationPolicy(lifetime: 60))
    let currentNote = clipboardLine.items.first { $0.noteText != nil }!
    try clipboardLine.editNote(currentNote.id, text: "edited timing note")
    clipboardLine.interactionHeld = true
    clipboardLine.refreshExpiration(now: firstCapture.addingTimeInterval(60))
    precondition(clipboardLine.items.count == 2, "active note editor keeps its source until it closes")
    clipboardLine.interactionHeld = false
    clipboardLine.refreshExpiration(now: firstCapture.addingTimeInterval(60))
    precondition(clipboardLine.items.isEmpty, "editing does not renew the clipboard capture time")
    clipboardLine.revealed = false
    capturedAt = firstCapture.addingTimeInterval(61)
    board.clearContents(); board.setString("edited timing note", forType: .string); intake.poll()
    precondition(clipboardLine.items.count == 1,
                 "copying expired content again renews its age")
    capturedAt = firstCapture.addingTimeInterval(71)
    board.clearContents(); board.setString("edited timing note", forType: .string); intake.poll()
    clipboardLine.refreshExpiration(now: firstCapture.addingTimeInterval(121))
    precondition(clipboardLine.items.isEmpty, "ordinary duplicates do not extend retention")
    precondition(clipboardLine.recent.allSatisfy { !ownedURLs.contains($0.url) }, "clipboard history stays session-only")
    let capacityLine = Line()
    defer { capacityLine.clearClipboardStorage() }
    capacityLine.maxItems = 1
    capacityLine.setExpirationPolicy(ItemExpirationPolicy(lifetime: 60))
    let captureTime = Date()
    try capacityLine.attachClipboard(.text("older note"), now: captureTime)
    try capacityLine.attachClipboard(.text("newer note"), now: captureTime.addingTimeInterval(30))
    try capacityLine.attachClipboard(.text("older note"), now: captureTime.addingTimeInterval(61))
    precondition(capacityLine.items.first?.noteText == "older note",
                 "recaptured expired content takes the newest slot at capacity")

    let menuSource = capacityLine.items[0].id
    let menuView = GrabView()
    var heldDuringMenu = false
    menuView.onPressChange = {
        capacityLine.pressedID = $0 ? menuSource : nil
        if !$0 { capacityLine.refreshExpiration(now: captureTime.addingTimeInterval(122)) }
    }
    menuView.menuProvider = {
        heldDuringMenu = capacityLine.pressedID == menuSource
        capacityLine.refreshExpiration(now: captureTime.addingTimeInterval(122))
        precondition(capacityLine.items.contains { $0.id == menuSource },
                     "context menu keeps its source while expiration refreshes")
        return NSMenu()
    }
    let menuEvent = NSEvent.mouseEvent(with: .rightMouseDown, location: .zero, modifierFlags: [],
                                      timestamp: 0, windowNumber: 0, context: nil,
                                      eventNumber: 0, clickCount: 1, pressure: 0)!
    menuView.rightMouseDown(with: menuEvent)
    precondition(heldDuringMenu && capacityLine.pressedID == nil && capacityLine.items.isEmpty,
                 "context menu releases its source and applies pending expiration when closed")
    print("PASS: clipboard image/note item count, retention, no pasteboard changes, drag/editor hold, restore/unlimited and recapture")
    print("PASS: live multi-folder expiration, source safety, drag deferral, restore/unlimited, pins/manual/restart and settings window construction")
}

private func testRetentionPreferences() {
    func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }
    let now = Date()
    func file(_ path: String) -> DownloadFile {
        DownloadFile(url: URL(fileURLWithPath: "/tmp/" + path), size: 100,
                     modified: now, created: now.addingTimeInterval(-120), added: now.addingTimeInterval(-10))
    }
    let suite = "Clothesline-Retention-Core-\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = RetentionPreferences(defaults: defaults)
    let parent = URL(fileURLWithPath: "/tmp")
    let otherParent = URL(fileURLWithPath: "/tmp/another")
    check(preferences.retentionLifetime == 0, "default keeps items indefinitely")
    let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!.standardizedFileURL.path
    defaults.set([downloads: 86400, otherParent.path: 3600], forKey: RetentionPreferences.legacyLifetimesKey)
    check(preferences.retentionLifetime == 86400, "migration preserves the existing Downloads choice")
    preferences.retentionLifetime = 60
    check(RetentionPreferences(defaults: defaults).retentionLifetime == 60, "shared retention persists")
    preferences.retentionLifetime = 0
    check(preferences.retentionLifetime == 0, "explicit unlimited overrides legacy preferences")
    preferences.retentionLifetime = -1
    check(preferences.retentionLifetime == 0, "invalid retention falls back to default")
    let policy = ItemExpirationPolicy(lifetime: 60)
    let recent = file("recent.pdf")
    let expired = DownloadFile(url: parent.appendingPathComponent("old"), size: 0, modified: now,
                               created: now.addingTimeInterval(-1000), added: now.addingTimeInterval(-60), isDirectory: true)
    let noAddedDate = DownloadFile(url: parent.appendingPathComponent("no-added.txt"), size: 1, modified: now,
                                   created: now.addingTimeInterval(-60), added: nil)
    check(policy.includes(recent, now: now), "recent arrival included")
    check(!policy.includes(recent, now: now.addingTimeInterval(50)), "expires exactly at boundary without new scan data")
    check(!policy.includes(expired, now: now), "directory modification does not renew arrival age")
    check(!policy.includes(noAddedDate, now: now), "missing entry date falls back to creation")
    let unlimited = DownloadFile(url: otherParent.appendingPathComponent("old.txt"), size: 1,
                                 modified: .distantPast, created: .distantPast, added: nil)
    check(!policy.includes(unlimited, now: now), "one retention applies to every automatic source")
    check(ItemExpirationPolicy().includes(unlimited, now: now), "zero retention means never expire")
    print("PASS: display preference persistence/precision, shared expiration boundaries and migration")

}
