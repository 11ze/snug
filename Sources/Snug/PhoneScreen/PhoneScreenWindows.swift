// 手机屏上 Snug 自己的两块面板：盖满整块屏的 App 资源库，和窗口放上来后底部的小横条。
// 跟着 PhoneDesk 的状态走：手机屏在才建，列表该露就露、该收就收，屏幕一变（含换档）就重新摆位置。
// 面板不抢焦点（点它不会激活 Snug），所有桌面都在，盖在这块屏的菜单栏之上；
// 只在搜索、选手机型号时临时接收键盘，用完就还回去，手机上的键盘输入平时留给放上来的窗口
import AppKit
import SnugCore
import SnugSystem
import SwiftUI

@MainActor
final class PhoneScreenWindows {
    private let state: AppState
    private let catalog: AppCatalog
    private let pages = PhonePages()
    private let intents: any PhoneIntents
    private let screenshot: PhoneScreenshot
    private var display: DisplayID?
    private var list: PhonePanel?
    private var homeBar: PhonePanel?
    private var homeBarView: HomeBarView?
    /// 底部浮的那一条：截图缩略图（可点）或一句文字提示（穿透）
    private var bottomPanel: NSPanel?
    /// 此刻浮着的是哪一条（"preview-3" / "toast-4"）：换了才重建视图、换点击穿透
    private var bottomShowing: String?
    /// 裁剪界面：盖满手机屏，拖出选区
    private var cropPanel: PhonePanel?
    /// 上一拍是不是在裁剪：手势翻译要跟着开关
    private var cropping = false
    private var screenObserver: (any NSObjectProtocol)?

    init(state: AppState, catalog: AppCatalog, intents: any PhoneIntents, screenshot: PhoneScreenshot) {
        self.state = state
        self.catalog = catalog
        self.intents = intents
        self.screenshot = screenshot
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        follow()
    }

