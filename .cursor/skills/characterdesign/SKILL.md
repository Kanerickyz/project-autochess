---
name: characterdesign
description: End-to-end workflow for creating or revising playable units—design alignment with user (design-brainstorm + studio subagents) first, then update Content, then implement .tres/abilities/pools. Default light acceptance.
---

# characterdesign

主代理当制作人：**先和用户对齐设计 → 再文档 → 再资源**。默认 **轻量验收**（`verify-godot` → `bash tools/run_light_verify.sh`）。

权威 checklist：[Documents/Content/CHARACTER_DESIGN.md](../../Documents/Content/CHARACTER_DESIGN.md)。

## 两阶段总览（顺序不可颠倒）

| 阶段 | 名称 | 技能 / 子代理 | 写入 |
| --- | --- | --- | --- |
| **I** | **设计对齐** | 本技能 + **`design-brainstorm`** + 只读工作室角色 | **不改** Content 正文、**不改**代码与 `.tres` |
| **II** | **落地执行** | 本技能 + `gameplay-engineer` / `balance-designer` 等 | Content → 资源 → 验证 |

用户说「直接做 / 上文已拍板 / 跳过头脑风暴」时，可进入阶段 II，但主代理须在交付中列出**已继承的设计输入**（对话或文档路径）；不得凭空补未确认的技能机制。

---

## 何时用

- 用户要**新建**或**修改**友方 / 敌方 / 随从角色（含攻血、技能、入池）
- 需要把「一个角色想法」落成 Content + `resources/units/` + 可选新 `AbilityData`

## 何时不用 / 改道

- 只改平衡、不动身份与挂载 → 可只派 `balance-designer`（仍建议核对 UNITS_ROSTER §3）；**若用户未给新数值意图，仍应先阶段 I 对齐**
- 熔印者、Boss 首领 → 走 ENCHANT / BOSS_ROSTER，不用本技能主路径
- 玩法规则未定、与愿景可能冲突 → 阶段 I 必须拉长，**不得**进入阶段 II
- 纯终稿美术换皮、不改数据 → `technical-artist` + PAPER_CUTOUT_ART_BRIEF（可跳过阶段 I 若合同已冻结）

## 与其它技能

| 技能 | 分工 |
| --- | --- |
| **`characterdesign`（本技能）** | 主持全流程：阶段 I 对齐 → 阶段 II 合同 → Content → 实现 |
| **`design-brainstorm`** | **阶段 I 必用流程**（见下）；不单列时仍须满足其硬约束与返回结构 |
| `implement` | 非角色纵切片（系统、UI、战斗管线） |
| `verify-godot` | 轻量 / 完全跑验证 |

---

## 阶段 I — 设计对齐（先于一切落地）

### 1. 主代理必做

1. **读锚点**（摘要后写入「设计对齐纪要」）：
   - [GAME_VISION.md](../../Documents/GAME_VISION.md)
   - [Features/UNITS.md](../../Documents/Features/UNITS.md)、[Features/UNIT_ABILITIES.md](../../Documents/Features/UNIT_ABILITIES.md)
   - [UNITS_ROSTER.md](../../Documents/Content/UNITS_ROSTER.md)、[UNIT_ABILITIES_ROSTER.md](../../Documents/Content/UNIT_ABILITIES_ROSTER.md)
2. **按 `design-brainstorm` 执行**（主代理主持；可合并为一轮对话，但不得省略其步骤）：
   - 玩家语言重述体验（商店 / 招募 / 准备 / 观战里这名角色干什么）
   - 标【愿景已有】/【用户新共识】/【建议】/【As-Is】
   - 每轮最多 **1–2 个**尖锐问题；有缺口立刻补、有歧义立刻问
3. **拉起子代理协作**（同时最多三个；Customize 不可见则手读 `.cursor/agents/*.md` 再 Task）：

| 子代理 | 何时派 | 模式 | 产出 |
| --- | --- | --- | --- |
| **`game-designer`** | **默认必派** | 只读 | 定位、技能时机可读表述、与 UNIT_ABILITIES 边界、验收要点（玩家能观察到什么） |
| **`balance-designer`** | 涉及攻血 / 品阶 / 花费 / 技能幅度 | 只读 | 对标同档角色、预算与升星尺度建议（标【建议】） |
| **`ui-designer`** | 卡面文案 / 技能说明长度 / 可读性 | 只读 | 描述句与图标占位是否够用 |

阶段 I **禁止**：改 `Documents/Content/*` 花名册正文、改 `resources/`、改场景与脚本；未经用户授权也不写完整规格章节进仓库（对话内「对齐纪要」可以）。

### 2. 阶段 I 收束物：设计对齐纪要

主代理整理后**给用户过目**（可贴在回复里），至少包含：

```text
【用户新共识】角色合同草案（名/id/定位/攻血/技能意图/入池/内部轴）
【愿景已有】与本角色相关的已定稿约束
【建议】子代理提出、尚未拍板的项
【风险】管线缺口（如缺触发器、缺目标选择器、需新 EffectAction）
【待你确认】1–2 条（或「确认按草案进入落地」）
```

### 3. 进入阶段 II 的门禁

满足**其一**才可开始改 Content / 写 `.tres`：

