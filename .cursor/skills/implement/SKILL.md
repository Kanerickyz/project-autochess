---
name: implement
description: Implements an already-agreed design in code, resources, or editor plugins by dispatching the needed studio subagents. Use when the user asks to implement from design docs or prior conversation consensus.
---

# implement

主代理当制作人与集成人。设计已定 → 按范围拉实现角色落地；细则只维护在 Documents/DEVELOPMENT_WORKFLOW.md，不要把长表复制进本技能。

与其它技能分工：

| 技能 | 用途 |
| --- | --- |
| `design-brainstorm` | 玩法未定；只聊设计，不改代码/资源 |
| **`implement`（本技能）** | 设计稿 / 上文共识已定；改代码、`resources/`、或 `addons/` 编辑器 |
| `vertical-slice` | 跨模块完整纵切片（含设计核对 → 实现 → QA/审查），带明确 L0–L5 目标 |

## 何时用

- 用户说「按设计稿 / Features / 上文共识实现」
- 规格已落盘（`Documents/Features/`、`Documents/Content/`、愿景相关节）或对话里已拍板且范围清楚
- 改动落在脚本、场景、`.tres`、或策划用编辑器插件（如 `addons/unit_catalog_editor/`、`addons/wave_spawn_editor/`）

## 何时不用 / 先改道

- 玩法意图未定、与愿景冲突未对齐 → 先用 `design-brainstorm`，**不要**边猜边写代码
- 用户要完整 L 级制片流程（设计→实现→QA→审查一条龙）→ 用 `vertical-slice`
- 仅验证已有改动 → `verify-godot` / `gui-acceptance`

## 开工前门禁

1. **验收方式**：用户未指定则先问（轻量 | 完全），写入合同。见 DEVELOPMENT_WORKFLOW「验收方式」。
2. **锚定设计输入**（主代理整理后传给子代理，勿假设子代理见过上文）：
   - 对话中的【用户新共识】/ 已拍板条目
   - 对应 `Documents/Features/*.md`、`Documents/Content/*`、`GAME_VISION` 相关节
   - As-Is 与 To-Be 差异（文档定稿 ≠ 代码已对齐）
3. **范围一句话**：玩家可观察变化 + 允许写入的模块；当前不做的不实现、不扩写规格。
4. 目标等级：用户指定则写入；未指定时轻量默认按「实现完成 + 加载烟测」交付，不自称 L3+；完全模式再定 L2–L5。

## 派谁（按触达，不到场的不派）

同时最多三个子代理。Cursor 角色：`.cursor/agents/<role>.md`，用 Task 委派。Customize 里看不见就不算已加载；手读对应文件再传合同。

| 触达 | 角色 | 写入 |
| --- | --- | --- |
| 棋盘 / 战斗 / 技能 / 商店 / 牌库 / Run / UI 行为 | `gameplay-engineer` | 写入白名单 |
| 具体点数、波次、经济、池子、`.tres` 数值 | `balance-designer` | 分配的数据资源 |
| 精灵、图标、导入、相机、缺失回退 | `technical-artist` | 分配的资产/表现 |
| 音频 cue / 占位音 | `audio-designer` | 分配的音频 |
| 仅需信息架构核对（不写代码） | `ui-designer` | 只读 |
| 实现前规格与验收是否漂移（可选、只读） | `game-designer` | 只读 |

默认最小集：有明确规格时只派 `gameplay-engineer`；数值空缺再加 `balance-designer`；纯表现/导入再加 `technical-artist`。

`project.godot`、共享场景、枚举、根文档由**主代理**写。每个文件一个写入负责人；共享 checkout 不并行改同一文件。

## 合同（派 Task 时必填）

```text
角色、目标、目标等级、验收方式（轻量|完全）、输入（设计路径 + 上文共识摘要）、验收、允许写入、禁止写入、依赖
返回：文件、结论、达到的等级、证据、下一级缺口、命令/退出码、风险、主代理待处理项
```

## 过程

1. 主代理冻结设计输入与写入白名单；冲突标出，不把建议写成已完成。
2. 按触达并行或串行派实现角色（最多三个）。
3. 主代理收回 diff：集成共享文件、补 UID/枚举、同步 Content 文档若合同要求。
4. 验证：
   - **轻量**：`verify-godot` → `bash tools/run_light_verify.sh`；不派 `qa-tester` / `gui-acceptance`；交付标明「效果未代验」。
   - **完全**：受影响 runner + 按目标 L 派 `qa-tester`；UI/图标走 `gui-acceptance`；`reviewer` 只读 diff。阻断退回实现。
5. L5 合同额外：禁止新功能，只修缺陷。

## 硬约束

- 玩法以 GAME_VISION 为准；战斗增益走 `EffectSpec` / `EffectResolver`；战斗触发走 `CombatEventBus`；v1 不做羁绊。
- 数值优先改 `resources/` 下 `.tres`；改共享 Resource 前判断 `duplicate()`。
- 编辑器插件改动须保持 Dock 可用，不破坏现有 `.tres` 读写约定。
- 不提交 `.godot/`、`.artifacts/`、日志与缓存；保留 `.uid` 与导入侧车。
- 子代理不创建额外子代理、不提交/推送/发布；主代理集成后按用户/云流程提交。

## 返回结构（主代理向用户交付）

```text
A. 实现范围（对照设计输入）
B. 改动文件与负责人
C. 验收方式 + 实跑命令/退出码
D. 达到的等级或「实现完成 + 轻量通过，待用户效果验收」
E. 未覆盖项 / 风险 / 下一级缺口
```
