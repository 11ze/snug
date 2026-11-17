// 截图裁剪的几何：图片等比铺在界面上某块区域里（可能留白），把手指拖出的选区换算回原图像素。
// 纯计算，界面显示多大、手指拖到哪儿都由调用方给；坐标一律左上原点
import CoreGraphics

public enum CropGeometry {
    /// 图片等比放进 area 后的实际显示矩形（居中，可能上下或左右留白）
    public static func fittedRect(image: CGSize, in area: CGRect) -> CGRect {
        guard image.width > 0, image.height > 0, area.width > 0, area.height > 0 else { return .zero }
        let scale = min(area.width / image.width, area.height / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(x: area.midX - size.width / 2, y: area.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    /// 选区（和 area 同一坐标系）换算成图片里的像素矩形：先裁到图片显示范围内，
    /// 再按显示比例换算、取整，宽高至少 1 像素（手指点一下也得裁出一块）
    public static func pixelRect(selection: CGRect, image: CGSize, in area: CGRect) -> CGRect {
        let fitted = fittedRect(image: image, in: area)
        guard fitted.width > 0, fitted.height > 0 else { return .zero }
        let clipped = selection.standardized.intersection(fitted)
        guard !clipped.isNull, clipped.width > 0, clipped.height > 0 else { return .zero }
        let sx = image.width / fitted.width
        let sy = image.height / fitted.height
        let x = ((clipped.minX - fitted.minX) * sx).rounded()
        let y = ((clipped.minY - fitted.minY) * sy).rounded()
        let width = max(1, (clipped.width * sx).rounded())
        let height = max(1, (clipped.height * sy).rounded())
        // 取整后可能比原图多出一像素（右边、下边），夹回去
        return CGRect(x: x, y: y,
                      width: min(width, image.width - x),
                      height: min(height, image.height - y))
    }

    /// 手指还没拖动时的默认选区：整张图
    public static func fullSelection(image: CGSize, in area: CGRect) -> CGRect {
        fittedRect(image: image, in: area)
    }
}
