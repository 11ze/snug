// 设置页、「关于 Snug」、欢迎页共用的行标题：系统设置那样的彩色方块图标（SF Symbols）+ 标题 + 一行短说明；
// 以及权限那几行的标题、状态和「授权…」按钮
import PermissionFlow
import SwiftUI

struct SettingLabel: View {
    let title: String
    var detail: String?
    /// 说明是要用户注意的问题：橙色、带警示图标，和正常状态区分开
    var warning = false
    let symbol: String
    let tint: Color

    init(_ title: String, detail: String? = nil, warning: Bool = false, symbol: String, tint: Color) {
        self.title = title
        self.detail = detail
        self.warning = warning
        self.symbol = symbol
        self.tint = tint
    }

    /// 图标块取设计令牌（mac.iconTile）
    init(_ title: String, detail: String? = nil, warning: Bool = false, tile: TileToken) {
        self.init(title, detail: detail, warning: warning, symbol: tile.symbol, tint: tile.color)
    }

    var body: some View {
        HStack(spacing: MacTokens.Space.m) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: MacTokens.Size.iconTile, height: MacTokens.Size.iconTile)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: MacTokens.Radius.iconTile, style: .continuous))
            VStack(alignment: .leading, spacing: MacTokens.Space.xxs) {
                Text(title)
                if let detail, warning {
                    Label(detail, systemImage: "exclamationmark.triangle.fill").font(.callout).foregroundStyle(MacTokens.Color.warning)
                } else if let detail {
                    Text(detail).font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }
}

extension SettingLabel {
    /// 辅助功能权限那一行（欢迎页、设置页）
    static var accessibility: SettingLabel {
        SettingLabel(PermissionName.accessibility, detail: "用于移动窗口与转换手势", tile: MacTokens.IconTile.accessibility)
    }

    /// 录屏权限那一行（设置的通用页）
    static var screenRecording: SettingLabel {
        SettingLabel(PermissionName.screenRecording, detail: "只有截图要用", tile: MacTokens.IconTile.screenRecording)
    }
}

/// 权限的状态：已授权带一个小对勾，未授权只写字。「授权…」放在各页的主按钮位置，不在这一行重复
struct PermissionStatus: View {
    let granted: Bool

    var body: some View {
        if granted {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).imageScale(.small)
                Text("已授权").foregroundStyle(.secondary)
            }
        } else {
            Text("未授权").foregroundStyle(.secondary)
        }
    }
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
