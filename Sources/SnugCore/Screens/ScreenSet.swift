// 屏幕模块，单一数据源：此刻有哪几块 Snug 屏、各是什么状态、什么比例、在哪一档，只有它知道，也只有它能改。
// 不认手机、平板、电脑，不认横竖：只认身份和宽 × 高（ScreenWish 给的）。
// 屏幕组合的每次变化都收在这里：WindowServer 在拓扑变化上很脆弱，屏建好太快就释放会卡死，热插拔还没处理完又建屏会崩。
// 一批增删（apply）前后只记一次周围的样子、只善后一次：macOS 一换屏幕组合，就把别的窗口挪来挪去、
// 把别的屏拨回它给这组屏幕记的模式（issue #13），换完按换之前的样子放回，Snug 的屏来去，别的都照旧。
// 设为主屏（docs/multi-screen.md 2.6）也是拓扑变化，同样收在这里：建好、善后之后设主屏，原主屏上的窗口跟着搬过去（V11）；
// 撤之前先设回（releaseMain，在 DeskSet 清场之前），窗口随之回到原主屏。改之前记还原账，Snug 崩了下次启动按账摆回。
// 动作由调用方排进同一条队（DeskSet 的 SerialLane），加屏失败的重试也排进这条队
import CoreGraphics
import Foundation

@MainActor
public final class ScreenSet {
    public enum State: Equatable, Sendable {
        case off
        case preparing
        case ready(DisplayID)
        /// 加屏失败（详情在日志里）。按 retryDelays 自动重试，用完就停在这里，直到不要了再要
        case failed

        public var display: DisplayID? {
            if case .ready(let id) = self { id } else { nil }
        }
    }

    /// 屏幕组合变了（或刚设回别的屏的模式）等这么久，系统挪完窗口再放回
    static let topologySettle: TimeInterval = 1
    /// 加屏失败后隔多久重试；这几次都不成就不再试，直到不要了再要
    static let retryDelays: [TimeInterval] = [5, 15, 30]

    /// 要的每块屏此刻的状态；不要的不在里面
    public private(set) var states: [ScreenID: State] = [:] {
        didSet { if states != oldValue { onChange?() } }
    }
    public var onChange: (() -> Void)?
    /// 即将加屏、撤屏，或把被拨动的别的屏设回去：会话层据此暂缓断开判定（屏幕一变，UU 的信号会抖一下）
    public var onTopologyChange: (() -> Void)?
    /// 放在 Snug 屏上的窗口：加屏、撤屏后放回别的窗口时跳过它们（由 DeskSet 给，ScreenSet 不认 Desk）
    var placedWindows: () -> Set<WindowKey> = { [] }

    private let displays: any VirtualDisplays
    private let windows: any WindowControl
    private let arrangement: any DisplayArrangement
    private let timeline: any Timeline
    private let lane: SerialLane
    /// 设主屏之前各屏的原点；设回才销账
    private let arrangementLedger: RestoreRecord<ArrangementRecord>
    /// 此刻被设成主屏的那块 Snug 屏
    private(set) var mainScreen: ScreenID?
    /// Snug 的屏出现之前的主屏（建第一块屏前记下）：设主屏记账时按它算原来的排布
    private var homeMain: DisplayID?
    /// 要的屏，按屏幕列表的顺序（建屏按这个顺序，UU 也按建屏顺序列出）
    private var wishes: [ScreenWish] = []
    private var live: [ScreenID: (display: DisplayID, bornAt: TimeInterval)] = [:]
    private var failures: [ScreenID: Int] = [:]
    private var pendingRetries: [ScreenID: Task<Void, Never>] = [:]
    /// 撤掉了、还没真正下线的屏：下线那一刻 macOS 才挪窗口、拨别的屏。显示器睡着（Mac 锁屏）时释放的虚拟屏
    /// 要等唤醒才下线（实测，可能是几小时后），等它们都真下线了再按撤屏前的样子放回（settleDisplays）
    private var retiring: Retiring?
    /// 远程在不在进行（会话层的结论，含断开后等重连的那段）：这期间别的屏可能处在远程用的临时模式
    private var remote = false
    /// 远程中撤过屏：那时别的屏可能正处在远程用的临时模式，系统套用时连永久配置一起写了。
    /// 远程结束（UU 已经还原）、Snug 的屏都不在、屏都醒着时，把别的屏此刻的模式写进永久配置
    private var persistOwed = false

