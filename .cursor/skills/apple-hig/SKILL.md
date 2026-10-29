---
name: apple-hig
description: Use when ui-designer (or menu/HUD/interaction motion work) needs Apple-inspired game UI, touch readability, accessibility, or Tween feedback patterns.
---

# apple-hig（游戏 UI + 交互动效）

给 **ui-designer** 与主代理的**可执行约束**：转述自 [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)，**聚焦游戏与交互反馈**；映射到本仓库 Godot 4 / 竖屏手机向自走棋。

**不是** Apple 原文全文，也**不是** SwiftUI / Liquid Glass / Game Center 实现手册。平台专章（visionOS 折屏等）默认不写进合同，除非用户点名。

权威原文入口（查阅细节时打开）：

| 主题 | 链接 |
|------|------|
| Designing for games | https://developer.apple.com/design/human-interface-guidelines/designing-for-games |
| Motion | https://developer.apple.com/design/human-interface-guidelines/motion |
| Accessibility | https://developer.apple.com/design/human-interface-guidelines/accessibility |
| Layout | https://developer.apple.com/design/human-interface-guidelines/layout |
| Designing for iOS | https://developer.apple.com/design/human-interface-guidelines/designing-for-ios |
| Design principles | https://developer.apple.com/design/human-interface-guidelines/design-principles |
| Feedback | https://developer.apple.com/design/human-interface-guidelines/feedback |

本项目玩法与观战定稿仍以 `Documents/GAME_VISION.md`、`Documents/Features/COMBAT_FEEDBACK.md`、`Documents/Features/MAIN_MENU.md` 为准；**冲突时项目文档优先**，本 skill 只补交互质量与可读性。

---

## 1. 何时用 / 何时不用

**用：** 主菜单、商店、招募、准备站位、战斗 HUD、介绍卡、按钮态、过渡与 Tween 反馈、触控热区、色盲/对比、信息层级。

**不用：** 另写战斗规则；在 `EffectResolver` 里加动画；把 Apple 系统控件当本游戏必须 1:1 复刻。

---

## 2. 游戏向原则（从 HIG 压缩）

审查或出方案时，用玩家语言检查：

| 原则 | 玩家侧含义 | 对本项目 |
|------|------------|----------|
| **Purpose** | 这一屏要帮玩家做成哪一件事 | 主菜单＝进局；商店＝养队；准备＝入座；战斗＝看懂谁在动 |
| **Simplicity** | 一次只强调一件主操作 | 首屏勿堆次要入口；HUD 勿同时抢焦点 |
| **Agency** | 可探索、可撤销/可退出引导 | 弹层可关；长流程可跳过或明确出口 |
| **Familiarity** | 同一控件同行为 | 确认/取消位置与用词全项目一致 |
| **Flexibility** | 适配尺寸与能力差异 | 竖屏手机 + 桌面窗；见 §3、§4 |
| **Delight ≠ 装饰** | 爽感应服务理解与节奏 | 动效传达状态，不挡操作（见 §5） |

---

## 3. 游戏 UI 可读与触控（HIG Games + iOS）

### 3.1 立刻能玩 / 少挡路

- 默认设置应可直接开玩；设置项延后到需要时再问。
- 教程优先「边玩边学」；长文说明作可选查阅。
- 加载与权限请求勿在首次点击前连环轰炸（对标 HIG Loading / Privacy 精神）。

### 3.2 字号与对比（可检清单）

HIG 游戏向下限（逻辑点；落地时按项目基准分辨率换算，勿死抄 pt 而不测实机）：

| 项 | 目标 |
|----|------|
| 正文默认可读 | 对标 iOS 约 **17** 逻辑点量级；自定义细字重宜再放大 |
| 硬下限 | 关键文案勿长期低于约 **11** 逻辑点等价可读性 |
| 对比 | 正文对比优先满足约 **4.5:1**；大号/粗体可约 **3:1** |
| 色盲 | **状态不只靠颜色**（形、图标、位置、文案并用） |

