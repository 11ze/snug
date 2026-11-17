import CoreGraphics
import Testing
@testable import SnugCore

@Suite("截图裁剪的几何 CropGeometry")
struct CropGeometryTests {
    /// 图片 1000×2000，放进 500×1000 的区域：正好等比铺满
    private let tall = CGSize(width: 1000, height: 2000)
    private let area = CGRect(x: 0, y: 0, width: 500, height: 1000)

    @Test("等比铺进去正中：宽高比一致时正好铺满，比例不同时留白也居中")
    func fitted() {
        #expect(CropGeometry.fittedRect(image: tall, in: area) == CGRect(x: 0, y: 0, width: 500, height: 1000))
        // 400×400 的方图放进 500×1000：上下留白
        let square = CGSize(width: 400, height: 400)
        #expect(CropGeometry.fittedRect(image: square, in: area) == CGRect(x: 0, y: 250, width: 500, height: 500))
    }

    @Test("整个图片都选上：裁出来就是整张图")
    func fullSelection() {
        #expect(CropGeometry.fullSelection(image: tall, in: area) == CGRect(x: 0, y: 0, width: 500, height: 1000))
        #expect(CropGeometry.pixelRect(selection: area, image: tall, in: area)
                == CGRect(x: 0, y: 0, width: 1000, height: 2000))
    }

    @Test("选区按显示比例换算成像素：拖左上四分之一就是原图左上四分之一")
    func quarter() {
        let selection = CGRect(x: 0, y: 0, width: 250, height: 500)
        #expect(CropGeometry.pixelRect(selection: selection, image: tall, in: area)
                == CGRect(x: 0, y: 0, width: 500, height: 1000))
    }

    @Test("选区拖到图片外面：先裁到图片范围，不越界；反着拖（右下到左上）也认")
    func clipped() {
        let outside = CGRect(x: -100, y: -100, width: 200, height: 300)
        #expect(CropGeometry.pixelRect(selection: outside, image: tall, in: area)
                == CGRect(x: 0, y: 0, width: 200, height: 400))
        let reversed = CGRect(x: 500, y: 1000, width: -250, height: -500)
        #expect(CropGeometry.pixelRect(selection: reversed, image: tall, in: area)
                == CGRect(x: 500, y: 1000, width: 500, height: 1000))
    }

    @Test("点一下（宽高为 0）也裁出至少 1 像素；完全在图片外就什么也没有")
    func degenerate() {
        let tap = CGRect(x: 250, y: 500, width: 0, height: 0)
        #expect(CropGeometry.pixelRect(selection: tap, image: tall, in: area) == .zero)
        let outside = CGRect(x: 900, y: 0, width: 10, height: 10)
        #expect(CropGeometry.pixelRect(selection: outside, image: tall, in: area) == .zero)
    }

    @Test("取整后不会比原图多出一像素：右下边界的选区夹回图片里")
    func noOverflow() {
        let selection = CGRect(x: 0.3, y: 0.3, width: 499.7, height: 999.7)
        let rect = CropGeometry.pixelRect(selection: selection, image: tall, in: area)
        #expect(rect.maxX <= 1000)
        #expect(rect.maxY <= 2000)
    }
}
