// 电脑屏的 App 资源库：Mac 样式的窗口，从菜单栏的「App 资源库」打开，在哪块 Snug 屏的菜单栏点就在哪块屏上开、往哪块屏放。
// 电脑屏没有小横条；已经开在别的屏上的窗口不会自己过来，点程序坞只是把它在原来的屏上提到前面（V9），
// 远端的人看不见别的屏、拖不了窗口，靠这里一键拉过来。
// 左栏「运行中 / 全部 App」；每个窗口标出现在在哪块屏，「放到这块屏」交给 DeskSet（电脑屏只挪过来居中，不铺满、不调字号）。
// 数据和屏上的资源库共用 AppCatalog；窗口在哪块屏问窗口服务器（不经过 App），露着时每次刷新列表跟着读
import AppKit
import SnugCore
import SnugSystem
import SwiftUI

@MainActor
@Observable
final class LibraryModel {
    enum Source: Hashable {
        case running, all
    }

    /// 往哪块屏放
    var target: ScreenID?
    var source = Source.running
    var query = ""
    /// 每个窗口此刻在哪块屏上；不在屏上的（最小化、在别的桌面）没有
    private(set) var locations: [WindowKey: DisplayID]

    @ObservationIgnored private var locating: Task<Void, Never>?

    /// locations：渲染样例给定的位置，平常由 startLocating 读
    init(locations: [WindowKey: DisplayID] = [:]) {
        self.locations = locations
    }

    /// 露着时跟着刷新读窗口在哪块屏
    func startLocating(_ catalog: AppCatalog) {
        guard locating == nil else { return }
        locating = Task { [weak self] in
            let windows = WindowService()
            while !Task.isCancelled {
                var found: [WindowKey: DisplayID] = [:]
                for pid in Set(catalog.running.map(\.pid)) {
                    for (key, frame) in await windows.frames(of: pid) {
                        found[key] = Self.display(at: CGPoint(x: frame.midX, y: frame.midY))
                    }
                }
                guard let self, !Task.isCancelled else { return }
                if found != locations { locations = found }
                try? await Task.sleep(for: .seconds(AppCatalog.refreshInterval))
            }
        }
    }

    func stopLocating() {
        locating?.cancel()
        locating = nil
    }

    private static func display(at point: CGPoint) -> DisplayID? {
        var id: CGDirectDisplayID = 0
        var count: UInt32 = 0
        guard CGGetDisplaysWithPoint(point, 1, &id, &count) == .success, count > 0 else { return nil }
        return id
    }
}

struct LibraryView: View {
    let state: AppState
    let catalog: AppCatalog
    @Bindable var model: LibraryModel
    let intents: any AppIntents
    let place: (WindowInfo) -> Void
    let open: (AppInfo) -> Void

    private var targetDisplay: DisplayID? { model.target.flatMap { state.desks.desks[$0]?.display } }
    private var targetName: String? { model.target.flatMap { state.screen($0)?.name } }

