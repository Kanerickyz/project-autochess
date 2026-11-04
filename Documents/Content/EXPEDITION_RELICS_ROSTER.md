# 远征圣物库（EXPEDITION_RELICS_ROSTER）

> Content · **【草案】非定稿** · 数值：**【数值草案 · 未实测】** · 2026-11-04  
> 功能共识见 [DesignNotes/EXPEDITION_RELICS_CONSENSUS.md](../DesignNotes/EXPEDITION_RELICS_CONSENSUS.md)（正式 Feature 待授权）。  
> **本篇写**：圣物内容池——分 Tier、名称、效果与**可读点数**、乘轴、硬顶、出售退金与事件偏抽权重草案。  
> **本篇不写**：完整 Feature 规则正文；事件文案库；`.tres` 实装（L2）。  
> 构筑审查：圣物优先作 **B（乘数）**；主题层仅弱放大且**不改主题人数**。

## 1. 分档与校准锚

| Tier | 身份 |
|------|------|
| **1** | 早期可安心带的弱 B / 薄规则；门槛低、破绽小；单独不够赢 |
| **2** | 中段成型件；要空间 / 时序 / 状态之一或带可读代价 |
| **3** | 稀有强规则；高机会成本或反差弱点；必须有硬顶 / 代价 |

**As-Is 校准锚**（数值相对这些刻度，非批跑结论）：

| 锚 | 值 |
|----|-----|
| 层结算金 | 第 n 层胜利 = **n+3**（第 1 层 4 金）；**本版胜场金 = 层金，同一笔** |
| 地图商店刷新 | 默认 **2** 金 |
| 大药 / 护甲 | 售价约 2；护甲抵挡 2/6/10 |
| 主题羁绊成形占位 | 开战全队临时攻击 **+1**（门槛 3） |
| 技能常见触发 | 受伤/击杀类 **+1** 攻或点伤 **1～2** |

**定稿择一（数值草案已选定）**

1. **旗缘余晖** → 本场临时**生命上限 +1**（不选攻，避免与羁绊 +1 攻同轴）。  
2. **八徽残印** → 每成形主题全体临时攻 **+1**，本圣物硬顶 **+2**。

---

## 2. Tier 1

| 显示名 | 暂定 id | 玩家可读效果（含点数） | 结构化字段 | 主乘轴 / 风险 | 综合 |
|--------|---------|------------------------|------------|---------------|------|
| 商路符牒 | `relic_merchant_writ` | 战斗胜利发层金时，额外 **+1** 金 | `bonus_floor_gold: 1` | 层金 × 微增；约 8～10 胜 ≈ +8～10 金 | 偏弱 |
| 摊贩折角 | `relic_bazaar_clip` | 地图商店刷新费 **−1**（不低于 **1**） | `map_shop_refresh_cost_delta: -1` · `min_refresh_cost: 1` | 刷店 × 降费；不进店空转 | 偏弱 |
| 鼓点耳饰 | `relic_drum_earring` | 友方**受伤触发类技能**结算后，该单位本场临时攻再 **+1**；每单位每回合因此最多再得 **2** 点 | `bonus_temp_attack: 1` · `cap_per_unit_per_round: 2` · `hook: after_hurt_ability_resolve` | 挨打链 × 伤后加攻；无挨打轴空转 | 偏弱～中庸 |
| 邻旗丝绦 | `relic_neighbor_pennant` | 友方技能给「邻格/周围友方」增益时，对每个受益目标再追加**同属性 +1**（加攻再 +1 攻；加生命上限再 +1 上限；两者都有则各 +1） | `neighbor_buff_extra_attack: 1` · `neighbor_buff_extra_max_hp: 1` · `match_granted_stats: true` | 邻格技能 × 微翻倍；散站低收益 | 偏弱～中庸 |
| 薄甲祷文 | `relic_thin_mail_prayer` | 开战全体友方本场临时生命上限 **+1** | `combat_start_temp_max_hp: 1` · `target: all_allies` | 弱开场垫；远弱于大生命药 | 偏弱 |
| 盾回残响 | `relic_shield_echo` | 友方受伤且未阵亡时，对攻击者 **1** 点反伤；每友方每回合最多 **1** 次 | `reflect_damage: 1` · `cap_per_ally_per_round: 1` · `require_survived_hit: true` | 承伤 × 反制；护甲挡伤可能不触发 | 偏弱 |
| 佣兵账签 | `relic_mercenary_chit` | 招募出售队伍成员时，原退金外额外 **+1** 金 | `sell_unit_bonus_gold: 1` | 卖人 × 薄利；不卖人则废 | 偏弱 |

