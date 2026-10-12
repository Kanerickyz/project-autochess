# Project Autochess — 文档索引

> 中世纪幻想 2D PvE 自走棋（构筑 + 布阵开战看联动 + 清波制）· Godot 4.6 · 最后更新：2026-10-12
>
> 主题以 [GAME_VISION.md](./GAME_VISION.md) 定稿为准；单位美术/命名仍可能为旧动物占位（【表现待迁移】）。

## 快速导航

| 文档 | 说明 |
|------|------|
| [ARCHITECTURE.md](./ARCHITECTURE.md) | 当前工程状态、推荐目录树、核心系统划分 |
| [DEVELOPMENT_WORKFLOW.md](./DEVELOPMENT_WORKFLOW.md) | Agent 职责、纵切片流程、L0–L5 阶段 |
| [GAME_VISION.md](./GAME_VISION.md) | PvE 构筑与布阵、**清波胜负**、流派联动、关卡棋盘、刷怪/Boss 节奏、里程碑 |
| [Features/UNITS.md](./Features/UNITS.md) | **角色单位**（友方角色 / 敌方角色 / 生成的代理角色；生命、攻击、移动；功能与数值分离） |
| [Features/GAME_LOOP.md](./Features/GAME_LOOP.md) | **游戏基础循环**（局外 / 一整局地图 / 节点内自走棋；主模式 vs 线性工具环） |
| [SHOP_SYSTEM.md](./SHOP_SYSTEM.md) | **商店 / 牌库 / Tier**（M3b + 增益商店已实现） |
| [BUFF_SYSTEM.md](./BUFF_SYSTEM.md) | **增益卡**规格、示例、附加流（文档目标） |
| [ABILITIES.md](./ABILITIES.md) | **单位内建技能**目录与策划模板 |
| [ABILITY_PROPOSALS.md](./ABILITY_PROPOSALS.md) | **未实现技能提案**（§3–§5 积木组合，策划稿） |
| [WEB_DEPLOY.md](./WEB_DEPLOY.md) | **GitHub Pages 浏览器试玩**（Actions 导出 Web、私有库限制） |
| [UNITS_ROSTER.md](./UNITS_ROSTER.md) | **角色一览**（Content；攻/血、技能摘要、流派索引；由脚本生成） |
| [Reference/SUPER_AUTO_PETS.md](./Reference/SUPER_AUTO_PETS.md) | **SAP Turtle Pack** 单位与食物参考（外部资料） |
| [Reference/SAP_SHOP_SYSTEM.md](./Reference/SAP_SHOP_SYSTEM.md) | **SAP 商店机制**参考（经济 / Tier / Roll / 合成） |
| [Reference/RISK_OF_RAIN_2.md](./Reference/RISK_OF_RAIN_2.md) | **Risk of Rain 2** 基础版道具 / 装备 / 技能参考（外部资料） |
| [Reference/MASTER_OF_PIECE.md](./Reference/MASTER_OF_PIECE.md) | **弈战征途 / Master of Piece** 系统 / 道具 / 机制参考（外部资料） |

## 编辑器插件（策划工具）

在 Godot **项目 → 项目设置 → 插件** 中启用：

| 插件 | Dock 名称 | 用途 |
|------|-----------|------|
| `addons/unit_catalog_editor/` | **Unit Catalog** | 按**友方 / 敌方 / 全部**浏览编辑 `resources/units/*.tres`（`UnitData.team_default`） |
| `addons/wave_spawn_editor/` | **Wave Spawn** | 可视化编辑 `WaveData` 刷怪时间表 |

角色目录：搜索 → **排序**（Tier / 攻 / 血 / 距，可勾选降序）→ 选单位 → 改属性/技能/头像 → **保存**；友方单位无 `ability` 时状态栏会提示。

## 仓库文件索引（当前）

含 **M1 棋盘** + **M2 战斗** + **M3.5 技能** + **M3b 商店/牌库**（角色 + 增益、Tier roll、满库替换；手牌 As-Is 为整库展示，抽 5 To-Be）。

```
Project Autochess/
├── Documents/
├── scenes/main/main.tscn
├── scenes/ui/board_*.tscn, hand_panel, shop_panel, *_modal
├── scripts/core/              # deck_state, shop_service, board_controller
├── scripts/data/              # deck_config, shop_offer, shop_pool_config
├── resources/deck/default_deck.tres
├── resources/shop/dev_shop_pool.tres
└── ...
```

## 推荐 `res://` 结构（待实现）

实现阶段可按 [ARCHITECTURE.md](./ARCHITECTURE.md) 在项目中创建下列路径，并在本索引中勾选进度。

