import AppKit
import SwiftUI

@MainActor
final class RecentDrawer {
    private var window: NSWindow?
    func refreshLanguage() { window?.title = AppLanguage.translate("最近文件") }
    func show(line: Line) {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 460),
                                  styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = AppLanguage.translate("最近文件")
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: RecentFilesView(line: line))
            window.center()
            self.window = window
        }
        refreshLanguage()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct RecentFilesView: View {
    @ObservedObject var line: Line
    @State private var query = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(AppLanguage.translate("搜索文件名称"), text: $query)
                .textFieldStyle(.roundedBorder)
            Text(AppLanguage.translate("最多保留 200 个近期文件入口；源文件仍在原位置。"))
                .font(.caption).foregroundStyle(.secondary)
            List(line.recentFiles(matching: query), id: \.path) { file in
                HStack {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: file.path))
                        .resizable().frame(width: 28, height: 28)
                    VStack(alignment: .leading) {
                        Text(file.url.lastPathComponent).lineLimit(1)
                        Text(file.url.deletingLastPathComponent().path)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Button(AppLanguage.translate("挂上")) {
                        do { try line.attachFiles([file.url]) }
                        catch { NSAlert(error: error).runModal() }
                    }
                }
                .onDrag { NSItemProvider(object: file.url as NSURL) }
                .contextMenu {
                    Button(AppLanguage.translate("打开")) { NSWorkspace.shared.open(file.url) }
                    Button(AppLanguage.translate("在 Finder 中显示")) { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }
                }
            }
            if line.recentFiles(matching: query).isEmpty {
                Text(AppLanguage.translate(query.isEmpty ? "暂无最近文件" : "没有匹配的文件")).foregroundStyle(.secondary)
            }
        }.padding(16).frame(minWidth: 400, minHeight: 300)
    }
}
