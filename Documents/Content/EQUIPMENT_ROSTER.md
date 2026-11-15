# 装备库（EQUIPMENT_ROSTER）

> Content · 地图商店装备花名册 · 2026-11-14  
> 规则见 [Features/MAP_SHOP.md](../Features/MAP_SHOP.md) · [Features/SYNERGY.md](../Features/SYNERGY.md)  
> **【用户新共识】** 护甲 + 六职转职纹章；纹章纯标签零护甲；货架 5 槽自本库随机。

---

## 1. 护甲

| id | 显示名 | 护甲抵挡 | 售价（balance） | 资源 |
|----|--------|----------|-----------------|------|
| `armor_t1` | 护甲 I | 2 | 1 | `resources/equipment/armor_t1.tres` |
| `armor_t2` | 护甲 II | 6 | 2 | `resources/equipment/armor_t2.tres` |
| `armor_t3` | 护甲 III | 10 | 4 | `resources/equipment/armor_t3.tres` |

- 每角色护甲槽 **最多 1**；再拖护甲 → **新替旧**（不退金）。  
- 战斗护甲规则不变（见 MAP_SHOP §5.1）。

---

## 2. 转职纹章（职业）

| id | 显示名 | 额外职业 | 护甲 | 售价（balance） | 资源 |
|----|--------|----------|------|-----------------|------|
| `emblem_tank` | 坦克纹章 | 坦克 | 0 | 4 | `resources/equipment/emblem_tank.tres` |
| `emblem_warrior` | 战士纹章 | 战士 | 0 | 4 | `resources/equipment/emblem_warrior.tres` |
| `emblem_ranged` | 远程纹章 | 远程 | 0 | 4 | `resources/equipment/emblem_ranged.tres` |
| `emblem_artisan` | 工匠纹章 | 工匠 | 0 | 4 | `resources/equipment/emblem_artisan.tres` |
| `emblem_band` | 军乐队纹章 | 军乐队 | 0 | 4 | `resources/equipment/emblem_band.tres` |
| `emblem_arcane` | 秘术纹章 | 秘术 | 0 | 4 | `resources/equipment/emblem_arcane.tres` |

### 规则摘要（定稿）

- **附加**额外职业，不替换本职；不改技能 / 攻击方式。  
- **无件数硬顶**；软顶 = 六职词表：一身最多本职 + 最多 5 件**异职**纹章。  
- **同职不可叠装**；本职已占某职 → **拒装**该职纹章。  
- 可与护甲同挂。  
- 羁绊计数：已入座、按 `unit.id` 去重；该 id 只要带有该职标签（本职或任一纹章）对该职贡献 **1**。

---

## 3. 武器（普攻触发）

| 系列 | 一档 | 二档 | 三档 |
|------|------|------|------|
| 附伤 | 粗砺砥石 +2 | 淬锋铁刃 +5 | 斩将重刃 +10 |
| 吸血 | 回春牙刃 +3 | 饮血弯刀 +5 | 命脉双刃 +10 |
| 攻速 | 攻速刀 −3% | 攻速刀+ −5% | 攻速刀++ −10% |
| 唤骨 | 指骨护符 3/10 | 唤冢铃 5/20 | 冥主徽记 10/30 |
| 燃烧 | 火焰刀 +1 层 | 火焰刀+ +2 | 火焰刀++ +5 |
| 中毒 | 毒刀 +1 层 | 毒刀+ +2 | 毒刀++ +5 |

- **主装备槽**与护甲**互斥**（新替旧）；转职纹章仍独立多件。  
- 普攻致死当击**不**再叠中毒/燃烧、不触发唤骨。  
- 池条目由 `EquipmentWeaponCatalog` 在运行时并入地图商店 `equipment_pool`（见 `MapShopConfig.get_equipment_pool()`）。

---

## 4. 货架池

地图商店 `equipment_pool` = 护甲 3 + 纹章 6 + **武器 18**（武器由代码池追加）。  
货架 **5 槽**，每次从池中**独立随机**（可重复同款）；刷新重抽 5 槽。  
刷新费 **2**（`refresh_cost`）。

---

## 5. 修订记录

| 日期 | 变更 |
|------|------|
| 2026-11-14 | 初稿：护甲三档 + 六职纹章；价由 balance 写入 `.tres`。 |
| 2026-11-14 | 售价定稿：护甲 1/2/4 不变；六职纹章统一 4；货架 5 槽。 |
| 2026-11-15 | 武器 18 件 + 燃烧战斗状态；主槽与护甲互斥。 |
