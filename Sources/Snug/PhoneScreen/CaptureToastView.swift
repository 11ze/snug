// 手机屏上的截图提示：黑底白字的小胶囊，浮在小横条上方。只报结果，不拦操作（面板设了穿透）
import SwiftUI

struct CaptureToastView: View {
    let toast: AppState.CaptureToast
    /// 这一档比基准宽度宽几倍：跟着手机屏一起放大，在手机上看着大小不变
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.symbol)
            Text(toast.text).font(PhoneStyle.body.weight(.medium)).lineLimit(2)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.black.opacity(0.8), in: Capsule())
        .scaleEffect(scale, anchor: .bottom)
    }
}
