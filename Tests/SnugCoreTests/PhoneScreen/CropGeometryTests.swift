import CoreGraphics
import Testing
@testable import SnugCore

@Suite("截图裁剪的几何 CropGeometry")
struct CropGeometryTests {
    /// 图片 1000×2000，显示成 500×1000
    private let tall = CGSize(width: 1000, height: 2000)
    private let shown = CGRect(x: 0, y: 0, width: 500, height: 1000)

    @Test("等比铺进去正中：宽高比一致时正好铺满，比例不同时留白也居中")
    func fitted() {
        #expect(CropGeometry.fittedRect(image: tall, in: shown) == shown)
        // 400×400 的方图放进 500×1000：上下留白
        let square = CGSize(width: 400, height: 400)
        #expect(CropGeometry.fittedRect(image: square, in: shown) == CGRect(x: 0, y: 250, width: 500, height: 500))
    }

    @Test("整张选上：裁出来就是整张图")
    func whole() {
        #expect(CropGeometry.pixelRect(selection: shown, shown: shown, image: tall) == CGRect(x: 0, y: 0, width: 1000, height: 2000))
    }

    @Test("选区按显示比例换算成像素：图片不在原点时先减去偏移")
    func quarter() {
        let offset = CGRect(x: 30, y: 60, width: 500, height: 1000)
        let selection = CGRect(x: 30 + 250, y: 60 + 500, width: 250, height: 500)
        #expect(CropGeometry.pixelRect(selection: selection, shown: offset, image: tall)
                == CGRect(x: 500, y: 1000, width: 500, height: 1000))
    }

    @Test("拖出图片范围的部分不算；完全在图片外就什么也没有")
    func clipped() {
        let partly = CGRect(x: -100, y: -100, width: 200, height: 300)
        #expect(CropGeometry.pixelRect(selection: partly, shown: shown, image: tall) == CGRect(x: 0, y: 0, width: 200, height: 400))
        let outside = CGRect(x: 900, y: 0, width: 10, height: 10)
        #expect(CropGeometry.pixelRect(selection: outside, shown: shown, image: tall) == .zero)
    }

    @Test("按边取整：两边各自四舍五入，右下边不会比原图多出一像素")
    func rounding() {
        // 左上边换算成 0.5 像素，右下边正好落在原图边上：按「起点 + 宽」取整会多出一像素
        let selection = CGRect(x: 0.25, y: 0.25, width: 499.75, height: 999.75)
        let rect = CropGeometry.pixelRect(selection: selection, shown: shown, image: tall)
        #expect(rect == CGRect(x: 1, y: 1, width: 999, height: 1999))
    }
}
