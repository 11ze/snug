// 截图裁剪：按像素矩形从一张 PNG 里裁出一块。裁剪坐标是图像坐标（左上原点），
// 由 CropGeometry 从手指拖出的选区换算好再传进来
import AppKit
import SnugCore

public enum ImageCrop {
    /// 裁不动（数据坏了、矩形为空或完全在图外）返回 nil，调用方保留原图
    public static func crop(_ image: CapturedImage, to rect: CGRect) -> CapturedImage? {
        guard rect.width >= 1, rect.height >= 1,
              let rep = NSBitmapImageRep(data: image.png),
              let source = rep.cgImage else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: source.width, height: source.height)
        let clipped = rect.intersection(bounds).integral
        guard !clipped.isNull, clipped.width >= 1, clipped.height >= 1,
              let cropped = source.cropping(to: clipped),
              let png = NSBitmapImageRep(cgImage: cropped).representation(using: .png, properties: [:])
        else { return nil }
        return CapturedImage(png: png, pixelWidth: cropped.width, pixelHeight: cropped.height)
    }
}
