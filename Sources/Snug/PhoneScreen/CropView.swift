// 裁剪界面：盖满手机屏。图片等比摆在中间（四周留出边距，手指够得到边角上的把手），
// 默认整张都选着，拖四角或四边往里收；顶部左边取消、右边完成。
// 坐标左上原点，和 CropGeometry 一致；尺寸按这一档的倍率放大（倍率由界面宽度算，换档时跟着变）
import SnugCore
import SwiftUI

struct CropView: View {
    let image: NSImage
    let pixelSize: CGSize
    let onCancel: () -> Void
    /// 完成：选区和图片的显示范围（同一坐标系）
    let onDone: (CGRect, CGRect) -> Void

    /// 拖过之后的选区；没拖过是整张图
    @State private var selection: CGRect?
    /// 正在拖的把手，和按下时的选区
    @State private var dragging: (handle: Handle, start: CGRect)?

    var body: some View {
        GeometryReader { geo in
            let metrics = Metrics(width: geo.size.width)
            let shown = metrics.shown(pixelSize, in: geo.size)
            let current = selection ?? shown
            ZStack(alignment: .topLeading) {
                Color.black
                Image(nsImage: image)
                    .resizable()
                    .frame(width: shown.width, height: shown.height)
                    .position(x: shown.midX, y: shown.midY)
                // 选区外压暗：整块挖掉选区
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: geo.size))
                    path.addRect(current)
                }
                .fill(.black.opacity(0.55), style: FillStyle(eoFill: true))
                handles(current, metrics)
                topBar(metrics) { onDone(current, shown) }
            }
            .contentShape(Rectangle())
            .gesture(drag(shown: shown, metrics: metrics))
            .onChange(of: geo.size) { old, new in
                // 换了一档（比如窗口关了、手机屏换回基准宽度）：选区按比例跟着图片走
                guard let selection else { return }
                let from = Metrics(width: old.width).shown(pixelSize, in: old)
                let to = Metrics(width: new.width).shown(pixelSize, in: new)
                guard from.width > 0, from.height > 0 else { return }
                self.selection = CGRect(x: to.minX + (selection.minX - from.minX) / from.width * to.width,
                                        y: to.minY + (selection.minY - from.minY) / from.height * to.height,
                                        width: selection.width / from.width * to.width,
                                        height: selection.height / from.height * to.height)
            }
        }
    }

    // MARK: 把手

    /// 八个把手：四角和四边中点
    enum Handle: CaseIterable {
        case topLeft, top, topRight, left, right, bottomLeft, bottom, bottomRight

        func point(in rect: CGRect) -> CGPoint {
            switch self {
            case .topLeft: CGPoint(x: rect.minX, y: rect.minY)
            case .top: CGPoint(x: rect.midX, y: rect.minY)
            case .topRight: CGPoint(x: rect.maxX, y: rect.minY)
            case .left: CGPoint(x: rect.minX, y: rect.midY)
            case .right: CGPoint(x: rect.maxX, y: rect.midY)
            case .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
            case .bottom: CGPoint(x: rect.midX, y: rect.maxY)
            case .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
            }
        }
    }

    /// 四角 L 形 + 四边中点短线，和手机上的截图裁剪一样；外加一圈细边框。
    /// 把手画在选区外沿：选区贴着图片边时，白把手也落在黑底上，不会和浅色截图混在一起
    private func handles(_ sel: CGRect, _ metrics: Metrics) -> some View {
        let line = 4 * metrics.scale
        let outer = sel.insetBy(dx: -line / 2, dy: -line / 2)
        let corner = min(metrics.corner, sel.width / 3, sel.height / 3)
        let tick = min(metrics.corner, sel.width / 4) / 2
        let marks = Path { path in
            for (x, dx) in [(outer.minX, corner), (outer.maxX, -corner)] {
                for (y, dy) in [(outer.minY, corner), (outer.maxY, -corner)] {
                    path.move(to: CGPoint(x: x, y: y + dy))
                    path.addLine(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x + dx, y: y))
                }
            }
            for y in [outer.minY, outer.maxY] {
                path.move(to: CGPoint(x: outer.midX - tick, y: y))
                path.addLine(to: CGPoint(x: outer.midX + tick, y: y))
            }
            for x in [outer.minX, outer.maxX] {
                path.move(to: CGPoint(x: x, y: outer.midY - tick))
                path.addLine(to: CGPoint(x: x, y: outer.midY + tick))
            }
        }
        return ZStack {
            Path(sel).stroke(.white.opacity(0.8), lineWidth: metrics.scale)
            marks.stroke(.white, style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
        }
    }

    /// 按下的地方离哪个把手最近（够近才算抓住）；都不近就不动，免得误改
    private func handle(at point: CGPoint, of sel: CGRect, within radius: CGFloat) -> Handle? {
        Handle.allCases
            .map { handle in (handle, hypot(handle.point(in: sel).x - point.x, handle.point(in: sel).y - point.y)) }
            .filter { $0.1 <= radius }
            .min { $0.1 < $1.1 }?.0
    }

    /// 拖动把手：只动对应的那条边或那个角，限制在图片范围内，宽高不小于 minSide
    private func resized(_ start: CGRect, _ handle: Handle, to location: CGPoint, within shown: CGRect, minSide: CGFloat) -> CGRect {
        var minX = start.minX, maxX = start.maxX, minY = start.minY, maxY = start.maxY
        let x = min(max(location.x, shown.minX), shown.maxX)
        let y = min(max(location.y, shown.minY), shown.maxY)
        if [.topLeft, .left, .bottomLeft].contains(handle) { minX = min(x, maxX - minSide) }
        if [.topRight, .right, .bottomRight].contains(handle) { maxX = max(x, minX + minSide) }
        if [.topLeft, .top, .topRight].contains(handle) { minY = min(y, maxY - minSide) }
        if [.bottomLeft, .bottom, .bottomRight].contains(handle) { maxY = max(y, minY + minSide) }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func drag(shown: CGRect, metrics: Metrics) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragging == nil {
                    let sel = selection ?? shown
                    guard let handle = handle(at: value.startLocation, of: sel, within: metrics.grabRadius) else { return }
                    dragging = (handle, sel)
                }
                guard let dragging else { return }
                selection = resized(dragging.start, dragging.handle, to: value.location, within: shown, minSide: metrics.minSide)
            }
            .onEnded { _ in dragging = nil }
    }

    // MARK: 按钮

    private func topBar(_ metrics: Metrics, done: @escaping () -> Void) -> some View {
        // 点按区域至少一个手指大（PressableStyle 按 label 的范围接点击）
        let side = PhoneStyle.touchTarget * metrics.scale
        return HStack {
            Button(action: onCancel) { Text("取消").frame(minWidth: side, minHeight: side) }
            Spacer()
            Button(action: done) { Text("完成").frame(minWidth: side, minHeight: side) }
        }
        .font(.system(size: 18 * metrics.scale, weight: .semibold))
        .foregroundStyle(.white)
        .buttonStyle(PressableStyle())
        .padding(.horizontal, metrics.margin)
        .frame(height: metrics.topBar)
        .frame(maxWidth: .infinity)
        .background(LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom))
    }

    /// 跟着倍率走的尺寸
    private struct Metrics {
        let scale: CGFloat

        init(width: CGFloat) { scale = ScreenFit.scale(screenWidth: width) }

        /// 顶部留给「取消 / 完成」
        var topBar: CGFloat { 64 * scale }
        /// 四周留出抓把手的空间
        var margin: CGFloat { 22 * scale }
        /// 离把手这么近就算抓住了
        var grabRadius: CGFloat { 34 * scale }
        /// 选区最小边长：再小就没法继续拖了
        var minSide: CGFloat { 44 * scale }
        /// 角上 L 形的边长
        var corner: CGFloat { 20 * scale }

        /// 图片的显示范围：顶部让出按钮，四周留边距，等比居中
        func shown(_ image: CGSize, in size: CGSize) -> CGRect {
            let area = CGRect(x: margin, y: topBar, width: max(1, size.width - margin * 2), height: max(1, size.height - topBar - margin))
            return CropGeometry.fittedRect(image: image, in: area)
        }
    }
}

