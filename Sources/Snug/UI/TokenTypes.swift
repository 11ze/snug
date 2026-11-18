// 设计令牌（DesignTokens.swift，生成的）用到的几种值
import AppKit
import SwiftUI

/// 一档字号：字号、字重、行高（点）
struct FontToken: Equatable {
    let size: CGFloat
    let weight: Font.Weight
    let lineHeight: CGFloat

    var font: Font { .system(size: size, weight: weight) }
    /// 行高减去字体自己的行高，排多行文字时补上
    var lineSpacing: CGFloat { max(0, lineHeight - NSFont.systemFont(ofSize: size).boundingRectForFont.height) }
}

/// 设置行左边的彩色小方块：底色和白色的 SF Symbol
struct TileToken: Equatable {
    let color: Color
    let symbol: String
}

/// 远程状态：颜色、图标、说法
struct StatusToken: Equatable {
    let color: Color
    let symbol: String
    let text: String

    /// 画成图标块时只要颜色和图标
    var tile: TileToken { TileToken(color: color, symbol: symbol) }
}

extension NSColor {
    /// 按外观取浅色、深色（iOS 的分组背景色这类 macOS 没有对应系统色的）
    static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }
}
