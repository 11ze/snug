// 一块屏此刻该在，以及它该是什么样：ScreenPlan 按配置和会话算出来交给 DeskSet，
// ScreenSet 按身份和比例建撤、在线换比例，Desk 按行为参数放窗口。
// 谁也不认手机、平板、电脑：类别到行为的映射只在 ScreenPlan 里（见 docs/multi-screen.md 4.1）
import CoreGraphics
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

/// 屏的身份：系统按 vendorID + productID + 序列号记住一块屏的设置、排布和 ICC 文件。
/// 数值全部实测过（见记忆 project-phone-screen 和 docs/multi-screen.md 第 7 节）
public struct ScreenSpec: Equatable, Sendable {
    /// 'SN'：认出自己建的屏
    public static let vendorID: UInt32 = 0x534E
    /// 竖屏、横屏的产品号：竖屏沿用 2.5 以前手机屏的 0x00F0，横屏另起 0x00F1
    public static let portraitProductID: UInt32 = 0x00F0
    public static let landscapeProductID: UInt32 = 0x00F1
    /// 建好不到这么久就释放会让 WindowServer 卡死（原作者实测）
    public static let minimumLifetime: TimeInterval = 2.5

    /// 在「显示器」设置和 UU远程 的屏幕列表里看到的名字（UU 列成「显示屏 N (名字)」）
    public var name: String
    /// 竖屏 0x00F0（2.5 以前的手机屏就是它），横屏 0x00F1
    public var productID: UInt32
    /// 序列号：固定一个，建了不上线就依次换备用的。固定身份能让系统记住这块屏的设置；每多用一个新身份，系统就多存一份 ICC 文件。
    /// 号码添加时分配、永不复用，免得系统把旧屏的记忆套到新屏上
    public var serials: [UInt32]
    /// 像素上限，框住这块屏的所有档位；必须和屏的方向一致（横屏上限的屏上，竖着的档不能用，V4）
    public var maxPixels: CGSize

    public init(name: String, productID: UInt32, serials: [UInt32], maxPixels: CGSize) {
        self.name = name
        self.productID = productID
        self.serials = serials
        self.maxPixels = maxPixels
    }

    /// 物理尺寸按像素上限、约 220ppi 折算。按设备的真实密度（手机 460ppi）算，全新身份的屏永远不上线，
    /// 而且这个身份从此被系统「拉黑」，改回来也不行
    public var millimeters: CGSize {
        CGSize(width: maxPixels.width / 220 * 25.4, height: maxPixels.height / 220 * 25.4)
    }
}

/// 一块屏上的行为，ScreenPlan 按型号的类别给
public struct ScreenBehavior: Equatable, Sendable {
    /// 触屏用的屏（手机、平板）：屏上有 App 资源库和小横条，放上来的窗口铺满整块屏、按窗口换档。
    /// 电脑屏没有面板，App 资源库从菜单栏打开，窗口只挪过来，大小不动
    public var touch: Bool
    /// 这块屏上翻不翻译手势
    public var gestures: Bool
    /// 放上来时放大字号（按 App 记住的级数，没记过用设置里的默认级数）
    public var zooms: Bool

    public init(touch: Bool, gestures: Bool, zooms: Bool) {
        self.touch = touch
        self.gestures = gestures
        self.zooms = zooms
    }

    /// 手机屏一直以来的样子
    public static let phone = ScreenBehavior(touch: true, gestures: true, zooms: true)
}

public struct ScreenWish: Equatable, Sendable {
    public let id: ScreenID
    public var spec: ScreenSpec
    public var fit: ScreenFit
    public var behavior: ScreenBehavior
    /// 建好后设为主屏、撤之前设回原来的主屏（最多一块，见 docs/multi-screen.md 2.6）
    public var main: Bool

    public init(id: ScreenID, spec: ScreenSpec, fit: ScreenFit, behavior: ScreenBehavior, main: Bool = false) {
        self.id = id
        self.spec = spec
        self.fit = fit
        self.behavior = behavior
        self.main = main
    }
}