---

## 3. Tier 2

| 显示名 | 暂定 id | 玩家可读效果（含点数） | 结构化字段 | 主乘轴 / 风险 | 综合 |
|--------|---------|------------------------|------------|---------------|------|
| 税吏铜衡 | `relic_tax_scale` | 每场战斗胜利层金额外 **+2**；地图商店消耗品与装备标价 **+1** | `bonus_floor_gold: 2` · `map_shop_price_delta: 1` | 胜场金 ↔ 店价；狂买装被吃回 | 中庸 |
| 猎号残片 | `relic_hunt_horn_shard` | 友方击杀时，随机**另一名**友方本场临时攻 **+1**；每场最多 **3** 次 | `kill_spread_temp_attack: 1` · `cap_per_combat: 3` · `exclude_killer: true` | 击杀 × 扩散；斩首/低击杀饿死 | 中庸 |
| 葬铃细链 | `relic_burial_bell` | 友方死亡时，周围一格存活友方本场临时攻 **+1** | `death_nearby_temp_attack: 1` · `radius: 1` | 退场 × 邻格；要扎堆 | 中庸 |
| 矛壁阵图 | `relic_spearwall_chart` | 开战落在**更近敌半场两行**的友方，本场临时攻 **+2** | `front_two_rows_temp_attack: 2` | 前压迫 × 输出；怕集火 | 中庸 |
| 苦修血印 | `relic_ascetic_seal` | 友方本场**首次**生命 ≤ 半血时，本场临时攻 **+2**（每单位每场一次） | `half_hp_temp_attack: 2` · `hp_threshold_ratio: 0.5` · `once_per_unit_per_combat: true` | 残血 × 怒攻；被秒杀不兑现 | 中庸 |
| 铁扉反栓 | `relic_iron_door_latch` | 友方受到会触发「受伤时」的伤害后，本回合内其对该攻击者下一次伤害 **+1** | `revenge_next_hit_damage_bonus: 1` · `window: this_turn` · `vs: that_attacker` | 受伤 × 反打；承伤位死则断 | 中庸 |
| 旗缘余晖 | `relic_banner_afterglow` | 若本场**至少一主题已成形**，开战全体本场临时生命上限 **+1**（不改主题人数） | `requires_any_theme_formed: true` · `combat_start_temp_max_hp: 1` · `theme_count_delta: 0` | 成形开关 × 弱垫血；未成形空转 | 中庸 |
| 赊账羊皮 | `relic_credit_vellum` | 事件付费/失金选项：金代价 **−3**（最低 0）；整局第一次真正减免后**碎裂离囊**（无退金） | `event_gold_cost_reduction: 3` · `min_cost_after: 0` · `shatter_after_first_real_save: true` · `shatter_refund_gold: 0` | 一次性代价转化；无代价事件占槽 | 中庸～偏强 |

---

## 4. Tier 3

| 显示名 | 暂定 id | 玩家可读效果（含点数） | 结构化字段 | 主乘轴 / 风险 | 综合 |
|--------|---------|------------------------|------------|---------------|------|
| 龙税敕令 | `relic_dragon_tax_edict` | 层结算金额外 **+3**（本版胜场金=层金，**只加一次**）；开战全体本场临时生命上限 **−2**（上限最低仍保留 **1**） | `bonus_floor_gold: 3` · `combat_start_temp_max_hp: -2` · `min_max_hp_after: 1` | 经济滚雪球 × 血换金；约 10 胜多 ~30 金 | 偏强 |
| 血宴权杖 | `relic_bloodfeast_rod` | 友方击杀时，对另一名随机敌人造成 **2** 点额外伤害；每友方每回合至多 **1** 次；整场总次数顶 **6** | `kill_cleave_damage: 2` · `cap_per_ally_per_round: 1` · `cap_per_combat: 6` · `exclude_killed_target: true` | 击杀 × 溅射；双顶切断连锁 | 偏强 |
| 绝阵羊皮卷 | `relic_laststand_scroll` | 一名友方阵亡时，其余存活友方本场临时攻 **+3**；整场最多触发 **2** 次 | `death_team_temp_attack: 3` · `cap_triggers_per_combat: 2` | 减员 × 绝地；无人死慢热 | 偏强 |
| 夹道刺篱 | `relic_hedge_of_pikes` | 开战座位**正交相邻**的两名友方，对邻格敌人伤害 **+2**（只认开战落点） | `ortho_pair_adjacent_enemy_damage_bonus: 2` · `qualify_at: combat_start_seats_only` | 邻接 × 夹击；怕 AOE | 偏强 |
| 殉道荆冠 | `relic_martyr_thorns` | 友方死亡时：对击杀者 **2** 点伤害；周围一格敌人获反伤层 **1**（其造成伤害时自身受 1；单敌反伤层软顶 **2**）；整场死亡触发顶 **4** | `death_damage_to_killer: 2` · `nearby_enemy_thorns: 1` · `thorns_stack_soft_cap_per_enemy: 2` · `cap_death_triggers_per_combat: 4` · `radius: 1` | 死亡 × 反制；少死人浪费 | 偏强 |
| 八徽残印 | `relic_eight_sigil_shard` | 每个**已成形**主题 → 全体本场临时攻 **+1**；本圣物该加成硬顶 **+2**（不改主题人数） | `per_formed_theme_temp_attack: 1` · `relic_attack_bonus_cap: 2` · `theme_count_delta: 0` | 多主题 × 弱层；单主题仅 +1 | 中庸～偏强 |
| 空棺契约 | `relic_empty_coffin_pact` | 备战每 **1** 人 → 上场全体本场临时攻 **+1**；该加成硬顶 **+3**；备战空则无效 | `temp_attack_per_bench_unit: 1` · `relic_attack_bonus_cap: 3` · `bench_empty_disables: true` | 囤板凳 × 供能；与满编反差 | 偏强 |

