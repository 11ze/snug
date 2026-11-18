// 屏幕列表里一项的身份：配置、还原账、屏的状态都按它对应
import Foundation

/// 屏幕列表里的一项：添加时生成，之后不变。还原账、屏的身份都按它对应
public struct ScreenID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) { self.rawValue = rawValue }

    /// 新加的屏：随机生成，不会和以前的重复
    public static func make() -> ScreenID { ScreenID(UUID().uuidString.lowercased()) }

    /// 2.5 及以前那块「Snug 手机屏」迁过来的 id
    public static let phone = ScreenID("phone")

    public var description: String { rawValue }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}