    init(displays: any VirtualDisplays, windows: any WindowControl, arrangement: any DisplayArrangement, timeline: any Timeline,
         lane: SerialLane, arrangementLedger: URL) {
        self.displays = displays
        self.windows = windows
        self.arrangement = arrangement
        self.timeline = timeline
        self.lane = lane
        self.arrangementLedger = RestoreRecord(url: arrangementLedger)
    }

    // MARK: 差量

    /// 对照现状做差量（在队里调用）：新的建出来，没了的撤掉，比例变了的在线换（同一身份），其余不碰。
    /// 交回这次换了比例的屏和换成了没有
    @discardableResult
    func apply(_ wishes: [ScreenWish]) async -> [ScreenID: Bool] {
        let wanted = Set(wishes.map(\.id))
        for id in pendingRetries.keys where !wanted.contains(id) { cancelRetry(id) }
        self.wishes = wishes
        await releaseMain(keeping: wishes)
        await reconcile()
        var reshaped: [ScreenID: Bool] = [:]
        for wish in wishes {
            guard let display = live[wish.id]?.display, let now = displays.fit(display), now != wish.fit else { continue }
            reshaped[wish.id] = await reshape(display, to: wish.fit)
        }
        await claimMain()
        return reshaped
    }

    /// 撤掉不要的、建出要了还没有的；失败的按 retryDelays 排队重试
    private func reconcile() async {
        let wanted = Set(wishes.map(\.id))
        let retire = live.keys.filter { !wanted.contains($0) }.sorted { $0.rawValue < $1.rawValue }
        let create = wishes.filter { live[$0.id] == nil }
        for id in states.keys where !wanted.contains(id) && live[id] == nil { states[id] = nil }
        guard !retire.isEmpty || !create.isEmpty else { return }
        for wish in create { states[wish.id] = .preparing }

        let change = create.isEmpty ? "撤屏" : retire.isEmpty ? "加屏" : "加撤屏"
        if let old = retiring, !create.isEmpty {
            retiring = nil
            Log.warn("撤掉的屏 \(old.displays.map { "#\($0)" }.joined(separator: "、")) 还没下线就又要加屏，不再等：它们下线时被挪动的窗口、被拨动的屏不会按撤屏前的样子放回")
        }
        if live.isEmpty, !create.isEmpty { homeMain = arrangement.origins().first { $0.value == .zero }?.key }
        var before = await surroundings(before: change)
        onTopologyChange?()

        var offline = true
        var gone: [DisplayID] = []
        for id in retire {
            guard let (display, bornAt) = live[id] else { continue }
            let age = timeline.now - bornAt
            if age < ScreenSpec.minimumLifetime { await timeline.sleep(ScreenSpec.minimumLifetime - age) }
            // 原本就在这块屏上的窗口交给系统安置：那块屏已经没了，放回原处只会落到屏幕外
            if let bounds = displays.bounds(display) {
                before.windows = before.windows.filter { !bounds.contains(CGPoint(x: $0.value.midX, y: $0.value.midY)) }
            }
            if await !displays.retire(display) { offline = false }
            live[id] = nil
            states[id] = nil
            gone.append(display)
            Log.info("已撤掉屏 #\(display)（\(id)）")
        }

        var created: [ScreenID: DisplayID] = [:]
        for wish in create {
            do {
                let display = try await displays.create(wish.spec, wish.fit)
                live[wish.id] = (display, timeline.now)
                created[wish.id] = display
                failures[wish.id] = nil
                Log.info("「\(wish.spec.name)」#\(display) 已建好（\(displays.width(display).map { "\($0) 宽" } ?? "不是 2 倍")）")
            } catch {
                states[wish.id] = .failed
                Log.error("加「\(wish.spec.name)」失败：\(error)")
                scheduleRetry(wish.id)
            }
        }

        // 远程结束后撤屏（UU 已经还原），撤屏前的样子就是用户自己的设置：系统套用旧模式时也写进了永久配置，
        // 只设回本次登录，磁盘上那组屏幕记的还是旧模式（实测），所以连永久配置一起写回。
        // 加屏、远程中撤屏，之前可能是远程用的临时模式：只设回本次登录，远程结束后再写永久配置
        if !retire.isEmpty, remote { persistOwed = true }
        let pending = Retiring(displays: gone, before: before, permanently: create.isEmpty && !remote)
        if offline {
            await settle(pending.before, after: change, permanently: pending.permanently)
        } else {
            retiring = pending
            Log.info("撤掉的屏还没下线（显示器睡着时要等唤醒），下线后再放回窗口、设回别的屏")
        }
        for (id, display) in created { states[id] = .ready(display) }
    }

    /// 加屏失败后过一会儿再试：手机上没有任何入口能重来，不重试就要等这次远程结束
    private func scheduleRetry(_ id: ScreenID) {
        pendingRetries[id]?.cancel()
        pendingRetries[id] = nil
        let count = failures[id] ?? 0
        guard count < Self.retryDelays.count else {
            Log.error("加屏（\(id)）连续失败 \(count + 1) 次，这次远程不再重试")
            return
        }
        let delay = Self.retryDelays[count]
        failures[id] = count + 1
        Log.info("\(Int(delay)) 秒后重试加屏（\(id)，第 \(count + 1) 次重试）")
        pendingRetries[id] = Task {
            await timeline.sleep(delay)
            guard !Task.isCancelled else { return }
            await lane.run {
                await self.reconcile()
                await self.claimMain()
            }.value
        }
    }

    private func cancelRetry(_ id: ScreenID) {
        pendingRetries.removeValue(forKey: id)?.cancel()
        failures[id] = nil
    }

    /// 还没到点的重试（测试等它们做完）
    var retries: [Task<Void, Never>] { Array(pendingRetries.values) }

    /// 换比例：屏在线换成新档位（屏不掉线、编号不变，UU 里选中的屏不丢）。换不成屏还是原来的档位，下次建屏按新的建
    private func reshape(_ display: DisplayID, to fit: ScreenFit) async -> Bool {
        guard await displays.reshape(display, to: fit) else {
            Log.warn("屏 #\(display) 没能换成新比例（\(fit)），下次加屏时按新的建")
            return false
        }
        return true
    }

    // MARK: 善后

    /// Snug 的屏以外的一切：窗口在哪、别的屏是什么模式。macOS 一换屏幕组合就会动它们：把窗口挪来挪去，
    /// 把别的屏拨回它给新的这组屏幕记的模式（远程期间主屏被临时改成 30Hz，撤屏时又被拨回 30Hz，issue #13）
    private struct Surroundings {
        var windows: [WindowKey: CGRect]
        var others: [OtherDisplay]
    }

    private struct Retiring {
        var displays: [DisplayID]
        var before: Surroundings
        var permanently: Bool
    }

    /// 记下来，别的屏的模式也写进日志：出了问题能分清是换屏幕组合时被拨动的，还是之前就是这样
    private func surroundings(before change: String) async -> Surroundings {
        let others = displays.otherDisplays()
        Log.info("\(change)前别的屏：\(others.isEmpty ? "没有" : others.map { "\($0.name) \($0.mode)" }.joined(separator: "、"))")
        return Surroundings(windows: await windows.snapshot(), others: others)
    }

    /// 屏幕组合换完（新屏上线、旧屏下线）后放回：先设回被拨动的屏（模式连分辨率一起变时会再挪窗口），
    /// 等系统挪完，再放回被挪动的窗口。这期间拔掉、新接上的屏不碰
    private func settle(_ before: Surroundings, after change: String, permanently: Bool) async {
        await timeline.sleep(Self.topologySettle)
        let now = Dictionary(displays.otherDisplays().map { ($0.id, $0.mode) }, uniquingKeysWith: { first, _ in first })
        let drifted = before.others.compactMap { was in now[was.id].flatMap { $0.isSame(as: was.mode) ? nil : (was, $0) } }
        if !drifted.isEmpty {
            let detail = drifted.map { was, now in "\(was.name) \(was.mode) → \(now)" }.joined(separator: "、")
            Log.info("\(change)时 macOS 把别的屏拨成了它给这组屏幕记的模式（\(detail)），设回\(change)前的样子")
            onTopologyChange?()
            for (was, _) in drifted { await displays.setMode(was.id, was.mode, permanently: permanently) }
            await timeline.sleep(Self.topologySettle)
        }
        let expected = Self.following(before.windows, from: before.others, to: displays.otherDisplays())
        await windows.restore(expected, except: placedWindows())
    }

    /// 窗口该在的位置：所在的屏被 macOS 挪了（Snug 的屏多了，它会把外接屏挪开让地方，撤屏后再挪回来），
    /// 屏上的窗口是跟着屏走的，记下的位置也按屏挪过的距离平移，不然放回去反倒把它们推偏
    static func following(_ windows: [WindowKey: CGRect], from before: [OtherDisplay], to now: [OtherDisplay]) -> [WindowKey: CGRect] {
        let moved: [(was: CGRect, by: CGVector)] = before.compactMap { was in
            guard let now = now.first(where: { $0.id == was.id }), now.bounds.origin != was.bounds.origin else { return nil }
            return (was.bounds, CGVector(dx: now.bounds.minX - was.bounds.minX, dy: now.bounds.minY - was.bounds.minY))
        }
        guard !moved.isEmpty else { return windows }
        return windows.mapValues { frame in
            guard let shift = moved.first(where: { $0.was.contains(CGPoint(x: frame.midX, y: frame.midY)) })?.by else { return frame }
            return frame.offsetBy(dx: shift.dx, dy: shift.dy)
        }
    }

    /// 远程在不在进行（会话层的结论）。远程结束后，远程中撤屏留下的永久配置要重写（settleDisplays）
    func setRemote(_ on: Bool) -> Bool {
        guard on != remote else { return false }
        remote = on
        return true
    }

    /// 有没有善后要做：撤掉的屏还没下线，或远程中撤过屏、永久配置要重写
    var owesSettling: Bool { retiring != nil || persistOwed }

    /// 撤掉的屏真下线了，就放回窗口、设回别的屏；远程中撤过屏的，远程结束、屏都醒着时把别的屏此刻的模式写进永久配置
    func settleDisplays() async {
        if let r = retiring {
            guard !r.displays.contains(where: displays.isOnline) else { return }
            retiring = nil
            Log.info("撤掉的屏 \(r.displays.map { "#\($0)" }.joined(separator: "、")) 下线了")
            await settle(r.before, after: "撤屏", permanently: r.permanently)
        }
        guard persistOwed, !remote, live.isEmpty else { return }
        let others = displays.otherDisplays()
        guard !others.contains(where: \.asleep) else { return }
        persistOwed = false
        Log.info("远程中撤过屏，远程结束后把别的屏此刻的模式写进永久配置：\(others.map { "\($0.name) \($0.mode)" }.joined(separator: "、"))")
        for other in others { await displays.setMode(other.id, other.mode, permanently: true) }
    }

    // MARK: 主屏

    /// 设主屏的那块要撤、或不再要它当主屏：先设回原来的主屏（在 DeskSet 清场之前调，跟过去的窗口随之回到原主屏，
    /// 剩下的才要清场）
    func releaseMain(keeping wishes: [ScreenWish]) async {
        guard let id = mainScreen, !wishes.contains(where: { $0.id == id && $0.main }) else { return }
        mainScreen = nil
        await restoreArrangement(because: "「\(id)」不再当主屏")
    }

    /// 要设为主屏的那块建好了、还不是主屏：记下各屏的原点，再设。原主屏上的窗口跟着主屏搬过去（V11），不放回
    private func claimMain() async {
        guard mainScreen == nil, let wish = wishes.first(where: \.main), let display = live[wish.id]?.display else { return }
        var before = arrangement.origins()
        // 系统按这组屏幕记的排布已经把某块 Snug 屏设成了主屏（上次设了主屏没设回就退出了，同一次登录里再建这几块屏，11-17 实测）：
        // 按 Snug 的屏出现前的主屏换算原来的排布，不然不再当主屏时摆回的还是这个样子
        if let home = homeMain, let shift = before[home], shift != .zero {
            before = before.mapValues { CGPoint(x: $0.x - shift.x, y: $0.y - shift.y) }
        }
        do {
            // 已有没销的账（上次没设回）就留着最早的那份：那才是用户自己的排布
            if arrangementLedger.pending() == nil { try arrangementLedger.record(ArrangementRecord(origins: before)) }
        } catch {
            return Log.error("设主屏的还原账写不进去（\(arrangementLedger.file.url.path)）：\(error)；不设主屏，不然不再当主屏时没有账可依、摆不回来")
        }
        onTopologyChange?()
        guard await arrangement.makeMain(display) else {
            Log.error("「\(wish.spec.name)」#\(display) 设成主屏失败")
            return settleArrangement()
        }
        mainScreen = wish.id
        Log.info("「\(wish.spec.name)」#\(display) 设成主屏（原来的原点：\(Self.describe(before))）")
        await timeline.sleep(Self.topologySettle)
    }

    /// 启动时：上次设了主屏没设回就退出了（崩溃）。不按账摆：Snug 的屏随上次的进程一起没了，屏幕组合一变，
    /// macOS 已经按剩下这组屏记的排布摆好；账里别的屏的位置是 Snug 的屏还在时的，系统给它们让过地方，
    /// 照着摆反倒把外接屏挪偏（11-17 实测：外接屏从 -217 被摆到 -408）。只销账、记一笔
    func recoverArrangement() async {
        guard let record = arrangementLedger.pending() else { return }
        Log.info("上次设了主屏没设回就退出了：Snug 的屏已随之撤掉，系统按这组屏幕记的排布摆好了（\(Self.describe(arrangement.origins()))），"
                 + "不再按账（\(Self.describe(record.origins))）摆")
        settleArrangement()
    }

    private func restoreArrangement(because reason: String) async {
        guard let record = arrangementLedger.pending() else { return }
        onTopologyChange?()
        if await arrangement.restore(record.origins) {
            Log.info("\(reason)，排布摆回设主屏之前（\(Self.describe(record.origins))）")
            settleArrangement()
        } else {
            // 账留着：再设主屏时还用这份最早的；屏撤掉时 macOS 按这组屏幕记的排布摆回
            Log.error("\(reason)，排布没能摆回去（\(Self.describe(record.origins))），屏撤掉时系统会按这组屏幕记的排布摆回")
        }
        await timeline.sleep(Self.topologySettle)
    }

    private func settleArrangement() {
        do { try arrangementLedger.settle() } catch { Log.error("设主屏的还原账销不掉（\(arrangementLedger.file.url.path)）：\(error)") }
    }

    private static func describe(_ origins: [DisplayID: CGPoint]) -> String {
        origins.sorted { $0.key < $1.key }.map { "#\($0.key) (\(Int($0.value.x)),\(Int($0.value.y)))" }.joined(separator: "、")
    }

    // MARK: 查询、换档

    /// 就绪的屏
    public func display(_ id: ScreenID) -> DisplayID? { states[id]?.display }

    /// 屏上此刻的比例：选档只能在屏上登记的档位里选。换比例还没轮到、或者没换成时，它和要的不一样
    func fit(_ id: ScreenID) -> ScreenFit? {
        guard let wish = wishes.first(where: { $0.id == id }) else { return nil }
        return display(id).flatMap(displays.fit) ?? wish.fit
    }

    /// 要的比例（配置里的型号对应的）
    func targetFit(_ id: ScreenID) -> ScreenFit? { wishes.first { $0.id == id }?.fit }

    /// 此刻是哪一档；不是 2 倍、或屏不在返回 nil
    func width(_ id: ScreenID) -> Int? { display(id).flatMap(displays.width) }

    func setWidth(_ id: ScreenID, _ width: Int) async {
        guard let display = display(id), displays.width(display) != width else { return }
        await displays.setWidth(display, width)
    }

    func bounds(_ id: ScreenID) -> CGRect? { display(id).flatMap(displays.bounds) }

    func windowArea(_ id: ScreenID, withHomeBar: Bool) -> CGRect? {
        display(id).flatMap { displays.windowArea($0, withHomeBar: withHomeBar) }
    }

    func mainArea() -> CGRect? { displays.mainArea() }

    /// 这个点落在哪块 Snug 屏上（就绪的）
    func screen(at point: CGPoint) -> ScreenID? {
        states.keys.first { bounds($0)?.contains(point) == true }
    }
}

/// 设主屏之前各屏的原点
struct ArrangementRecord: Codable, Equatable, Sendable {
    var origins: [DisplayID: CGPoint]
}
