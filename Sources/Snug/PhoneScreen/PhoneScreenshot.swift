// 手机屏上的截图：点底部小横条左边的相机键，截下铺满手机屏的窗口，直接进电脑剪贴板。
// 截完底部浮一条带缩略图的提示，点开可以裁掉不要的部分，裁好的那块替换剪贴板里的整张图。
// 没授权时先请系统弹一次授权；macOS 14 上授权后要重启 Snug 才生效，如实提示，不假装截成了
import AppKit
import SnugCore
import SnugSystem

@MainActor
final class PhoneScreenshot {
    /// 文字提示留多久
    static let toastDuration: TimeInterval = 3
    /// 缩略图留多久：比文字长一点，留出点它的时间
    static let previewDuration: TimeInterval = 5

    private let state: AppState
    private let window: any WindowCapturing
    private let clipboard: any ClipboardWriting
    /// 正在截：连点不再叠一次
    private var busy = false
    private var hideTimer: Timer?
    /// 提示每换一条就换一个号，界面靠它重新计时
    private var serial = 0

    /// 传 nil 用系统实现：默认值在 init 里再建，免得在 nonisolated 的默认参数里碰主线程隔离的构造
    init(state: AppState,
         window: (any WindowCapturing)? = nil,
         clipboard: (any ClipboardWriting)? = nil) {
        self.state = state
        self.window = window ?? WindowCaptureService()
        self.clipboard = clipboard ?? SystemClipboard()
    }

    /// 此刻有没有屏幕录制权限（设置页显示、定时刷新）
    var trusted: Bool { window.trusted }

    /// 截当前铺满手机屏的窗口。没有窗口、正在截时点它不起作用
    func take() {
        guard let placed = state.phone.placed, !busy else { return }
        guard window.trusted else {
            if requestPermission() {
                Log.info("截图：屏幕录制已授权，等重启生效")
                show(symbol: "arrow.clockwise.circle.fill", text: "已允许屏幕录制，重启 Snug 后生效")
            } else {
                show(symbol: "hand.raised.fill", text: "先在系统设置里允许屏幕录制")
            }
            return
        }
        busy = true
        Task { @MainActor in
            defer { busy = false }
            let started = Date()
            do {
                let image = try await window.capture(placed.window.key)
                guard clipboard.write(image) else {
                    Log.warn("截图：剪贴板写不进去（\(placed.window.label)）")
                    show(symbol: "exclamationmark.triangle.fill", text: "剪贴板被别的程序占着，没写进去")
                    return
                }
                Log.info("截图：\(placed.window.label) → 剪贴板 \(image.sizeText)，\(image.png.count) 字节，"
                    + String(format: "%.2fs", Date().timeIntervalSince(started)))
                showPreview(image)
            } catch CaptureFailure.windowGone {
                Log.warn("截图：窗口已经关了（\(placed.window.label)）")
                show(symbol: "exclamationmark.triangle.fill", text: "窗口已经关了，没截成")
            } catch CaptureFailure.noPermission {
                // 中途被收回权限：和开头没授权走同一条路
                if requestPermission() {
                    show(symbol: "arrow.clockwise.circle.fill", text: "已允许屏幕录制，重启 Snug 后生效")
                } else {
                    show(symbol: "hand.raised.fill", text: "先在系统设置里允许屏幕录制")
                }
            } catch {
                Log.warn("截图失败（\(placed.window.label)）：\(error)")
                show(symbol: "exclamationmark.triangle.fill", text: "这次没截到，再试一次")
            }
        }
    }

    // MARK: 裁剪

    /// 点缩略图：进裁剪。正在裁剪时再点不起作用
    func openCrop() {
        guard var preview = state.capturePreview, !preview.cropping else { return }
        cancelHide()
        preview.cropping = true
        state.capturePreview = preview
    }

    /// 取消裁剪：回到缩略图，剪贴板里还是整张图
    func cancelCrop() {
        guard var preview = state.capturePreview, preview.cropping else { return }
        preview.cropping = false
        state.capturePreview = preview
        scheduleHide(after: Self.previewDuration)
    }

    /// 完成裁剪：selection 是裁剪界面里的选区，area 是图片在那块界面里占的区域（都是点）。
    /// 裁好的图替换剪贴板；裁不出来就留着整张图并说明
    func finishCrop(selection: CGRect, area: CGRect) {
        guard let preview = state.capturePreview else { return }
        let image = CapturedImage(png: preview.png, pixelWidth: preview.pixelWidth, pixelHeight: preview.pixelHeight)
        let pixels = CropGeometry.pixelRect(selection: selection, image: CGSize(width: preview.pixelWidth, height: preview.pixelHeight),
                                            in: area)
        guard let cropped = ImageCrop.crop(image, to: pixels), clipboard.write(cropped) else {
            Log.warn("截图裁剪：裁不出来（选区 \(pixels)），剪贴板里留着整张图")
            closePreview()
            show(symbol: "exclamationmark.triangle.fill", text: "没裁出来，剪贴板里还是整张图")
            return
        }
        Log.info("截图裁剪：\(image.sizeText) 的 \(pixels) → \(cropped.sizeText)，\(cropped.png.count) 字节")
        closePreview()
        show(symbol: "checkmark.circle.fill", text: "已复制选区 \(cropped.sizeText)")
    }

    /// 请系统弹一次屏幕录制的授权；弹不出来（已经授权过、或系统这次不弹）就打开系统设置让人自己看。
    /// 返回是否已授权：macOS 14 上授权后要重启 App 才生效，调用方据此说清楚
    @discardableResult
    func requestPermission() -> Bool {
        if window.requestPermission() { return true }
        openScreenRecordingSettings()
        return false
    }

    func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: 提示

    /// 截图成功：底部浮缩略图，几秒后自己收起（剪贴板里已经是整张图了）
    private func showPreview(_ image: CapturedImage) {
        serial += 1
        state.capturePreview = AppState.CapturePreview(id: serial, png: image.png,
                                                       pixelWidth: image.pixelWidth, pixelHeight: image.pixelHeight)
        state.captureToast = nil
        scheduleHide(after: Self.previewDuration)
    }

    /// 裁完、出错这类一句话的结果
    private func show(symbol: String, text: String) {
        serial += 1
        let toast = AppState.CaptureToast(id: serial, symbol: symbol, text: text)
        state.captureToast = toast
        state.capturePreview = nil
        hideTimer?.invalidate()
        let timer = Timer(timeInterval: Self.toastDuration, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.state.captureToast?.id == toast.id else { return }
                self.state.captureToast = nil
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        hideTimer = timer
    }

    /// 到点收起缩略图（正在裁剪时不收）
    private func scheduleHide(after seconds: TimeInterval) {
        hideTimer?.invalidate()
        let id = serial
        let timer = Timer(timeInterval: seconds, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.state.capturePreview?.id == id, self.state.capturePreview?.cropping == false else { return }
                self.state.capturePreview = nil
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        hideTimer = timer
    }

    private func closePreview() {
        hideTimer?.invalidate()
        state.capturePreview = nil
    }

    private func cancelHide() {
        hideTimer?.invalidate()
        hideTimer = nil
    }
}
