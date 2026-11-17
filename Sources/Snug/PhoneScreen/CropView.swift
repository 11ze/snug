// 裁剪界面：盖满手机屏。图片等比摆在中间（四周留出边距，手指够得到边角上的把手），
// 默认整张图都选着，拖四角或四边往里缩；要哪块就从整张往里收。
// 顶部左边取消、右边完成。视图坐标（左上原点）和 CropGeometry 一致，换算成像素由调用方做
import SnugCore
import SwiftUI

struct CropView: View {
    let preview: AppState.CapturePreview
    /// 这一档比基准宽度宽几倍
    let scale: CGFloat
    let onCancel: () -> Void
    /// 完成：选区、图片所在的区域（都是视图坐标）一起交回去
    let onDone: (CGRect, CGRect) -> Void

    /// 当前选区，坐标是这块视图
    @State private var selection: CGRect?
    /// 正在拖哪个把手，以及按下时的选区
    @State private var dragging: (edge: Edge, start: CGRect)?
    /// 图片在视图里的位置（等比居中），进入时定下来
    @State private var fitted = CGRect.zero

    /// 八个把手。角上四个，边中点四个
    enum Edge: CaseIterable {
        case topLeft, top, topRight, left, right, bottomLeft, bottom, bottomRight
    }

    /// 顶部留给「取消 / 完成」，底部和两侧留出抓把手的空间
    private var topBarHeight: CGFloat { 64 * scale }
    private var margin: CGFloat { 22 * scale }
    /// 把手离得这么近就算抓住了
    private var grabRadius: CGFloat { 34 * scale }
    /// 选区最小边长：再小就没法继续拖了
    private var minSide: CGFloat { 44 * scale }
    /// 角上 L 形的边长
    private var cornerLength: CGFloat { 20 * scale }

    private var image: NSImage {
        NSImage(data: preview.png) ?? NSImage(size: NSSize(width: 1, height: 1))
    }

    private var pixelSize: CGSize {
        CGSize(width: preview.pixelWidth, height: preview.pixelHeight)
    }

