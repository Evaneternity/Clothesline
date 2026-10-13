import Foundation

/// Platform-independent filtering and download-completion gate.
/// A filename alone is not evidence that a browser has finished writing it.
struct DownloadFile: Equatable {
    let url: URL
    let size: Int64
    let modified: Date
    let created: Date
    let added: Date?

    var path: String { url.standardizedFileURL.path }
    var recency: Date { added ?? created }
    /// Keeps an intentionally dismissed file hidden until a *new* download replaces it.
    var fingerprint: String {
        "\(path)|\(size)|\(modified.timeIntervalSince1970)|\(created.timeIntervalSince1970)"
    }
}

enum DownloadIndex {
    private static let temporarySuffixes: Set<String> = [
        "crdownload", "download", "part", "partial", "tmp", "temp",
        "opdownload", "aria2", "filepart", "dms", "downloadfile"
    ]

    static func isCandidateName(_ name: String) -> Bool {
        guard !name.isEmpty, !name.hasPrefix("."), !name.hasPrefix("~$") else { return false }
        let ext = (name as NSString).pathExtension.lowercased()
        return !temporarySuffixes.contains(ext) && !name.hasSuffix(".DS_Store")
    }

    static func scan(_ directory: URL) throws -> [DownloadFile] {
        let keys: [URLResourceKey] = [
            .isRegularFileKey, .isHiddenKey, .fileSizeKey,
            .creationDateKey, .contentModificationDateKey, .addedToDirectoryDateKey
        ]
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
        // Browsers can keep a temporary sibling while streaming into a
        // final-looking destination filename. Suppress that destination until
        // the sibling disappears (e.g. foo.pdf.crdownload -> foo.pdf).
        let inProgress = Set(urls.compactMap { url -> String? in
            let ext = url.pathExtension.lowercased()
            return temporarySuffixes.contains(ext) ? url.deletingPathExtension().lastPathComponent : nil
        })
        return urls.compactMap { url -> DownloadFile? in
            guard isCandidateName(url.lastPathComponent),
                  !inProgress.contains(url.lastPathComponent),
                  let info = try? url.resourceValues(forKeys: Set(keys)),
                  info.isRegularFile == true,
                  info.isHidden != true,
                  let size = info.fileSize, size >= 0 else { return nil }
            let modified = info.contentModificationDate ?? .distantPast
            let created = info.creationDate ?? modified
            return DownloadFile(url: url, size: Int64(size), modified: modified,
                                created: created, added: info.addedToDirectoryDate)
        }
        .sorted { a, b in
            if a.recency != b.recency { return a.recency > b.recency }
            return a.path > b.path
        }
    }
}

/// Requires two identical file-stat samples, and enough time after the last write.
/// For an existing completed download this adds ~1s on app launch; for a large
/// ongoing download it prevents premature display even when already named .zip.
struct DownloadCompletionGate {
    private struct Signature: Equatable {
        let size: Int64
        let modified: Date
        let created: Date
    }
    private var previous: [String: Signature] = [:]
    private var counts: [String: Int] = [:]
    private let requiredSamples: Int
    private let quietPeriod: TimeInterval

    init(requiredSamples: Int = 2, quietPeriod: TimeInterval = 2) {
        self.requiredSamples = max(2, requiredSamples)
        self.quietPeriod = quietPeriod
    }

    mutating func completed(_ files: [DownloadFile], now: Date = Date()) -> [DownloadFile] {
        var next: [String: Signature] = [:]
        var nextCounts: [String: Int] = [:]
        var finished: [DownloadFile] = []
        for file in files {
            let key = file.path
            let signature = Signature(size: file.size, modified: file.modified,
                                      created: file.created)
            next[key] = signature
            let count = previous[key] == signature ? (counts[key] ?? 0) + 1 : 1
            nextCounts[key] = count
            // Some browsers first create the destination file and then stream
            // into it. Both a quiet write window and stable samples are needed.
            let recentlyTouched = max(file.modified, file.added ?? file.created)
            if count >= requiredSamples && now.timeIntervalSince(recentlyTouched) >= quietPeriod {
                finished.append(file)
            }
        }
        previous = next
        counts = nextCounts
        return finished
    }
}
