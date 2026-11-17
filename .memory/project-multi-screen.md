---
name: project-multi-screen
description: "多屏（issue #7、#10、#16）11-17 定稿待实测：屏幕列表 + 每块屏一个开关和型号、程序不识别控制端；方案全文在 docs/multi-screen.md，这里只记文档之外的上下文"
metadata:
  node_type: memory
  type: project
  originSessionId: f97709de-705a-489b-bb7a-7353b1fba51c
  modified: 2026-11-17T12:45:10.477Z
---

**方案全文在 `docs/multi-screen.md`**（11-17 和主人逐条拍板的定稿）：架构图、拆/删/改/加清单、迁移与回滚、待实测 V1～V10、实施顺序都在里面。开工、讨论多屏时先读它；方向有变改文档，不在这里另记一份。

文档之外的上下文：
- **主人最在意的三条**（讨论时反复强调）：用户自由组合、不替用户限定怎么用（几台设备同时用都行）；程序不主动读 UU 去识别设备（「主动去读会出问题、会很乱」），型号我们备齐、用户自己选；每块屏的生命周期各管各的，一台设备离开不能连累别的屏
- **测试设备**：主人的手机；借来的 iPad（主人自己的 iPad 还在寄）；一台闲置的 Windows 电脑，可装 UU 当电脑控制端；MacBook Air M4 也能当电脑控制端。V1～V5、V7、V8 不用 iPad
- **#7 原型作者在等答复**（11-17 问的是先收小补丁还是等两屏结构）：方案定了不收单屏拆建的补丁，发版时一并回复，感谢对方的实测数据、邀请帮测平板
- 发版后：#4 补一句，#6 说明按屏选型号满足了需求（[[feedback-issue-replies]]：不关别人的 issue）

**How to apply:** 主人说开工就按文档第 8 节的顺序走，第一步是 `--probe-screens` 加实测；实测结果填回文档第 7 节。相关的已有实测见 [[project-phone-screen]]，产品取舍见 [[project-product]]，无显示器的 Mac 见 [[project-headless-mac]]
