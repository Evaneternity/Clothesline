import AppKit
import Foundation
import Darwin

/// Observes a single user-authorized Downloads folder.
/// Directory vnode events trigger fast rescans; the slow timer catches events
/// lost during sleep/wake, atomic rename, or filesystem observer replacement.
@MainActor
final class DownloadsWatcher {
    private(set) var folder: URL
    private let onUpdate: ([DownloadFile]) -> Void
    private let onFailure: (String?) -> Void
    private let worker = DispatchQueue(label: "app.clothesline.download-scan", qos: .utility)
    private var source: DispatchSourceFileSystemObject?
    private var timer: Timer?
    private var pending: DispatchWorkItem?
    private var scannerBusy = false
    private var scanAgain = false
    private var generation = 0
    private var gate = DownloadCompletionGate()

    init(folder: URL, onUpdate: @escaping ([DownloadFile]) -> Void,
         onFailure: @escaping (String?) -> Void) {
        self.folder = folder
        self.onUpdate = onUpdate
        self.onFailure = onFailure
    }

    func start() {
        stop()
        gate = DownloadCompletionGate()
        let epoch = generation
        let path = folder.path
        worker.async { [weak self] in
            let fd = open(path, O_EVTONLY)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == epoch else {
                    if fd >= 0 { close(fd) }
                    return
                }
                if fd >= 0 {
                    let src = DispatchSource.makeFileSystemObjectSource(
                        fileDescriptor: fd,
                        eventMask: [.write, .rename, .delete, .attrib, .extend],
                        queue: .main)
                    src.setEventHandler { [weak self] in self?.scheduleScan() }
                    src.setCancelHandler { close(fd) }
                    self.source = src
                    src.resume()
                } else {
                    self.onFailure("Cannot monitor folder. Select Downloads from the menu to grant access.")
                }
                self.scheduleScan()
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleScan(immediate: true) }
        }
    }

    func stop() {
        generation &+= 1
        source?.cancel(); source = nil
        pending?.cancel(); pending = nil
        timer?.invalidate(); timer = nil
        scannerBusy = false
        scanAgain = false
    }

    func scheduleScan(immediate: Bool = false) {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.scan() }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (immediate ? 0 : 0.25), execute: work)
    }

    private func scan() {
        guard !scannerBusy else { scanAgain = true; return }
        scannerBusy = true
        let epoch = generation
        let folder = self.folder
        worker.async { [weak self] in
            let result = Result { try DownloadIndex.scan(folder) }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == epoch else { return }
                self.scannerBusy = false
                switch result {
                case .success(let files):
                    self.onFailure(nil)
                    self.onUpdate(self.gate.completed(files))
                case .failure(let error):
                    self.onFailure(error.localizedDescription)
                }
                if self.scanAgain {
                    self.scanAgain = false
                    self.scheduleScan(immediate: true)
                }
            }
        }
    }

    func wake() {
        // Vnode watching can be invalidated while the Mac is sleeping or a
        // volume is remounted, so recreate the source rather than just polling.
        start()
    }
}
