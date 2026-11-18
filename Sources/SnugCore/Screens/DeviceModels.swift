// 机型库：屏的比例按用户选的型号算（见 ScreenFit），行为按型号的类别标签定（见 ScreenPlan）。
// 机型库 Assets/device-models.json 是唯一的数据源，加机型、改数值都只改它；这里只管解码、校验和查找。
// 文件按类别分三段（手机、平板、电脑），类别写在段上，一条机型不会漏写类别。
// 用户选的那一台连同屏幕数值和类别一起存进配置（DeviceChoice）：启动时按机型名跟机型库对一遍（resolve），数值改过的跟着改；
// 机型库改名、删了这一条，就用存下的数值兜底
import Foundation

/// 设备类别：行为只看它，不看屏的形状（iPhone Duo 内屏和 iPad Pro 11 形状几乎一样，一个是手机一个是平板）
public enum DeviceKind: String, Codable, CaseIterable, Sendable {
    case phone, tablet, computer
}

// 按类别定的几条规则只写在这里，全用 switch：加一个类别时编译器逐处报错，不会有哪处悄悄按老规矩走
extension DeviceKind {
    /// 触屏：屏上有 App 资源库面板，翻译手势、放大字号（见 ScreenPlan.behavior）；电脑都不要
    public var isTouch: Bool {
        switch self {
        case .phone, .tablet: true
        case .computer: false
        }
    }

    /// 平常的方向：添加屏幕时选了这一类先摆成它；名字里是这个方向就不写「横屏」「竖屏」（见 ScreenConfig.suggestedName）
    public var usualOrientation: Orientation {
        switch self {
        case .phone: .portrait
        case .tablet, .computer: .landscape
        }
    }

    /// 能选的方向：电脑只有横屏（docs/multi-screen.md 第 1 节）
    public var allowedOrientations: [Orientation] {
        switch self {
        case .phone, .tablet: [.portrait, .landscape]
        case .computer: [.landscape]
        }
    }

    /// 一块屏的型号能换成哪几类：触不触屏一样的才能换。屏上的面板、手势跟着触屏走，跨过去等于换一块屏
    public var swappableKinds: Set<DeviceKind> {
        Set(Self.allCases.filter { $0.isTouch == isTouch })
    }
}

/// 屏的方向：添加时定，之后不改（换方向要撤屏重建，UU 也得重选屏，和换一块新屏没有区别）
public enum Orientation: String, Codable, CaseIterable, Sendable {
    case portrait, landscape
}

/// 一台设备的屏幕，短边在前。手机、平板写面板的分辨率（像素），另有逻辑分辨率的短边（点）；
/// 手机只看比例，所以自己填的也可以是比例（9 × 20 和 1080 × 2400 一样）。
/// 电脑写系统设置「显示器」里用的那一档（点，如 MacBook Air 13 的 1470 × 956）：电脑屏照搬它，和本机看着一样大。
/// Mac 的缩放档不是面板像素的整数分之一（Air 15 是 2880 × 1864 显示成 1710 × 1112），从像素推不准，所以直接写点
public struct DeviceScreen: Codable, Hashable, Sendable {
    public var width: Int
    public var height: Int
    /// 手机、平板逻辑分辨率的短边（点）。Apple 设备有公开数值；不知道时按 ScreenFit 里的估值。电脑不用
    public var points: Int?
    /// 有刘海的 MacBook：刘海那一条的高度（点），横屏时扣掉
    public var notch: Int?

    public init(width: Int, height: Int, points: Int? = nil, notch: Int? = nil) {
        self.width = width
        self.height = height
        self.points = points
        self.notch = notch
    }

    /// 能用来算比例：都是正数，短边在前
    public var isValid: Bool {
        width > 0 && height > 0 && width <= height && (points ?? 1) > 0 && (notch ?? 0) >= 0
    }

    /// 自己填的分辨率或比例：长短边填反了的换过来；没填、不是正数、大得离谱的不收
    public static func custom(_ a: Int?, _ b: Int?) -> DeviceScreen? {
        let range = 1...20000
        guard let a, let b, range.contains(a), range.contains(b) else { return nil }
        return DeviceScreen(width: min(a, b), height: max(a, b))
    }
}

/// 机型库里的一台
public struct DeviceModel: Hashable, Sendable, Identifiable {
    public let brand: String
    public let name: String
    public let kind: DeviceKind
    public let screen: DeviceScreen

    /// 品牌 + 型号，如「Apple iPhone 17 Pro Max」「华为 Mate 70 Pro」：选中后存进配置、显示在设置里的就是它
    public var id: String { "\(brand) \(name)" }
}

/// 用户选的设备：机型库里的一台，或自己填的分辨率和类别
public struct DeviceChoice: Codable, Equatable, Sendable {
    /// 机型全名（DeviceModel.id）；自己填的为 nil
    public var model: String?
    public var screen: DeviceScreen
    public var kind: DeviceKind

    public init(model: String?, screen: DeviceScreen, kind: DeviceKind = .phone) {
        self.model = model
        self.screen = screen
        self.kind = kind
    }

    public init(_ model: DeviceModel) {
        self.init(model: model.id, screen: model.screen, kind: model.kind)
    }

    private enum CodingKeys: String, CodingKey { case model, screen, kind }

    /// 2.5 以前存的手机型号没有 kind：都是手机
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        model = try c.decodeIfPresent(String.self, forKey: .model)
        screen = try c.decode(DeviceScreen.self, forKey: .screen)
        kind = (try? c.decodeIfPresent(DeviceKind.self, forKey: .kind)) ?? .phone
    }

    /// 没选过时用的：手机屏最早就是在这台上调出来的（540×950）。必须和机型库里的那一条一致（有测试盯着）
    public static let standard = DeviceChoice(model: "Apple iPhone 17 Pro Max", screen: DeviceScreen(width: 1320, height: 2868, points: 440))

    /// 显示用的名字：机型去掉品牌（「iPhone 17 Pro Max」），自己填的写分辨率
    public var title: String {
        guard let model else { return "\(screen.width) × \(screen.height)" }
        return model.hasPrefix("Apple ") ? String(model.dropFirst("Apple ".count)) : model
    }
}

