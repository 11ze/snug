# Snug 图标资源

| 文件 | 用途 |
|---|---|
| `AppIcon-1024.png` | App 图标 1024×1024 PNG（母版，含 macOS 圆角底板与阴影，底板外透明） |
| `AppIcon.icns` | macOS 应用图标，放进 `.app/Contents/Resources/`，并在 Info.plist 设 `CFBundleIconFile = AppIcon` |

界面里的其它图标（菜单栏、设置页、屏上面板）一律用 SF Symbols，不另外绘制。

## 设计说明

方案「三屏叠片」（2.6.1 起）：青色显示器 = 被远程的 Mac，深蓝竖屏 = 手机，天蓝横屏 = 平板，半透明交叠处更深的蓝 = 每台设备各有一块合身的屏。2.6 起支持手机、平板与电脑，图标从原来的「双屏叠片」（显示器 + 一块竖屏）扩成三块。

- 配色：`#00EAFF → #0FC4FA`（显示器）、`#0A7CFF → #0057F0`（平板）、`#0441F5`（手机与交叠）
- 规格：1024 画布、824 底板、圆角 185；阴影下移 10、模糊 12、`#0B2A55` 不透明度 0.22
- 画面由 AI 生成，底板边缘与阴影按上面的规格后期重做；没有矢量源文件

重新生成 icns（`scripts/snug app` 只拷 icns，不从 PNG 生成）：

```bash
mkdir AppIcon.iconset
for s in 16 32 128 256 512; do
  sips -z $s $s AppIcon-1024.png --out AppIcon.iconset/icon_${s}x${s}.png
  sips -z $((s*2)) $((s*2)) AppIcon-1024.png --out AppIcon.iconset/icon_${s}x${s}@2x.png
done
iconutil -c icns AppIcon.iconset -o AppIcon.icns && rm -r AppIcon.iconset
```
