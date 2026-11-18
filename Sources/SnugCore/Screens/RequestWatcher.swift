// 发出退出、关窗请求之后盯着结果，不占队：成了、用户在对话框里点了取消、还是一直没动静。
// App 在问用户（「要存储吗」「还有进程在跑」）就把问的那个窗口交回（ask），由 DeskSet 放上发起的那块屏，问着就一直等
import Foundation

@MainActor
final class RequestWatcher {
    /// 盯着的请求：请它退出的 App、请它关掉的窗口
    enum Request: Hashable {
        case quit(Int32)
        case close(WindowKey)
    }

    enum Answer {
        case done, canceled, stalled
    }

    /// 隔多久看一次结果
    static let poll: TimeInterval = 0.25
    /// 对话框答完后再等这么久：App 还在、窗口还在，就是点了取消（存储要一点时间，不能一没对话框就下结论）
    static let answerGrace: TimeInterval = 2

    private let windows: any WindowControl
    private let timeline: any Timeline
    private var tasks: [Request: Task<Void, Never>] = [:]

    init(windows: any WindowControl, timeline: any Timeline) {
        self.windows = windows
        self.timeline = timeline
    }

    func isWatching(_ request: Request) -> Bool { tasks[request] != nil }

    /// 还在盯的（测试等它们做完）
    var running: [Task<Void, Never>] { Array(tasks.values) }

    /// 另起一个任务盯着。同一件事再盯一次（提示强制退出后又点了退出）先停掉旧的
    func watch(_ request: Request, _ body: @escaping @MainActor () async -> Void) {
        tasks[request]?.cancel()
        tasks[request] = Task {
            await body()
            // 取消的已经被换掉或清掉了，别把新的那个删了
            if !Task.isCancelled { tasks[request] = nil }
        }
    }

    func unwatch(_ request: Request) {
        tasks.removeValue(forKey: request)?.cancel()
    }

    /// 屏都撤了（这次远程结束）：不再盯，App 照样在退、窗口照样在关
    func unwatchAll() {
        tasks.values.forEach { $0.cancel() }
        tasks = [:]
    }

    /// 等结果（在 watch 的任务里调）：done 为真就是成了；App 在问用户（可能一连问好几次：多个未存储的文稿先问「要先检查吗」，
    /// 再逐个问）就把问的窗口交给 ask，问着就一直等；问完了 done 还不成立，就是点了取消；一直没动静，等满 seconds 算卡住
    func awaitAnswer(from pid: Int32, within seconds: TimeInterval, done: () async -> Bool,
                     ask: (WindowInfo) async -> Void) async -> Answer {
        let deadline = timeline.now + seconds
        var asked: WindowKey?
        var answeredAt: TimeInterval?
        while !Task.isCancelled {
            if await done() { return .done }
            if let asking = await windows.askingWindow(of: pid) {
                answeredAt = nil
                if asking.key != asked {
                    asked = asking.key
                    await ask(asking)
                }
            } else if asked != nil {
                let at = answeredAt ?? timeline.now
                answeredAt = at
                if timeline.now - at >= Self.answerGrace { return .canceled }
            } else if timeline.now >= deadline {
                return .stalled
            }
            await timeline.sleep(Self.poll)
        }
        return .canceled
    }
}
