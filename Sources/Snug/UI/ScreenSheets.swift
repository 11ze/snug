// 设置窗口「屏幕」页弹出的两张表单，和设置窗口同一种分组样式（标签在左、控件在右，提示写在对应那一行的标签下）：
// - 添加屏幕：先选设备，再选方向（电脑只能横），型号列表只列这一类的；名字按型号和方向自动起，改过就不再跟着变
// - 屏幕详情：一块屏自己的设置。改型号当场换比例、不用重连；方向添加后不能改；删除在左下、红字，再问一次
import AppKit
import SwiftUI
import SnugCore

struct AddScreenSheet: View {
    let state: AppState
    let intents: any AppIntents
    let close: () -> Void

    @State private var kind = DeviceKind.phone
    @State private var orientation = Orientation.portrait
    @State private var device: DeviceChoice?
    @State private var name = ""
    /// 用户自己改过名字（和建议的不一样）：之后换型号、方向不再覆盖。文本框拿到焦点时会原样写回一次，不能一写就算改过
    @State private var named = false

    /// 手机默认和新装时那块屏一样（机型库里排第一的是折叠屏的内屏，当默认不合适）；平板、电脑是这一类第一台（新的在前）；
    /// 机型库读不出来就用默认的那台换成这一类
    private var chosen: DeviceChoice {
        if let device, device.kind == kind { return device }
        if kind == .phone { return state.devices.resolve(.standard) }
        if let first = state.devices.brands(kind).first?.models.first { return DeviceChoice(first) }
        return DeviceChoice(model: nil, screen: DeviceChoice.standard.screen, kind: kind)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MacTokens.Space.l) {
            Text("添加屏幕").font(.headline)
            Form {
                Section {
                    LabeledContent("设备") {
                        Picker("设备", selection: $kind) {
                            ForEach(DeviceKind.allCases, id: \.self) { kind in
                                Label(kind.title, systemImage: kind.symbol(.portrait)).labelStyle(.titleAndIcon).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                    LabeledContent {
                        Picker("方向", selection: $orientation) {
                            Label("竖", systemImage: "rectangle.portrait").labelStyle(.titleAndIcon).tag(Orientation.portrait)
                            Label("横", systemImage: "rectangle").labelStyle(.titleAndIcon).tag(Orientation.landscape)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                        .disabled(kind == .computer)
                    } label: {
                        Text("方向")
                        Text("添加后不能改")
                    }
                    LabeledContent("型号") {
                        DeviceMenu(state: state, kinds: [kind], current: chosen) { device = $0 }
                    }
                    LabeledContent {
                        TextField("名字", text: Binding(get: { name }, set: { name = $0; named = $0 != suggested }), prompt: Text(suggested))
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.leading)
                            .frame(width: MacTokens.Size.nameFieldWidth)
                    } label: {
                        Text("名字")
                        Text("显示在 UU远程 的屏幕列表里")
                    }
                }
            }
            .sheetForm()
            Tip(symbol: "info.circle", text: "UU远程 一次只让一台设备控制。新加的屏留给横竖切换，或者换另一台设备时用。")
            if kind == .computer {
                Tip(symbol: "exclamationmark.triangle", text: "没接显示器的 Mac，加任何一块屏都会顶掉系统的默认屏。")
            }
            HStack {
                Spacer()
                Button("取消", action: close).keyboardShortcut(.cancelAction)
                Button("添加") {
                    let name = name.trimmingCharacters(in: .whitespaces)
                    intents.addScreen(orientation: orientation, device: chosen, name: name.isEmpty ? suggested : name)
                    close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(MacTokens.Space.xl)
        .frame(width: MacTokens.Size.sheetWidth)
        .onAppear { name = suggested }
        .onChange(of: kind) {
            // 每类设备平常的方向：手机竖，平板、电脑横
            orientation = kind == .phone ? .portrait : .landscape
            device = nil
        }
        .onChange(of: suggested) { if !named { name = suggested } }
    }

    private var suggested: String { ScreenConfig.suggestedName(for: chosen, orientation: orientation) }
}

struct ScreenDetailSheet: View {
    let id: ScreenID
    let state: AppState
    let intents: any AppIntents
    let close: () -> Void

    @State private var name = ""
    @State private var confirmingDelete = false

    var body: some View {
        if let screen = state.screen(id) {
            content(screen)
        } else {
            // 删掉了（或配置被别处改了）：没东西可看
            Color.clear.frame(width: 1, height: 1).onAppear(perform: close)
        }
    }

    private func content(_ screen: ScreenConfig) -> some View {
        VStack(alignment: .leading, spacing: MacTokens.Space.l) {
            HStack(spacing: MacTokens.Space.m) {
                StatusTile(MacTokens.IconTile.screen(symbol: screen.symbol))
                VStack(alignment: .leading, spacing: MacTokens.Space.xxs) {
                    Text(screen.name).font(.headline)
                    Text("\(screen.device.kind.title) · \(screen.sizeText)").foregroundStyle(.secondary)
                }
            }
            Form {
                Section {
                    LabeledContent("名字") {
                        TextField("名字", text: $name)
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.leading)
                            .frame(width: MacTokens.Size.nameFieldWidth)
                            .onSubmit { intents.renameScreen(id, name) }
                    }
                    LabeledContent("型号") {
                        // 触屏和电脑之间不换：屏上的面板、手势跟着类别走，换类别等于换一块屏
                        DeviceMenu(state: state, kinds: screen.device.kind == .computer ? [.computer] : [.phone, .tablet],
                                   current: screen.device) { intents.setScreenDevice(id, $0) }
                    }
                    LabeledContent("方向") { Text(screen.orientation.title).foregroundStyle(.secondary) }
                } footer: {
                    Text("改型号当场换比例，不用重连。方向添加后不能改；改名下次远程时生效。")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .sheetForm()
            HStack {
                Button("删除这块屏…", role: .destructive) { confirmingDelete = true }
                    .buttonStyle(.borderless)
                    .foregroundStyle(MacTokens.Color.danger)
                Spacer()
                Button("完成") {
                    intents.renameScreen(id, name)
                    close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(MacTokens.Space.xl)
        .frame(width: MacTokens.Size.sheetWidth)
        .onAppear { name = screen.name }
        .confirmationDialog("删除「\(screen.name)」？", isPresented: $confirmingDelete) {
            Button("删除", role: .destructive) {
                close()
                intents.removeScreen(id)
            }
        } message: {
            Text("远程中删除会马上撤掉这块屏，上面的窗口放回原处。")
        }
    }
}

/// 表单里的分组：去掉 Form 自带的底色和左右留白，和表单本身的底色、边距对齐
private extension View {
    func sheetForm() -> some View {
        formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, -MacTokens.Space.xl)
            .padding(.vertical, -MacTokens.Space.l)
    }
}

/// 表单底部的一行提示：强调色的图标 + 次要色的字
private struct Tip: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: MacTokens.Space.s) {
            Image(systemName: symbol).foregroundStyle(MacTokens.Color.accent)
            Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .font(.callout)
    }
}

/// 型号：按品牌分组的菜单，选中的打勾；最后一项自己填分辨率（弹出小窗）。kinds：只列这几类
struct DeviceMenu: View {
    let state: AppState
    let kinds: Set<DeviceKind>
    let current: DeviceChoice
    let choose: @MainActor (DeviceChoice) -> Void
    @State private var customizing = false

    var body: some View {
        let brands = state.devices.search("", in: kinds)
        Menu(current.customScreen.map { "\(current.displayName) \($0.sizeText)" } ?? current.displayName) {
            ForEach(brands) { brand in
                Menu(kinds.count > 1 && brand.kind != .phone ? "\(brand.name) · \(brand.kind.title)" : brand.name) {
                    ForEach(brand.models) { model in
                        Toggle(model.name, isOn: Binding(get: { model.id == current.model }, set: { _ in choose(DeviceChoice(model)) }))
                    }
                }
            }
            if !brands.isEmpty { Divider() }
            Toggle("自定义分辨率…", isOn: Binding(get: { current.model == nil }, set: { _ in customizing = true }))
        }
        .fixedSize()
        .popover(isPresented: $customizing, arrowEdge: .bottom) {
            CustomScreenForm(current: current) { screen in
                customizing = false
                // 自己填的沿用现在的类别
                if let screen { choose(DeviceChoice(model: nil, screen: screen, kind: current.kind)) }
            }
        }
    }
}

/// 自己填分辨率：宽 × 高，横着填也行，比例也行（见 DeviceScreen.custom）
private struct CustomScreenForm: View {
    let current: DeviceChoice
    /// 填好的分辨率；取消为 nil
    let done: (DeviceScreen?) -> Void
    @State private var width: Int?
    @State private var height: Int?

    private var screen: DeviceScreen? { DeviceScreen.custom(width, height) }

    var body: some View {
        VStack(alignment: .leading, spacing: MacTokens.Space.m) {
            Text("自定义分辨率").font(.headline)
            HStack(spacing: MacTokens.Space.s) {
                TextField("宽", value: $width, format: .number.grouping(.never))
                Text("×").foregroundStyle(.secondary)
                TextField("高", value: $height, format: .number.grouping(.never))
            }
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.center)
            Text(current.kind == .computer ? "电脑上「显示器」设置里的分辨率，如 1920 × 1080" : DeviceScreen.customHint)
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("取消") { done(nil) }
                    .keyboardShortcut(.cancelAction)
                Button("使用") { done(screen) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(screen == nil)
            }
        }
        .padding(MacTokens.Space.l)
        .frame(width: MacTokens.Size.resolutionPopoverWidth)
        .onAppear {
            guard let screen = current.customScreen else { return }
            width = screen.width
            height = screen.height
        }
    }
}
