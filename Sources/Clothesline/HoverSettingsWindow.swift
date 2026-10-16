import AppKit
import SwiftUI

@MainActor
final class HoverSettingsWindow {
    private(set) var window: NSWindow?

    func show(preferences: HoverPreferences, onChange: @escaping () -> Void) {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 310),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        window?.title = AppLanguage.text("悬停显示晾衣绳延迟", "Hover to Show Clothesline Delay")
        window?.contentView = NSHostingView(rootView: HoverSettingsView(
            preferences: preferences, onChange: onChange,
            onClose: { [weak self] in self?.window?.close() }))
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct HoverSettingsView: View {
    let preferences: HoverPreferences
    let onChange: () -> Void
    let onClose: () -> Void
    @State private var hoverDelay: Double

    init(preferences: HoverPreferences, onChange: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.preferences = preferences
        self.onChange = onChange
        self.onClose = onClose
        _hoverDelay = State(initialValue: preferences.hoverDelay)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(AppLanguage.text("鼠标停留时间", "Pointer hover time"))
                Spacer()
                TextField("", value: $hoverDelay, format: .number.precision(.fractionLength(1)))
                    .frame(width: 70).multilineTextAlignment(.trailing)
                    .accessibilityLabel(AppLanguage.text("悬停显示晾衣绳延迟（秒）", "Hover to show clothesline delay in seconds"))
                Text(AppLanguage.text("秒", "seconds"))
                Stepper("", value: $hoverDelay, in: 0...10, step: 0.1).labelsHidden()
            }
            Text(AppLanguage.text(
                "鼠标在状态栏 / 屏幕顶部连续停留多久后显示晾衣绳。范围 0.0–10.0 秒，精度 0.1 秒；移开后重新计时。",
                "Wait this long at the menu bar / top edge before showing the clothesline. Range: 0.0–10.0 seconds, in 0.1-second steps. Leaving resets the timer."))
            Text(AppLanguage.text(
                "默认 0.0 秒，无需额外等待。文件、文件夹及剪贴板图片 / 文字便签均遵守此设置；自动隐藏模式下，无内容时不弹出。",
                "Default: 0.0 seconds, with no added delay. Applies to files, folders and clipboard images / notes. In auto-hide mode, an empty rope stays hidden."))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Divider()
            HStack {
                Button(AppLanguage.text("恢复默认", "Restore Defaults")) {
                    hoverDelay = HoverPreferences.defaultHoverDelay
                    preferences.hoverDelay = hoverDelay
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
        .onChange(of: hoverDelay) { _, value in
            preferences.hoverDelay = value
            hoverDelay = preferences.hoverDelay
            onChange()
        }
    }
}
