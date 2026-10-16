import AppKit

/// Best-effort detection using public window metadata, without reading window
/// titles, capturing the screen, requesting permissions, or using private APIs.
/// Dock's window layers are undocumented and may change between macOS releases.
@MainActor
final class MissionControlAvoidance {
    struct DockWindow {
        let layer: Int
        let bounds: CGRect
    }

    private let readWindows: @MainActor () -> [DockWindow]
    private var windows: [DockWindow] = []
    private var checkedAt: TimeInterval?

    init(readWindows: @escaping @MainActor () -> [DockWindow] = { MissionControlAvoidance.dockWindows() }) {
        self.readWindows = readWindows
    }

    func reset() {
        checkedAt = nil
        windows = []
    }

    func clearance(for screenBounds: CGRect, now: TimeInterval, responsive: Bool) -> CGFloat {
        // Window enumeration is relatively expensive; never run it at the
        // pointer timer's 20 Hz. Check faster while showing/dragging the rope.
        let interval: TimeInterval = responsive ? 0.2 : 1
        if checkedAt.map({ now - $0 >= interval || now < $0 }) ?? true {
            windows = readWindows()
            checkedAt = now
        }
        return Self.clearance(for: screenBounds, windows: windows)
    }

    /// CGWindow coordinates are top-down relative to the primary display, not
    /// NSScreen.main (which follows focus). Negative coordinates are valid.
    static func windowBounds(for screenFrame: CGRect, primaryFrame: CGRect) -> CGRect {
        CGRect(x: screenFrame.minX, y: primaryFrame.maxY - screenFrame.maxY,
               width: screenFrame.width, height: screenFrame.height)
    }

    static func clearance(for screen: CGRect, windows: [DockWindow]) -> CGFloat {
        guard screen.width > 0, screen.height > 0 else { return 0 }
        var clearance: CGFloat = 0
        for window in windows where window.layer == 18 || window.layer == 20 {
            let bounds = window.bounds
            guard bounds.width.isFinite, bounds.height.isFinite,
                  bounds.minX.isFinite, bounds.minY.isFinite,
                  bounds.maxY.isFinite,
                  bounds.width >= screen.width * 0.9,
                  bounds.intersection(screen).width >= screen.width * 0.9 else { continue }
            if window.layer == 18 && bounds.intersection(screen).height >= screen.height * 0.9 {
                // Full Mission Control / App Exposé uses a screen-sized layer
                // 18 surface. Its strip may not have separate window bounds.
                clearance = max(clearance, min(280, max(160, screen.height * 0.22)))
            } else if abs(bounds.minY - screen.minY) <= 24,
                      bounds.height >= 32 && bounds.height <= screen.height * 0.4 {
                // A wide, shallow Dock surface at this display's top edge:
                // the Spaces strip shown during a Finder drag.
                clearance = max(clearance, bounds.maxY - screen.minY + 16)
            }
            // A full-screen layer 20 surface alone is also present on an idle
            // desktop on recent macOS versions, so it is deliberately ignored.
        }
        return clearance
    }

    static func dockWindows() -> [DockWindow] {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first,
              let info = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]]
        else { return [] }
        return dockWindows(in: info, ownerPID: dock.processIdentifier)
    }

    static func dockWindows(in info: [[String: Any]], ownerPID: pid_t) -> [DockWindow] {
        info.compactMap { window in
            guard (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == ownerPID,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  let dictionary = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dictionary) else { return nil }
            return DockWindow(layer: layer, bounds: bounds)
        }
    }
}
