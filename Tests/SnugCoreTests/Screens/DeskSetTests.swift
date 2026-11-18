import CoreGraphics
import Foundation
import Testing
@testable import SnugCore

/// 第二块屏：新加的屏的身份
private let second = ScreenID("second")
private let secondSpec = ScreenSpec(name: "Snug 第二块", productID: ScreenSpec.portraitProductID,
                                    serials: [200_100_000, 200_100_001, 200_100_002], maxPixels: ScreenFit.portraitPixels)
private let computer = ScreenBehavior(touch: false, gestures: false, zooms: false)

@MainActor
private extension Rig {
    func secondWish(_ behavior: ScreenBehavior = .phone) -> ScreenWish {
        ScreenWish(id: second, spec: secondSpec, fit: .standard, behavior: behavior)
    }

    /// 两块屏都建好，流水账清空
    func readyTwo(_ behavior: ScreenBehavior = .phone) async {
        set.setWishes([desk.wish, secondWish(behavior)])
        await set.idle()
        journal.clear()
    }

    func placed(on id: ScreenID) -> WindowInfo? { set.state.desks[id]?.placed?.window }
    func record(of id: ScreenID) -> PlacedRecord? { RestoreRecord<PlacedRecord>(url: paths.placedRecord(for: id)).pending() }
    /// 第二块屏的可放区域（假屏往右排，第二块在第一块右边 4000 点）
    var secondArea: CGRect { phoneArea.offsetBy(dx: 4000, dy: 0) }
}

@Suite("多块屏 DeskSet")
@MainActor
struct DeskSetTests {
    @Test("两块屏一批建：前后只拍一次快照、只善后一次；各用各的身份")
    func createsTogether() async throws {
        let rig = try Rig()
        rig.set.setWishes([rig.desk.wish, rig.secondWish()])
        await rig.set.idle()
        #expect(rig.journal.all == ["snapshot", "create", "create", "restore"])
        #expect(rig.set.state.desks[.phone]?.screen == .ready(101))
        #expect(rig.set.state.desks[second]?.screen == .ready(102))
        #expect(rig.displays.specs[101]?.name == "Snug 手机屏")
        #expect(rig.displays.specs[102]?.name == "Snug 第二块")
    }

    @Test("每块屏各放各的，互不打扰；还原账每块一份")
    func independent() async throws {
        let rig = try Rig()
        await rig.readyTwo()
        await rig.pull(ghostty)
        rig.set.pull(finder, on: second)
        await rig.set.idle()
        #expect(rig.placed(on: .phone) == ghostty)
        #expect(rig.placed(on: second) == finder)
        #expect(rig.windows.window(ghostty.key)?.frame == phoneArea)
        #expect(rig.windows.window(finder.key)?.frame == rig.secondArea)
        #expect(rig.record(of: .phone)?.original == ghosttyHome)
        #expect(rig.record(of: second)?.original == finderHome)
    }

    @Test("在 B 屏上点已经放在 A 屏上的窗口：挪到 B，A 回到 App 资源库；原位记录跟着走，中间不还原一次")
    func transfer() async throws {
        let rig = try Rig()
        await rig.readyTwo()
        await rig.pull(ghostty)
        rig.journal.clear()
        rig.set.pull(ghostty, on: second)
        await rig.set.idle()
        #expect(rig.placed(on: .phone) == nil)
        #expect(rig.set.state.desks[.phone]?.listVisible == true)
        #expect(rig.placed(on: second) == ghostty)
        #expect(rig.windows.window(ghostty.key)?.frame == rig.secondArea)
        #expect(!rig.journal.all.contains("move 7 \(ghosttyHome.short)"))
        #expect(!rig.journal.all.contains { $0.hasPrefix("zoom") })
        #expect(rig.record(of: .phone) == nil)
        #expect(rig.record(of: second)?.original == ghosttyHome)
        // 再从 B 放回原位：回到最初的位置，字号缩回
        rig.set.putBack(on: second)
        await rig.set.idle()
        #expect(rig.windows.window(ghostty.key)?.frame == ghosttyHome)
        #expect(rig.windows.window(ghostty.key)?.zoom == 0)
    }

    @Test("挪到电脑屏：先在手机屏上放回原位、缩回字号，再挪到电脑屏居中，不铺满")
    func transferToComputer() async throws {
        let rig = try Rig()
        await rig.readyTwo(computer)
        await rig.pull(ghostty)
        rig.set.pull(ghostty, on: second)
        await rig.set.idle()
        #expect(rig.placed(on: .phone) == nil)
        #expect(rig.windows.window(ghostty.key)?.zoom == 0)
        let area = try #require(rig.displays.windowArea(102, withHomeBar: false))
        #expect(rig.windows.window(ghostty.key)?.frame == area.centered(ghosttyHome.size))
        #expect(rig.record(of: .phone) == nil)
        #expect(rig.record(of: second) == nil)
    }