    var body: some View {
        NavigationSplitView {
            List(selection: $model.source) {
                Label("运行中", systemImage: "macwindow").badge(withWindows.count).tag(LibraryModel.Source.running)
                Label("全部 App", systemImage: "square.grid.2x2").badge(catalog.installed.count).tag(LibraryModel.Source.all)
            }
            .navigationSplitViewColumnWidth(MacTokens.Size.librarySidebar)
        } detail: {
            Group {
                switch model.source {
                case .running: running
                case .all: all
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { banner }
            .navigationTitle("App 资源库")
            .navigationSubtitle(targetName.map { "放到「\($0)」" } ?? "Snug 的屏都不在")
        }
        .searchable(text: $model.query, placement: .toolbar, prompt: "搜索")
        .frame(minWidth: MacTokens.Size.LibraryWindow.width, minHeight: MacTokens.Size.LibraryWindow.height)
    }

    private var query: String { model.query.trimmingCharacters(in: .whitespaces) }

    /// 电脑屏没有面板：这块屏正在做的事、出的问题（放不过来、屏没好）写在列表上面，下一个动作开始时清掉
    @ViewBuilder private var banner: some View {
        let desk = model.target.flatMap { state.desks.desks[$0] }
        if let work = desk?.work {
            HStack(spacing: MacTokens.Space.s) {
                ProgressView().controlSize(.small)
                Text(work.libraryText).foregroundStyle(.secondary)
                Spacer()
            }
            .bannerStyle()
        } else if let notice = desk?.notice {
            HStack(alignment: .firstTextBaseline, spacing: MacTokens.Space.s) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(MacTokens.Color.warning)
                Text(notice.text.headline)
                if let detail = notice.text.detail { Text(detail).foregroundStyle(.secondary) }
                Spacer()
            }
            .bannerStyle()
        }
    }

    /// 有窗口的才列：电脑屏上要的是把窗口拉过来，没窗口的 App 在「全部 App」里点开
    private var withWindows: [RunningApp] { catalog.running.filter { !$0.windows.isEmpty } }

    @ViewBuilder private var running: some View {
        // 搜索：App 名对上的整个 App、标题对上的窗口各自列出
        let apps: [RunningApp] = query.isEmpty ? withWindows : {
            let found = AppList.search(query, installed: [], running: withWindows)
            let ids = Set(found.apps.map(\.bundleID))
            let windows = Set(found.windows.map(\.key))
            return withWindows.compactMap { app in
                if ids.contains(app.app.bundleID) { return app }
                var only = app
                only.windows = app.windows.filter { windows.contains($0.key) }
                return only.windows.isEmpty ? nil : only
            }
        }()
        if !catalog.loaded {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if apps.isEmpty {
            ContentUnavailableView(query.isEmpty ? "没有正在运行的 App" : "无结果", systemImage: "macwindow")
        } else {
            List {
                ForEach(apps) { app in
                    Section {
                        ForEach(app.windows) { window in windowRow(window).listRowSeparator(.hidden) }
                    } header: {
                        HStack(spacing: MacTokens.Space.s) {
                            Image(nsImage: catalog.icon(for: app.app)).resizable().frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(app.app.name).font(.headline).foregroundStyle(.primary)
                                Text(app.windowSummary).font(.callout).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func windowRow(_ window: WindowInfo) -> some View {
        let here = targetDisplay != nil && model.locations[window.key] == targetDisplay
        return HStack(spacing: MacTokens.Space.s) {
            Image(systemName: "macwindow").foregroundStyle(.secondary)
            Text(window.displayTitle).lineLimit(1)
            Spacer(minLength: MacTokens.Space.m)
            Text(where_(window, here: here)).font(.callout).foregroundStyle(.secondary)
            if !here {
                Button("放到这块屏") { place(window) }
                    .disabled(targetDisplay == nil || state.desks.closing.contains(window.key))
            }
        }
        .frame(minHeight: MacTokens.Size.rowMinHeight - MacTokens.Space.s)
    }

    /// 窗口在哪：这块屏、别的 Snug 屏（写名字）、别的屏（写屏名）、已最小化
    private func where_(_ window: WindowInfo, here: Bool) -> String {
        if here { return "在这块屏" }
        if window.minimized { return "已最小化" }
        guard let display = model.locations[window.key] else { return "不在当前桌面" }
        if let id = state.desks.desks.first(where: { $0.value.display == display })?.key, let name = state.screen(id)?.name {
            return "在「\(name)」"
        }
        return CGDisplayIsBuiltin(display) != 0 ? "在内建屏" : "在「\(Screens.name(of: display))」"
    }

    @ViewBuilder private var all: some View {
        let apps = query.isEmpty ? catalog.installed.map(\.app) : AppList.search(query, installed: catalog.installed, running: []).apps
        if catalog.installed.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: MacTokens.Space.m)], spacing: MacTokens.Space.l) {
                    ForEach(apps, id: \.bundleID) { app in
                        Button { open(app) } label: {
                            VStack(spacing: MacTokens.Space.xs) {
                                Image(nsImage: catalog.icon(for: app)).resizable().frame(width: 56, height: 56)
                                Text(app.name).font(.callout).lineLimit(1)
                                Circle().fill(.secondary).frame(width: 4, height: 4).opacity(catalog.running(app) == nil ? 0 : 1)
                            }
                            .frame(maxWidth: 96)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(targetDisplay == nil)
                    }
                }
                .padding(MacTokens.Space.xl)
            }
        }
    }
}

private extension View {
    func bannerStyle() -> some View {
        font(.callout)
            .padding(.horizontal, MacTokens.Space.l)
            .padding(.vertical, MacTokens.Space.s)
            .background(.bar)
    }
}

private extension Desk.Work {
    /// 资源库窗口上的进度：电脑屏只有打开 App、挪窗口两件事
    var libraryText: String {
        switch self {
        case .opening(let app): "正在打开 \(app.name)…"
        case .placing(let window): "正在把 \(window.app) 挪过来…"
        default: "请稍候…"
        }
    }
}

/// 资源库窗口：一个，开在要放的那块屏上；关掉就停刷新
@MainActor
final class LibraryWindowController: NSObject, NSWindowDelegate {
    private let state: AppState
    private let catalog: AppCatalog
    private let desks: DeskSet
    private let intents: any AppIntents
    private let model = LibraryModel()
    private var window: NSWindow?
    private static let owner = "library"

    init(state: AppState, catalog: AppCatalog, desks: DeskSet, intents: any AppIntents) {
        self.state = state
        self.catalog = catalog
        self.desks = desks
        self.intents = intents
    }

    /// clicked：点菜单栏图标时那块屏。是 Snug 的屏就往它放，不然往 UU 正在推的那块、再不然第一块就绪的
    func show(on clicked: DisplayID?) {
        let ready = state.config.screens.map(\.id).filter { state.desks.desks[$0]?.display != nil }
        let onClicked = ready.first { state.desks.desks[$0]?.display == clicked }
        model.target = onClicked ?? state.watchedScreen ?? ready.first
        if window == nil {
            let view = LibraryView(state: state, catalog: catalog, model: model, intents: intents,
                                   place: { [weak self] window in
                                       guard let self, let target = model.target else { return }
                                       desks.pull(window, on: target)
                                   },
                                   open: { [weak self] app in
                                       guard let self, let target = model.target else { return }
                                       switch AppList.action(for: app, running: catalog.running) {
                                       case .pull(let window): desks.pull(window, on: target)
                                       case .open(let app): desks.open(app, on: target)
                                       }
                                   })
            let w = NSWindow(contentViewController: NSHostingController(rootView: view))
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            w.title = "App 资源库"
            w.setContentSize(NSSize(width: MacTokens.Size.LibraryWindow.width, height: MacTokens.Size.LibraryWindow.height))
            w.isReleasedWhenClosed = false
            w.delegate = self
            window = w
        }
        // 开在要放的那块屏上：远端的人看得见
        if let display = model.target.flatMap({ state.desks.desks[$0]?.display }), let screen = Screens.screen(for: display), let window {
            let frame = window.frame
            window.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - frame.width / 2, y: screen.visibleFrame.midY - frame.height / 2))
        } else {
            window?.center()
        }
        catalog.want(Self.owner)
        model.startLocating(catalog)
        window?.present(activating: true)
    }

    func windowWillClose(_ notification: Notification) {
        catalog.release(Self.owner)
        model.stopLocating()
    }
}