---

## 5. 行囊出售退金（招募卖圣物）

| Tier | 退金 | 理由（启发式） |
|------|------|----------------|
| T1 | **2** | ≈ 1 次地图刷店 |
| T2 | **4** | ≈ 2 次刷店 / 约 2 瓶大药价位 |
| T3 | **6** | 可卖但远低于龙税滚雪球期望 |

事件**换下**（满囊挤掉 / 自愿换下）仍为 **0 金**。赊账羊皮碎裂 **0 金**。

---

## 6. 事件池偏抽权重（启发式）

先抽 Tier，再在该 Tier 池内均匀抽；三选一三格独立抽（同 id 去重重抽）。按 Act1 `floor_count ≈ 15`：

| 层段 | T1 | T2 | T3 |
|------|----|----|----|
| 1–4 | **70%** | **25%** | **5%** |
| 5–9 | **35%** | **50%** | **15%** |
| 10–15 | **15%** | **45%** | **40%** |

---

## 7. 硬顶速查

| 圣物 | 顶 |
|------|-----|
| 鼓点耳饰 | 每单位每回合 +攻 ≤2 |
| 盾回残响 | 每友方每回合反伤 ≤1 |
| 猎号残片 | 每场扩散 ≤3 |
| 苦修血印 | 每单位每场 1 次 |
| 血宴权杖 | 每友方每回合 1 + 整场 6 |
| 绝阵羊皮卷 | 整场触发 ≤2 |
| 殉道荆冠 | 整场死亡触发 ≤4；单敌反伤层软顶 2 |
| 八徽残印 | 本圣物攻加成硬顶 2 |
| 空棺契约 | 本圣物攻加成硬顶 3 |
| 龙税生命罚 | 上限最低保留 1 |

---

## 8. 覆盖自检

| 类型 | 条目 |
|------|------|
| 经济 | 商路符牒、摊贩折角、佣兵账签、税吏铜衡、赊账羊皮、龙税敕令 |
| 触发链 | 鼓点耳饰、猎号残片、葬铃细链、血宴权杖、绝阵羊皮卷 |
| 站位 / 邻格 | 邻旗丝绦、矛壁阵图、夹道刺篱 |
| 弱全体 | 薄甲祷文、旗缘余晖 |
| 反制 | 盾回残响、铁扉反栓、殉道荆冠 |
| 主题弱放大 | 旗缘余晖、八徽残印（均不改计数） |
| 带代价 | 税吏铜衡、赊账羊皮、龙税敕令、空棺契约、苦修血印 |

**刻意不做**：无门槛全体永久 +攻；「视同主题 +N 人」；战中主动点按。

---

## 9. 修订记录

| 日期 | 说明 |
|------|------|
| 2026-11-04 | 初稿草案：T1×7 / T2×8 / T3×7；对齐行囊共识。 |
| 2026-11-04 | 【数值草案 · 未实测】填点；旗缘选生命、八徽选攻+硬顶 2；龙税层金只加一次；退金与事件权重草案。 |