    @Test("撤一块屏，另一块不动：撤的那块按账放回，留下的那块照旧放着")
    func removeOne() async throws {
        let rig = try Rig()
        await rig.readyTwo()
        await rig.pull(ghostty)
        rig.set.pull(finder, on: second)
        await rig.set.idle()
        rig.timeline.advance(10)
        rig.journal.clear()
        rig.set.setWishes([rig.desk.wish])
        await rig.set.idle()
        #expect(rig.journal.all.contains("retire 102"))
        #expect(!rig.journal.all.contains("retire 101"))
        #expect(rig.windows.window(finder.key)?.frame == finderHome)
        #expect(rig.placed(on: .phone) == ghostty)
        #expect(rig.windows.window(ghostty.key)?.frame == phoneArea)
        #expect(rig.set.state.desks[second] == nil)
        #expect(rig.record(of: second) == nil)
    }

    @Test("撤屏前清场：用户在这块屏上直接开的窗口挪到主屏居中，大小不超过主屏；最小化的、别的屏上的不动")
    func clearsBeforeRetire() async throws {
        let rig = try Rig()
        await rig.readyTwo(computer)
        let memo = WindowInfo(key: WindowKey(pid: 30, id: 40), app: "备忘录", bundleID: "com.apple.Notes", title: "新开的")
        let huge = WindowInfo(key: WindowKey(pid: 31, id: 41), app: "预览", bundleID: "com.apple.Preview", title: "大图")
        let memoFrame = CGRect(x: rig.secondArea.minX + 50, y: 100, width: 600, height: 400)
        rig.windows.add(memo.key, frame: memoFrame, info: memo)
        rig.windows.add(huge.key, frame: CGRect(x: rig.secondArea.midX - 1500, y: 0, width: 3000, height: 1000), info: huge)
        rig.timeline.advance(10)
        rig.set.setWishes([rig.desk.wish])
        await rig.set.idle()
        let main = FakeDisplays.main
        #expect(rig.windows.window(memo.key)?.frame == main.centered(memoFrame.size))
        #expect(rig.windows.window(huge.key)?.frame == main)
        #expect(rig.windows.window(ghostty.key)?.frame == ghosttyHome)
        // 清场在撤屏之前（∅：这块屏没记账），挪完的位置记进撤屏前的快照，善后不会把它们挪回去
        #expect(rig.journal.all == ["move 40 \(main.centered(memoFrame.size).short) ∅", "move 41 \(main.short) ∅", "snapshot", "retire 102", "restore"])
    }

    @Test("退出 App：它在各块屏上的窗口都先放回原位")
    func quitAcrossScreens() async throws {
        let rig = try Rig()
        let second7 = WindowInfo(key: WindowKey(pid: ghostty.key.pid, id: 70), app: ghostty.app, bundleID: ghostty.bundleID, title: "~/other")
        let secondHome = CGRect(x: 200, y: 150, width: 900, height: 600)
        rig.windows.add(second7.key, frame: secondHome, info: second7)
        await rig.readyTwo()
        await rig.pull(ghostty)
        rig.set.pull(second7, on: second)
        await rig.set.idle()
        rig.set.quit(RunningApp(pid: ghostty.key.pid, app: AppInfo(bundleID: "com.mitchellh.ghostty", name: ghostty.app, path: nil), windows: [ghostty, second7]), from: .phone)
        await rig.set.idle()
        #expect(rig.windows.window(ghostty.key)?.frame == ghosttyHome)
        #expect(rig.windows.window(second7.key)?.frame == secondHome)
        #expect(rig.placed(on: .phone) == nil)
        #expect(rig.placed(on: second) == nil)
    }

    @Test("在手机上退出一块屏：只退这一块，这次远程不再加它；另一块照旧")
    func dismissOne() async throws {
        let rig = try Rig()
        await rig.readyTwo()
        await rig.pull(ghostty)
        rig.timeline.advance(10)
        rig.set.dismissScreen(second)
        await rig.set.idle()
        #expect(rig.set.state.desks[second] == nil)
        #expect(rig.set.state.dismissed == [second])
        #expect(rig.placed(on: .phone) == ghostty)
        // 同一次远程里再算一遍要哪些屏：退出的那块不回来
        rig.set.setWishes([rig.desk.wish, rig.secondWish()])
        await rig.set.idle()
        #expect(rig.set.state.desks[second] == nil)
        // 远程结束再开始：回来
        rig.set.setWishes([])
        await rig.set.idle()
        rig.set.setWishes([rig.desk.wish, rig.secondWish()])
        await rig.set.idle()
        #expect(rig.set.state.desks[second]?.screen.display != nil)
    }

