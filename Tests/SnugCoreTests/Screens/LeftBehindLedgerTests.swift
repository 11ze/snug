import CoreGraphics
import Foundation
import Testing
@testable import SnugCore

@Suite("留下的账 LeftBehindLedger")
@MainActor
final class LeftBehindLedgerTests {
    let tmp: TempDir
    let url: URL
    let journal = Journal()

    init() throws {
        tmp = try TempDir()
        url = tmp.url.appendingPathComponent("left-behind.json")
    }

    private func ledger() -> LeftBehindLedger {
        let windows = FakeWindows(journal: journal)
        return LeftBehindLedger(url: url, windows: windows, apps: FakeApps(journal: journal, windows: windows, timeline: ManualTimeline()))
    }

    private func record(_ window: WindowInfo) -> PlacedRecord {
        PlacedRecord(window: window.key, app: window.app, label: window.label, original: ghosttyHome,
                     bundleID: window.bundleID, title: window.title, filled: phoneArea)
    }

    @Test("销账按认下的那一笔找，不按下标：先销了排在前面的，后面那笔照样销对；改了就落盘，重开读得回来")
    func settlesTheClaimedEntry() async throws {
        let second = WindowInfo(key: WindowKey(pid: 10, id: 9), app: ghostty.app, bundleID: ghostty.bundleID, title: "~/other")
        let book = ledger()
        _ = await book.add(record(ghostty))
        _ = await book.add(record(second))
        #expect(ledger().book.entries.count == 2)
        let first = try #require(book.owed(by: ghostty, frame: phoneArea))
        let later = try #require(book.owed(by: second, frame: phoneArea))
        book.settle(first)
        #expect(book.book.entries.map(\.record.window) == [second.key])
        book.settle(later)
        #expect(book.isEmpty)
        #expect(ledger().isEmpty)
    }

    @Test("没铺成过的（还没挪上屏就没了）不记账")
    func skipsUnfilled() async {
        let book = ledger()
        var unfilled = record(ghostty)
        unfilled.filled = nil
        _ = await book.add(unfilled)
        #expect(book.isEmpty)
    }
}