本仓库 As-Is：色盲与小窗验收见 `gui-acceptance` 与 ui-designer 合同（1920×1080 + 较小窗口）。

### 3.3 触控目标

| 项 | 目标 |
|----|------|
| 默认可点区域 | 约 **44×44** 逻辑点量级 |
| 绝对下限 | 约 **28×28**；更小须扩大不可见热区 |
| 间距 | 有描边约 **12** 点边距；无描边可见边约 **24** 点，降误触 |

**iPhone 握持：** 主 CTA 与高频控件优先放在屏**中下部**；顶部堆次要信息。

### 3.4 布局与安全区

- 内容避开刘海 / 圆角 / Home 指示条等安全区；全屏美术可出血，**可点控件与关键文案不可压进不安全区**。
- 菜单与 HUD 用相对约束适配多长宽比（约 19.5:9、16:10、4:3）；避免写死坐标后只在一种机型好看。
- 信息层级：重要在上/阅读起点；对齐表达关联；分组表达同类；渐进披露，首屏少选项。

### 3.5 游戏内菜单

- 菜单打开后仍须**字可读、键可点**，且尽量不遮死战场关键信息（血攻标、当前行动者）。
- 全屏沉浸可关系统杂讯，但退出/设置须一眼可达。

---

## 4. 无障碍（游戏必做子集）

从 HIG Accessibility 抽出本项目默认要评的项：

1. **感知多通道**：关键结果勿只靠一种感官（至少 UI 可见；音频可关时仍可读）。
2. **色 + 形**：敌我、可买/不可买、胜负警告等。
3. **动效可选通信**：重要信息不能「只有动画播过才知道」；须有稳态文案/数字/图标。
4. **少强迫限时 UI**：自动关掉的提示须可被理解或可手动关；避免认知负担过重的闪屏连环。
5. **Reduce Motion 精神**：用户或系统偏好减动时，缩短/淡化位移与弹性，改用淡入淡出或瞬切（实现可分期；设计方案须标清）。
6. **游戏难度/辅助**：若合同含辅助选项，可建议降反应压力、可重复阅读说明——**不擅自改胜负规则**。

---

## 5. 交互与 Tween（核心）

依据 HIG **Motion** + 本仓库 `COMBAT_FEEDBACK`：**Tween 只做表现**，不进 `EffectResolver`；战斗表现随 `presentation_time_scale` 缩短。

### 5.1 动效职责（先定「为什么动」）

每个 Tween / 过渡必须能回答其一，否则删掉：

| 职责 | 例子 |
|------|------|
| **状态** | 按钮按下变暗、不可用半透明 |
| **反馈** | 购买成功轻弹、错误轻抖 |
| **空间关系** | 面板从触发按钮方向滑入 |
| **注意力** | 当前行动者高亮、技能介绍卡入场 |
| **连贯** | 场景淡出淡入（`SceneTransition`） |

禁止：为炫而循环大位移、挡点击的长动画、高频操作每次都播大段过场。

### 5.2 手势与反馈一致

- 滑入的面板，优先用**同轴反向**或明确关闭控件退出（勿「下滑打开、侧滑才能关」这类违和组合）。
- 反馈跟手：按下立刻有态；抬起再播完成态。
- **可取消 / 可打断**：尽量允许跳过或点击穿透到下一操作；勿锁死等到动画结束（战斗介绍卡节奏以 COMBAT_FEEDBACK 定稿为准）。

### 5.3 Godot Tween 配方（设计侧点名，实现归 gameplay-engineer）

审查方案时用下表点名曲线；**具体秒数跟项目现有常量**，下表是相对尺度：

