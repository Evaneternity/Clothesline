import AppKit
import ServiceManagement

@MainActor
protocol LoginService: AnyObject {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

@MainActor
final class SystemLoginService: LoginService {
    var status: SMAppService.Status { SMAppService.mainApp.status }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
}

@MainActor
final class LoginItems {
    private let service: LoginService
    init(service: LoginService? = nil) { self.service = service ?? SystemLoginService() }
    var status: SMAppService.Status { service.status }
    // Never register on launch. Only an explicit menu action changes system state.
    func toggle() throws {
        switch service.status {
        case .enabled, .requiresApproval: try service.unregister()
        default: try service.register()
        }
    }
}

struct AppVersion: Comparable, Equatable {
    let numbers: [Int]
    let prerelease: [String]
    init?(_ raw: String) {
        guard !raw.isEmpty else { return nil }
        var text = raw
        if text.hasPrefix("v") { text.removeFirst() }
        guard !text.isEmpty, let main = text.split(separator: "+", maxSplits: 1).first else { return nil }
        let parts = main.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let core = parts[0].split(separator: ".", omittingEmptySubsequences: false)
        guard core.count == 3, core.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) && Int($0) != nil }) else { return nil }
        numbers = core.map { Int($0)! }
        prerelease = parts.count == 2 ? parts[1].split(separator: ".", omittingEmptySubsequences: false).map(String.init) : []
        guard prerelease.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }) }) else { return nil }
    }
    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.numbers != rhs.numbers { return lhs.numbers.lexicographicallyPrecedes(rhs.numbers) }
        if lhs.prerelease.isEmpty { return false }
        if rhs.prerelease.isEmpty { return true }
        for (a, b) in zip(lhs.prerelease, rhs.prerelease) where a != b {
            if let x = Int(a), let y = Int(b) { return x < y }
            if Int(a) != nil { return true }
            if Int(b) != nil { return false }
            return a < b
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }
}

struct GitHubRelease: Decodable {
    let tag_name: String
    let html_url: URL
    let draft: Bool
    let prerelease: Bool
    var safePage: URL? {
        guard html_url.scheme == "https", html_url.host == "github.com", html_url.user == nil,
              html_url.path.hasPrefix("/zhongguozhang/Clothesline/releases/tag/") else { return nil }
        return html_url
    }
}

enum ReleaseSelection {
    static func newest(in data: Data, current: AppVersion) throws -> GitHubRelease? {
        try JSONDecoder().decode([GitHubRelease].self, from: data)
            .filter {
                guard !$0.draft, $0.safePage != nil, let version = AppVersion($0.tag_name) else { return false }
                return !current.prerelease.isEmpty || (!$0.prerelease && version.prerelease.isEmpty)
            }
            .max { AppVersion($0.tag_name)! < AppVersion($1.tag_name)! }
    }
}

@MainActor
final class UpdateChecker {
    private(set) var checking = false
    static let repository = URL(string: "https://github.com/zhongguozhang/Clothesline")!
    static var currentVersion: String { Bundle.main.object(forInfoDictionaryKey: "ClotheslineReleaseVersion") as? String ?? "0.1.0-rc.3" }
    func check() {
        guard !checking else { return }
        checking = true
        Task {
            defer { checking = false }
            do {
                let config = URLSessionConfiguration.ephemeral
                config.timeoutIntervalForRequest = 15; config.timeoutIntervalForResource = 20
                config.httpCookieStorage = nil; config.urlCache = nil
                let session = URLSession(configuration: config)
                defer { session.invalidateAndCancel() }
                var request = URLRequest(url: URL(string: "https://api.github.com/repos/zhongguozhang/Clothesline/releases?per_page=100")!)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("Clothesline/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
                guard let version = AppVersion(Self.currentVersion) else { throw URLError(.cannotParseResponse) }
                let release = try ReleaseSelection.newest(in: data, current: version)
                let alert = NSAlert()
                if let release, let newer = AppVersion(release.tag_name), newer > version {
                    alert.messageText = AppLanguage.text("发现新版本 \(release.tag_name)", "New Version: \(release.tag_name)")
                    alert.informativeText = AppLanguage.text("当前版本 \(Self.currentVersion)。前往 GitHub 查看说明并下载安装包。", "Current version: \(Self.currentVersion). View release notes and download the installer on GitHub.")
                    alert.addButton(withTitle: AppLanguage.text("前往下载", "View Download"))
                    alert.addButton(withTitle: AppLanguage.text("稍后", "Later"))
                    NSApp.activate(ignoringOtherApps: true)
                    if alert.runModal() == .alertFirstButtonReturn, let url = release.safePage { NSWorkspace.shared.open(url) }
                } else {
                    alert.messageText = AppLanguage.text("暂无更新版本", "No Newer Version Available")
                    alert.informativeText = AppLanguage.text("当前版本：\(Self.currentVersion)。", "Current version: \(Self.currentVersion).")
                    alert.addButton(withTitle: AppLanguage.text("好", "OK"))
                    NSApp.activate(ignoringOtherApps: true); alert.runModal()
                }
            } catch {
                let alert = NSAlert()
                alert.messageText = AppLanguage.text("无法检查更新", "Unable to Check for Updates")
                alert.informativeText = AppLanguage.text("请检查网络后重试。", "Check your connection and try again.") + "\n" + error.localizedDescription
                alert.addButton(withTitle: AppLanguage.text("好", "OK"))
                NSApp.activate(ignoringOtherApps: true); alert.runModal()
            }
        }
    }
}
