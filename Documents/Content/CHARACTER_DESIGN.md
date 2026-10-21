# 角色设计与落地流程（CHARACTER_DESIGN）

> Content · 工作流说明（非玩法规则）  
> 功能规则见 [Features/UNITS.md](../Features/UNITS.md)、[Features/UNIT_ABILITIES.md](../Features/UNIT_ABILITIES.md)；友方名单见 [UNITS_ROSTER.md](./UNITS_ROSTER.md)；技能池见 [UNIT_ABILITIES_ROSTER.md](./UNIT_ABILITIES_ROSTER.md)。  
> Cursor 执行本流程时用技能 **`.cursor/skills/characterdesign/SKILL.md`**。

## 1. 适用场景

| 场景 | 说明 |
|------|------|
| **新建角色** | 新友方 / 新敌方模板 / 战斗随从（token） |
| **修改角色** | 改显示名、身体数值、攻击方式、主技能挂载、入池范围 |
| **不适用** | 熔印者（附魔产物，见 [Features/ENCHANT.md](../Features/ENCHANT.md)）；Boss 高威胁位（见 [BOSS_ROSTER.md](./BOSS_ROSTER.md)） |

第一版不做种族/职业羁绊；**不对玩家挂流派标签**（内部轴备注仅策划用，见 UNIT_ABILITIES §2.5）。

## 2. 开工前信息（合同）

用户或策划未给全时，主代理补齐或追问（每轮最多 1–2 个尖锐问题）：

| 字段 | 必填 | 说明 |
|------|------|------|
| **显示名** | 是 | 中文约 2～3 字；中世纪魔幻包装 |
| **资源 id** | 是 | 英文 `snake_case`；友方 `resources/units/realtime/{id}.tres` |
| **阵营** | 是 | 友方默认 `PLAYER`；遭遇敌用 `resources/units/enemies/enemy_{id}.tres`，`id` 带 `enemy_` 前缀 |
| **角色定位** | 是 | 一句话（坦/远/生成/退场等） |
| **攻击方式** | 是 | 近战单体 / 远程投射物 / 近战溅射（由 `projectile_speed`、`splash_radius` 组合决定，见 UNITS §4.2） |
| **生命 / 攻击** | 是 | 友方单维常用 **1–10 整数**；其它战斗字段可对表同定位角色 |
| **主技能** | 视情况 | 自带技能单位：绑定已有 `AbilityData` 或新建条目；白板可留空 |
| **花费 / 品阶** | 友方入店 | `cost`、`tier`；与 [UNITS_ROSTER](./UNITS_ROSTER.md) §3.2 品阶尺一致 |
| **内部轴 / 流派偏好** | 建议 | 仅写进 Content 内部备注列，不进玩家 UI |
| **入池** | 视投放 | 招募 `default_recruit_config.tres`、敌池 `resources/spawn/*`、关卡 `enemy_pool` 等 |
| **美术** | 默认占位 | 终稿前见 §4；终稿后见 [PAPER_CUTOUT_ART_BRIEF](./PAPER_CUTOUT_ART_BRIEF.md) |

## 3. 文档先于实现（顺序）

1. **改 Content**（按改动范围）  
   - 友方： [UNITS_ROSTER.md](./UNITS_ROSTER.md)（§2 定位、§3 数值、§6 技能 1:1 挂载）  
   - 新技能： [UNIT_ABILITIES_ROSTER.md](./UNIT_ABILITIES_ROSTER.md) + 规则不越界 [UNIT_ABILITIES.md](../Features/UNIT_ABILITIES.md)  
   - 敌方专属叙述：在 UNITS_ROSTER §5 或遭遇文档中补一句（若仅镜像友方模板可写「同模板」）  
   - 贴图键（终稿）： [PAPER_CUTOUT_ART_BRIEF.md](./PAPER_CUTOUT_ART_BRIEF.md) §11  