| 场景 | 建议 | 曲线倾向 | 注意 |
|------|------|----------|------|
| 按钮按下 | scale → **0.96–0.98**，时长短 | `EASE_OUT` + `TRANS_QUAD`/`SINE` | 高频，务必短 |
| 按钮抬起/成功 | 回 1.0，可极轻 overshoot | `TRANS_BACK` + `EASE_OUT` **极弱** | 过弹像玩具 |
| 模态/面板出现 | 淡入 + 短位移（自下或自触发源） | `TRANS_CUBIC`/`QUAD` + `EASE_OUT` | 位移≤控件高度一小段 |
| 面板消失 | 淡出 + 回缩或逆向滑出 | `EASE_IN` | 与出现镜像 |
| 列表项入场 | 错峰 `set_delay` | 同上 | 总时长可控，勿瀑布过久 |
| 强调「叮」一下 | 微 scale 或介绍卡 reel | 项目已有 `TRANS_BACK` 短拍 | 对标 `realtime_unit_info_card` 结算拍 |
| 场景切换 | 全屏淡变 + 内容轻沉 | 跟 `MAIN_MENU` / `SceneTransition` | 勿再叠第三套过场 |
| 错误/拒绝 | 短水平或旋转微抖 | `TRANS_SINE` 往返 | 幅度小；可加色/图标 |
| 减动模式 | 用 alpha 切或时长×0.3–0.5，去掉 BACK | `TRANS_SINE`/`LINEAR` | 信息仍在 |

**并行 vs 串联：** 同一反馈的位移动效与淡入可 `parallel()`；叙事步骤（先卡后结算）必须串联，且与 COMBAT_FEEDBACK「先卡再执行」一致。

**时间尺度：** 观战加速时所有表现 Tween 应吃同一 `presentation_time_scale`（或等价），禁止逻辑时钟与表现时钟绑死导致「加速后动画仍墙钟 2 秒」。

### 5.4 分层：谁能动

| 层 | 可以 | 不可以 |
|----|------|--------|
| UI / 介绍卡 / 菜单 | Tween、shader 闪 | 改伤害公式 |
| 单位程序动画 | 受击、移动插值（表现） | 决定是否命中 |
| `EffectResolver` / 管线 | — | 写动画 |

---

## 6. 对本项目界面的检查清单

出设计结论或 L0–L4 清单时，按表面勾选（未覆盖写「未评」）：

**主菜单**

- [ ] 品牌/主 CTA 一眼可见；次要入口不抢主按钮
- [ ] 主按钮落在舒适触达区；热区达标
- [ ] 进出有统一过渡；无多余循环动效

**商店 / 招募**

- [ ] 买/刷新/上阵等主操作可扫读
- [ ] 买不起、已满等状态有色以外的线索
- [ ] 成功/失败反馈短且不挡连续点击

**准备 / 站位**

- [ ] 可拖/可点目标热区足够；非法落点有拒绝反馈
- [ ] 席位与棋盘层级清晰（谁在上谁可点）

**战斗观战**

- [ ] 当前行动者通道不被装饰动画抢走
- [ ] 技能卡「先出现再结算」节奏可理解
- [ ] 高频触发不靠全屏大动画刷屏（可减幅，不可无表现）

**通用**

- [ ] 小窗 / 竖屏长屏无裁切关键数字
- [ ] 对比与色盲项已评或标未测
- [ ] 动效均有 §5.1 职责；无纯装饰长 Tween

---

## 7. ui-designer 输出要求（叠加）

在原有「层级 / 状态 / 文案 / 分辨率」之外，涉及交互时追加：

1. **动效意图表**：控件或流程 → 职责（§5.1）→ 建议 Tween 配方（§5.3）→ 可打断？
2. **触控与安全区**：热区、主 CTA 位置、不安全区规避。
3. **无障碍短评**：色、对比、减动、非唯一通道。
4. **标【建议】vs【项目定稿】**：HIG 启发不得写成 GAME_VISION 已定稿。

不创建子代理；不改 `resources/` / 场景；实现交给 gameplay-engineer / technical-artist。

---

## 8. 明确不做（默认）

- 复刻 UIKit / SwiftUI 组件库或 SF Symbols 强制替换现有纸剪 UI
- Liquid Glass 材质作为本游戏必做项
- Game Center、SharePlay、App Store 评分弹窗文案（除非单独合同）
- 把「苹果风」理解成紫渐变营销页（与本游戏中世纪纸剪主题冲突时，**主题美术优先**，HIG 只管清晰与反馈）
