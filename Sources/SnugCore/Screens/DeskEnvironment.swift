// 几块屏共用的：系统能力、时钟、屏幕模块、那一条队，和两本跨屏的账（字号簿、留下的账）。
// DeskSet 建一份，交给每块 Desk；Desk 只经它碰共用的东西，不认别的 Desk
import CoreGraphics
import Foundation

@MainActor
final class DeskEnvironment {
    let windows: any WindowControl
    let apps: any AppControl
    let timeline: any Timeline
    let screens: ScreenSet
    let lane: SerialLane
    let paths: SnugPaths
    /// 设置里的默认字号级数
    var defaultZoom: Int
    /// 每个 App 在手机、平板屏上记住的字号级数
    var zoomBook: ZoomBook
    /// 在 Snug 屏上被 Snug 之外关掉的窗口欠下的账（见 LeftBehind）
    var leftBehind: LeftBehindBook
    private let zoomFile: JSONFile<ZoomBook>
    private let leftBehindFile: JSONFile<LeftBehindBook>

    init(windows: any WindowControl, apps: any AppControl, timeline: any Timeline, screens: ScreenSet, lane: SerialLane,
         paths: SnugPaths, defaultZoom: Int) {
        self.windows = windows
        self.apps = apps
        self.timeline = timeline
        self.screens = screens
        self.lane = lane
        self.paths = paths
        self.defaultZoom = defaultZoom
        zoomFile = JSONFile(url: paths.zoomBook)
        zoomBook = zoomFile.loadOrQuarantine() ?? ZoomBook()
        leftBehindFile = JSONFile(url: paths.leftBehind)
        leftBehind = leftBehindFile.loadOrQuarantine() ?? LeftBehindBook()
    }

    /// 原位：落在 Snug 屏上的（App 按上次记住的位置把窗口开在了那块屏上）改成主屏居中，屏一撤那个位置就不存在了
    func originalFrame(_ frame: CGRect) -> CGRect {
        guard screens.screen(at: CGPoint(x: frame.midX, y: frame.midY)) != nil, let main = screens.mainArea() else { return frame }
        return main.centered(frame.size)
    }

    /// 窗口在 Snug 之外没了：账不销，转成留下的账，等它带着屏上的大小回来再还（见 LeftBehind）。
    /// 字号按 App 存在哪处理：存在整个 App 里的（Zed）马上从它别的窗口缩回；会被 App 记住、回来时又认不出的（VS Code
    /// 按工作区记，重开时大小可能被重设），交回要给用户的提示
    func leaveBehind(_ record: PlacedRecord) async -> Desk.Notice? {
        var record = record
        var notice: Desk.Notice?
        if record.zoom != 0 {
            switch ZoomBook.scope(of: record.bundleID) {
            case .app?:
                // 进程没了，内存里的字号跟着没了；还在就从它别的窗口缩回，没有别的窗口就留着，等它再出窗口时缩回
                if await !apps.isRunning(pid: record.window.pid) { record.zoom = 0 }
                else if await repayAppZoom(record) { record.zoom = 0 }
            case .workspace?:
                notice = .zoomLeftBehind(app: record.app, steps: record.zoom)
            case .liveWindow?, .restoredWindow?, nil:
                break
            }
        }
        leftBehind.add(LeftBehind(record: record, since: Date()))
        leftBehind.prune(now: Date())
        saveLeftBehind()
        return notice
    }

    /// 字号存在整个 App 里（Zed）：从这个进程开着的另一个窗口缩回。没有别的窗口、或发不出去返回 false
    func repayAppZoom(_ record: PlacedRecord) async -> Bool {
        guard let other = await windows.shownWindows(of: record.window.pid).first(where: { $0.key != record.window }) else {
            Log.info("\(record.label) 关了，\(record.app) 没有别的窗口，放大的 \(record.zoom) 级字号等它再出窗口时缩回")
            return false
        }
        let done = await windows.zoom(other.key, steps: -record.zoom)
        Log.info("\(record.label) 关了，字号存在整个 \(record.app) 里：从 \(other.label) 缩回 \(record.zoom) 级\(done ? "" : "，没发出去")")
        return done
    }

    func saveLeftBehind() {
        do {
            try leftBehindFile.save(leftBehind)
        } catch {
            Log.error("留下的账写不进去（left-behind.json）：\(error)")
        }
    }

    func saveZoomBook() {
        do {
            try zoomFile.save(zoomBook)
        } catch {
            Log.error("记不住字号级数（zoom.json 写不进去）：\(error)")
        }
    }
}

extension CGRect {
    /// 在这块区域里居中放一个 size 大小的框，大小不超过区域
    func centered(_ size: CGSize) -> CGRect {
        let size = CGSize(width: min(size.width, width), height: min(size.height, height))
        return CGRect(x: (midX - size.width / 2).rounded(), y: (midY - size.height / 2).rounded(), width: size.width, height: size.height)
    }
}
