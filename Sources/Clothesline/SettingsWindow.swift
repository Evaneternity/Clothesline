import AppKit
import SwiftUI

@MainActor
final class SettingsWindow {
    private(set) var window: NSWindow?

    func show(preferences: DisplayPreferences, folders: [URL], onChange: @escaping () -> Void) {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 470),
                                  styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 500, height: 360)
            window.center()
            self.window = window
        }
        window?.title = AppLanguage.text("Clothesline 设置", "Clothesline Settings")
        window?.contentView = NSHostingView(rootView: DisplaySettingsView(
            preferences: preferences, folders: folders, onChange: onChange))
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct DisplaySettingsView: View {
    let preferences: DisplayPreferences
    let folders: [URL]
    let onChange: () -> Void
    @State private var hoverDelay: Double

    init(preferences: DisplayPreferences, folders: [URL], onChange: @escaping () -> Void) {
        self.preferences = preferences
        self.folders = folders
        self.onChange = onChange
        _hoverDelay = State(initialValue: preferences.hoverDelay)
    }

    var body: some View {
        Form {
            Section(AppLanguage.text("悬停展示", "Hover to Reveal")) {
                HStack {
                    Text(AppLanguage.text("状态栏停留时间", "Menu bar hover delay"))
                    Spacer()
                    TextField("", value: $hoverDelay, format: .number.precision(.fractionLength(1)))
                        .frame(width: 65)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel(AppLanguage.text("状态栏停留时间（秒）", "Hover delay in seconds"))
                    Text(AppLanguage.text("秒", "seconds"))
                    Stepper("", value: $hoverDelay, in: 0...10, step: 0.1).labelsHidden()
                }
                Text(AppLanguage.text("0.0–10.0 秒，步长 0.1 秒。移开鼠标会重新计时；没有可显示项目时不弹出。",
                                      "0.0–10.0 seconds in 0.1-second steps. Leaving the menu bar resets the timer. An empty clothesline stays hidden."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(AppLanguage.text("监控文件过期时间", "Watched Item Expiration")) {
                Text(AppLanguage.text("按进入目录的时间计算，无法获取时使用创建时间。文件和文件夹到期后自动隐藏，原文件保留；固定、手动挂载和剪贴板项目不受影响。",
                                      "Age is measured from entry into the folder, falling back to creation time. Expired files and folders are hidden; originals stay in place. Pins, manually hung items and clipboard items are kept."))
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(folders, id: \.standardizedFileURL.path) { folder in
                    FolderLifetimeRow(folder: folder, preferences: preferences, onChange: onChange)
                }
            }
            Text(AppLanguage.text("修改立即保存。“一直显示晾衣绳”仍可主动显示空绳。",
                                  "Changes are saved immediately. Always Show Clothesline can still display an empty rope."))
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .onChange(of: hoverDelay) { _, value in
            preferences.hoverDelay = value
            hoverDelay = preferences.hoverDelay
            onChange()
        }
    }
}

private struct FolderLifetimeRow: View {
    let folder: URL
    let preferences: DisplayPreferences
    let onChange: () -> Void
    @State private var expires: Bool
    @State private var amount: Double
    @State private var unit: Double

    init(folder: URL, preferences: DisplayPreferences, onChange: @escaping () -> Void) {
        self.folder = folder
        self.preferences = preferences
        self.onChange = onChange
        let lifetime = preferences.lifetime(for: folder)
        let value = lifetime > 0 ? lifetime : DisplayPreferences.defaultLifetime
        let unit: Double = value.truncatingRemainder(dividingBy: 86400) == 0 ? 86400 :
            (value.truncatingRemainder(dividingBy: 3600) == 0 ? 3600 : 60)
        _expires = State(initialValue: lifetime > 0)
        _amount = State(initialValue: value / unit)
        _unit = State(initialValue: unit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(folder.lastPathComponent).font(.headline)
            Text(folder.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            HStack {
                Toggle(AppLanguage.text("到期隐藏", "Hide after"), isOn: $expires)
                Spacer()
                TextField("", value: $amount, format: .number.precision(.fractionLength(0...1)))
                    .frame(width: 70)
                    .accessibilityLabel(AppLanguage.text("保留时长", "Retention duration"))
                    .disabled(!expires)
                Picker("", selection: $unit) {
                    Text(AppLanguage.text("分钟", "minutes")).tag(60.0)
                    Text(AppLanguage.text("小时", "hours")).tag(3600.0)
                    Text(AppLanguage.text("天", "days")).tag(86400.0)
                }.labelsHidden().frame(width: 95).disabled(!expires)
            }
            if !expires {
                Text(AppLanguage.text("永不过期", "Never expire")).font(.caption).foregroundStyle(.secondary)
            }
        }
        .onChange(of: expires) { _, _ in save() }
        .onChange(of: amount) { _, _ in save() }
        .onChange(of: unit) { _, _ in save() }
    }

    private func save() {
        if expires {
            // A checked row always has a positive lifetime, even when typed as zero.
            preferences.setLifetime(max(60, amount * unit), for: folder)
            amount = preferences.lifetime(for: folder) / unit
        } else { preferences.setLifetime(0, for: folder) }
        onChange()
    }
}
