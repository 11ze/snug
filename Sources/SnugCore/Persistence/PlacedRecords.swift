// 还原账在盘上的那一摞（一个文件一笔：触屏 placed/<屏 id>.json，电脑屏挪过来的窗口 placed/<屏 id>~<pid>-<窗口号>.json，
// 见 SnugPaths），和 2.5 那份 phone-screen.json 的迁移
import Foundation

struct PlacedRecords: Sendable {
    let paths: SnugPaths

    /// 手机屏已经有账（新版留了没放回的、降级回 2.5 又崩了一次）时，旧账单独存一份，和别的屏的账一样还，一笔不丢
    static let legacyScreen = ScreenID("phone-2.5")

    /// 每一笔还原账的名字（隔离起来的坏文件不算），当作屏的身份按它找到那个文件。目录还没有就是没有账；读不出来（没有权限）记一笔，当作这次没有账可还
    func screens() -> [ScreenID] {
        let names: [String]
        do {
            names = try FileManager.default.contentsOfDirectory(atPath: paths.placedRecords.path)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return []
        } catch {
            Log.error("还原账的目录读不出来（\(paths.placedRecords.path)），这次不还原：\(error)")
            return []
        }
        return names.sorted().compactMap { name in
            guard name.hasSuffix(".json"), !name.contains(".corrupt-") else { return nil }
            return ScreenID(String(name.dropLast(".json".count)))
        }
    }

    /// 2.5 及以前只有一块手机屏时的那份账：挪成手机屏的账；手机屏已经有账就挪成 legacyScreen 那一份。挪不动留在原处，下次再挪
    func migrateLegacy() {
        let fm = FileManager.default
        let legacy = paths.legacyPlacedRecord
        guard fm.fileExists(atPath: legacy.path) else { return }
        let phone = paths.placedRecord(for: .phone)
        let target = fm.fileExists(atPath: phone.path) ? paths.placedRecord(for: Self.legacyScreen) : phone
        do {
            try fm.createDirectory(at: paths.placedRecords, withIntermediateDirectories: true)
            try fm.moveItem(at: legacy, to: target)
            Log.info("旧版的还原账 phone-screen.json 挪成 placed/\(target.lastPathComponent)\(target == phone ? "" : "（手机屏已经有账，单独存一份一起还）")")
        } catch {
            Log.error("旧版的还原账挪不过去（\(legacy.path) → \(target.lastPathComponent)），留在原处下次再挪：\(error)")
        }
    }
}
