// 截图之后的缩略图条：左边是刚截的图，右边一行字说明已经复制、点一下能裁。
// 浮在底部小横条上方，点它进裁剪；几秒不点自己收起（剪贴板里已经是整张图了）
import SwiftUI

struct CapturePreviewView: View {
    let preview: AppState.CapturePreview
    /// 这一档比基准宽度宽几倍：跟着手机屏一起放大，在手机上看着大小不变
    let scale: CGFloat
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56 * scale, height: 56 * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 8 * scale, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8 * scale, style: .continuous).stroke(.white.opacity(0.18)))
                VStack(alignment: .leading, spacing: 3) {
                    // verbatim：普通字符串插值会被当成可本地化的键，整数自动加千分位
                    Text(verbatim: "已复制 \(preview.pixelWidth) × \(preview.pixelHeight)")
                        .font(PhoneStyle.body.weight(.medium))
                    Text("点按裁剪")
                        .font(PhoneStyle.label)
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .scaleEffect(scale, anchor: .bottom)
        .accessibilityLabel("截图已复制，点按裁剪")
    }

    private var thumbnail: NSImage {
        NSImage(data: preview.png) ?? NSImage(size: NSSize(width: 1, height: 1))
    }
}
