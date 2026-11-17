// 手机屏上的「截图」：截下铺满手机屏的那个窗口，直接放进电脑剪贴板。
// 截和写剪贴板都要系统接口，在这里定成协议；实现在 SnugSystem，测试里换成假的
import Foundation

/// 截好的一张图（PNG）
public struct CapturedImage: Equatable, Sendable {
    public let png: Data
    public let pixelWidth: Int
    public let pixelHeight: Int

    public init(png: Data, pixelWidth: Int, pixelHeight: Int) {
        self.png = png
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }

    /// 手机屏上提示用「1512 × 982」
    public var sizeText: String { "\(pixelWidth) × \(pixelHeight)" }
}

/// 截图没成的几种情况，措辞归界面层
public enum CaptureFailure: Error, Equatable, Sendable {
    /// 还没有屏幕录制权限
    case noPermission
    /// 窗口已经关了
    case windowGone
    /// 系统这次没给画面（锁屏、窗口刚收起、截流失败）
    case unavailable
}

/// 截一个窗口。主线程：截出来的图转 PNG 用 NSBitmapImageRep，放在主线程省去跨线程搬运
@MainActor
public protocol WindowCapturing: AnyObject {
    /// 此刻有没有屏幕录制权限（系统设置里允许过、并且这次运行已经生效）
    var trusted: Bool { get }
    /// 截 window 的完整画面（被别的窗口挡着也截得到）。失败抛 CaptureFailure
    func capture(_ window: WindowKey) async throws -> CapturedImage
    /// 请系统弹一次屏幕录制的授权提示；已经授权过返回 true。macOS 14 上授权后要重启 App 才生效
    func requestPermission() -> Bool
}

/// 把图放进剪贴板：先清空再放，和系统截图工具一样，粘出来就是这一张
public protocol ClipboardWriting: Sendable {
    /// 成功返回 true；剪贴板被别的程序占着等情况返回 false
    func write(_ image: CapturedImage) -> Bool
}