    var body: some View {
        GeometryReader { geo in
            let area = imageArea(geo.size)
            let fit = CropGeometry.fittedRect(image: pixelSize, in: area)
            let current = selection ?? fit
            ZStack(alignment: .topLeading) {
                Color.black
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: fit.width, height: fit.height)
                    .position(x: fit.midX, y: fit.midY)
                // 选区外压暗：整块挖掉选区
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: geo.size))
                    path.addRect(current)
                }
                .fill(.black.opacity(0.55), style: FillStyle(eoFill: true))
                handles(current)
                topBar
            }
            .contentShape(Rectangle())
            .gesture(draw(fit: fit))
            .onAppear {
                fitted = fit
                if selection == nil { selection = fit }
            }
            .onChange(of: geo.size) { _, _ in
                // 屏幕换了尺寸（换档、旋转）：按新位置重新铺，选区保持比例
                guard fitted.width > 0 else { return }
                let ratio = CGRect(x: (current.minX - fitted.minX) / fitted.width,
                                   y: (current.minY - fitted.minY) / fitted.height,
                                   width: current.width / fitted.width,
                                   height: current.height / fitted.height)
                fitted = fit
                selection = CGRect(x: fit.minX + ratio.minX * fit.width, y: fit.minY + ratio.minY * fit.height,
                                   width: ratio.width * fit.width, height: ratio.height * fit.height)
            }
        }
    }

    /// 图片能放的区域：顶部让出按钮，四周留边距
    private func imageArea(_ size: CGSize) -> CGRect {
        CGRect(x: margin, y: topBarHeight,
               width: max(1, size.width - margin * 2),
               height: max(1, size.height - topBarHeight - margin))
    }

    // MARK: 把手

    /// 四角 L 形 + 四边中点短线，和手机截图裁剪一样
    private func handles(_ sel: CGRect) -> some View {
        let corner = min(cornerLength, sel.width / 3, sel.height / 3)
        let tick = min(cornerLength, sel.width / 4) / 2
        return Path { path in
            // 左上
            path.move(to: CGPoint(x: sel.minX, y: sel.minY + corner))
            path.addLine(to: CGPoint(x: sel.minX, y: sel.minY))
            path.addLine(to: CGPoint(x: sel.minX + corner, y: sel.minY))
            // 右上
            path.move(to: CGPoint(x: sel.maxX - corner, y: sel.minY))
            path.addLine(to: CGPoint(x: sel.maxX, y: sel.minY))
            path.addLine(to: CGPoint(x: sel.maxX, y: sel.minY + corner))
            // 左下
            path.move(to: CGPoint(x: sel.minX, y: sel.maxY - corner))
            path.addLine(to: CGPoint(x: sel.minX, y: sel.maxY))
            path.addLine(to: CGPoint(x: sel.minX + corner, y: sel.maxY))
            // 右下
            path.move(to: CGPoint(x: sel.maxX - corner, y: sel.maxY))
            path.addLine(to: CGPoint(x: sel.maxX, y: sel.maxY))
            path.addLine(to: CGPoint(x: sel.maxX, y: sel.maxY - corner))
            // 四边中点
            path.move(to: CGPoint(x: sel.midX - tick, y: sel.minY))
            path.addLine(to: CGPoint(x: sel.midX + tick, y: sel.minY))
            path.move(to: CGPoint(x: sel.midX - tick, y: sel.maxY))
            path.addLine(to: CGPoint(x: sel.midX + tick, y: sel.maxY))
            path.move(to: CGPoint(x: sel.minX, y: sel.midY - tick))
            path.addLine(to: CGPoint(x: sel.minX, y: sel.midY + tick))
            path.move(to: CGPoint(x: sel.maxX, y: sel.midY - tick))
            path.addLine(to: CGPoint(x: sel.maxX, y: sel.midY + tick))
        }
        .stroke(.white, style: StrokeStyle(lineWidth: 3 * scale, lineCap: .round))
    }

    /// 每个把手的位置
    private func point(_ edge: Edge, of sel: CGRect) -> CGPoint {
        switch edge {
        case .topLeft: CGPoint(x: sel.minX, y: sel.minY)
        case .top: CGPoint(x: sel.midX, y: sel.minY)
        case .topRight: CGPoint(x: sel.maxX, y: sel.minY)
        case .left: CGPoint(x: sel.minX, y: sel.midY)
        case .right: CGPoint(x: sel.maxX, y: sel.midY)
        case .bottomLeft: CGPoint(x: sel.minX, y: sel.maxY)
        case .bottom: CGPoint(x: sel.midX, y: sel.maxY)
        case .bottomRight: CGPoint(x: sel.maxX, y: sel.maxY)
        }
    }

    /// 按下的地方离哪个把手最近（够近才算抓住）；都不近就不动，免得误改
    private func grabbedEdge(at point: CGPoint, in sel: CGRect) -> Edge? {
        var best: (edge: Edge, distance: CGFloat)?
        for edge in Edge.allCases {
            let p = self.point(edge, of: sel)
            let d = hypot(p.x - point.x, p.y - point.y)
            if d <= grabRadius, best == nil || d < best!.distance { best = (edge, d) }
        }
        return best?.edge
    }

    /// 拖动把手：只动对应的那条边或那个角，限制在图片范围内，宽高不小于 minSide
    private func resized(_ start: CGRect, edge: Edge, to location: CGPoint, within fit: CGRect) -> CGRect {
        var minX = start.minX, maxX = start.maxX, minY = start.minY, maxY = start.maxY
        let x = min(max(location.x, fit.minX), fit.maxX)
        let y = min(max(location.y, fit.minY), fit.maxY)
        switch edge {
        case .topLeft: minX = min(x, maxX - minSide); minY = min(y, maxY - minSide)
        case .top: minY = min(y, maxY - minSide)
        case .topRight: maxX = max(x, minX + minSide); minY = min(y, maxY - minSide)
        case .left: minX = min(x, maxX - minSide)
        case .right: maxX = max(x, minX + minSide)
        case .bottomLeft: minX = min(x, maxX - minSide); maxY = max(y, minY + minSide)
        case .bottom: maxY = max(y, minY + minSide)
        case .bottomRight: maxX = max(x, minX + minSide); maxY = max(y, minY + minSide)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func draw(fit: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let sel = selection ?? fit
                if dragging == nil {
                    guard let edge = grabbedEdge(at: value.startLocation, in: sel) else { return }
                    dragging = (edge, sel)
                }
                guard let d = dragging else { return }
                selection = resized(d.start, edge: d.edge, to: value.location, within: fit)
            }
            .onEnded { _ in dragging = nil }
    }

    // MARK: 按钮

    private var topBar: some View {
        HStack {
            Button("取消", action: onCancel)
            Spacer()
            Button("完成") {
                guard let sel = selection else { return onCancel() }
                onDone(sel, fitted)
            }
        }
        .font(PhoneStyle.body.weight(.semibold))
        .foregroundStyle(.white)
        .buttonStyle(.plain)
        .padding(.horizontal, margin + 4 * scale)
        .frame(maxWidth: .infinity)
        .frame(height: topBarHeight)
        .background(LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom))
    }
}