    private func follow() {
        withObservationTracking {
            _ = state.phone
            _ = state.streamedDisplay
            _ = state.captureToast
            _ = state.capturePreview
            _ = pages.active
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.update()
                    self?.follow()
                }
            }
        }
    }

    private func update() {
        let phone = state.phone
        guard let id = phone.display, let screen = Screens.screen(for: id) else { return tearDown() }
        if id != display {
            tearDown()
            build(on: id)
        }
        guard let list, let homeBar else { return }
        list.setFrame(screen.frame, display: true)
        homeBar.setFrame(homeBarFrame(on: screen), display: true)
        homeBarView?.scale = ScreenFit.scale(screenWidth: screen.frame.width)

        let showList = phone.listVisible || phone.placed == nil
        // 手机在看这块屏。不知道 UU 在推哪块屏（推流日志没读到）时当作在看
        let watching = state.streamedDisplay == nil || state.phoneInUse
        if showList { list.orderFrontRegardless() } else { list.orderOut(nil) }
        // 手机离开了就关掉搜索、手机型号页，交还键盘：不然在主屏上打的字会进到看不见的输入框
        if !showList || !watching { pages.close() }
        // 只在打开页面那一下拿键盘：之后用户点了别的窗口，不能每次状态一变就抢回来
        let entering = pages.active && !list.acceptsKeys
        list.acceptsKeys = pages.active
        if entering { list.makeKey() }
        // 列表每轮要把所有 App 的窗口读一遍，还和搬窗口共用一条队：手机没在看手机屏就不刷
        if showList, watching {
            catalog.startRefreshing()
        } else {
            catalog.stopRefreshing()
        }
        catalog.setPaused(phone.work != nil)
        if phone.placed != nil, !showList { homeBar.orderFrontRegardless() } else { homeBar.orderOut(nil) }
        updateBottom(on: screen)
        updateCrop(on: screen)
    }

    /// 底部浮条：截图后的缩略图优先（要点得到），没有就显示文字提示（只看不点），都没有就收起。
    /// 高度跟着档位放大，胶囊不至于贴到窗口上
    private func updateBottom(on screen: NSScreen) {
        let key: String
        let height: CGFloat
        let interactive: Bool
        if let preview = state.capturePreview, !preview.cropping {
            key = "preview-\(preview.id)"
            height = 96
            interactive = true
        } else if let toast = state.captureToast {
            key = "toast-\(toast.id)"
            height = 72
            interactive = false
        } else {
            bottomPanel?.orderOut(nil)
            bottomShowing = nil
            return
        }
        let panel = bottomPanel ?? {
            let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.hasShadow = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            bottomPanel = panel
            return panel
        }()
        let scale = ScreenFit.scale(screenWidth: screen.frame.width)
        let frame = NSRect(x: screen.frame.minX,
                           y: screen.frame.minY + ScreenFit.homeBarHeight(screenWidth: screen.frame.width) + 8,
                           width: screen.frame.width, height: height * scale)
        panel.setFrame(frame, display: true)
        if bottomShowing != key {
            // 缩略图要点得到；文字提示放行，手指落在它上面时照样操作下面的窗口
            panel.ignoresMouseEvents = !interactive
            if let preview = state.capturePreview, !preview.cropping {
                panel.contentView = FirstMouseHostingView(rootView: CapturePreviewView(preview: preview, scale: scale) { [weak self] in
                    self?.screenshot.openCrop()
                })
            } else if let toast = state.captureToast {
                panel.contentView = NSHostingView(rootView: CaptureToastView(toast: toast, scale: scale))
            }
            bottomShowing = key
        }
        panel.orderFrontRegardless()
    }

    /// 裁剪界面：盖满手机屏，用和 App 资源库同一种面板（SwiftUI 才画得出来）。
    /// 开着时手势翻译停掉，不然手指拖动画框会被翻译成滚动
    private func updateCrop(on screen: NSScreen) {
        let croppingNow = state.capturePreview?.cropping == true
        if croppingNow != cropping {
            cropping = croppingNow
            intents.syncGestures()
        }
        guard croppingNow, let preview = state.capturePreview else {
            if cropPanel != nil {
                cropPanel?.orderOut(nil)
                cropPanel = nil
                homeBar?.orderFrontRegardless()
            }
            return
        }
        if cropPanel == nil {
            let scale = ScreenFit.scale(screenWidth: screen.frame.width)
            let host = FirstMouseHostingView(rootView: CropView(
                preview: preview, scale: scale,
                onCancel: { [weak self] in self?.screenshot.cancelCrop() },
                onDone: { [weak self] selection, area in
                    self?.screenshot.finishCrop(selection: selection, area: area)
                }))
            let panel = PhonePanel(content: host)
            panel.setFrame(screen.frame, display: true)
            cropPanel = panel
        }
        cropPanel?.setFrame(screen.frame, display: true)
        cropPanel?.orderFrontRegardless()
        homeBar?.orderOut(nil)
    }

    private func build(on id: DisplayID) {
        display = id
        list = PhonePanel(content: FirstMouseHostingView(rootView: PhoneHomeView(state: state, catalog: catalog, pages: pages, intents: intents)))
        let bar = HomeBarView()
        bar.onActivate = { [weak self] in self?.intents.showList() }
        bar.onCapture = { [weak self] in self?.screenshot.take() }
        homeBar = PhonePanel(content: bar)
        homeBarView = bar
    }

    private func tearDown() {
        catalog.reset()
        pages.close()
        list?.orderOut(nil)
        homeBar?.orderOut(nil)
        bottomPanel?.orderOut(nil)
        bottomPanel = nil
        bottomShowing = nil
        cropPanel?.orderOut(nil)
        cropPanel = nil
        cropping = false
        list = nil
        homeBar = nil
        homeBarView = nil
        display = nil
    }
    /// 可见区底部那一条：放上来的窗口正好让出这一条（高度跟着档位缩放，见 ScreenFit.homeBarHeight）
    private func homeBarFrame(on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        return NSRect(x: visible.minX, y: visible.minY, width: visible.width,
                      height: ScreenFit.homeBarHeight(screenWidth: screen.frame.width))
    }
}

