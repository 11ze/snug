// 屏幕排布：各屏的原点、设主屏、按记下的原点摆回去。主屏就是原点在 (0, 0) 的那块屏，
// 设主屏 = 把它挪到 (0, 0)、别的屏跟着平移，相对位置不变。只对本次登录生效。
// 会卡住：GUI 进程不要在主线程上调（原作者实测，放到别的队列）
import CoreGraphics
import SnugCore

public enum DisplayArrangement {
    /// 每块在线屏此刻的原点（全局坐标，左上原点）
    public static func origins() -> [DisplayID: CGPoint] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [:] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [:] }
        return Dictionary(uniqueKeysWithValues: ids.prefix(Int(count)).map { ($0, CGDisplayBounds($0).origin) })
    }

    /// 把 id 设成主屏
    public static func makeMain(_ id: DisplayID) -> CGError {
        let now = origins()
        guard let shift = now[id] else { return .illegalArgument }
        return configure(now.mapValues { CGPoint(x: $0.x - shift.x, y: $0.y - shift.y) })
    }

    /// 按记下的原点摆回去；记下之后才出现、或已经不在的屏不动
    public static func restore(_ saved: [DisplayID: CGPoint]) -> CGError {
        let online = origins()
        return configure(saved.filter { online[$0.key] != nil })
    }

    private static func configure(_ targets: [DisplayID: CGPoint]) -> CGError {
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
