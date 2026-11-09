# 中毒流内容（POISON_ARCHETYPE）

> Content · 与 [Features/ARCHETYPE.md](../Features/ARCHETYPE.md) 配套 · 2026-11-09  
> 规则与职能见 Feature；本篇写**技能内容草案、As-Is 种子、挂载计划**。  
> **不对玩家露出**「中毒流 / 异常流」标签。  
> **本篇不写**：燃烧；具体定点数（由数值填 `.tres`）；未授权的新角色花名定稿。

## 1. 范围

| 项 | 结论 |
|----|------|
| 主轴 | 内部 **异常流** → 本切片只交 **中毒簇** |
| 规则 | [Features/ARCHETYPE.md](../Features/ARCHETYPE.md) §3 |
| 状态结算 | [Features/COMBAT_STATUS.md](../Features/COMBAT_STATUS.md) |
| 技能总表 | 条目亦登记在 [UNIT_ABILITIES_ROSTER.md](./UNIT_ABILITIES_ROSTER.md)；本篇按职能汇总 |

## 2. As-Is 种子

| 显示名 | 技能 | id | 职能 | 内部备注 |
|--------|------|-----|------|----------|
| 药师 | 药雾蚀敌 | `turn_start_nearby_enemies_apply_poison` | 邻格施加者 | 异常·中毒·邻格施加 |

资源已挂：`resources/units/realtime/apothecary.tres` ↔ 对应 ability。

## 3. 最小可玩技能包（职能条目）

> 强度为相对档；**无定点数**。挂载列「（待挂）」表示 Content 已立项、角色 1:1 挂载另开角色切片。  
> 毒向受益者依赖效果管线「读目标中毒层数造成技能伤」【实现 To-Be】，见 Feature §3.4。

| id（暂定） | 显示名 | 大类 · 频率 | 小队 | 效果草案（无点数） | 综合 | 挂载 | 职能 / 内部备注 |
|------------|--------|-------------|------|--------------------|------|------|-----------------|
| `turn_start_nearby_enemies_apply_poison` | 药雾蚀敌 | 回合 · 偶尔多次 | 否 | 自己回合开始时，对周围一格敌军施加中毒（层数随升星） | **中庸** | 药师 | 邻格施加 · **已有** |
| `deal_damage_apply_poison` | 毒矢沾衣 | 出手 · 高频 | 否 | 自己造成伤害时，对**事件目标**施加中毒 **小幅**层数 | **偏弱～中庸** | （待挂） | 命中施加 · **草案** |
| `deal_vs_poisoned_add_poison` | 蚀疮加深 | 出手 · 偶尔多次 | 否 | 自己造成伤害且目标**已有中毒**时，再对其施加中毒 **小幅**层数 | **中庸** | （待挂） | 放大器 · **草案** |
| `deal_damage_bonus_from_poison_stacks` | 毒厚加创 | 出手 · 高频 | 否 | 自己造成伤害且目标中毒层 **> 0** 时，再造成一段与**当前层数相关**的技能伤害；**不消耗**毒层；该段**不**再触发上毒 / 再读层连锁 | **中庸～偏强** | （待挂） | 毒向受益者 · **草案** · 管线 To-Be |

拖拍肉盾：不强制新技能；可用现有高生命角色或白板身体。

## 4. 挂载与实现状态

| 项 | 状态 |
|----|------|
| Feature 规则 | [ARCHETYPE.md](../Features/ARCHETYPE.md) 已定稿 |
| 邻格施加（药师） | 【As-Is】已挂载 |
| 命中施加 / 放大器 / 受益者 | Content 草案已入技能库 §3.4；**未**建 `.tres`、**未**挂角色 |
| 受益者伤害模式 | 【实现 To-Be】读目标 `poison` 层数 |
| 新友方角色 | 未定显示名；落地走 [CHARACTER_DESIGN.md](./CHARACTER_DESIGN.md) |

## 5. 维护

- 改中毒流规则只改 Feature；改条目文案 / 挂载同步本篇与 [UNIT_ABILITIES_ROSTER.md](./UNIT_ABILITIES_ROSTER.md)、角色库 §6。  
- 新建角色挂本簇技能前走角色设计流程；终稿前 icon 用 DEV 占位。
