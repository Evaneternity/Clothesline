import Foundation

struct HoverPreferences {
    static let hoverKey = "lineHoverDelay"
    static let defaultHoverDelay: TimeInterval = 0
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
}