2. **同步索引**：[Content/INDEX.md](./INDEX.md)、必要时 [Documents/INDEX.md](../INDEX.md)  
3. **再写资源与池子**（见 §5）  
4. **验收**：默认 **轻量** `bash tools/run_light_verify.sh`；动到技能管线或战斗断言时按改动跑相关 `*_test_runner.gd`（完全验收另议）

## 4. 美术占位（默认可用）

| 用途 | 路径 | 说明 |
|------|------|------|
| **卡片 / 列表 icon** | `res://assets/sprites/placeholders/character_dev.png` | 用户提供的 **DEV** 全身贴纸（源图可为 jpg，仓库内以 png 入库）；新角色在终稿前 **`UnitData.icon` 指向此图** |
| **棋盘纸面头身** | 留空或仍用 `0_head` / `0_body` | `portrait_head` / `portrait_body` 为空时 UI 用全局纸面占位（见 `unit_card_display.gd`） |
| **终稿** | `assets/sprites/paper_cutout/units/` 等 | 按纸剪规范出图后改 `icon` / 纸面分层，并登记 §11 映射 |

不在占位阶段要求红蓝阵营贴图；场上纸面模式仍依赖 cutout 表或通用占位。

## 5. 实现清单（资源与代码）

### 5.1 友方主资源

- 新建 `resources/units/realtime/{id}.tres`（`UnitData` + `UnitStats`）  
- `icon` → `character_dev.png`（占位）  
- `ability` → 已有或新建 `resources/abilities/*.tres`（**单主技能一条 `EffectSpec` 链**，经 `EffectResolver`）  
- 忽略 / 不依赖 `command_cost`（主路径已停用）

### 5.2 敌方镜像（若需遭遇出场）

- 新建 `resources/units/enemies/enemy_{id}.tres`：数值可与友方同模板；`team_default = ENEMY`；显示名常加「敌·」前缀  
- 敌池引用：检查 `resources/spawn/act1_enemy_pool.tres`、`default_spawn_budget.tres`、`resources/levels/board_act1.tres` 等是否需加入 ext_resource  

### 5.3 随从 / token

- 路径常为 `resources/units/tokens/`；**默认无主技能**、不占准备座位；生成类技能在 UNITS_ROSTER §6.1 自检  

### 5.4 新建技能（若无合适条目）

1. Content 技能库增行（id、显示名、触发、效果草案、强度、挂载）  
2. `resources/abilities/{id}.tres`（`AbilityData` + `EffectSpec`）  
3. UNITS_ROSTER §6 更新 1:1 挂载；**一个主技能只挂一名友方**  

### 5.5 投放与编辑器

- 招募 / 商店池：`resources/recruit/default_recruit_config.tres`（及同类配置）  
- 策划可在 Godot 启用 `addons/unit_catalog_editor/` 浏览全单位；**入池仍要改对应 `.tres` 池子**  
- **玩家可见新单位合入**：bump `project.godot` → `application/config/version`（见 [CONTRIBUTING.md](../../CONTRIBUTING.md)）

### 5.6 修改已有角色

- 只改牵涉的 Content 行与对应 `.tres`；换技能时同步 §6 与技能库挂载列，避免双挂  
- 数值以资源为准时，回写 UNITS_ROSTER §3 并标 As-Is  

## 6. 硬约束（与 AGENTS 一致）

- 战斗增益只经 `EffectSpec` + `EffectResolver`；触发经 `CombatEventBus`  
- v1 不做羁绊；商店养成对象是**队伍**，不是遭遇内抽牌  
- 当前不做的能力不写进 Content 规格（见 [DEVELOPMENT_WORKFLOW.md](../DEVELOPMENT_WORKFLOW.md) 养成规范）

## 7. 交付说明模板

```text
A. 角色合同（名/id/定位/攻血/技能/入池）
B. 已更新文档（路径列表）
C. 资源与池子（路径列表）
D. 美术：占位 DEV / 终稿路径
E. 验收：轻量或完全 + 命令与退出码
F. 未覆盖（需用户局内自验项）
```