public struct DeviceCatalog: Equatable, Sendable {
    public struct Brand: Equatable, Sendable, Identifiable {
        public let name: String
        /// 别名：英文名、拼音（「华为」也能用 huawei 搜到）
        public let aliases: [String]
        public let kind: DeviceKind
        /// 按机型库里的顺序（新的在前）
        public let models: [DeviceModel]
        /// 同一个品牌在几个类别里各有一段（Apple 的 iPhone、iPad、Mac）
        public var id: String { "\(kind.rawValue)/\(name)" }
    }

    /// 按文件里的顺序：手机、平板、电脑
    public let brands: [Brand]

    public static let empty = DeviceCatalog(brands: [])

    init(brands: [Brand]) { self.brands = brands }

    /// 解码并校验机型库。不合格的条目整份拒收，并写明是哪一条、错在哪：机型库是随 App 发的，错了要在测试里拦下来
    public init(json: Data) throws {
        let file: File
        do {
            file = try JSONDecoder().decode(File.self, from: json)
        } catch {
            throw DeviceCatalogError("解不开：\(error)")
        }
        var seen = Set<String>()
        var brands: [Brand] = []
        for kind in DeviceKind.allCases {
            var seenBrands = Set<String>()
            for brand in file[kind] {
                guard !brand.name.isEmpty, !brand.models.isEmpty else { throw DeviceCatalogError("品牌「\(brand.name)」没有名字或没有机型") }
                // 界面按品牌名分节（ForEach 的 id），同一个类别里同一个品牌只能有一段
                guard seenBrands.insert(Self.normalized(brand.name)).inserted else { throw DeviceCatalogError("\(kind.rawValue) 里品牌「\(brand.name)」重复了") }
                let models = try brand.models.map { entry in
                    guard entry.screen.count == 2 else { throw DeviceCatalogError("\(brand.name) \(entry.name)：screen 要写成 [短边, 长边]") }
                    let model = DeviceModel(brand: brand.name, name: entry.name, kind: kind,
                                            screen: DeviceScreen(width: entry.screen[0], height: entry.screen[1], points: entry.points, notch: entry.notch))
                    guard !entry.name.isEmpty, model.screen.isValid else {
                        throw DeviceCatalogError("\(model.id)：分辨率要是正数、短边在前")
                    }
                    guard seen.insert(Self.normalized(model.id)).inserted else { throw DeviceCatalogError("\(model.id)：重复了") }
                    return model
                }
                brands.append(Brand(name: brand.name, aliases: brand.aliases ?? [], kind: kind, models: models))
            }
        }
        self.brands = brands
    }

    public init(contentsOf url: URL) throws {
        try self.init(json: try Data(contentsOf: url))
    }

    public var models: [DeviceModel] { brands.flatMap(\.models) }

    public func brands(_ kind: DeviceKind) -> [Brand] { brands.filter { $0.kind == kind } }

    public func model(id: String) -> DeviceModel? {
        models.first { $0.id == id }
    }

    /// 配置里存的那台按机型库现在的数值来：机型库改过这台的分辨率就用新的；改名、删了就用存下的数值（自己填的原样返回）
    public func resolve(_ choice: DeviceChoice) -> DeviceChoice {
        guard let id = choice.model, let model = model(id: id) else { return choice }
        return DeviceChoice(model)
    }

    /// 按型号名、品牌名和别名找，不分大小写、不看空格（17promax、mate70、huawei mate 都行）。品牌整个命中就列出全部。
    /// kinds 给了就只在这几类里找
    public func search(_ query: String, in kinds: Set<DeviceKind> = Set(DeviceKind.allCases)) -> [Brand] {
        let q = Self.normalized(query)
        let pool = brands.filter { kinds.contains($0.kind) }
        guard !q.isEmpty else { return pool }
        return pool.compactMap { brand in
            let names = ([brand.name] + brand.aliases).map(Self.normalized)
            let models = brand.models.filter { model in
                let name = Self.normalized(model.name)
                return names.contains { ($0 + name).contains(q) }
            }
            return models.isEmpty ? nil : Brand(name: brand.name, aliases: brand.aliases, kind: brand.kind, models: models)
        }
    }

    static func normalized(_ text: String) -> String {
        text.lowercased().filter { !$0.isWhitespace }
    }

    /// 文件的样子：{"phone": [品牌…], "tablet": [品牌…], "computer": [品牌…]}，
    /// 品牌是 {"name", "aliases"?, "models": [{"name", "screen": [短边, 长边], "points"?, "notch"?, "year"}]}。
    /// year 只给整理机型库的人看（按它从新到旧排），代码不读
    private struct File: Decodable {
        struct Brand: Decodable {
            let name: String
            let aliases: [String]?
            let models: [Model]
        }

        struct Model: Decodable {
            let name: String
            let screen: [Int]
            let points: Int?
            let notch: Int?
        }

        let phone: [Brand]
        let tablet: [Brand]?
        let computer: [Brand]?

        subscript(kind: DeviceKind) -> [Brand] {
            switch kind {
            case .phone: phone
            case .tablet: tablet ?? []
            case .computer: computer ?? []
            }
        }
    }
}

public struct DeviceCatalogError: Error, Equatable, CustomStringConvertible {
    public let description: String
    init(_ description: String) { self.description = "机型库：\(description)" }
}
