import AppKit
import SwiftUI

@MainActor
final class RetentionSettingsWindow {
    private(set) var window: NSWindow?

    func show(preferences: RetentionPreferences, onChange: @escaping () -> Void) {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 310),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        window?.title = AppLanguage.text("保留文件时间", "Item Retention Time")
        window?.contentView = NSHostingView(rootView: RetentionSettingsView(
            preferences: preferences, onChange: onChange,
            onClose: { [weak self] in self?.window?.close() }))
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct RetentionSettingsView: View {
    let preferences: RetentionPreferences
    let onChange: () -> Void
    let onClose: () -> Void
    @State private var expires: Bool
    @State private var amount: Double
    @State private var unit: Double

    init(preferences: RetentionPreferences, onChange: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.preferences = preferences
        self.onChange = onChange
        self.onClose = onClose
        let lifetime = preferences.retentionLifetime
        let value = lifetime > 0 ? lifetime : 86400
        let unit: Double = value.truncatingRemainder(dividingBy: 86400) == 0 ? 86400 :
            (value.truncatingRemainder(dividingBy: 3600) == 0 ? 3600 : 60)
        _expires = State(initialValue: lifetime > 0)
        _amount = State(initialValue: value / unit)
        _unit = State(initialValue: unit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(AppLanguage.text("到期自动隐藏", "Automatically hide expired items"), isOn: $expires)
            HStack {
                Text(AppLanguage.text("保留时长", "Keep items for"))
                Spacer()
                TextField("", value: $amount, format: .number.precision(.significantDigits(1...6)))
                    .frame(width: 85).multilineTextAlignment(.trailing)
                    .accessibilityLabel(AppLanguage.text("保留时长", "Retention duration"))
                Picker("", selection: $unit) {
                    Text(AppLanguage.text("分钟", "minutes")).tag(60.0)
                    Text(AppLanguage.text("小时", "hours")).tag(3600.0)
                    Text(AppLanguage.text("天", "days")).tag(86400.0)
                }.labelsHidden().frame(width: 100)
            }.disabled(!expires)
            Text(AppLanguage.text(
                "统一用于监控文件、文件夹和剪贴板图片 / 文字便签。文件按进入目录时间计算（缺失时按创建时间），剪贴板按捕获时间计算。",
                "Applies to watched files, folders and clipboard images / notes. Files age from entry into their folder (creation time if unavailable); clipboard items age from capture."))
            Text(AppLanguage.text(
                "范围 1 分钟–365 天；默认关闭，关闭后永不过期。到期只隐藏，原文件和系统剪贴板不变；固定、手动挂上的文件继续保留。",
                "Range: 1 minute–365 days. Off by default; items are kept indefinitely when off. Expiration only hides items; originals and the system clipboard are unchanged. Pinned and manually hung files are kept."))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Divider()
            HStack {
                Button(AppLanguage.text("恢复默认", "Restore Defaults")) {
                    expires = false
                    preferences.retentionLifetime = RetentionPreferences.defaultLifetime
                    onChange()
                }
                Spacer()
                Text(AppLanguage.text("修改立即保存", "Changes save immediately"))
                    .font(.caption).foregroundStyle(.secondary)
                Button(AppLanguage.text("完成", "Done"), action: onClose).keyboardShortcut(.defaultAction)
            }
        }
        .font(.body)
        .padding(20)
        .frame(width: 480, height: 310)
        .onChange(of: expires) { _, _ in saveRetention() }
        .onChange(of: amount) { _, _ in saveRetention() }
        .onChange(of: unit) { _, _ in saveRetention() }
    }

    private func saveRetention() {
        preferences.retentionLifetime = expires ? max(60, amount * unit) : 0
        if expires { amount = preferences.retentionLifetime / unit }
        onChange()
    }
}
