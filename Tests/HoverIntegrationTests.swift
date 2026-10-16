import AppKit

@MainActor
func testHoverSettings() throws {
    func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }
    let suite = "Clothesline-Display-\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = HoverPreferences(defaults: defaults)
    check(preferences.hoverDelay == 0, "default hover delay")
    preferences.hoverDelay = 1.26
    check(HoverPreferences(defaults: defaults).hoverDelay == 1.3, "delay persists at 0.1s precision")
    preferences.hoverDelay = -1
    check(preferences.hoverDelay == 0, "negative delay clamped")
    preferences.hoverDelay = .infinity
    check(preferences.hoverDelay == 0, "invalid delay falls back safely")
    preferences.hoverDelay = 100
    check(preferences.hoverDelay == 10, "delay upper bound")
    var reveal = LineRevealController()
    func poll(_ time: Double, top: Bool = true, over: Bool = false, shown: Bool = false,
              items: Bool = true, pinned: Bool = false, held: Bool = false, delay: Double = 0.5) -> Bool {
        reveal.reveal(atTop: top, overLine: over, isRevealed: shown, hasItems: items,
                      alwaysVisible: pinned, interactionHeld: held, delay: delay, now: time)
    }
    check(!poll(0) && !poll(0.4), "brief hover stays hidden")
    check(!poll(0.45, top: false), "leaving cancels hover")
    check(!poll(1) && !poll(1.4) && poll(1.5), "new hover waits full delay")
    check(poll(1.6, top: false, over: true, shown: true), "pointer can move onto cards")
    check(poll(2.0, top: false, shown: true), "brief leave grace period")
    check(!poll(2.4, top: false, shown: true), "hides after grace period")
    reveal.reset()
    check(!poll(3, items: false) && !poll(30, items: false), "empty rope never opens on hover")
    check(!poll(30.1) && poll(30.6), "new arrival starts fresh dwell")
    check(!poll(30.7, shown: true, items: false), "last expiration hides even while at top")
    check(poll(31, items: false, pinned: true), "explicit always-visible still works")
    reveal.reset()
    check(poll(32, delay: 0), "zero delay reveals on first sample")
    check(poll(33, top: false, shown: true, items: false, held: true), "drag retains source when scan expires")
    check(!poll(34, top: false, shown: true, items: false), "drag completion permits empty hide")
    reveal.reset()
    check(!poll(35, delay: 1.3) && !poll(36.2, delay: 1.3) && poll(36.4, delay: 1.3),
          "noninteger configurable delay")
    reveal.reset()
    check(!poll(40), "screen/settings changes reset dwell")
    reveal.reset()
    check(!reveal.reveal(atTop: true, overLine: false, isRevealed: false, hasItems: false,
                         alwaysVisible: false, externalDrag: true, delay: 0.5, now: 50), "empty drop target waits for hover")
    check(reveal.reveal(atTop: true, overLine: false, isRevealed: false, hasItems: false,
                        alwaysVisible: false, externalDrag: true, delay: 0.5, now: 51), "intentional Finder drag can populate an empty rope")
    print("PASS: delayed reveal, hover cancellation, empty suppression, drag hold and always-visible")

    let shared = UserDefaults.standard
    let keys = ["attachedFolderBookmarks", "pinnedFiles", "recentFileBookmarks", "dismissedFiles", "menuLanguage"]
    let saved = keys.map { shared.object(forKey: $0) }
    keys.forEach { shared.removeObject(forKey: $0) }
    defer {
        for (key, value) in zip(keys, saved) {
            if let value { shared.set(value, forKey: key) }
            else { shared.removeObject(forKey: key) }
        }
    }
    let line = Line()
    let board = NSPasteboard.withUniqueName()
    defer { line.clearClipboardStorage(); board.releaseGlobally() }
    let intake = ClipboardMonitor(pasteboard: board, defaults: defaults) { content, manual in
        try line.attachClipboard(content, manual: manual)
    }
    intake.setTextEnabled(true)
    intake.setImagesEnabled(true)
    board.clearContents(); board.setString("hover note", forType: .string)
    intake.poll()
    precondition(line.items.count == 1 && !line.revealed, "automatic notes wait for pointer dwell")
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.setColor(.blue, atX: 0, y: 0)
    let png = bitmap.representation(using: .png, properties: [:])!
    board.clearContents(); board.setData(png, forType: .png)
    intake.poll()
    precondition(line.items.count == 2 && !line.revealed, "automatic images wait for pointer dwell")
    var clipboardReveal = LineRevealController()
    func pointer(_ time: TimeInterval) -> Bool {
        clipboardReveal.reveal(atTop: true, overLine: false, isRevealed: line.revealed,
                               hasItems: !line.items.isEmpty, alwaysVisible: false, delay: 0.5, now: time)
    }
    precondition(!pointer(100) && !pointer(100.4), "clipboard-only rope waits for configured delay")
    precondition(pointer(100.5), "clipboard-only rope reveals at the delay boundary")
    let before = board.changeCount
    try line.attachClipboard(.text("explicit capture"), manual: true)
    precondition(line.revealed && board.changeCount == before, "explicit capture reveals without writing clipboard")

    let view = GrabView()
    var pressed = false
    var sawMenu = false
    view.onPressChange = { pressed = $0 }
    view.menuProvider = {
        sawMenu = true
        precondition(pressed, "context menu holds its card before tracking")
        var controller = LineRevealController()
        precondition(controller.reveal(atTop: false, overLine: false, isRevealed: true,
                                      hasItems: false, alwaysVisible: false, interactionHeld: pressed,
                                      delay: 1, now: 100), "menu source remains revealed away from the rope")
        return NSMenu()
    }
    let event = NSEvent.mouseEvent(with: .rightMouseDown, location: .zero, modifierFlags: [],
                                  timestamp: 0, windowNumber: 0, context: nil,
                                  eventNumber: 0, clickCount: 1, pressure: 0)!
    view.rightMouseDown(with: event)
    precondition(sawMenu && !pressed, "menu releases its source after tracking")

    let delegate = AppDelegate()
    let menu = NSMenu()
    for language in AppLanguage.allCases {
        AppLanguage.current = language
        delegate.menuNeedsUpdate(menu)
        let index = menu.items.firstIndex { $0.title == AppLanguage.translate("自动隐藏晾衣绳") }!
        precondition(menu.items[index + 1].title == AppLanguage.translate("悬停显示晾衣绳延迟…"))
        let window = HoverSettingsWindow()
        window.show(preferences: preferences, onChange: {})
        precondition(window.window?.isVisible == true && window.window?.title ==
                     AppLanguage.text("悬停显示晾衣绳延迟", "Hover to Show Clothesline Delay"))
        window.window?.close()
    }
    print("PASS: hover precision, boundaries, reset/empty/drag behavior, clipboard intake, menu hold and bilingual settings")
}