    @Test("启动时按每块屏的账还原：上次崩溃时两块屏上各放着一个窗口")
    func recoverAll() async throws {
        let tmp = try TempDir()
        do {
            let rig = try Rig(dataDirectory: tmp.url)
            await rig.readyTwo()
            await rig.pull(ghostty)
            rig.set.pull(finder, on: second)
            await rig.set.idle()
        }
        let rig = try Rig(dataDirectory: tmp.url)
        rig.windows.setFrame(ghostty.key, phoneArea)
        rig.windows.setFrame(finder.key, phoneArea.offsetBy(dx: 4000, dy: 0))
        rig.set.recover()
        await rig.set.idle()
        #expect(rig.windows.window(ghostty.key)?.frame == ghosttyHome)
        #expect(rig.windows.window(finder.key)?.frame == finderHome)
        #expect(rig.record(of: .phone) == nil)
        #expect(rig.record(of: second) == nil)
    }

    @Test("2.5 留下的还原账 phone-screen.json：挪成 placed/phone.json 再按它还原")
    func migratesLegacyRecord() async throws {
        let rig = try Rig()
        let record = PlacedRecord(window: ghostty.key, app: ghostty.app, label: ghostty.label, original: ghosttyHome, wasFullScreen: false, zoom: 2,
                                  bundleID: ghostty.bundleID, title: ghostty.title, filled: phoneArea)
        try RestoreRecord<PlacedRecord>(url: rig.paths.legacyPlacedRecord).record(record)
        rig.windows.setFrame(ghostty.key, phoneArea)
        rig.set.recover()
        await rig.set.idle()
        #expect(rig.windows.window(ghostty.key)?.frame == ghosttyHome)
        #expect(!FileManager.default.fileExists(atPath: rig.paths.legacyPlacedRecord.path))
        #expect(rig.record(of: .phone) == nil)
    }

    @Test("加屏失败、等着重试时改了别的设置（又走一次差量）：不当场再建失败的那块，三次重试照样按点来")
    func failedWaitsForRetry() async throws {
        let rig = try Rig()
        rig.set.setWishes([rig.desk.wish])
        await rig.set.idle()
        rig.journal.clear()
        rig.displays.failuresLeft = .max
        rig.set.setWishes([rig.desk.wish, rig.secondWish()])
        var renamed = rig.secondWish()
        renamed.behavior = computer
        rig.set.setWishes([rig.desk.wish, renamed])
        await rig.set.idle()
        // 头一次加三次重试，一共 4 次
        #expect(rig.journal.all.filter { $0.hasPrefix("create") }.count == 4)
        #expect(rig.set.state.desks[second]?.screen == .failed)
    }

    // MARK: 设为主屏

    @Test("设为主屏：建好、善后之后设主屏；原主屏上的窗口跟着搬过去，不放回")
    func claimsMain() async throws {
        let rig = try Rig()
        var wish = rig.secondWish(computer)
        wish.main = true
        rig.set.setWishes([rig.desk.wish, wish])
        await rig.set.idle()
        #expect(rig.journal.all == ["snapshot", "create", "create", "restore", "main 102"])
        #expect(rig.arrangement.main == 102)
    }

    @Test("撤设成主屏的那块：先设回原主屏（窗口跟着回去），再清场、再撤")
    func releasesMainBeforeClearing() async throws {
        let rig = try Rig()
        var wish = rig.secondWish(computer)
        wish.main = true
        rig.set.setWishes([rig.desk.wish, wish])
        await rig.set.idle()
        rig.timeline.advance(10)
        rig.journal.clear()
        rig.set.setWishes([rig.desk.wish])
        await rig.set.idle()
        let arranged = try #require(rig.journal.all.firstIndex { $0.hasPrefix("arrange") })
        let retired = try #require(rig.journal.index(of: "retire 102"))
        #expect(arranged < retired)
        #expect(rig.arrangement.main == 1)
    }

