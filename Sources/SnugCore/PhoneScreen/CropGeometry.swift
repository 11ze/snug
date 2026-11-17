// 截图裁剪的几何：图片等比铺在裁剪界面里，把手指拖出的选区换算回原图像素。
// 纯计算，坐标一律左上原点；界面多大、选区在哪由调用方给
import CoreGraphics

public enum CropGeometry {
    /// 图片等比放进 area 后的显示范围（居中，可能上下或左右留白）
    public static func fittedRect(image: CGSize, in area: CGRect) -> CGRect {
        guard image.width > 0, image.height > 0, area.width > 0, area.height > 0 else { return .zero }
        let scale = min(area.width / image.width, area.height / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(x: area.midX - size.width / 2, y: area.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    /// 选区换算成原图里的像素矩形。shown 是图片的显示范围，和选区同一坐标系；
    /// 拖出图片的部分不算，完全在图片外返回 .zero。四条边各自取整，右下边不会越出原图
    public static func pixelRect(selection: CGRect, shown: CGRect, image: CGSize) -> CGRect {
        let clipped = selection.intersection(shown)
        guard !clipped.isNull, clipped.width > 0, clipped.height > 0 else { return .zero }
        let sx = image.width / shown.width
        let sy = image.height / shown.height
        let minX = ((clipped.minX - shown.minX) * sx).rounded()
        let minY = ((clipped.minY - shown.minY) * sy).rounded()
        let maxX = min(image.width, ((clipped.maxX - shown.minX) * sx).rounded())
        let maxY = min(image.height, ((clipped.maxY - shown.minY) * sy).rounded())
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
