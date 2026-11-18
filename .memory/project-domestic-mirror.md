---
name: project-domestic-mirror
description: 国内源与 README 媒体：dl.zephyrxiang.com/snug/ 放安装包、更新包与 README 媒体；看下载量的办法；README 的结构、截图规格与待换的演示动图；证书 2027-01-12 到期
metadata:
  node_type: memory
  type: project
  originSessionId: f97709de-705a-489b-bb7a-7353b1fba51c
  modified: 2026-11-16T05:06:11.511Z
---

2026-11-13 主人定的：安装包要有国内源（以后官网也从这里取，GitHub Release 照留）；README 的图片、视频也放这里，用原画质。

**国内源**
- **摆法**：前缀 `https://dl.zephyrxiang.com/snug/`，和 SpeakMore 发布包同一个桶（桶名、地域、凭据名在不进 git 的 `.machine.env`，这份记忆会公开，别写进来）。`v<版本>/` 发过不改，2.1.0 起多 `Snug-<版本>.pack` 和 `update.json`；`latest/Snug.dmg` 和 `latest/update.json`（App 检查更新的地址）缓存 5 分钟、只往新版本换；`media/<名>.<指纹>.<后缀>` 放 README 媒体
- **命令**：`ship` 发版时自动传；`mirror <版本>` 补传 GitHub 上已公开的版本；`media <文件…>` 传媒体并打出地址。对象都带 sha256 元数据，重跑一样就跳过、不一样就拒绝
- **CDN**：防盗链关着（GitHub 图片代理才取得到）；每小时 4 GB 的流量上限和费用跟 SpeakMore 共用
- **看下载量**（主人问了才查）：GitHub 用 releases API 的 download_count，含少量发版核对、扣不干净；国内源没有现成命令，先在 SpeakMore 仓库跑一次它的 stats 刷新 `.stats/logs` 里同域名的访问日志缓存（只读），再筛 `/snug/`，按「字节 ÷ 包大小」折算、同 IP 同天最多算 1 次、本机出口算自测。curl 拉包的不能当自测：2026-11-14 宣传片后十几个不同来源用 curl 下载，还去找 `latest/` 下的校验文件，多半是用户让 AI 助手装的
- **证书**：`dl.zephyrxiang.com` 的免费证书 2027-01-12 到期，续期记在 SpeakMore 的记忆里；不换，两个项目的下载会一起断
- 上传用的是主账号密钥，以后可换成只能写 `snug/` 前缀的子账号密钥（未做）

**README**（中英文两份一起改，媒体走 `scripts/snug media`）
- **结构**（11-15 重组）：主线是原生体验（竖屏原生显示、原生手势），放最前；App 资源库、适配所有 App 与手机是它的延伸，别写成工作台。安卓按「全面支持」写，主人定的，不收窄。致谢后、许可证前有一节 Star 趋势（11-16 加）：star-history.com 的外链 SVG，亮暗两版用 `<picture>` 切换，GitHub 会保留 `<picture>` 并走图片代理。它偶尔因 GitHub 接口限流显示出错图，过一会儿自己恢复；要完全可控再改成用 Actions 自己画图传国内源
- **多屏版重组**（11-18 主人定，随多屏版本发）：主题从「手机上的原生体验」扩到任何设备，标语中英文 README 统一用英文 **Make UU Remote Native on Any Device**，不另配中文标语。结构围绕标语：先「每台设备都是原生体验」（手机 → 平板 → 电脑，手机、平板是别人没做过的，放前面），再「一台 Mac，所有设备」（屏幕列表、机型库、自定义分辨率、设主屏、无显示器的 Mac mini / Mac Studio），再 App 资源库、对比、安装使用等。无显示器的 Mac 主人拍板照写（「咱们都做了……先写再说」），不因没实测就不写。配图：手机、平板都展示横竖两种，电脑只有横屏、配设主屏
- **社区移植**（安装与卸载之后、致谢之前一节表格，顶部下载区有一句引导）：只列已独立成仓的移植，注明独立维护、问题到对应仓库反馈。现有两行：nicocart/snug-win（#18，已发正式版）；rizetngan/snug-for-windows（PR #17 的作者独立成仓，11-18 加、PR 已关，标「社区预览版，尚未发布正式版本」，对方发正式版后来通知时改掉这句）。这次直接改在 main 上（`c9bada3`），multi-screen 合并时 README 要带上这一行
- **待换**：顶部中间的演示动图和高清视频仍是 2.2 的「窗口列表」，等演示录制（[[project-demo-recording]]）完成时一起换；手机截图已是 2.4 的（主人手机实拍，不用打码）
- **GitHub 的限制**：会删掉 `<video>`，录屏用 animated WebP，完整 MP4 用链接给（链接不走代理，没有大小限制）。外链图片一律经 GitHub 图片代理，大小上限在代理：开源 camo 默认 5 MiB，4.97 MB 实测能取到。代理原样转发字节，不会再压缩
- **动图体积**几乎全花在整屏滚动的帧上（每帧约 50 KB，打字、弹键盘的帧约 7 KB）；超了先用 img2webp 逐帧 `-q` 只降滚动段，宽度 540 在 README 30% 宽下看不出差别
- **录屏打码**：按字符范围定位（Vision `boundingBox(for:)`），只糊「用户名@机器名」那一截，敲的命令照常露出；逐帧识别复查，并拿没打码的原画做正对照
- **手机截图**：17 Pro Max 原图 1320×2868，顶部 273 行是黑边，裁成 `crop=1320:2595:0:273,pad=1320:2598:0:0:black`（ffmpeg，sips 裁不动），和旧图一样 1320×2598，否则并排时高度对不齐
- **Mac 端截图**不用主人截，渲染样例：设置页用 `.build/debug/Snug --render-settings <目录>`；欢迎页、关于页用装好的正式版渲染（`/Applications/Snug.app/Contents/MacOS/Snug --render-about <目录>`），因为调试版不在 App 包里，图标会变成文件夹、版本显示「开发版」。渲染参数在启动最前面处理完就退出，不碰正在跑的那份。安装一节三张并排（欢迎页、设置、关于），都补到 1040×1096（设置、关于用同色 f6f6f6 上下补边）

相关：[[project-release]]