| 路径 | 职责 | 状态 |
|------|------|------|
| `scenes/main/main.tscn` | 对局根场景、Camera2D | **M1 已实现** |
| `scenes/_legacy/ui/board_view.tscn` | 旧 2D 棋盘（非热路径） | **Legacy** |
| `scenes/ui/board_world.tscn` | 3D 棋盘世界（主路径） | **已实现** |
| `scenes/ui/board_cell.tscn` | 格子 Area2D | **M1 已实现** |
| `scenes/units/placeholder_unit.tscn` | 占位单位视觉 | **M1 已实现** |
| `scripts/core/board_grid.gd` | 格占用、`get_empty_cells` | **M1 已实现** |
| `scripts/core/board_controller.gd` | 牌库/手牌/商店/布阵/击杀掉金 | **M3b 已实现** |
| `scripts/core/run_economy.gd` | 金币余额、击杀奖励、波次结算金 | **M3 已实现** |
| `scripts/core/shop_service.gd` | 双卡种商店、Tier roll、购买、刷新 | **M3b 已实现** |
| `scripts/core/deck_state.gd` | 牌库条目、满库替换、`attach_buff` | **M3b 已实现** |
| `scripts/core/deck_entry.gd` | 牌库单条目 | **M3b 已实现** |
| `scripts/core/draw_service.gd` | 每波 PREPARE 无放回抽 5 | **To-Be（未实装）** |
| `scenes/ui/shop_panel.tscn` | 双卡种商店 UI（角色 + 增益） | **M3b 已实现** |
| `scenes/ui/hand_panel.tscn` | 手牌 / 牌库条目（As-Is 整库） | **M3b 已实现** |
| `scenes/ui/deck_replace_modal.tscn` | 满库替换弹窗 | **M3b 已实现** |
| `scenes/ui/buff_attach_modal.tscn` | 增益附加弹窗 | **已实现** |
| `scripts/data/deck_config.gd` | 牌库初始/上限/抽牌数 | **M3b 已实现** |
| `scripts/data/shop_offer.gd` | 角色卡 / 增益卡 Offer | **已实现** |
| `resources/buffs/` | 增益卡 `.tres` | **已实现** |
| `scripts/data/buff_card_data.gd` | 增益卡资源 | **已实现** |
| `scripts/core/tier_unlock.gd` | Tier 1–6 解锁 | **已实现** |
| `resources/deck/default_deck.tres` | 默认牌库配置 | **M3b 已实现** |
| `scenes/ui/player_hud.tscn` | 金币 HUD | **M3 已实现** |
| `resources/economy/` | `EconomyConfig` | **M3 已实现** |
| `resources/shop/` | `ShopPoolConfig` | **M3 已实现** |
| `resources/levels/dev_6x6.tres` | **8×8** 线性开发关，**15 波**（`wave_01`–`wave_15`）；`main.tscn` 直接 F5 | **M1 已实现** |
| `resources/levels/board_act1.tres` | Act1 默认棋盘（无波次表） | **Run 已实现** |
| `resources/runs/act1_map.tres` | Act1 地图配置 + 遭遇池 | **Run 已实现** |
| `resources/encounters/` | `EncounterData`（自 `wave_*.tres` 拆分） | **Run 已实现** |
| `scenes/main/run_game.tscn` | 爬塔 Run 主入口（地图 + 遭遇） | **Run 已实现** |
| `scenes/main/sandbox.tscn` | 沙盒模式（手动摆盘、试战斗） | **已实现** |
| `scenes/ui/sandbox/` | 沙盒单位选择面板 | **已实现** |
| `scripts/core/sandbox_controller.gd` | 沙盒 EDIT/COMBAT 流程 | **已实现** |
| `scenes/ui/map/` | 地图选路 UI | **Run 已实现** |
| `scripts/core/run/` | RunController、MapGenerator、RunGameController | **Run 已实现** |
| `scenes/ui/`（其余） | 商店、手牌、弹窗、HUD | **M3b 已实现** |
| `scenes/units/`（其余） | 正式单位预制体 | 未实现 |
| `scenes/combat/` | 战斗舞台、投射物、特效 | 已创建（骨架） |
| `scripts/autoload/` | 仅 `GameSettings`（无全局 EventBus/GameState） | **已实现** |
| `scripts/core/` | 棋盘、经济、牌库、商店 | **M3b 已实现** |
| `scripts/ui/` | 棋盘 Cell/View 脚本 | **M1 已实现** |
| `resources/levels/` | `LevelData` | **M1 已实现** |
| `scripts/combat/events/` | `CombatEventBus`、战斗事件载荷 | 已创建（骨架） |
| `scripts/combat/effects/` | `EffectResolver`、`StatModifierStack` | **M3.5 已实现** |
| `scripts/combat/` | `CombatArena`、tick、伤害管线 | **M2 已实现** |
| `scripts/data/` | `EffectSpec`、`AbilityData`、`UnitData` | **M3.5 已实现** |
| `resources/units/test_*.tres` | 三样本测试单位 | **M3.5 已实现** |
| `resources/abilities/` | 单位内建技能（见 ABILITIES.md）；商店技能 `.tres` **待迁出** | **M3.5+** |
| `resources/effects/` | 可复用效果片段（可选） | 空目录（效果嵌在 ability `.tres`） |
| `resources/traits/` | 羁绊 `.tres`（**远期**，非 v1） | 不实现 |
| `resources/items/` | 装备（可选） | 空目录（未使用） |
| `assets/sprites/` | 2D 精灵与图集 | 已创建（骨架） |
| `assets/audio/` | BGM / SFX | 已创建（骨架） |
| `assets/fonts/` | UI 字体 | 见项目 Theme |

