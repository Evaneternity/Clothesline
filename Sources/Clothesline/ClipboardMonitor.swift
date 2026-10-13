import AppKit
import CryptoKit

/// Reads only new clipboard changes for explicitly enabled types.
/// Owned copies carry a marker so the app cannot feed its own clipboard back.
enum ClipboardContent {
    case image(Data)
    case text(String)
    var data: Data {
        switch self { case .image(let data): return data; case .text(let text): return Data(text.utf8) }
    }
    var isText: Bool { if case .text = self { return true }; return false }
    var identity: String {
        (isText ? "text:" : "image:") + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
final class ClipboardMonitor {
    static let ownMarker = NSPasteboard.PasteboardType("app.clothesline.owned-copy")
    private let pasteboard: NSPasteboard
    private let defaults: UserDefaults
    private let onCapture: (ClipboardContent, Bool) throws -> Void
    private var changeCount: Int
    private var timer: Timer?
    private(set) var failure: String?
    var imagesEnabled: Bool { defaults.bool(forKey: "clipboardImagesEnabled") }
    var textEnabled: Bool { defaults.bool(forKey: "clipboardTextEnabled") }

    init(pasteboard: NSPasteboard = .general, defaults: UserDefaults = .standard,
         onCapture: @escaping (ClipboardContent, Bool) throws -> Void) {
        self.pasteboard = pasteboard; self.defaults = defaults; self.onCapture = onCapture
        changeCount = pasteboard.changeCount
    }
    func setImagesEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: "clipboardImagesEnabled")
        changeCount = pasteboard.changeCount
    }
    func setTextEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: "clipboardTextEnabled")
        changeCount = pasteboard.changeCount
    }
    func start() {
        stop()
        changeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }
    func stop() { timer?.invalidate(); timer = nil }
    func poll() {
        guard imagesEnabled || textEnabled else { return }
        let count = pasteboard.changeCount
        guard count != changeCount else { return }
        changeCount = count
        guard pasteboard.data(forType: Self.ownMarker) == nil else { return }
        do {
            if let content = readContent(images: imagesEnabled, text: textEnabled) {
                guard pasteboard.changeCount == count else { return }
                try onCapture(content, false)
            }
            failure = nil
        } catch { failure = error.localizedDescription }
    }
    @discardableResult
    func captureCurrent() throws -> Bool {
        let count = pasteboard.changeCount
        guard let content = readContent(images: true, text: true), pasteboard.changeCount == count else { return false }
        try onCapture(content, true)
        changeCount = count
        failure = nil
        return true
    }
    private func readContent(images: Bool, text: Bool) -> ClipboardContent? {
        // Finder file copies remain files, never notes containing file paths.
        guard !(pasteboard.types ?? []).contains(.fileURL) else { return nil }
        if images {
            for type in [NSPasteboard.PasteboardType.png, .tiff] {
                if let data = pasteboard.data(forType: type), data.count <= 32 * 1024 * 1024,
                   let bitmap = NSBitmapImageRep(data: data),
                   let png = bitmap.representation(using: .png, properties: [:]) {
                    return .image(png)
                }
            }
        }
        // Do not turn an image's alternative string into a note when images are off.
        if (pasteboard.types ?? []).contains(.png) || (pasteboard.types ?? []).contains(.tiff) { return nil }
        if text, let value = pasteboard.string(forType: .string), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           value.utf8.count <= 200_000 { return .text(value) }
        return nil
    }
    static func markOwned(_ pasteboard: NSPasteboard) {
        pasteboard.setData(Data([1]), forType: ownMarker)
    }
}
