---
name: characterdesign
description: End-to-end workflow for creating or revising playable units—read design docs, freeze a character brief, update Content first, then implement .tres/abilities/pools. Default light acceptance. Use when adding or changing roster characters, enemies, or tokens.
---

# characterdesign

主代理当制作人：**先文档、后资源**；默认 **轻量验收**（`verify-godot` → `bash tools/run_light_verify.sh`）。完整制片（L 级 + QA/GUI）用 `vertical-slice`；仅头脑风暴玩法用 `design-brainstorm`；设计已定且非「角色」范围用 `implement`。

权威 checklist：[Documents/Content/CHARACTER_DESIGN.md](../../Documents/Content/CHARACTER_DESIGN.md)。

## 何时用

- 用户要**新建**或**修改**友方 / 敌方 / 随从角色（含攻血、技能、入池）
- 需要把「一个角色想法」落成 Content + `resources/units/` + 可选新 `AbilityData`

## 何时不用 / 改道

- 只改平衡、不动身份与挂载 → 可只派 `balance-designer`（仍建议核对 UNITS_ROSTER §3）
- 熔印者、Boss 首领 → 走 ENCHANT / BOSS_ROSTER，不用本技能主路径
- 玩法规则未定 → `design-brainstorm` 先拍板
- 纯终稿美术换皮、不改数据 → `technical-artist` + PAPER_CUTOUT_ART_BRIEF

## 与其它技能

| 技能 | 分工 |
| --- | --- |
| **`characterdesign`（本技能）** | 角色合同 → Content → 单位/技能/池子 |
| `design-brainstorm` | 定位/技能意图未定 |
| `implement` | 非角色纵切片（系统、UI、战斗管线） |
| `verify-godot` | 轻量 / 完全跑验证 |

## 开工前门禁

1. **验收方式**：用户未指定 → **默认轻量**；写入合同。完全验收须列 runner / L 级。
2. **读锚点**（主代理摘要后传给子代理）：
   - [GAME_VISION.md](../../Documents/GAME_VISION.md)（主题、无羁绊、队伍养成）
   - [Features/UNITS.md](../../Documents/Features/UNITS.md)、[Features/UNIT_ABILITIES.md](../../Documents/Features/UNIT_ABILITIES.md)
   - [UNITS_ROSTER.md](../../Documents/Content/UNITS_ROSTER.md)、[UNIT_ABILITIES_ROSTER.md](../../Documents/Content/UNIT_ABILITIES_ROSTER.md)
   - [CHARACTER_DESIGN.md](../../Documents/Content/CHARACTER_DESIGN.md)
3. **角色合同**（缺项则追问，每轮 ≤2 问）：

| 项 | 说明 |
| --- | --- |
| 显示名 | 中文短名 |
| 资源 `id` | `snake_case` |
| 阵营 | 友方 / 敌方镜像 / token |
| 定位 + 攻击方式 | 近战单体 / 远射 / 溅射 |
| `max_hp` / `attack` | 及必要的 reach、弹速、溅射、`steps_per_turn` |
| 主技能 | 已有 ability id / 新建 / 白板 |
| 内部轴备注 | **不对玩家展示**流派名 |
| 入池 | 招募、敌池、关卡等 |
| 美术 | 默认占位 §下 |

4. **冲突**：文档定稿 ≠ 代码已对齐时标 As-Is；不把建议写成已完成。

## 美术占位【默认】

终稿前统一：

- `UnitData.icon` → `res://assets/sprites/placeholders/character_dev.png`（DEV 全身贴纸）
- `portrait_head` / `portrait_body` 可留空（棋盘用 `0_head` / `0_body`）；终稿按 [PAPER_CUTOUT_ART_BRIEF.md](../../Documents/Content/PAPER_CUTOUT_ART_BRIEF.md)

不要求本阶段提供 `assets/sprites/units/{id}.png` 或纸剪红蓝贴图。

## 过程（顺序固定）

### 1. 对齐目标

- 用玩家语言重述：这名角色在商店/招募/战斗里**干什么**。
- 新技能：对照 UNIT_ABILITIES（单主技能、EffectSpec、事件总线）；能否复用技能库现有 id。

### 2. 更新文档（未授权不得跳过）

按 [CHARACTER_DESIGN.md](../../Documents/Content/CHARACTER_DESIGN.md) §3：

1. `UNITS_ROSTER`（+ 必要时 `UNIT_ABILITIES_ROSTER`）
2. `Content/INDEX.md`（+ 大改时 `Documents/INDEX.md`）
3. 终稿贴图计划时改 `PAPER_CUTOUT_ART_BRIEF` §11

### 3. 实现

派工（同时最多三个；Customize 不可见则手读 `.cursor/agents/*.md`）：

| 触达 | 角色 |
| --- | --- |
| `.tres`、池子、AbilityData | `gameplay-engineer` + 常配 `balance-designer` |
| 仅 icon 占位引用、不改图 | 可由 gameplay-engineer 在 `UnitData` 写 ext_resource |
| 终稿精灵 / 导入 | `technical-artist` |
| 规格与 1:1 挂载核对（可选只读） | `game-designer` |

**写入白名单（典型）**：

- `resources/units/realtime/*.tres`、`resources/units/enemies/*.tres`、`resources/units/tokens/*.tres`
- `resources/abilities/*.tres`
- `resources/recruit/*.tres`、`resources/spawn/*.tres`、`resources/levels/*.tres`（入池时）
- 对应 `Documents/Content/*`
- 玩家可见：**主代理** bump `project.godot` `application/config/version`

**禁止**：另写一套 Buff/羁绊；主路径读 `command_cost`；未写进合同的池外投放。

### 4. 验证

- **轻量（默认）**：`bash tools/run_light_verify.sh`；交付标明战斗/UI **效果由用户自验**。
- **完全**：改动技能/战斗时加跑受影响 `scripts/**/*_test_runner.gd`；UI 终稿用 `gui-acceptance`。

## 修改 vs 新建

| 新建 | 修改 |
| --- | --- |
| 全合同 + 新 `.tres` + §6 挂载 + 入池 | 差分更新 Content 行与对应资源 |
| 敌方需 `enemy_*` 镜像时同步敌池 | 换技能：旧挂载行释放、避免双挂 |
| 新 ability：技能库 + `.tres` + EffectSpec | 数值微调：优先 `.tres`，回写 §3 |

## 子代理合同片段

```text
角色、目标、验收方式（默认轻量）、合同摘要（名/id/攻血/技能/池）、
已更新文档路径、允许写入、禁止写入、
返回：文件列表、文档-资源一致性、命令/退出码、待用户验项
```

## 硬约束

- 战斗增益：`EffectSpec` + `EffectResolver`；触发：`CombatEventBus`
- v1 无羁绊；内部「流派」不进玩家 UI
- 共享 Resource 改动注意 `duplicate()`；保留 `.uid` 与 import 侧车
- 子代理不提交/不推；主代理集成后按云流程提交

## 返回结构（主代理 → 用户）

```text
A. 角色合同摘要
B. 文档变更（先于实现）
C. 资源 / 池子 / 版本号
D. 美术：DEV 占位或终稿路径
E. 验收命令与退出码
F. 未覆盖项与建议的下一刀（终稿美术、完全 runner 等）
```
