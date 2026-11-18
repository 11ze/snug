// 一条队：动作按提交顺序一个做完再做下一个。屏幕调度的所有动作都排在同一条队里
// （加屏要等上线、搬窗口要核对重试，中间不能被别的动作插进来）
@MainActor
final class SerialLane {
    private var tail: Task<Void, Never>?
    /// 合并排队的（见 runCoalesced）：排着或正在做的
    private var coalesced: Set<String> = []

    @discardableResult
    func run(_ operation: @escaping @MainActor @Sendable () async -> Void) -> Task<Void, Never> {
        let previous = tail
        let task = Task { @MainActor in
            await previous?.value
            await operation()
        }
        tail = task
        return task
    }

    /// 定期的核对、善后：同一件事还排着、或正在做，就不再排（一拍一拍地来，App 卡住时不能越堆越多）
    func runCoalesced(_ key: String, _ operation: @escaping @MainActor @Sendable () async -> Void) {
        guard coalesced.insert(key).inserted else { return }
        run {
            defer { self.coalesced.remove(key) }
            await operation()
        }
    }

    func drain() async {
        while let current = tail {
            await current.value
            if tail == current { return }
        }
    }
}