## 引擎配置摘要

| 项 | 值 |
|----|-----|
| 引擎 | Godot **4.6** |
| 项目名 | Project Autochess |
| 特性标签 | `4.6`, `GL Compatibility`（WebGL 2 / 浏览器导出所需） |
| 物理（3D） | Jolt Physics |
| 渲染器 | `gl_compatibility`（含 ETC2/ASTC 导入，便于 Web） |
| 窗口 | 1920×1080，`canvas_items` + `keep`（16:9，Web/桌面一致） |

## 核心系统对照（规划）

| 系统 | 职责 | 详见 |
|------|------|------|
| Level / Wave | 关卡配置、遭遇、`MatchStateMachine` | GAME_VISION · **M2c** |
| Run / Map | 爬塔地图、选路、节点类型、Boss | GAME_VISION · **Run** |
| Run / Match | 遭遇内：抽牌布阵 → 战斗 → 结算；地图商店节点 | GAME_VISION · **M2c / Run** |
| Economy & Shop | 角色卡/增益卡、Tier、牌库、击杀掉金、波次结算 | **SHOP_SYSTEM** · **BUFF_SYSTEM** · **M3b** |
| Board & Deck | 可变棋盘 + 牌库手牌放置（抽 5 To-Be） | SHOP_SYSTEM · **M3b** |
| Combat Sim | `CombatArena`、固定 tick、`UnitBrain` | ARCHITECTURE §3.4 · **M2b** |
| Spawn | `SpawnSystem` 空闲格刷怪 | **M2a** · ARCHITECTURE §3.3 |
| Effect / Synergy | `EffectResolver` + `EffectSpec` + 3 样本技能 | ARCHITECTURE §3.7 · **M3.5** |
| Units & Abilities | 单位数据、星级、`AbilityData` | **Features/UNITS** · ARCHITECTURE §3.5 · ABILITIES |
| UI Layer | 与逻辑解耦的界面 | ARCHITECTURE §3.6 |

## 协作入口

项目规则在根目录 [AGENTS.md](../AGENTS.md)，代码与 Godot 规范在 [CONTRIBUTING.md](../CONTRIBUTING.md)。Cursor 角色、规则和技能在 `.cursor/`。

## 维护说明

- 新增场景或 Autoload 后：更新 **仓库文件索引** 与 **推荐结构** 状态列。
- 新增/修改 `resources/units/*.tres` 后：运行 `py tools/generate_units_roster.py` 更新 [UNITS_ROSTER.md](./UNITS_ROSTER.md)，并同步 [ABILITIES.md](./ABILITIES.md) §1.2。
- 重大设计变更：同步修改 `ARCHITECTURE.md` / `SHOP_SYSTEM.md`，并在本页「快速导航」保持链接有效。胜负、乐趣支柱与主题（中世纪幻想）以 [GAME_VISION.md](./GAME_VISION.md) 定稿为准。
- 外部游戏参考资料（如 SAP 数值对照、RoR2 道具、Master of Piece 机制）放在 `Documents/Reference/`，与架构 / 策划文档分离；**勿**与 [SHOP_SYSTEM.md](./SHOP_SYSTEM.md) / [BUFF_SYSTEM.md](./BUFF_SYSTEM.md) 等自研规格混淆。SAP **单位/食物数据**与**商店机制**分列 `SUPER_AUTO_PETS.md` 与 `SAP_SHOP_SYSTEM.md`；对冲战棋 Roguelike 参考见 `MASTER_OF_PIECE.md`。
