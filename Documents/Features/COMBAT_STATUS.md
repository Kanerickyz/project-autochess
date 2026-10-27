# 战斗状态（Combat Status）

> 功能规格 · 仅**本场遭遇**内生效的可叠层词条 · 2026-10-27  
> 相关：[战斗](./COMBAT.md) · [角色技能](./UNIT_ABILITIES.md) · [战斗观战反馈](./COMBAT_FEEDBACK.md) · [增益卡](../BUFF_SYSTEM.md)（Run 持久，**不是**战斗状态）

## 1. 这是什么

**战斗状态**是挂在**战斗内单位实例**上的临时词条（虚弱 / 狂暴 / 中毒等），可叠层，参与伤害与回合开始结算。与商店 **增益卡（BuffCardData）** 区分：增益卡跨遭遇；状态**遭遇结束清空**，不写入队伍成员。

玩家在开战观战时长按单位，信息卡下附属块展示当前状态（与装备附属同 UX）。

## 2. 范围

### 2.1 v1 包含

| 状态 id | 显示名 | 极性 | 规则（每层 +1，上限 **15**） |
|---------|--------|------|------------------------------|
| `weak` | 虚弱 | 负 | 受到**普攻或技能伤害**时，在**护甲计算前**将该次伤害数字 **+1**（不含中毒 tick）。 |
| `berserk` | 狂暴 | 正 | **仅普攻** outgoing 伤害，在护甲前 **+1**。 |
| `poison` | 中毒 | 负 | **自己回合开始时**（先于 `ON_ROUND_START` 技能）失去生命 **层数** 点；不走护甲、不吃虚弱。 |

- 叠层：`stacks = clamp(stacks + delta, 0, 15)`。  
- 施加 / 驱散：技能 `EffectSpec` → `EffectAction` `APPLY_COMBAT_STATUS` / `REMOVE_COMBAT_STATUS`（`stat_name` = 状态 id，`value` = 层数，受技能升星倍率）。  
- 实现：实例 `CombatStatusStack`；结算在伤害管线集中读取；不新增第三套战斗 Bus。

### 2.2 v1 不包含

- 跨遭遇状态、商店购买状态、羁绊计数。  
- 通用净化 / 免疫（除非技能显式 `REMOVE_COMBAT_STATUS`）。  
- 准备阶段状态展示（仅战斗中有状态才出附属块）。  
- 脚下角标（仅长按卡；可后续切片）。

## 3. 结算顺序

**普攻**（含反打，走 `RealtimeDamagePipeline.resolve_hit` / 旧网格 `from_attack=true`）：

```text
基础伤害 → +狂暴（攻击方）→ +虚弱（受击方，护甲前）→ 护甲 → 扣 HP
```

**技能伤害**（`DEAL_DAMAGE` 等，`from_attack=false`）：

```text
技能伤害 → +虚弱（受击方，护甲前）→ 护甲 → 扣 HP
```

**自己行动轮开始**（`RealtimeCombatSim`）：

```text
中毒 tick（直扣 HP，层数合计）→ 若仍存活 → ON_ROUND_START 技能链
```

若中毒致死：本动**不**触发 `ON_ROUND_START`；行动者从队列跳过，与死亡规则一致。

## 4. UI

- `UnitInfoText.INFO_ATTACHMENT_KIND_STATUS`：附属块标题「状态」，正文为规则摘要 + `N 层`。  
- 顺序：装备附属在前，状态附属按 `weak` / `berserk` / `poison` 固定序，仅展示层数 &gt; 0 的项。  
- 长按不暂停行动队列。

## 5. 与增益卡 / StatModifierStack

| 层 | 生命周期 | 典型来源 |
|----|----------|----------|
| 增益卡 | Run 持久 | 商店 |
| `StatModifierStack` | 本场临时攻/血等 | `MODIFY_STAT` |
| `CombatStatusStack` | 本场临时词条 | `APPLY_COMBAT_STATUS` |

## 6. 验收口径（玩家可观察）

- 叠层至 15 不再增加；遭遇结束后状态不再显示。  
- 狂暴只改变普攻扣血，不改变技能伤害数字。  
- 虚弱在「有护甲」时仍先加在进护甲前的伤害数字上（与 MAP_SHOP 护甲规则联测）。  
- 中毒在回合开始技能播报之前扣血；致死则本回合开始技能不播。