    @Test("系统按这组屏幕记的排布已经把 Snug 的屏设成主屏（上次设了主屏没设回就崩了，同一次登录里再建）：原来的排布按 Snug 的屏出现前的主屏记，不再当主屏时还给它")
    func claimsMainAlreadyMadeBySystem() async throws {
        let rig = try Rig()
        rig.displays.onCreate = { [unowned arrangement = rig.arrangement] in
            arrangement.origins_ = [1: CGPoint(x: -1512, y: 0), 101: .zero]
        }
        var wish = rig.secondWish(computer)
        wish.main = true
        rig.set.setWishes([wish])
        await rig.set.idle()
        rig.set.setWishes([rig.secondWish(computer)])
        await rig.set.idle()
        #expect(rig.arrangement.main == 1)
        #expect(rig.arrangement.origins()[101] == CGPoint(x: 1512, y: 0))
    }

    @Test("设了主屏时放上屏的外接屏窗口：原位按没设主屏时的坐标记，不再当主屏、撤屏后回到原处")
    func placedWhileMainReturnsHome() async throws {
        let rig = try Rig()
        let home = CGRect(x: -1800, y: 100, width: 800, height: 600)
        let xcode = WindowInfo(key: WindowKey(pid: 30, id: 50), app: "Xcode", bundleID: "com.apple.dt.Xcode", title: "snug")
        rig.windows.add(xcode.key, frame: home, info: xcode)
        var wish = rig.secondWish(computer)
        wish.main = true
        rig.set.setWishes([rig.desk.wish, wish])
        await rig.set.idle()
        // 设成主屏的那块屏原来的原点：主屏的原点总在 (0,0)，别的屏连同上面的窗口一起平移了这么多
        let shift = try #require(rig.displays.bounds(102)).origin
        _ = await rig.windows.move(xcode.key, to: home.offsetBy(dx: -shift.x, dy: -shift.y))
        await rig.pull(xcode)
        wish.main = false
        rig.set.setWishes([rig.desk.wish, wish])
        await rig.set.idle()
        rig.timeline.advance(10)
        rig.set.setWishes([])
        await rig.set.idle()
        #expect(rig.windows.window(xcode.key)?.frame == home)
    }

    @Test("屏留着、只是不再当主屏：设回原主屏，屏不撤")
    func unsetMainKeepsScreen() async throws {
        let rig = try Rig()
        var wish = rig.secondWish(computer)
        wish.main = true
        rig.set.setWishes([wish])
        await rig.set.idle()
        rig.journal.clear()
        rig.set.setWishes([rig.secondWish(computer)])
        await rig.set.idle()
        #expect(rig.journal.all.filter { $0.hasPrefix("arrange") }.count == 1)
        #expect(!rig.journal.all.contains { $0.hasPrefix("retire") })
        #expect(rig.arrangement.main == 1)
    }

    @Test("同样的要求重复给：不重复设主屏")
    func claimsOnce() async throws {
        let rig = try Rig()
        var wish = rig.secondWish(computer)
        wish.main = true
        rig.set.setWishes([wish])
        await rig.set.idle()
        rig.set.setWishes([wish])
        await rig.set.idle()
        #expect(rig.journal.all.filter { $0.hasPrefix("main") }.count == 1)
    }

    @Test("设主屏失败：屏照常用，之后不再当主屏时不去摆排布")
    func mainFails() async throws {
        let rig = try Rig()
        rig.arrangement.fails = true
        var wish = rig.secondWish(computer)
        wish.main = true
        rig.set.setWishes([wish])
        await rig.set.idle()
        #expect(rig.set.state.desks[second]?.screen == .ready(101))
        rig.arrangement.fails = false
        rig.set.setWishes([rig.secondWish(computer)])
        await rig.set.idle()
        #expect(!rig.journal.all.contains { $0.hasPrefix("arrange") })
    }

    @Test("不再当主屏时摆不回去：原来的排布留着，再设主屏、再设回时摆回设主屏之前")
    func restoreFailsKeepsSavedOrigins() async throws {
        let rig = try Rig()
        var wish = rig.secondWish(computer)
        wish.main = true
        rig.set.setWishes([wish])
        await rig.set.idle()
        rig.arrangement.fails = true
        wish.main = false
        rig.set.setWishes([wish])
        await rig.set.idle()
        #expect(rig.arrangement.main == 101)
        rig.arrangement.fails = false
        wish.main = true
        rig.set.setWishes([wish])
        await rig.set.idle()
        wish.main = false
        rig.set.setWishes([wish])
        await rig.set.idle()
        #expect(rig.arrangement.main == 1)
        #expect(rig.arrangement.origins()[1] == .zero)
    }
}
