// 策略：配置 + 会话 → 此刻要哪些屏、每块的比例和行为。纯函数，规则只写在这里，换规则不动任何模块（docs/multi-screen.md 3.1、4.2）。
// - 远程开始（含断开后等重连的那段）就建出所有开着的屏：UU 每次新连接都从主屏开始，用户要在 UU 里手动选屏，屏得先在
// - 换手接管落在重连等待期之内，算同一次远程，屏不撤不建（V12）
// - 程序不识别控制端：每块屏用什么比例、有什么行为，只取决于用户的设置，同样的设置每次结果都一样
// - 类别到行为的映射只在这里：手机、平板翻译手势、放大字号、屏上有面板；电脑都不要
import Foundation

/// 会话给出的事实
public struct RemoteFacts: Equatable, Sendable {
    /// 在不在远程（含断开后等重连的那段）
    public var active: Bool
    /// UU 画面那一路在推哪块屏；不知道是 nil
    public var streamed: DisplayID?

    public init(active: Bool, streamed: DisplayID? = nil) {
        self.active = active
        self.streamed = streamed
    }
}

public enum ScreenPlan {
    /// 此刻要的屏，按屏幕列表的顺序。trusted：没有辅助功能权限放不了窗口、翻译不了手势，一块都不建；
    /// preview：不等远程，建出所有开着的屏（--preview-screens）
    public static func wishes(config: AppConfig, remote: RemoteFacts, trusted: Bool, preview: Bool = false) -> [ScreenWish] {
        guard trusted, remote.active || preview else { return [] }
        return config.screens.filter(\.enabled).prefix(ScreenConfig.limit).map { screen in
            ScreenWish(id: screen.id, spec: screen.spec, fit: screen.fit, behavior: behavior(screen.device.kind, gestures: config.gestures),
                       main: config.mainScreen == screen.id)
        }
    }

    /// 类别 → 行为。手势总开关关掉时哪块屏都不翻译
    public static func behavior(_ kind: DeviceKind, gestures: Bool) -> ScreenBehavior {
        switch kind {
        case .phone, .tablet: ScreenBehavior(touch: true, gestures: gestures, zooms: true)
        case .computer: ScreenBehavior(touch: false, gestures: false, zooms: false)
        }
    }
}
