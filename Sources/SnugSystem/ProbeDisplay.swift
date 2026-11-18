// 实测用的实验屏（--probe-screens）：照规格建、释放，不经过手机屏的调度。
// 厂商、产品号和手机屏一样，序列号用实验身份（见 ProbeScreen）；物理尺寸照手机屏的办法按像素上限、约 220ppi 折算，
// 按真实密度折算的全新身份不会上线（见 ScreenSpec）。在主线程建和释放，释放时不能留别的强引用
import CGVirtualDisplayBridge
import CoreGraphics
import Foundation
import SnugCore

@MainActor
public final class ProbeDisplay {
    public let screen: ProbeScreen
    public let id: DisplayID
    /// 建出来的时刻（系统运行时间）：不到最短存活就释放会让 WindowServer 卡死
    public let bornAt: TimeInterval
    private var display: CGVirtualDisplay?

    /// 建不出来（同身份的屏还在、apply 失败）返回 nil
    public init?(_ screen: ProbeScreen) {
        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.name = screen.name
        descriptor.maxPixelsWide = UInt32(screen.maxPixels.width)
        descriptor.maxPixelsHigh = UInt32(screen.maxPixels.height)
        descriptor.sizeInMillimeters = CGSize(width: Double(screen.maxPixels.width) / 220 * 25.4,
                                              height: Double(screen.maxPixels.height) / 220 * 25.4)
        descriptor.vendorID = ScreenSpec.vendorID
        descriptor.productID = ScreenSpec.portraitProductID
        descriptor.serialNum = screen.serial
        guard let display = autoreleasepool(invoking: { CGVirtualDisplay(descriptor: descriptor) }) else { return nil }
        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = true
        settings.modes = screen.modes.map { CGVirtualDisplayMode(width: UInt($0.width), height: UInt($0.height), refreshRate: 60) }
        guard autoreleasepool(invoking: { display.apply(settings) }) else { return nil }
        self.screen = screen
        self.display = display
        id = display.displayID
        bornAt = ProcessInfo.processInfo.systemUptime
    }

    public func release() {
        autoreleasepool { display = nil }
    }

    public var isOnline: Bool { Screens.online()?.contains(id) == true }
}