- 用户明确回复：**确认 / 按草案做 / 可以落地**（或等价表述）
- 用户事先声明：**跳过头脑风暴，以下为准**并给出完整合同

否则停在阶段 I，只追问、只更新纪要，**不实现**。

---

## 阶段 II — 落地执行

### 开工前门禁

1. **验收方式**：用户未指定 → **默认轻量**；写入合同。
2. **冻结角色合同**（来自阶段 I 纪要；缺项再追问，每轮 ≤2 问）：

| 项 | 说明 |
| --- | --- |
| 显示名 | 中文短名 |
| 资源 `id` | `snake_case` |
| 阵营 | 友方 / 敌方镜像 / token |
| 定位 + 攻击方式 | 近战单体 / 远射 / 溅射 |
| `max_hp` / `attack` | 及必要的 reach、弹速、溅射、`steps_per_turn` |
| 主技能 | 已有 ability id / 新建 / 白板；触发与目标的人类说法 |
| 技能数值尺度 | 含升星 / 三合一规则（是否与全局 ×6 一致须写明） |
| 内部轴备注 | **不对玩家展示**流派名 |
| 入池 | 招募、敌池、关卡等 |
| 美术 | 默认占位 §下 |

3. **冲突**：文档定稿 ≠ 代码已对齐时标 As-Is；不把建议写成已完成。

### 美术占位【默认】

终稿前统一：

- `UnitData.icon` → `res://assets/sprites/placeholders/character_dev.png`
- **透明底**：占位 PNG 须带 **alpha**；源图白底在入库前抠成透明（仅保留角色与纸边描边，勿留矩形白底）。棋盘 / 卡面经 `paper_unit_art.tres` 映射时也用同一张图，白底会直接露馅。
- `portrait_head` / `portrait_body` 可留空；终稿按 [PAPER_CUTOUT_ART_BRIEF.md](../../Documents/Content/PAPER_CUTOUT_ART_BRIEF.md)

### 过程（顺序固定）

#### 1. 更新文档（未授权不得跳过）

按 [CHARACTER_DESIGN.md](../../Documents/Content/CHARACTER_DESIGN.md) §3：

1. `UNITS_ROSTER`（+ 必要时 `UNIT_ABILITIES_ROSTER`）
2. `Content/INDEX.md`（+ 大改时 `Documents/INDEX.md`）
3. 终稿贴图计划时改 `PAPER_CUTOUT_ART_BRIEF` §11

#### 2. 实现

派工（同时最多三个）：

| 触达 | 角色 |
| --- | --- |
| `.tres`、池子、AbilityData、管线缺口 | `gameplay-engineer` |
| 数值 `.tres`、品阶花费 | `balance-designer`（常与 gameplay 并行） |
| 终稿精灵 / 导入 | `technical-artist` |
| 落地前核对 1:1 挂载与合同（可选） | `game-designer` 只读 |

**写入白名单（典型）**：`resources/units/**`、`resources/abilities/**`、池子与关卡 `.tres`、对应 `Documents/Content/*`、玩家可见时 bump `project.godot` 版本。

**禁止**：另写 Buff/羁绊；主路径读 `command_cost`；合同外入池。

#### 3. 验证

- **轻量（默认）**：`bash tools/run_light_verify.sh`；效果由用户自验。
- **完全**：受影响 `*_test_runner.gd`；UI 终稿 `gui-acceptance`。

### 修改 vs 新建

| 新建 | 修改 |
| --- | --- |
| 阶段 I 全合同 + 阶段 II 新 `.tres` + §6 + 入池 | 阶段 I 差分说明 + Content 与资源差分 |
| 敌方 `enemy_*` 镜像与敌池 | 换技能：释放旧挂载，避免双挂 |

---

## 子代理 Task 合同片段

**阶段 I（game-designer / balance-designer）**

```text
模式：只读。主持技能：characterdesign 阶段 I + design-brainstorm。
输入：用户原话 + 设计对齐纪要草稿 + 相关 Documents 路径。
任务：补定位/风险/【建议】/验收观察点；返回 D/E 结构（见 design-brainstorm）。
禁止：写 Content、代码、resources。
```

**阶段 II（gameplay-engineer）**

```text
模式：写入。前置：用户已确认阶段 I 纪要。
合同：验收方式、冻结合同摘要、允许写入路径、禁止项。
返回：文件列表、文档一致性、命令/退出码、待用户验项。
```

---

## 硬约束

- 战斗增益：`EffectSpec` + `EffectResolver`；触发：`CombatEventBus`
- v1 无羁绊；内部「流派」不进玩家 UI
- 共享 Resource 注意 `duplicate()`；保留 `.uid` 与 import 侧车
- 子代理不提交/不推；主代理集成后按云流程提交

## 返回结构（主代理 → 用户）

**阶段 I 结束时（未落地）**

```text
A. 设计对齐纪要（含【用户新共识】合同草案）
B. 子代理要点（game-designer / balance-designer / ui-designer）
C. 风险与管线缺口
D. 待确认问题（或请用户确认进入落地）
E. 明确写：尚未改 Content / 尚未改资源
```

**阶段 II 结束时**

```text
A. 角色合同摘要（对照阶段 I）
B. 文档变更
C. 资源 / 池子 / 版本号
D. 美术：DEV 占位或终稿路径
E. 验收命令与退出码
F. 未覆盖项
```
