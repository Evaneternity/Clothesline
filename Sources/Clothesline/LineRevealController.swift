import Foundation

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
