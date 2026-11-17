// 权限在系统设置里的叫法，菜单、设置页、欢迎页、手机屏提示都用它，用户照着字面就能在系统设置里找到；
// 以及打开授权引导的「授权…」按钮
import PermissionFlow
import SwiftUI

enum PermissionName {
    /// macOS 27 起叫「设备控制和数据访问」，更早叫「辅助功能」
    static let accessibility = PermissionFlowResources.localizedString(
        for: PermissionFlowResources.accessibilityName(), localeIdentifier: "zh-Hans")
    /// macOS 15 起叫「录屏与系统录音」，更早叫「屏幕录制」（PermissionFlow 只有旧叫法）
    static let screenRecording = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 15 ? "录屏与系统录音" : "屏幕录制"
}

/// 「授权…」：PermissionFlow 打开系统设置对应的隐私页，旁边浮出一个小窗口，把 Snug 拖进列表即可
struct AuthorizeButton: View {
    let pane: PermissionFlowPane

    var body: some View {
        let app = Bundle.main.bundleURL
        PermissionFlowButton(
            pane: pane,
            suggestedAppURLs: [app],
            configuration: .init(requiredAppURLs: [app], promptForAccessibilityTrust: false, localeIdentifier: "zh-Hans")
        ) { _ in
            Text("授权…")
        }
    }
}
