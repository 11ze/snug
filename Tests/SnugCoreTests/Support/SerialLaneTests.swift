import Testing
@testable import SnugCore

@Suite("一条队 SerialLane")
@MainActor
struct SerialLaneTests {
    @Test("合并排队：同一件事还排着或正在做就不再排，做完了才能再排；别的事照常排")
    func coalesces() async {
        let lane = SerialLane()
        var log: [String] = []
        lane.run { await Task.yield(); log.append("放窗口") }
        lane.runCoalesced("verify") { log.append("核对") }
        lane.runCoalesced("verify") { log.append("核对 2") }
        lane.runCoalesced("settle") { log.append("善后") }
        await lane.drain()
        lane.runCoalesced("verify") { log.append("核对 3") }
        await lane.drain()
        #expect(log == ["放窗口", "核对", "善后", "核对 3"])
    }
}
