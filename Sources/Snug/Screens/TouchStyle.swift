// 手机、平板屏上界面的字号、尺寸与颜色，数值全部取设计令牌（design/design-tokens.json 的 touch）。
// 手机竖屏 1 点在手机上约 0.82 点，所以字和按钮都按 iOS 的大小放大一档，看起来才和手机上的原生 App 一样大；
// 平板上照样用这些数（V10：约大 1.24 倍，字大、舒服）。颜色用 iOS 的分组背景色（macOS 没有对应的系统色）
import AppKit
import SwiftUI

enum TouchStyle {
    static let largeTitle = TouchTokens.Font.largeTitle.font
    static let headline = TouchTokens.Font.headline.font
    static let body = TouchTokens.Font.body.font
    static let label = TouchTokens.Font.label.font
    static let caption = TouchTokens.Font.caption.font

    /// 手指点得准的最小高度（iOS 44 点 × 1.25）
    static let touchTarget = TouchTokens.Size.touchTarget
    static let cornerRadius = TouchTokens.Radius.card
    static let iconSize = TouchTokens.Size.listIcon
    /// 页面左右的边距
    static let margin = TouchTokens.Space.margin

    static let background = TouchTokens.Color.background
    static let card = TouchTokens.Color.card
    static var backgroundNSColor: NSColor { NSColor(background) }
    static let fill = TouchTokens.Color.fill
    static let segment = TouchTokens.Color.segment
    /// 不跟 Mac 的强调色走，手机上的 App 都是这个蓝
    static let tint = TouchTokens.Color.tint
    static let tintFill = TouchTokens.Color.tintFill
}

/// 按下时轻微变暗，松手恢复（手机上点下去要有反馈）；正在忙、点不了时变淡，看得出来点不了
struct PressableStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? MotionTokens.pressedOpacity : 1) : MotionTokens.disabledOpacity)
            .contentShape(Rectangle())
    }
}
