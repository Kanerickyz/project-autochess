---
name: design-brainstorm
description: Runs a design brainstorm with studio roles (usually game-designer). Use when starting a feature design doc, exploring player experience, or the user asks to brainstorm before writing specs. No code or resource changes.
---

# design-brainstorm

主代理主持；默认拉起 `game-designer`（只读）。需要数值维度时再加 `balance-designer`，UI 信息架构时再加 `ui-designer`。同时最多三个子代理。

## 何时用

- 新 Feature 规格动笔前
- 用户要「先聊设计 / 头脑风暴」
- 玩法意图未定，或文档与愿景可能冲突、需先对齐

## 硬约束

- **不改代码、不改 `resources/`、不改场景**；未经用户明确授权也不落盘设计规格正文（可建/更新本 skill 或对话内共识摘要）。
- 遵守 [Documents/DEVELOPMENT_WORKFLOW.md](../../Documents/DEVELOPMENT_WORKFLOW.md)「养成规范」：当前不做的默认不写进规格；区分【愿景已有】/【用户新共识】/【建议】/【As-Is】。
- 玩法以 [Documents/GAME_VISION.md](../../Documents/GAME_VISION.md) 定稿为准；发现 Features 与愿景冲突要标出，不假装已对齐。

## 过程

1. 读愿景与相关 Features / 商店等短文，标清已有边界。
2. 用玩家语言重述要讨论的体验（操作、胜负、节奏、爽点），少堆内部标识。
3. 给出短诊断 + 可选方向（或唯一推荐草案），**不要**一上来写完整规格章节。
4. **随时提出**：对用户表述的补充、疑问、风险与建议——不必等用户问完再统一提问；每轮最多 **1–2 个**尖锐跟进问题。
5. 用户拍板后，再另开「写入 Feature 文档」任务；本 skill 本身以共识收束为止。

## 对用户的态度（必须）

在头脑风暴中，主代理与设计子代理对用户说过的内容：

- 有缺口 → **立刻补充**（行业参照或本项目已定稿约束）
- 有歧义或未决 → **立刻提问**（具体、可二选一/排序）
- 有更好或更省风险的做法 → **立刻建议**，并标【建议】，不冒充已定稿

禁止只做复读式附和；禁止把建议写成「已实现 / 已定稿」。

## 返回结构（给主代理转述）

```text
A. 议题一句话（玩家体验）
B. 已有文档边界（愿景 / Features / As-Is）
C. 头脑风暴要点（爽点、风险、可选方向或推荐草案）
D. 补充 / 疑问 / 建议（主动提出）
E. 1–2 个跟进问题
F. 尚未落盘；下一步是否写 Feature 文档待用户授权
```
