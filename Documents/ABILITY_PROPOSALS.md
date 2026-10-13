# 技能提案（ABILITY_PROPOSALS）

> 策划草案 · 均可由 [ABILITIES.md](./ABILITIES.md) §3–§5 现有积木实现 · **未创建 `.tres` / 未挂载单位**  
> 已实现技能见 [ABILITIES.md §1.2](./ABILITIES.md#12-单位内建技能目录) · 角色库见 [Content/UNITS_ROSTER.md](./Content/UNITS_ROSTER.md)

---

## 1. 使用说明

- 本文档仅收录**未实现**的内建技能提案；落地后迁入 ABILITIES §1.2，并在本文标记「已实现」或删除条目。
- 每条提案的 `trigger` / `target_selector` / `actions` 必须能在 §3–§5 找到对应枚举，**不**要求扩展引擎。
- `display_name` 风格与现网单位一致：「触发时机 + 目标 + 效果」。
- 每条提案含 **效果说明**：用自然语言描述引擎层实际发生什么（持续域、目标、数值），便于策划快速浏览；细节见 §3–§5 各条表格。
- 多 `EffectAction` 按顺序占多个战斗 interval；`+1/+1` 类建议拆成 `MODIFY_STAT attack` → `MODIFY_STAT max_hp` → `HEAL`（见 ABILITIES §5 非永久 Buff 约定）。
- 标注 **Legacy** 者概念来自 ABILITIES §1.3 废弃商店技能样本，可挂载到新单位复用。

---

## 2. 覆盖缺口速查

相对 [§1.2 已实现目录](./ABILITIES.md#12-单位内建技能目录) 与 `resources/abilities/*.tres`：

| 触发器 | §1.2 覆盖 | 本提案条数 | 代表 id |
|--------|-----------|------------|---------|
| `OnDealDamage` | **无** | 5 | `deal_damage_buff_self_atk` |
| `OnRoundStart` | 仅 Legacy 样本 | 4 | `round_start_heal_self` |
| `OnCrit` | 仅枪手第二段 | 4 | `crit_heal_self` |
| `OnKill` | 河马、犀牛 | 4 | `knockout_heal_self` |
| `OnSummoned` | 蝎子 | 2 | `summoned_gain_max_hp` |
| `OnFriendSummoned` | 马、驯兽师、火鸡 | 2 | `friend_summoned_heal_summoned` |
| `OnMove` | 战车（伤害） | 3 | `move_heal_self` |
| `OnAttackHit` | 刺客（换位） | 1 | `attack_hit_buff_self_atk` |
| `OnFriendDeath` | 鲨鱼、苍蝇 | 2 | `friend_death_heal_self` |
| `OnDamageTaken` | 已多 | 2 | `hurt_perm_max_hp` |
| `OnCombatStart` / `OnDeath` | 已多 | 2 | `combat_start_buff_all_atk_1` |
| 商店 `OnBuy/Sell/LevelUp` | 已有多条 | 6 | `buy_perm_crit_random_ally` |
| 双 Spec | 枪手 | 3 | `dual_hurt_rage` |

| 效果 / 目标 | §1.2 稀少用法 | 本提案侧重 |
|-------------|---------------|------------|
| `PERMANENT_DECK_STAT` + `crit_rate_percent` | 枪手（受伤） | 造成伤害 / 购买 / 出售 / 升级 |
| `FRIENDS_HURT_AOE` | 狼獾（threshold=3） | threshold=2 轻量版 |
| `SWAP_POSITIONS` | 刺客 | 死亡时换位 |
| `APPLY_CELL_EFFECT` | 地图流 | 回合开始 / 击倒 / 移动（随机格） |
| `NEAREST_ALLY_BEHIND` | 骆驼 | 造成伤害时 buff 身后队友 |

### 2.1 提案总览（40）

| id | 工作名 | 触发器 | 效果说明 | Tier |
|----|--------|--------|----------|------|
| `deal_damage_buff_self_atk` | 血刃 | `OnDealDamage` | 每次造成伤害后，本单位本局攻击力 +1 | T2 |
| `deal_damage_heal_self` | 吸血触媒 | `OnDealDamage` | 每次造成伤害后，恢复 1 生命 | T3 |
| `deal_damage_random_enemy_1` | 溅射尖刺 | `OnDealDamage` | 每次造成伤害后，对随机敌人额外 1 点伤害 | T2 |
| `deal_damage_perm_crit_2` | 精准射手 | `OnDealDamage` | 每次造成伤害后，牌库永久 +2% 暴击 | T3 |
| `deal_damage_buff_ally_behind` | 掩护射击 | `OnDealDamage` | 每次造成伤害后，身后最近队友本局 +1 攻击 | T2 |
| `round_start_heal_self` | 自愈节律 | `OnRoundStart` | 每个战斗 tick 开始时，恢复 1 生命 | T2 |
| `round_start_buff_self_atk` | 热身 | `OnRoundStart` | 每个战斗 tick 开始时，本局攻击力 +1 | T1 |
| `round_start_hurt_random_ally` | 鲁莽同伴 | `OnRoundStart` | 每个 tick 开始时，对随机其他队友 1 点伤害 | T3 |
| `round_start_apply_burn_random` | 余烬蔓延 | `OnRoundStart` | 每个 tick 开始时，对 1 随机格施加 1 回合燃烧 | T4 |
| `crit_heal_self` | 暴击回春 | `OnCrit` | 每次暴击后，恢复 2 生命 | T3 |
| `crit_damage_random_enemy` | 暴击溅射 | `OnCrit` | 每次暴击后，对随机敌人 2 点伤害 | T3 |
| `crit_buff_self_crit_5` | 暴击滚雪球 | `OnCrit` | 每次暴击后，本局暴击率 +5% | T2 |
| `crit_buff_all_allies_atk` | 战吼暴击 | `OnCrit` | 每次暴击后，全体队友本局 +1 攻击 | T4 |
| `knockout_heal_self` | 凯旋 | `OnKill` | 每次击杀后，恢复 3 生命 | T3 |
| `knockout_damage_last_enemy` | 穿后 | `OnKill` | 每次击杀后，对后排敌人 3 点伤害 | T4 |
| `knockout_buff_self_crit` | 猎杀专注 | `OnKill` | 每次击杀后，本局暴击率 +10% | T3 |
| `knockout_apply_burn_around` | 焚尸 | `OnKill` | 每次击杀后，在被击杀者周围格施加燃烧 | T4 |
| `summoned_gain_max_hp` | 壮硕入场 | `OnSummoned` | 被召唤上场时，本局生命上限 +2 | T2 |
| `summoned_heal_self_full` | 完美落地 | `OnSummoned` | 被召唤上场时，恢复 3 生命 | T3 |
| `friend_summoned_heal_summoned` | 驯养恢复 | `OnFriendSummoned` | 友方召唤后，为被召唤者恢复 2 生命 | T2 |
| `friend_summoned_perm_atk` | 烙印 | `OnFriendSummoned` | 友方召唤后，为被召唤者牌库永久 +1 攻击 | T3 |
| `move_heal_self` | 步疗 | `OnMove` | 每次移动完成后，恢复 1 生命 | T1 |
| `move_buff_self_atk` | 冲锋势头 | `OnMove` | 每次移动完成后，本局攻击力 +1 | T2 |
| `move_apply_burn_random` | 焦土足迹 | `OnMove` | 每次移动完成后，对 1 随机格施加燃烧 | T3 |
| `attack_hit_buff_self_atk` | 迎击姿态 | `OnAttackHit` | 被攻击命中前，本局攻击力 +2 | T2 |
| `friend_death_heal_self` | 哀悼恢复 | `OnFriendDeath` | 友方死亡后，恢复 2 生命 | T3 |
| `friend_death_damage_random_enemy` | 复仇怒火 | `OnFriendDeath` | 友方死亡后，对随机敌人 2 点伤害 | T3 |
| `hurt_perm_max_hp` | 疤甲 | `OnDamageTaken` | 每次受伤后，牌库永久 +1 生命上限 | T2 |
| `hurt_friends_hurt_aoe_light` | 群伤感应 | `OnDamageTaken` | 本 tick 友方受伤≥2 次时，对全体敌人 1 点伤害 | T3 |
| `combat_start_buff_all_atk_1` | 集结号 | `OnCombatStart` | 开战时为全体队友本局 +1 攻击 | T3 |
| `faint_swap_with_healthiest` | 临终让位 | `OnDeath` | 死亡时与 max_hp 最高队友交换位置 | T3 |
| `buy_buff_random_ally_atk` | 采购强化 | `OnBuy` | 购入后，随机牌库队友永久 +1 攻击 | T1 |
| `buy_perm_crit_random_ally` | 校准镜片 | `OnBuy` | 购入后，随机牌库队友永久 +3% 暴击 | T2 |
| `sell_buff_random_ally_crit` | 遗产瞄准 | `OnSell` | 出售前，随机牌库队友永久 +5% 暴击 | T2 |
| `sell_heal_shop_characters` | 货架保养 | `OnSell` | 出售时，商店全部角色 offer +2 生命上限 | T1 |
| `levelup_buff_self_crit` | 熟练瞄准 | `OnLevelUp` | 合成升级后，该条目永久 +2% 暴击 | T2 |
| `levelup_stock_free_apple` | 庆功宴 | `OnLevelUp` | 升级后，补充免费苹果增益至空 buff 槽 | T1 |
| `dual_hurt_rage` | 狂怒伤疤 | `OnDamageTaken`×2 | 受伤时本局 +2 攻，且永久 +1 攻（双 spec） | T2 |
| `dual_crit_lifesteal` | 暴击吸血 | `OnCrit`×2 | 暴击时本局 +5% 暴击并恢复 1 生命（双 spec） | T3 |
| `dual_death_summon_burn` | 焚化献祭 | `OnDeath`×2 | 死亡时召唤 token 并对周围格施加燃烧（双 spec） | T4 |

> **持续域约定**：「本局」= `StatModifierStack`，波次结束清空；「永久」= `DeckEntry.bonus_*`，整局 run 保留。

---

## 3. 战斗技能提案（31）

### 3.1 OnDealDamage（5）

#### `deal_damage_buff_self_atk` — 血刃（建议 Tier 2）

| 字段 | 值 |
|------|-----|
| display_name | 造成伤害时 对自身 +1 攻击 |
| trigger | `OnDealDamage` |
| target_selector | `SELF` |
| exclude_owner | — |
| actions | `MODIFY_STAT` attack +1 |
| 效果说明 | 每次成功造成伤害后，本单位本局攻击力 +1（波次结束清空）。 |
| 建议单位定位 | T2 前排输出，越打越强 |
| 备注 | 首个使用 `OnDealDamage` 的提案；高频触发需控制基础攻击 |

#### `deal_damage_heal_self` — 吸血触媒（建议 Tier 3）

| 字段 | 值 |
|------|-----|
| display_name | 造成伤害时 恢复 1 生命 |
| trigger | `OnDealDamage` |
| target_selector | `SELF` |
| exclude_owner | — |
| actions | `HEAL` +1 |
| 效果说明 | 每次造成伤害后，恢复 1 点生命（不超过生命上限）。 |
| 建议单位定位 | T3 续航战士 |
| 备注 | 与河马「击倒回血」区分触发时机 |

#### `deal_damage_random_enemy_1` — 溅射尖刺（建议 Tier 2）

| 字段 | 值 |
|------|-----|
| display_name | 造成伤害时 对随机敌人造成 1 点伤害 |
| trigger | `OnDealDamage` |
| target_selector | `RANDOM_ENEMY` |
| exclude_owner | — |
| actions | `DEAL_DAMAGE` 1 |
| 效果说明 | 每次造成伤害后，额外对一名随机存活敌人造成 1 点伤害（经 DamagePipeline，可暴击）。 |
| 建议单位定位 | T2 多段攻击配合 |
| 备注 | 连锁伤害走 `DamagePipeline`，可暴击 |

#### `deal_damage_perm_crit_2` — 精准射手（建议 Tier 3）

| 字段 | 值 |
|------|-----|
| display_name | 造成伤害时 永久 +2% 暴击 |
| trigger | `OnDealDamage` |
| target_selector | `SELF` |
| exclude_owner | — |
| actions | `PERMANENT_DECK_STAT` crit_rate_percent +2 |
| 效果说明 | 每次造成伤害后，本单位牌库条目永久 +2% 暴击率（整局 run 保留）。 |
| 建议单位定位 | T3 远程，与枪手 run 叠层区分触发 |
| 备注 | 战斗内写入 `DeckEntry.bonus_crit_rate_percent` |

#### `deal_damage_buff_ally_behind` — 掩护射击（建议 Tier 2）

| 字段 | 值 |
|------|-----|
| display_name | 造成伤害时 对身后最近队友 +1 攻击 |
| trigger | `OnDealDamage` |
| target_selector | `NEAREST_ALLY_BEHIND` |
| exclude_owner | — |
| actions | `MODIFY_STAT` attack +1 |
| 效果说明 | 每次造成伤害后，为身后最近一名队友本局 +1 攻击。 |
| 建议单位定位 | T2 后排射手 + 前排配合 |
| 备注 | 与骆驼「受伤 buff 身后」对称 |

---

### 3.2 OnRoundStart（4）

#### `round_start_heal_self` — 自愈节律（建议 Tier 2）

| 字段 | 值 |
|------|-----|
| display_name | 回合开始时 恢复 1 生命 |
| trigger | `OnRoundStart` |
| target_selector | `SELF` |
| exclude_owner | — |
| actions | `HEAL` +1 |
| 效果说明 | 每个战斗 tick 开始时，恢复 1 点生命。 |
| 建议单位定位 | T2 坦克，长战恢复 |
| 备注 | 每 combat tick 触发一次 |

#### `round_start_buff_self_atk` — 热身（建议 Tier 1）

| 字段 | 值 |
|------|-----|
| display_name | 回合开始时 对自身 +1 攻击 |
| trigger | `OnRoundStart` |
| target_selector | `SELF` |
| exclude_owner | — |
| actions | `MODIFY_STAT` attack +1 |
| 效果说明 | 每个战斗 tick 开始时，本单位本局攻击力 +1。 |
| 建议单位定位 | T1 成长型 |
| 备注 | 长战斗叠加明显，需低基础攻 |

#### `round_start_hurt_random_ally` — 鲁莽同伴（建议 Tier 3）

| 字段 | 值 |
|------|-----|
| display_name | 回合开始时 对随机其他队友造成 1 点伤害 |
| trigger | `OnRoundStart` |
| target_selector | `RANDOM_ALLY` |
| exclude_owner | true |
| actions | `DEAL_DAMAGE` 1 |
| 效果说明 | 每个战斗 tick 开始时，对一名随机其他队友造成 1 点伤害。 |
| 建议单位定位 | T3 自损协同（配合受伤流） |
| 备注 | **Legacy**：概念来自 `round_start_hurt_ally.tres` |

#### `round_start_apply_burn_random` — 余烬蔓延（建议 Tier 4）

| 字段 | 值 |
|------|-----|
| display_name | 回合开始时 对 1 个随机格子施加燃烧（1 回合） |
| trigger | `OnRoundStart` |
| target_selector | `RANDOM_CELLS`（target_count=1） |
| exclude_owner | — |
| actions | `APPLY_CELL_EFFECT` burn |
| 效果说明 | 每个战斗 tick 开始时，在 1 个随机格施加 1 回合燃烧（站格者每 tick 受伤）。 |
| 建议单位定位 | T4 地图流核心 |
| 备注 | 与灰烬萨满「开战烧格」区分频率 |

---

### 3.3 OnCrit（4）

#### `crit_heal_self` — 暴击回春（建议 Tier 3）

| 字段 | 值 |
|------|-----|
| display_name | 造成暴击时 恢复 2 生命 |
| trigger | `OnCrit` |
| target_selector | `SELF` |
| exclude_owner | — |
| actions | `HEAL` +2 |
| 效果说明 | 每次造成暴击伤害后，恢复 2 点生命。 |
| 建议单位定位 | T3 暴击续航 |
| 备注 | 与枪手「暴击叠暴击率」互补 |

#### `crit_damage_random_enemy` — 暴击溅射（建议 Tier 3）

| 字段 | 值 |
|------|-----|
| display_name | 造成暴击时 对随机敌人造成 2 点伤害 |
| trigger | `OnCrit` |
| target_selector | `RANDOM_ENEMY` |
| exclude_owner | — |
| actions | `DEAL_DAMAGE` 2 |
| 效果说明 | 每次暴击后，对一名随机敌人额外造成 2 点伤害。 |
| 建议单位定位 | T3 暴击 AoE 点杀 |
| 备注 | 二次伤害可再暴击（需防循环 depth） |

#### `crit_buff_self_crit_5` — 暴击滚雪球（建议 Tier 2）

| 字段 | 值 |
|------|-----|
| display_name | 造成暴击时 +5% 暴击 |
| trigger | `OnCrit` |
| target_selector | `SELF` |
| exclude_owner | — |
| actions | `MODIFY_STAT` crit_rate_percent +5 |
| 效果说明 | 每次暴击后，本单位本局暴击率 +5%。 |
| 建议单位定位 | T2 暴击流（本局） |
| 备注 | 枪手第二段为 +10%；本提案更弱、更泛用 |

#### `crit_buff_all_allies_atk` — 战吼暴击（建议 Tier 4）

| 字段 | 值 |
|------|-----|
| display_name | 造成暴击时 对全体队友 +1 攻击 |
| trigger | `OnCrit` |
| target_selector | `ALL_ALLIES` |
| exclude_owner | false |
| actions | `MODIFY_STAT` attack +1 |
| 效果说明 | 每次暴击后，全体队友本局攻击力 +1。 |
| 建议单位定位 | T4 团队暴击核心 |
| 备注 | 需较高初始暴击率或增益配合 |

---

### 3.4 OnKill（4）

#### `knockout_heal_self` — 凯旋（建议 Tier 3）

| 字段 | 值 |
|------|-----|
| display_name | 击倒时 恢复 3 生命 |
| trigger | `OnKill` |
| target_selector | `SELF` |
| exclude_owner | — |
| actions | `HEAL` +3 |
| 效果说明 | 每次击杀敌方单位后，恢复 3 点生命。 |
| 建议单位定位 | T3 收割型前排 |
| 备注 | 河马为 +3/+3 stat；本提案纯回复 |

#### `knockout_damage_last_enemy` — 穿后（建议 Tier 4）

| 字段 | 值 |
|------|-----|
| display_name | 击倒时 对后排敌人造成 3 点伤害 |
| trigger | `OnKill` |
| target_selector | `LAST_ENEMY` |
| exclude_owner | — |
| actions | `DEAL_DAMAGE` 3 |
| 效果说明 | 每次击杀后，对后排敌人造成 3 点伤害。 |
| 建议单位定位 | T4 刺客型收割 |
| 备注 | 犀牛为 4 点打前排；本提案打后排 |

#### `knockout_buff_self_crit` — 猎杀专注（建议 Tier 3）

| 字段 | 值 |
|------|-----|
| display_name | 击倒时 +10% 暴击 |
| trigger | `OnKill` |
| target_selector | `SELF` |
| exclude_owner | — |
| actions | `MODIFY_STAT` crit_rate_percent +10 |
| 效果说明 | 每次击杀后，本单位本局暴击率 +10%。 |
| 建议单位定位 | T3 连杀暴击流 |
| 备注 | 本局临时，波次结束清空 |

#### `knockout_apply_burn_around` — 焚尸（建议 Tier 4）

| 字段 | 值 |
|------|-----|
| display_name | 击倒时 对目标格周围施加燃烧（1 回合） |
| trigger | `OnKill` |
| target_selector | `CELLS_AROUND_EVENT` |
| exclude_owner | — |
| actions | `APPLY_CELL_EFFECT` burn, radius=1 |
| 效果说明 | 每次击杀后，在被击杀者所在格周围施加 1 回合燃烧。 |
| 建议单位定位 | T4 地图 + 击倒混合 |
| 备注 | `EVENT_TARGET` 为被击倒敌人所在格 |

---

### 3.5 OnSummoned / OnFriendSummoned（4）

#### `summoned_gain_max_hp` — 壮硕入场（建议 Tier 2）

| 字段 | 值 |
|------|-----|
| display_name | 被召唤时 对自身 +2 生命上限 |
| trigger | `OnSummoned` |
| target_selector | `SELF` |
| exclude_owner | — |
| actions | `MODIFY_STAT` max_hp +2 |
| 效果说明 | 被召唤放置上场时，本单位本局生命上限 +2。 |
| 建议单位定位 | T2 token 或召唤物本体 |
| 备注 | 蝎子为 +4 攻；本提案偏坦 |

#### `summoned_heal_self_full` — 完美落地（建议 Tier 3）

| 字段 | 值 |
|------|-----|
| display_name | 被召唤时 恢复 3 生命 |
| trigger | `OnSummoned` |
| target_selector | `SELF` |
| exclude_owner | — |
| actions | `HEAL` +3 |
| 效果说明 | 被召唤上场时，恢复 3 点生命。 |
| 建议单位定位 | T3 大型召唤 token |
| 备注 | 若 max_hp 较低可改为 buff max_hp + heal 分步 |

#### `friend_summoned_heal_summoned` — 驯养恢复（建议 Tier 2）

| 字段 | 值 |
|------|-----|
| display_name | 友方召唤时 对被召唤单位 恢复 2 生命 |
| trigger | `OnFriendSummoned` |
| target_selector | `EVENT_TARGET` |
| exclude_owner | — |
| actions | `HEAL` +2 |
| 效果说明 | 友方召唤单位成功后，为被召唤者恢复 2 点生命。 |
| 建议单位定位 | T2 召唤流辅助 |
| 备注 | 火鸡为 +1/+1 buff；本提案纯治疗 |

#### `friend_summoned_perm_atk` — 烙印（建议 Tier 3）

| 字段 | 值 |
|------|-----|
| display_name | 友方召唤时 对被召唤单位 永久 +1 攻击 |
| trigger | `OnFriendSummoned` |
| target_selector | `EVENT_TARGET` |
| exclude_owner | — |
| actions | `PERMANENT_DECK_STAT` attack +1（写入被召唤单位对应 deck entry） |
| 效果说明 | 友方召唤成功后，为被召唤者牌库条目永久 +1 攻击。 |
| 建议单位定位 | T3 召唤流投资 |
| 备注 | 需 `EffectResolver` 将 permanent 落到 `payload.target` 的 deck entry |

---

### 3.6 OnMove（3）

#### `move_heal_self` — 步疗（建议 Tier 1）

| 字段 | 值 |
|------|-----|
| display_name | 移动时 恢复 1 生命 |
| trigger | `OnMove` |
| target_selector | `SELF` |
| exclude_owner | — |
| actions | `HEAL` +1 |
| 效果说明 | 每次移动完成后，恢复 1 点生命。 |
| 建议单位定位 | T1 灵活前排 |
| 备注 | **Legacy**：概念来自 `heal_on_move.tres` |

#### `move_buff_self_atk` — 冲锋势头（建议 Tier 2）

| 字段 | 值 |
|------|-----|
| display_name | 移动时 对自身 +1 攻击 |
| trigger | `OnMove` |
| target_selector | `SELF` |
| exclude_owner | — |
| actions | `MODIFY_STAT` attack +1 |
| 效果说明 | 每次移动完成后，本单位本局攻击力 +1。 |
| 建议单位定位 | T2 机动战士 |
| 备注 | 与战车「移动造成伤害」同触发不同效果 |

#### `move_apply_burn_random` — 焦土足迹（建议 Tier 3）

| 字段 | 值 |
|------|-----|
| display_name | 移动时 对 1 个随机格子施加燃烧（1 回合） |
| trigger | `OnMove` |
| target_selector | `RANDOM_CELLS`（target_count=1） |
| exclude_owner | — |
| actions | `APPLY_CELL_EFFECT` burn |
| 效果说明 | 每次移动完成后，在 1 个随机格施加 1 回合燃烧。 |
| 建议单位定位 | T3 地图流机动单位 |
| 备注 | 引擎若未来支持「移动目标格」可改为精确落点 |

---

### 3.7 OnAttackHit / OnFriendDeath / OnDamageTaken（5）

#### `attack_hit_buff_self_atk` — 迎击姿态（建议 Tier 2）

| 字段 | 值 |
|------|-----|
| display_name | 受击前 对自身 +2 攻击 |
| trigger | `OnAttackHit` |
| target_selector | `SELF` |
| exclude_owner | — |
| actions | `MODIFY_STAT` attack +2 |
| 效果说明 | 被敌方攻击命中结算前，本单位本局攻击力 +2。 |
| 建议单位定位 | T2 反击型 |
| 备注 | 刺客为换位；本提案为纯 buff |

#### `friend_death_heal_self` — 哀悼恢复（建议 Tier 3）

| 字段 | 值 |
|------|-----|
| display_name | 友方死亡时 恢复 2 生命 |
| trigger | `OnFriendDeath` |
| target_selector | `SELF` |
| exclude_owner | — |
| actions | `HEAL` +2 |
| 效果说明 | 其他友方单位死亡后，恢复 2 点生命。 |
| 建议单位定位 | T3 后排生存 |
| 备注 | 鲨鱼为 +2/+2 stat |

#### `friend_death_damage_random_enemy` — 复仇怒火（建议 Tier 3）

| 字段 | 值 |
|------|-----|
| display_name | 友方死亡时 对随机敌人造成 2 点伤害 |
| trigger | `OnFriendDeath` |
| target_selector | `RANDOM_ENEMY` |
| exclude_owner | — |
| actions | `DEAL_DAMAGE` 2 |
| 效果说明 | 友方死亡后，对一名随机敌人造成 2 点伤害。 |
| 建议单位定位 | T3 友亡反击 |
| 备注 | 苍蝇为召唤；本提案为直伤 |

#### `hurt_perm_max_hp` — 疤甲（建议 Tier 2）

| 字段 | 值 |
|------|-----|
| display_name | 受伤时 永久 +1 生命上限 |
| trigger | `OnDamageTaken` |
| target_selector | `SELF` |
| exclude_owner | — |
| actions | `PERMANENT_DECK_STAT` max_hp +1 |
| 效果说明 | 每次受伤后，本单位牌库条目永久 +1 生命上限。 |
| 建议单位定位 | T2 run 成长坦克 |
| 备注 | 熊为本局 +2 max_hp |

#### `hurt_friends_hurt_aoe_light` — 群伤感应（建议 Tier 3）

| 字段 | 值 |
|------|-----|
| display_name | 受伤时 若本回合友方受伤≥2 次，对全体敌人造成 1 点伤害 |
| trigger | `OnDamageTaken` |
| target_selector | `ALL_UNITS`（敌人侧） |
| exclude_owner | — |
| actions | `FRIENDS_HURT_AOE` value=1, threshold=2 |
| 效果说明 | 受伤时若本 combat tick 内友方已受伤 ≥2 次，对全体敌人造成 1 点伤害。 |
| 建议单位定位 | T3 团队受伤流 |
| 备注 | 狼獾 threshold=3、伤害 2；本提案更轻 |

---

### 3.8 OnCombatStart / OnDeath（2）

#### `combat_start_buff_all_atk_1` — 集结号（建议 Tier 3）

| 字段 | 值 |
|------|-----|
| display_name | 开战时 对全体队友 +1 攻击 |
| trigger | `OnCombatStart` |
| target_selector | `ALL_ALLIES` |
| exclude_owner | false |
| actions | `MODIFY_STAT` attack +1 |
| 效果说明 | 战斗开始时，全体队友本局攻击力 +1。 |
| 建议单位定位 | T3 团队 buff 核心 |
| 备注 | 犰狳为 +8 max_hp 全场；本提案偏攻 |

#### `faint_swap_with_healthiest` — 临终让位（建议 Tier 3）

| 字段 | 值 |
|------|-----|
| display_name | 死亡时 与当前血量最高的其他队友换位 |
| trigger | `OnDeath` |
| target_selector | `HEALTHIEST_ALLY` |
| exclude_owner | true |
| actions | `SWAP_POSITIONS` |
| 效果说明 | 本单位死亡时，与除自身外生命上限最高的队友交换棋盘格位置。 |
| 建议单位定位 | T3 战术牺牲位 |
| 备注 | 刺客为受击前换位；本提案为死亡时 |

---

## 4. 商店阶段技能提案（6）

#### `buy_buff_random_ally_atk` — 采购强化（建议 Tier 1）

| 字段 | 值 |
|------|-----|
| display_name | 购买时 对随机队友 +1 攻击 |
| trigger | `OnBuy` |
| target_selector | `RANDOM_DECK_ALLY` |
| exclude_owner | true |
| actions | `PERMANENT_DECK_STAT` attack +1 |
| 效果说明 | 从商店购入本单位后，随机一名牌库队友永久 +1 攻击。 |
| 建议单位定位 | T1 商店协同 |
| 备注 | 水獭为 +1 max_hp |

#### `buy_perm_crit_random_ally` — 校准镜片（建议 Tier 2）

| 字段 | 值 |
|------|-----|
| display_name | 购买时 对随机队友 永久 +3% 暴击 |
| trigger | `OnBuy` |
| target_selector | `RANDOM_DECK_ALLY` |
| exclude_owner | true |
| actions | `PERMANENT_DECK_STAT` crit_rate_percent +3 |
| 效果说明 | 购入后，随机一名牌库队友永久 +3% 暴击率。 |
| 建议单位定位 | T2 暴击构筑辅助 |
| 备注 | `ShopEffectResolver` 已支持 crit 永久写入 |

#### `sell_buff_random_ally_crit` — 遗产瞄准（建议 Tier 2）

| 字段 | 值 |
|------|-----|
| display_name | 出售时 对随机队友 永久 +5% 暴击 |
| trigger | `OnSell` |
| target_selector | `RANDOM_DECK_ALLY` |
| exclude_owner | true |
| actions | `PERMANENT_DECK_STAT` crit_rate_percent +5 |
| 效果说明 | 出售本单位前，随机一名牌库队友永久 +5% 暴击率。 |
| 建议单位定位 | T2 出售流 |
| 备注 | 河狸为 +1 攻 ×2 目标 |

#### `sell_heal_shop_characters` — 货架保养（建议 Tier 1）

| 字段 | 值 |
|------|-----|
| display_name | 出售时 商店角色 +2 生命上限 |
| trigger | `OnSell` |
| target_selector | `ALL_SHOP_CHARACTERS` |
| exclude_owner | — |
| actions | `SHOP_CHARACTER_BONUS_HP` +2 |
| 效果说明 | 出售时，当前商店全部角色 offer 永久 +2 生命上限。 |
| 建议单位定位 | T1 商店滚雪球 |
| 备注 | 鸭子为 +1；本提案数值更高 |

#### `levelup_buff_self_crit` — 熟练瞄准（建议 Tier 2）

| 字段 | 值 |
|------|-----|
| display_name | 升级时 永久 +2% 暴击 |
| trigger | `OnLevelUp` |
| target_selector | `SELF`（触发者 deck entry） |
| exclude_owner | — |
| actions | `PERMANENT_DECK_STAT` crit_rate_percent +2 |
| 效果说明 | 牌库合成升级后，该 deck 条目永久 +2% 暴击率。 |
| 建议单位定位 | T2 合成升级奖励 |
| 备注 | 鱼为双目标 +1/+1 |

#### `levelup_stock_free_apple` — 庆功宴（建议 Tier 1）

| 字段 | 值 |
|------|-----|
| display_name | 升级时 补充免费苹果（攻击）增益 |
| trigger | `OnLevelUp` |
| target_selector | — |
| exclude_owner | — |
| actions | `STOCK_FREE_BUFF` buff_perm_atk |
| 效果说明 | 升级后，向空 buff 槽补充 1 个免费苹果（攻击）增益 offer。 |
| 建议单位定位 | T1 经济 / 增益流 |
| 备注 | 鸽子为出售补面包屑 |

---

## 5. 双 Spec / 多段提案（3）

#### `dual_hurt_rage` — 狂怒伤疤（建议 Tier 2）

| Spec | trigger | target | actions |
|------|---------|--------|---------|
| 1 | `OnDamageTaken` | `SELF` | `MODIFY_STAT` attack +2（本局） |
| 2 | `OnDamageTaken` | `SELF` | `PERMANENT_DECK_STAT` attack +1 |

| 字段 | 值 |
|------|-----|
| display_name | 受伤时 对自身 +2 攻击；永久 +1 攻击 |
| 效果说明 | 每次受伤：本局 +2 攻击；永久 +1 攻击（两段 spec）。 |
| 建议单位定位 | T2 受伤成长 |
| 备注 | **Legacy** + 枪手式双 spec；孔雀仅本局 +4 |

#### `dual_crit_lifesteal` — 暴击吸血（建议 Tier 3）

| Spec | trigger | target | actions |
|------|---------|--------|---------|
| 1 | `OnCrit` | `SELF` | `MODIFY_STAT` crit_rate_percent +5 |
| 2 | `OnCrit` | `SELF` | `HEAL` +1 |

| 字段 | 值 |
|------|-----|
| display_name | 造成暴击时 +5% 暴击；恢复 1 生命 |
| 效果说明 | 每次暴击：本局 +5% 暴击；恢复 1 生命（两段 spec）。 |
| 建议单位定位 | T3 暴击续航 |
| 备注 | 同 tick 两 action，表现层顺序播放 |

#### `dual_death_summon_burn` — 焚化献祭（建议 Tier 4）

| Spec | trigger | target | actions |
|------|---------|--------|---------|
| 1 | `OnDeath` | `SELF` 格 | `SPAWN_UNIT` 小型 token |
| 2 | `OnDeath` | `CELLS_AROUND_EVENT` | `APPLY_CELL_EFFECT` burn |

| 字段 | 值 |
|------|-----|
| display_name | 死亡时 生成余烬虫（1/1）；对周围格施加燃烧 |
| 效果说明 | 死亡时：召唤 token；对周围格施加燃烧（两段 spec）。 |
| 建议单位定位 | T4 召唤 + 地图 |
| 备注 | 需新建 token `UnitData`；燃烧与余烬鼠类似 |

---

## 6. 维护约定

1. 新技能策划**先入本文档**，评审通过后再建 `resources/abilities/<id>.tres` 并挂载单位。
2. 实现后：更新 [ABILITIES.md §1.2](./ABILITIES.md#12-单位内建技能目录)、必要时同步 [Content/UNITS_ROSTER.md](./Content/UNITS_ROSTER.md)，并在本文对应条目标注 **已实现** 或删除。
3. 若提案需新触发器 / 目标 / 效果，先扩展引擎并更新 ABILITIES §3–§5，**不得**仅在本文档假设已支持。
4. SAP 灵感对照见 [Reference/SUPER_AUTO_PETS.md](./Reference/SUPER_AUTO_PETS.md)，数值以本项目为准。
