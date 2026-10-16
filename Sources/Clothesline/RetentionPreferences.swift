import Foundation

struct RetentionPreferences {
    static let retentionKey = "itemRetentionLifetime"
    static let legacyLifetimesKey = "monitoredFolderLifetimes"
    static let defaultLifetime: TimeInterval = 0
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// One lifetime for automatic files, folders, clipboard images and notes.
    /// Preserve a previous directory choice on upgrade, preferring Downloads.
    var retentionLifetime: TimeInterval {
        get {
            if let saved = defaults.object(forKey: Self.retentionKey) as? NSNumber {
                return Self.normalizedLifetime(saved.doubleValue)
            }
            let legacy = defaults.dictionary(forKey: Self.legacyLifetimesKey) ?? [:]
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.standardizedFileURL.path
            let value = downloads.flatMap { legacy[$0] as? NSNumber }
                ?? legacy.keys.sorted().compactMap { legacy[$0] as? NSNumber }.first
            return value.map { Self.normalizedLifetime($0.doubleValue) } ?? Self.defaultLifetime
        }
        nonmutating set { defaults.set(Self.normalizedLifetime(newValue), forKey: Self.retentionKey) }
    }

    private static func normalizedLifetime(_ value: TimeInterval) -> TimeInterval {
        guard value.isFinite, value >= 0 else { return defaultLifetime }
        return value == 0 ? 0 : min(365 * 24 * 60 * 60, max(60, value))
    }
}

struct ItemExpirationPolicy {
    var lifetime: TimeInterval = 0

    func includes(since date: Date, now: Date) -> Bool {
        lifetime <= 0 || now.timeIntervalSince(date) < lifetime
    }

    func includes(_ file: DownloadFile, now: Date) -> Bool {
        // Editing a file or directory must not renew its entry time.
        includes(since: file.recency, now: now)
    }
}
