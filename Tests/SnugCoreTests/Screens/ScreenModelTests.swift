import CoreGraphics
import Foundation
import Testing
@testable import SnugCore

@Suite("屏的身份 ScreenSpec")
struct ScreenSpecTests {
    @Test("物理尺寸按像素上限（框住所有档位）、220ppi 折算（不是手机的 460ppi）")
    func millimeters() {
        let mm = phoneSpec.millimeters
        #expect(abs(mm.width - 2160.0 / 220 * 25.4) < 0.001)
        #expect(abs(mm.height - 4320.0 / 220 * 25.4) < 0.001)
    }
}


@Suite("窗口信息")
struct WindowInfoTests {
    private func w(_ id: UInt32, _ app: String) -> WindowInfo {
        WindowInfo(key: WindowKey(pid: 1, id: id), app: app, bundleID: nil, title: "")
    }

    @Test("日志标签：有标题带标题，太长截断")
    func label() {
        #expect(w(1, "Finder").label == "Finder")
        let long = WindowInfo(key: WindowKey(pid: 1, id: 1), app: "Safari", bundleID: nil, title: String(repeating: "长", count: 40))
        #expect(long.label == "Safari「\(String(repeating: "长", count: 30))」")
    }

    @Test("标题去掉看不见的格式字符（网页的隐形水印），组合表情的零宽连接符留着")
    func visibleTitle() {
        #expect(WindowInfo.visibleTitle("\u{200C}\u{200B}\u{2061}\u{FEFF}报销 - Feishu Docs") == "报销 - Feishu Docs")
        #expect(WindowInfo.visibleTitle("\u{200E}README.md\u{200F}") == "README.md")
        #expect(WindowInfo.visibleTitle("家 👨\u{200D}👩\u{200D}👧") == "家 👨\u{200D}👩\u{200D}👧")
    }

    @Test("框对比：2 点以内算对上")
    func matches() {
        let a = CGRect(x: 0, y: 25, width: 540, height: 897)
        #expect(a.matches(CGRect(x: 1, y: 26, width: 541, height: 896)))
        #expect(!a.matches(CGRect(x: 0, y: 25, width: 540, height: 870)))
    }
}

@Suite("字号账本 ZoomBook")
struct ZoomBookTests {
    @Test("名单里的 App 按记住的级数，没记过用默认；名单外一律 0（不乱发 ⌘=）")
    func steps() {
        var book = ZoomBook()
        #expect(book.steps(for: "com.mitchellh.ghostty", default: 2) == 2)
        book.remember(3, for: "com.mitchellh.ghostty")
        #expect(book.steps(for: "com.mitchellh.ghostty", default: 2) == 3)
        #expect(book.steps(for: "com.apple.finder", default: 2) == 0)
        #expect(book.steps(for: nil, default: 2) == 0)
        // 浏览器按网站记缩放、改了收不回来：不调
        #expect(book.steps(for: "com.apple.Safari", default: 2) == 0)
        #expect(book.steps(for: "com.google.Chrome", default: 2) == 0)
    }

    @Test("级数夹在 -4...8")
    func clamped() {
        var book = ZoomBook()
        book.remember(20, for: "com.googlecode.iterm2")
        #expect(book.steps(for: "com.googlecode.iterm2", default: 0) == 8)
        #expect(book.steps(for: "com.apple.Terminal", default: -9) == -4)
    }

    @Test("编码后能读回")
    func roundTrip() throws {
        var book = ZoomBook()
        book.remember(1, for: "dev.zed.Zed")
        #expect(try JSONDecoder().decode(ZoomBook.self, from: JSONEncoder().encode(book)) == book)
    }
}
