// 屏幕排布：各屏的原点、设主屏、按记下的原点摆回去。主屏就是原点在 (0, 0) 的那块屏，
// 设主屏 = 把它挪到 (0, 0)、别的屏跟着平移，相对位置不变。只对本次登录生效。
// 会卡住：不在主线程上调（原作者实测），放到后台线程做完再回来
import CoreGraphics
import SnugCore

@MainActor
public final class DisplayArrangementService: DisplayArrangement {
    public init() {}

    public func origins() -> [DisplayID: CGPoint] { Self.origins() }

    public func makeMain(_ id: DisplayID) async -> Bool {
        let error = await Task.detached {
            let now = Self.origins()
            guard let shift = now[id] else { return CGError.illegalArgument }
            return Self.configure(now.mapValues { CGPoint(x: $0.x - shift.x, y: $0.y - shift.y) })
        }.value
        if error != .success { Log.error("设主屏 #\(id)：CGError=\(error.rawValue)") }
        return error == .success
    }

    public func restore(_ saved: [DisplayID: CGPoint]) async -> Bool {
        let error = await Task.detached {
            let online = Self.origins()
            return Self.configure(saved.filter { online[$0.key] != nil })
        }.value
        if error != .success { Log.error("摆回排布：CGError=\(error.rawValue)") }
        return error == .success
    }

    /// 每块在线屏此刻的原点（全局坐标，左上原点）
    nonisolated static func origins() -> [DisplayID: CGPoint] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [:] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [:] }
        return Dictionary(uniqueKeysWithValues: ids.prefix(Int(count)).map { ($0, CGDisplayBounds($0).origin) })
    }

    private nonisolated static func configure(_ targets: [DisplayID: CGPoint]) -> CGError {
        var config: CGDisplayConfigRef?
        let begin = CGBeginDisplayConfiguration(&config)
        guard begin == .success else { return begin }
        for (id, origin) in targets {
            let staged = CGConfigureDisplayOrigin(config, id, Int32(origin.x.rounded()), Int32(origin.y.rounded()))
            guard staged == .success else {
                CGCancelDisplayConfiguration(config)
                return staged
            }
        }
        let done = CGCompleteDisplayConfiguration(config, .forSession)
        if done != .success { CGCancelDisplayConfiguration(config) }
        return done
    }
}
