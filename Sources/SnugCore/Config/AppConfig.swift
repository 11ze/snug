// 用户设置（config.json）。App 层的 AppController 是唯一写入者
import Foundation

public struct AppConfig: Codable, Equatable, Sendable {
    /// 屏幕列表：远程时建出开着的那几块（见 ScreenPlan）。新装只有一块竖屏手机屏
    public var screens = [ScreenConfig.legacyPhone(.standard, enabled: true)]
    /// 远程时设为主屏的那块；nil 表示不改主屏（默认）
    public var mainScreen: ScreenID?
    /// 下一块新加的屏用哪一段序列号（只增不减：删掉的屏的号也不回收，免得系统把旧屏的记忆套到新屏上）
    public var nextSerialBlock = 0
    /// 手机、平板屏上把 UU 发来的单指操作翻译成 iPhone 的手势
    public var gestures = true
    /// 手机、平板屏底部小横条左边放相机键：截当前窗口到剪贴板。要另授「录屏与系统录音」权限，默认关
    public var screenshot = false
    /// 窗口放上手机、平板屏时，字号默认放大几级（每个 App 改过之后按它自己记住的级数）
    public var zoomSteps = 2
    /// 是否已看过首次启动的欢迎页
    public var welcomed = false
    /// 从哪检查和下载更新。UU远程 的用户基本在国内，默认腾讯云
    public var updateSource = UpdateSource.tencent
    /// 上次运行的版本：和这次不一样说明刚换了版本，启动时弹「关于 Snug」
    public var lastVersion: Version?

    public static let zoomStepsRange = 0...4
    /// 新加的屏的序列号从这里起，每块一段（主号加两个备用）。和 2.5 以前手机屏的 200_000_108 起的那组、实验用的 999_000_xxx 都不重
    static let serialBase: UInt32 = 200_100_000

    public init() {}

    /// 加一块屏：分配一段没用过的序列号，名字按型号起
    public mutating func addScreen(orientation: Orientation, device: DeviceChoice, name: String? = nil) -> ScreenConfig {
        let base = Self.serialBase + UInt32(nextSerialBlock) * 10
        nextSerialBlock += 1
        let screen = ScreenConfig(id: .make(), orientation: orientation, device: device, enabled: true,
                                  name: name ?? ScreenConfig.suggestedName(for: device, orientation: orientation),
                                  serials: [base, base + 1, base + 2])
        screens.append(screen)
        return screen
    }

    public mutating func removeScreen(_ id: ScreenID) {
        screens.removeAll { $0.id == id }
        if mainScreen == id { mainScreen = nil }
    }

    /// 2.5.x 还在读的两项：取第一块竖屏手机屏的值，降级回去照样能用（过两个大版本再停写，见 docs/multi-screen.md 5.5）
    var legacyPhone: ScreenConfig? { screens.first { $0.orientation == .portrait && $0.device.kind == .phone } }

    private enum CodingKeys: String, CodingKey {
        case screens, mainScreen, nextSerialBlock, phoneScreen, gestures, screenshot, zoomSteps, phone, welcomed, updateSource, lastVersion
    }

    // 每一项都有默认值：以后加字段、或者手改漏了某项，都不会让整份配置被判为损坏
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppConfig()
        if c.contains(.screens) {
            // 逐项解：手改坏了的那一项（取值不认识、缺字段、分辨率不对、重了号）丢掉并记一笔，不连累别的。
            // 键在却不是列表就整份按损坏处理（ConfigStore 隔离原文件）：当成 2.5 的配置迁移的话，下次写盘就把列表覆盖了
            var seen = Set<ScreenID>()
            var screens: [ScreenConfig] = []
            for (i, item) in try c.decode([Lossy<ScreenConfig>].self, forKey: .screens).enumerated() {
                switch item.result {
                case .success(let screen) where screen.device.screen.isValid && !screen.serials.isEmpty && !seen.contains(screen.id):
                    seen.insert(screen.id)
                    screens.append(screen)
                case .success(let screen):
                    Log.warn("配置里第 \(i + 1) 块屏「\(screen.name)」数值不合格（分辨率不对、没有序列号或重了号），丢掉这一项")
                case .failure(let error):
                    Log.warn("配置里第 \(i + 1) 块屏解不开，丢掉这一项：\(error)")
                }
            }
            self.screens = screens
        } else {
            // 2.5 及以前：一块竖屏手机屏，开关和型号沿用；手改坏了的型号（缺字段、横着写、不是正数）用默认值
            let enabled = try c.decodeIfPresent(Bool.self, forKey: .phoneScreen) ?? true
            let phone = (try? c.decodeIfPresent(DeviceChoice.self, forKey: .phone)).flatMap { $0.screen.isValid ? $0 : nil } ?? .standard
            screens = [.legacyPhone(phone, enabled: enabled)]
        }
        mainScreen = (try? c.decodeIfPresent(ScreenID.self, forKey: .mainScreen)).flatMap { id in screens.contains { $0.id == id } ? id : nil }
        nextSerialBlock = max(0, (try? c.decodeIfPresent(Int.self, forKey: .nextSerialBlock)) ?? 0)
        gestures = try c.decodeIfPresent(Bool.self, forKey: .gestures) ?? d.gestures
        screenshot = try c.decodeIfPresent(Bool.self, forKey: .screenshot) ?? d.screenshot
        zoomSteps = try c.decodeIfPresent(Int.self, forKey: .zoomSteps).map { $0.clamped(to: Self.zoomStepsRange) } ?? d.zoomSteps
        welcomed = try c.decodeIfPresent(Bool.self, forKey: .welcomed) ?? d.welcomed
        // 不认识的更新源（更新的版本加的、降级回来）用默认值
        updateSource = (try? c.decodeIfPresent(UpdateSource.self, forKey: .updateSource)) ?? d.updateSource
        lastVersion = try? c.decodeIfPresent(Version.self, forKey: .lastVersion)
    }
}

/// 解不开也不抛的一项：列表里坏了的那一项单独丢掉，不让整个列表解不开
private struct Lossy<Value: Decodable>: Decodable {
    let result: Result<Value, any Error>

    init(from decoder: any Decoder) throws {
        result = Result { try Value(from: decoder) }
    }
}

extension AppConfig {
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(screens, forKey: .screens)
        try c.encodeIfPresent(mainScreen, forKey: .mainScreen)
        try c.encode(nextSerialBlock, forKey: .nextSerialBlock)
        // 旧版读的两项：没有竖屏手机屏时写成关着的默认手机。多出的 kind 旧版不认、照样解得开
        try c.encode(legacyPhone?.enabled ?? false, forKey: .phoneScreen)
        try c.encode(legacyPhone?.device ?? .standard, forKey: .phone)
        try c.encode(gestures, forKey: .gestures)
        try c.encode(screenshot, forKey: .screenshot)
        try c.encode(zoomSteps, forKey: .zoomSteps)
        try c.encode(welcomed, forKey: .welcomed)
        try c.encode(updateSource, forKey: .updateSource)
        try c.encodeIfPresent(lastVersion, forKey: .lastVersion)
    }
}