/// 不抢焦点、所有桌面都在、盖住菜单栏的面板
final class PhonePanel: NSPanel {
    init(content: NSView) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        // 菜单栏是 24，菜单栏右边的图标是 25：再高一级才盖得住
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        hasShadow = false
        isOpaque = true
        backgroundColor = PhoneStyle.backgroundNSColor
        contentView = content
    }

    /// 平时点面板不让它变成键盘焦点：手机上的键盘输入要留给放上来的窗口；搜索、选手机型号时才打开
    var acceptsKeys = false {
        didSet {
            // 交还键盘：收起再摆回去才会让出焦点（resignKey 只是通知，调了也还是焦点）
            guard !acceptsKeys, isKeyWindow, isVisible else { return }
            orderOut(nil)
            orderFrontRegardless()
        }
    }

    override var canBecomeKey: Bool { acceptsKeys }
    override var canBecomeMain: Bool { false }
}

/// 面板不是键盘焦点，第一下点击也要直接生效
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// 底部小横条：点一下，或者往上滑，回到 App 资源库。中间是 SF Symbols 的 chevron.compact.up。
/// 左边是截屏键：截下铺满这块屏的窗口、直接进电脑剪贴板。
/// 手机屏换到更宽的一档时跟着放大（scale），在手机上看着、点着、滑着都和基准宽度一样
final class HomeBarView: NSView {
    /// 基准宽度下往上滑过这么多点算数
    static let swipeDistance: CGFloat = 12
    /// 基准宽度下截屏键的点击宽度：图标只有二十几点，点的地方要给够
    static let captureWidth: CGFloat = 56

    var onActivate: (() -> Void)?
    var onCapture: (() -> Void)?
    /// 这一档比基准宽度宽几倍（ScreenFit.scale）
    var scale: CGFloat = 1 {
        didSet { if scale != oldValue { updateIcons() } }
    }
    private let grabber = NSImageView()
    private var swipe: CGFloat = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        updateIcons()
        grabber.contentTintColor = .secondaryLabelColor
        addSubview(grabber)
        grabber.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            grabber.centerXAnchor.constraint(equalTo: centerXAnchor),
            grabber.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("不从 nib 加载") }

    private func updateIcons() {
        grabber.image = NSImage(systemSymbolName: "chevron.compact.up", accessibilityDescription: "App 资源库")?
            .withSymbolConfiguration(.init(pointSize: 22 * scale, weight: .semibold))
        needsDisplay = true
    }

    /// 相机键的点击区域：整条高、左边这么宽。视觉上只有一个相机图标，点哪儿都算
    private var captureHit: NSRect {
        NSRect(x: 0, y: 0, width: Self.captureWidth * scale, height: bounds.height)
    }

    /// 相机图标直接画在横条上，不放子视图：横条不是键盘焦点，子视图收不到第一次点击
    private var captureIcon: NSImage? {
        let color = NSImage.SymbolConfiguration(paletteColors: [.secondaryLabelColor])
        return NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "截图")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 17 * scale, weight: .semibold).applying(color))
    }

    override var isOpaque: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        PhoneStyle.backgroundNSColor.setFill()
        bounds.fill()
        guard let icon = captureIcon else { return }
        let side = 22 * scale
        icon.draw(in: NSRect(x: captureHit.midX - side / 2, y: (bounds.height - side) / 2, width: side, height: side))
    }

    /// 接住按下，抬起才会送到这里
    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else { return }
        if captureHit.contains(point) { onCapture?() } else { onActivate?() }
    }

    /// 手势翻译把单指上滑变成滚动：手指往上走，滚动量是负的
    override func scrollWheel(with event: NSEvent) {
        if event.phase == .began { swipe = 0 }
        swipe += event.scrollingDeltaY
        if swipe <= -Self.swipeDistance * scale {
            swipe = 0
            onActivate?()
        }
    }
}
