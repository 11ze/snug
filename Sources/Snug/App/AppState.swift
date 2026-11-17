// 发布给界面的状态。界面只读它，改动一律走意图协议（由 AppController 实现）。
// 菜单栏、设置窗口、手机屏上的列表读的是同一份状态：任何入口改了，所有界面一起变
import Foundation
import Observation
import SnugCore

enum ConnectionPhase: Equatable {
    case idle
    case connected
    /// 断开了，还在重连窗口里（这段时间内再连上算同一次远程，手机屏留着）
    case reconnecting
}

@MainActor
@Observable
final class AppState {
    var config = AppConfig()
    /// 机型库（启动时读一次）：设置和手机屏上选手机型号用
    var phones = PhoneCatalog.empty
    var connection = ConnectionPhase.idle
    /// 此刻同时连着的控制端
    var controllers: [String] = []
    /// UU 此刻在推的屏
    var streamedDisplay: DisplayID?
    var phone = PhoneDesk.State()
    /// 手势翻译要开却没开起来（建事件监听失败）
    var gesturesFailed = false
    var accessibilityTrusted = false
    /// 屏幕录制权限：手机屏上的截图要它，和辅助功能分开授权
    var screenRecordingTrusted = false
    var launchAtLogin = false
    /// 上一次打开开机启动没成
    var loginItemIssue: LoginItemIssue?
    /// 上一次改设置没能写进 config.json
    var configSaveFailed = false
    /// 旧版「UU远程伴侣」正在运行
    var legacyAppRunning = false
    /// 正在退出收尾
    var quitting = false
    /// 应用内更新：查到了什么、进行到哪（Updater 写）
    var update = UpdateState()
    /// 手机屏上截图之后的文字提示，3 秒后收起（见 PhoneScreenshot）
    var captureToast: CaptureToast?
    /// 截图之后的预览：底部浮缩略图，点开进裁剪，几秒后自己收起（见 PhoneScreenshot）
    var capturePreview: CapturePreview?

    init() {}

    /// UU 正在推手机屏，也就是用户此刻正在手机屏上
    var phoneInUse: Bool {
        guard let display = phone.display else { return false }
        return streamedDisplay == display
    }

    /// 只在值真的变了时才写，免得每拍都让界面重算
    func update<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<AppState, T>, _ value: T) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
    }
}

extension AppState {
    /// 手机屏底部浮出来的文字提示：只报结果，不拦操作
    struct CaptureToast: Equatable {
        /// 每换一条换一个号，界面靠它重新计时
        let id: Int
        let symbol: String
        let text: String
    }

    /// 截图之后的预览：底部浮一条带缩略图的提示，点开可以裁掉不要的部分。
    /// 不进裁剪的话几秒后自己收起，剪贴板里已经是整张图了
    struct CapturePreview: Equatable {
        /// 每换一张换一个号，界面靠它重新计时
        let id: Int
        let png: Data
        let pixelWidth: Int
        let pixelHeight: Int
        /// 正在裁剪：盖满手机屏，手势翻译要停掉
        var cropping = false
    }
}

enum LoginItemIssue: Equatable {
    /// 用户在「登录项」里关过 Snug，要在那里允许
    case needsApproval
    /// Snug 不在「应用程序」里
    case notInApplications
    case failed
}

/// 设置窗口、菜单栏能发起的意图。AppController 是唯一实现（渲染 PNG 时用一个什么都不做的替身）。
/// Sendable：实现都是 @MainActor 的类型，状态受主线程隔离保护，可以安全地交给视图——不标的话，
/// 把 intents.setPhone 这种函数引用存进视图属性时，Swift 6.2 会当成非 Sendable 值跨隔离域传递而报错
@MainActor
protocol AppIntents: AnyObject, Sendable {
    func setPhoneScreen(_ on: Bool)
    func setGestures(_ on: Bool)
    func setZoomSteps(_ steps: Int)
    func setLaunchAtLogin(_ on: Bool)
    /// 开机启动待允许：直接打开系统设置的「登录项」
    func openLoginItemsSettings()
    func markWelcomed()
    func quitLegacyApp()
    func quit()
    func checkForUpdates()
    func installUpdate()
    func setUpdateSource(_ source: UpdateSource)
    /// 自动更新走不通时，打开所选更新源的下载地址
    func openDownloadPage()
    /// 换手机型号：手机屏在就马上换成它的比例
    func setPhone(_ phone: PhoneChoice)
    /// 手机屏上的截图要屏幕录制权限：请系统弹一次授权，再把系统设置打开
    func openScreenRecordingSettings()
}

/// 手机屏上的 App 资源库和小横条能发起的意图
@MainActor
protocol PhoneIntents: AnyObject, Sendable {
    func pull(_ window: WindowInfo)
    /// 点一个 App：在跑且有窗口就放最近用过的那个，否则打开它、等新窗口出来再放（见 AppList.action）
    func open(_ app: AppInfo)
    func newWindow(_ app: RunningApp)
    func quit(_ app: RunningApp)
    func forceQuit(pid: Int32, app: String)
    func close(_ window: WindowInfo)
    func dismissNotice()
    func showList()
    func returnToPlaced()
    func putBack()
    func zoom(by delta: Int)
    func setPhone(_ phone: PhoneChoice)
    /// 退出手机屏：这次远程不再显示（见 PhoneDesk.dismissScreen）
    func dismissScreen()
    /// 按当前状态重算手势翻译：裁剪界面开着时停掉，不然手指拖动画框会被翻译成滚动
    func syncGestures()
}

/// 打开各个窗口
@MainActor
protocol Navigation: AnyObject, Sendable {
    func openSettings()
    func openWelcome()
    func openAbout()
    func openUpdate()
}
