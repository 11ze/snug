// 一条队：动作按提交顺序一个做完再做下一个。屏幕调度的所有动作都排在同一条队里
// （加屏要等上线、搬窗口要核对重试，中间不能被别的动作插进来）
@MainActor
final class SerialLane {
    private var tail: Task<Void, Never>?

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

    func drain() async {
        while let current = tail {
            await current.value
            if tail == current { return }
        }
    }
}
