// 手机、平板屏上的「型号」页：点首页右上角的设备图标进入，改的是这一块屏的型号。最上面是现在用的那台，下面自己填分辨率，
// 再下面按品牌列出机型库（Assets/device-models.json）里的手机和平板（这块屏的类别排前面），顶部能搜型号。
// 选好就回到首页，这块屏当场换成它的比例（换的时候整屏写明「正在调整屏幕比例」）。和设置里这块屏的详情是同一份配置
import SnugCore
import SwiftUI

struct PhoneModelPage: View {
    let screen: ScreenID
    let state: AppState
    @Bindable var pages: PhonePages
    let intents: any PhoneIntents

    private var query: String { pages.trimmedQuery }
    private var current: DeviceChoice { state.screen(screen)?.device ?? .standard }

    var body: some View {
        VStack(spacing: 0) {
            // 和 iOS 的导航栏一样：标题居中，右边「完成」
            ZStack {
                Text("型号").font(TouchStyle.headline)
                HStack {
                    Spacer()
                    BarButton(title: "完成", bold: true) { pages.close() }
                }
            }
            .frame(height: TouchStyle.touchTarget)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SearchBar {
                        TextField("搜索型号", text: $pages.query).textFieldStyle(.plain)
                        ClearButton(text: $pages.query)
                    }
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.never)
        }
    }

    @ViewBuilder private var content: some View {
        // 触屏只换成手机、平板；这块屏的类别排前面
        let found = state.devices.search(query, in: [.phone, .tablet])
        let brands = found.filter { $0.kind == current.kind } + found.filter { $0.kind != current.kind }
        LazyVStack(alignment: .leading, spacing: 24) {
            if query.isEmpty {
                TitledSection("当前 · 这块屏按它调整比例") { CurrentPhone(choice: current) }
            }
            if brands.isEmpty {
                if query.isEmpty {
                    EmptyState(symbol: current.kind.symbol(.portrait), title: "未读取到机型库", text: "可在下方自定义分辨率")
                } else {
                    EmptyState(symbol: "magnifyingglass", title: "无结果", text: "没有与「\(query)」相符的型号")
                }
            }
            // 搜不到时也给自定义：列表里没有的设备就靠它（类别沿用这块屏现在的）
            if query.isEmpty || brands.isEmpty {
                TitledSection("自定义") { CustomScreen(current: current) { choose(DeviceChoice(model: nil, screen: $0, kind: current.kind)) } }
            }
            ForEach(brands) { brand in
                TitledSection(brand.kind == .phone ? brand.name : "\(brand.name) · \(brand.kind.title)") {
                    ListCard(brand.models, dividerInset: 20) { model in
                        ModelRow(model: model, selected: model.id == current.model) { choose(DeviceChoice(model)) }
                    }
                }
            }
        }
    }

    private func choose(_ device: DeviceChoice) {
        pages.close()
        intents.setDevice(device)
    }
}

/// 现在用的那台：名字、分辨率
private struct CurrentPhone: View {
    let choice: DeviceChoice

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: choice.kind.symbol(.portrait))
                .font(TouchStyle.headline.weight(.regular))
                .foregroundStyle(TouchStyle.tint)
                .frame(width: TouchStyle.iconSize)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(choice.displayName).font(TouchStyle.headline).lineLimit(1)
                Text(choice.screen.sizeText).font(TouchStyle.body).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .card()
    }
}

/// 自己填分辨率：宽 × 高，横着填也行，比例也行（见 DeviceScreen.custom）。现在用的是自己填的，就先填上它
private struct CustomScreen: View {
    let current: DeviceChoice
    let use: (DeviceScreen) -> Void
    @State private var width = ""
    @State private var height = ""

    private var screen: DeviceScreen? { DeviceScreen.custom(Int(width), Int(height)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                NumberField(placeholder: "宽", text: $width)
                Text("×").font(TouchStyle.body).foregroundStyle(.secondary)
                NumberField(placeholder: "高", text: $height)
                PillButton(title: "使用") { screen.map(use) }
                    .disabled(screen == nil)
            }
            Text(DeviceScreen.customHint)
                .font(TouchStyle.label)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .card()
        .onAppear {
            guard let screen = current.customScreen else { return }
            width = String(screen.width)
            height = String(screen.height)
        }
    }
}

private struct NumberField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(TouchStyle.body.monospacedDigit())
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .fieldBackground()
            .onChange(of: text) { _, new in
                let digits = new.filter(\.isASCII).filter(\.isNumber)
                if digits != new { text = digits }
            }
    }
}

/// 机型库里的一台：型号、分辨率，选中的打勾
private struct ModelRow: View {
    let model: DeviceModel
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name).font(TouchStyle.body).lineLimit(1)
                    Text(model.screen.sizeText).font(TouchStyle.label).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if selected {
                    Image(systemName: "checkmark").font(TouchStyle.body.weight(.semibold)).foregroundStyle(TouchStyle.tint)
                }
            }
            .padding(.horizontal, 20)
            .frame(minHeight: TouchStyle.touchTarget + 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
