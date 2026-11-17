# 设计

Snug 界面的设计令牌和原型。多屏开工前先在这里把界面定下来（见 [docs/multi-screen.md](../docs/multi-screen.md) 第 8 节第 2 步），产品定位见 [docs/PRODUCT.md](../docs/PRODUCT.md)。

```
design/
  design-tokens.json      设计令牌：字号、颜色、间距、圆角、尺寸、动效的唯一来源
  tokens-to-css.mjs       把令牌转成原型用的 CSS 变量
  prototype/
    index.html            界面原型：Mac 上（菜单栏、设置三页、添加屏幕、屏幕详情、关于、电脑屏的 App 资源库）
                          和 Snug 屏上（手机竖屏、手机横屏、平板横屏）
    prototype.css         原型的样式，数值全部取 tokens.css 的变量
    tokens.css            生成的，不要手改
    export-assets.swift   从本机导出原型要用的 SF Symbols 和 App 图标
    assets/               导出的图标（不进 git：苹果的图标不随仓库分发）
```

## 打开原型

```bash
swift design/prototype/export-assets.swift   # 第一次，或者加了新图标之后
open design/prototype/index.html
```

右上角可以切浅色、深色。

## 改令牌

只改 `design-tokens.json`，改完重新生成 CSS：

```bash
node design/tokens-to-css.mjs
```

令牌分两套：`mac` 管 Mac 上的界面，`touch` 管手机和平板屏上的面板。带 `system` 的颜色在 Swift 里用对应的系统语义色，`light` / `dark` 只给原型预览用。界面代码以后也从这份文件取值。
