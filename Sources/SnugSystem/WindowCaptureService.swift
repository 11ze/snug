// 截图和剪贴板的系统实现：ScreenCaptureKit 截窗口，NSPasteboard 写剪贴板。
// 截窗口要「屏幕录制」权限，和辅助功能是两回事：第一次调用由系统弹窗，macOS 14 上允许后要重启 App 才生效
import AppKit
@preconcurrency import ScreenCaptureKit
import SnugCore

@MainActor
public final class WindowCaptureService: WindowCapturing {
    public init() {}

    /// 只读当前状态，不会弹窗
    public var trusted: Bool { CGPreflightScreenCaptureAccess() }

    public func requestPermission() -> Bool {
        // 没授权时这个调用弹系统的授权提示；已经授权直接返回 true，不再弹
        CGRequestScreenCaptureAccess()
    }

    public func capture(_ window: WindowKey) async throws -> CapturedImage {
        guard trusted else { throw CaptureFailure.noPermission }
        let content: SCShareableContent
        do {
            // onScreenWindowsOnly 传 false：窗口在别的桌面空间、刚铺满手机屏时也找得到，按编号认，不怕多
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        } catch {
            // 没有权限时这里也会失败（SCStreamErrorDomain -3801），和别的原因分开报
            throw trusted ? CaptureFailure.unavailable : CaptureFailure.noPermission
        }
        guard let target = content.windows.first(where: { $0.windowID == window.id }) else {
            throw CaptureFailure.windowGone
        }
        let filter = SCContentFilter(desktopIndependentWindow: target)
        // 按窗口的点尺寸乘屏幕的倍率给像素尺寸：截出来就是 Retina 原画，不是放大过的
        let scale = CGFloat(filter.pointPixelScale)
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int((target.frame.width * scale).rounded()))
        configuration.height = max(1, Int((target.frame.height * scale).rounded()))
        configuration.showsCursor = false
        let image: CGImage
        do {
            image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        } catch {
            throw CaptureFailure.unavailable
        }
        let rep = NSBitmapImageRep(cgImage: image)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw CaptureFailure.unavailable
        }
        return CapturedImage(png: png, pixelWidth: image.width, pixelHeight: image.height)
    }
}

/// 剪贴板：清空后只放这一张 PNG。其它 App 粘出来就是图，不用管原来剪贴板里是什么
public struct SystemClipboard: ClipboardWriting {
    public init() {}

    public func write(_ image: CapturedImage) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setData(image.png, forType: .png)
    }
}
