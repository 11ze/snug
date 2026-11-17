import AppKit
import WebKit
// 用 WebKit（Safari 的内核）直接打开本地文件截整页，检查原型在 Safari 里的样子（Chrome 加本地服务器看不出 Safari 的问题）。
// 用法：swiftc -O -o /tmp/snapshot design/prototype/snapshot.swift && /tmp/snapshot design/prototype/index.html out.png 1500 [dark]
let args = CommandLine.arguments
let file = URL(fileURLWithPath: args[1]), out = URL(fileURLWithPath: args[2])
let width = CGFloat(Double(args[3]) ?? 1500)
let dark = args.count > 4 && args[4] == "dark"
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
final class Nav: NSObject, WKNavigationDelegate {
    let done: (WKWebView) -> Void
    init(_ d: @escaping (WKWebView) -> Void) { done = d }
    func webView(_ w: WKWebView, didFinish n: WKNavigation!) { DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.done(w) } }
}
let web = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: 1000))
if dark { web.appearance = NSAppearance(named: .darkAqua) }
let window = NSWindow(contentRect: web.frame, styleMask: [.borderless], backing: .buffered, defer: false)
window.contentView = web
let nav = Nav { w in
    w.evaluateJavaScript("document.documentElement.scrollHeight") { h, _ in
        let height = (h as? CGFloat) ?? 1000
        w.setFrameSize(NSSize(width: width, height: height)); window.setContentSize(NSSize(width: width, height: height))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let cfg = WKSnapshotConfiguration(); cfg.rect = NSRect(x: 0, y: 0, width: width, height: height)
            w.takeSnapshot(with: cfg) { img, err in
                if let img, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                    try? rep.representation(using: .png, properties: [:])?.write(to: out); print("截图 \(Int(width))×\(Int(height)) → \(out.path)")
                } else { print("截图失败：\(String(describing: err))") }
                exit(0)
            }
        }
    }
}
web.navigationDelegate = nav
web.loadFileURL(file, allowingReadAccessTo: file.deletingLastPathComponent())
DispatchQueue.main.asyncAfter(deadline: .now() + 30) { print("超时"); exit(1) }
app.run()
