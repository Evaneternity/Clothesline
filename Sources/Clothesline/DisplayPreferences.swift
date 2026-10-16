import Foundation

/// Shared by settings, folder monitoring and the pointer controller.
struct DisplayPreferences {
    static let hoverKey = "lineHoverDelay"
    static let lifetimesKey = "monitoredFolderLifetimes"
    static let defaultHoverDelay: TimeInterval = 0.5
    static let defaultLifetime: TimeInterval = 24 * 60 * 60
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var hoverDelay: TimeInterval {
        get {
            guard defaults.object(forKey: Self.hoverKey) != nil else { return Self.defaultHoverDelay }
            return Self.normalizedHoverDelay(defaults.double(forKey: Self.hoverKey))
        }
        nonmutating set { defaults.set(Self.normalizedHoverDelay(newValue), forKey: Self.hoverKey) }
    }

    static func normalizedHoverDelay(_ value: TimeInterval) -> TimeInterval {
        guard value.isFinite else { return defaultHoverDelay }
        return (min(10, max(0, value)) * 10).rounded() / 10
    }

    /// Zero means no expiration. Positive values are seconds, up to one year.
    func lifetime(for folder: URL) -> TimeInterval {
        let values = defaults.dictionary(forKey: Self.lifetimesKey) ?? [:]
        guard let value = values[folder.standardizedFileURL.path] as? NSNumber else { return Self.defaultLifetime }
        return Self.normalizedLifetime(value.doubleValue)
    }

    func setLifetime(_ value: TimeInterval, for folder: URL) {
        var values = defaults.dictionary(forKey: Self.lifetimesKey) ?? [:]
        values[folder.standardizedFileURL.path] = Self.normalizedLifetime(value)
        defaults.set(values, forKey: Self.lifetimesKey)
    }

    private static func normalizedLifetime(_ value: TimeInterval) -> TimeInterval {
        guard value.isFinite, value >= 0 else { return defaultLifetime }
        return value == 0 ? 0 : min(365 * 24 * 60 * 60, max(60, value))
    }
}

struct FolderExpirationPolicy {
    var lifetimes: [String: TimeInterval] = [:]

    func includes(_ file: DownloadFile, now: Date) -> Bool {
        let parent = file.url.deletingLastPathComponent().standardizedFileURL.path
        guard let lifetime = lifetimes[parent], lifetime > 0 else { return true }
        // Directory modifications must not extend the lifetime of old downloads.
        // recency uses addedToDirectoryDate, falling back to creation time.
        return now.timeIntervalSince(file.recency) < lifetime
    }
}

/// Monotonic times prevent wall-clock changes from completing a hover early.
struct LineRevealController {
    private var enteredTopAt: TimeInterval?
    private var lastInside: TimeInterval?

    mutating func reset() {
        enteredTopAt = nil
        lastInside = nil
    }

    mutating func reveal(atTop: Bool, overLine: Bool, isRevealed: Bool,
                         hasItems: Bool, alwaysVisible: Bool, interactionHeld: Bool = false,
                         externalDrag: Bool = false,
                         delay: TimeInterval, now: TimeInterval) -> Bool {
        if interactionHeld {
            enteredTopAt = nil
            lastInside = now
            return isRevealed
        }
        guard hasItems || externalDrag else {
            reset()
            return alwaysVisible
        }
        if atTop {
            if enteredTopAt == nil { enteredTopAt = now }
        } else { enteredTopAt = nil }
        let waited = enteredTopAt.map { now - $0 >= delay } ?? false
        if (atTop && (isRevealed || waited)) || (isRevealed && overLine) {
            lastInside = now
        }
        return alwaysVisible || (lastInside.map { now - $0 < 0.75 } ?? false)
    }
}
