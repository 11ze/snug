---
name: project-ui-redesign
description: "11-17 做完并经主人确认：UI 按内容分层重组、HTML 原型、对齐苹果规范的设计令牌 JSON（design/）；参照 ~/coding/personal/learn-ui；界面以原型为准"
metadata:
  type: project
---

**11-17 主人定**：多屏的技术方案定了，但「现在还不能开工」。功能越加越多，App 的界面几乎都是从上往下一项项排下来（主人原话「瀑布式地一个个流下来，内容没有分层，这很不合理」），多屏还要加屏幕列表、每块屏的型号和开关、设为主屏、电脑屏的菜单栏入口。所以先：

1. 结合现有界面（`--render-<界面> <目录>` 能渲染出现在的设置、欢迎、关于、手机屏等），梳理加了多屏之后各界面怎么变，把内容分层、重组
2. 在 HTML 上画原型（放仓库、本地看，不外传，见数据边界）
3. 对齐苹果的设计规范，参照主人在学苹果设计规范的项目 `~/coding/personal/learn-ui`，收出一套设计令牌，统一放进一个 JSON（如 `design-tokens.json`），界面都从这里取
4. 主人确认原型和规范后，才开始多屏的功能代码；主人的说法是「相当于前后端都已经定好了，再开始全面铺开」

**进度（11-17）**：主人要求「先定设计令牌，再画原型」，顺序不能反。已做：`design/design-tokens.json`（mac / touch 两套，颜色带 system 名和预览值）→ `node design/tokens-to-css.mjs` 生成 CSS 变量 → `design/prototype/index.html` 画了 11 张（菜单栏、设置·屏幕/触控/通用、添加屏幕、屏幕详情、关于、电脑屏 App 资源库、手机竖屏、手机横屏两栏、平板横屏两栏让开 UU 按钮）。图标用 `swift design/prototype/export-assets.swift` 本地导出、不进 git。11-17 第一轮反馈已改：Safari 直接开本地文件时 CSS 遮罩读不了本地图标（图标全空、对齐显得怪），改成 export-assets.swift 把符号内嵌成 data URI 写进 assets/symbols.css；添加屏幕、屏幕详情改成和设置窗口同一种分组样式（标签左、控件右）；屏幕行的详情入口用 ⓘ；列表下写明「一次只一台控制、多开留给横竖切换和换设备」。**检查原型要用 WebKit 直接开本地文件截图**（`design/prototype/snapshot.swift`，用法见 design/README.md），别只用 Chrome 加本地服务器，那样看不出 Safari 的问题。

**11-17 主人确认原型和令牌，已合并推送**。定下来的界面逐条写在多屏设计记录第 8 节第 2 步（已删，见 [[project-multi-screen]]），界面以 `design/prototype/index.html` 为准；做第 7 步界面时令牌接进 Swift（建议生成常量加单测校验，`PhoneStyle` 改从令牌取），做完用 `--render-<界面>` 和原型逐张对照。主人偏好：直接看原型图调，少讲文字。docs/PRODUCT.md 是给设计工具（impeccable）的产品说明。

**Why:** 先定界面和规范，功能代码和界面代码一次写对，之后也好维护。

**How to apply:** 这是多屏设计记录第 8 节第 2 步，2.6.0 已按原型做完；技术方案见 [[project-multi-screen]]，界面文字和图标规矩见 [[feedback-ui-style]]，产品取舍见 [[project-product]]。原型定稿前不写多屏功能代码。
