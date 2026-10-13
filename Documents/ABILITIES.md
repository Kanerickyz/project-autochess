# 技能目录与设计指导

> **技能** = 单位**内建**联动能力（`UnitData.ability` / `passives`）。**增益卡**见 [BUFF_SYSTEM.md](./BUFF_SYSTEM.md)，不再从商店购买技能卡。  
> 技术管线见 [ARCHITECTURE.md](./ARCHITECTURE.md) §3.7 · 商店/牌库见愿景与架构摘要。

相关文档：[INDEX.md](./INDEX.md) · [Features/UNITS.md](./Features/UNITS.md)（角色单位：技能与攻击方式是两套系统） · [ABILITY_PROPOSALS.md](./ABILITY_PROPOSALS.md)（未实现提案） · [Reference/SUPER_AUTO_PETS.md](./Reference/SUPER_AUTO_PETS.md)（外部参考，非实现规格）

> **已实现（2026-05）**：商店 roll `buff_pool`；战斗技能仅内建 `ability` / `passives`。原商店技能表见 §1.3（已废弃）。

---

## 1. 单位技能（必填）

### 1.1 约定

- 每只 `UnitData` **必须**配置 `ability`（主联动技能）
- `AbilityData.display_name` 使用**效果描述**（与 UI `UnitInfoText.get_ability_description` 一致），勿再用简短绰号
- `passives` 可选，用于额外被动
- **无**战斗联动设计的单位：使用占位被动（如空触发或纯描述性 `OnCombatStart` 无效果），避免 `ability == null` 导致 UI/解析分支
- `AbilityData.skip_attack_after_move`：为 `true` 时，单位本回合**执行移动后**跳过跟进普攻（仍可在未移动且已在攻击范围内时正常攻击）
- `AbilityData.can_normal_attack`：为 `false` 时，单位**无法进行普通攻击**（仅依赖技能造成伤害等；战车、皇后为 `false`）
- `AbilityData.uses_line_attack`：为 `true` 时，单位在攻击阶段以**直线扫射**替代普攻：从当前位置选行/列/两对角之一，对该直线上的每个敌人造成伤害；AI 选命中敌人数最多的轴（并列时行 → 列 → 主对角 → 副对角）。触发 `CombatEvents.ON_LINE_ATTACK`，伤害走 `DamagePipeline.apply_line_attack`（非 EffectResolver）
- `AbilityData.line_attack_uses_attack`：为 `true`（默认）时，直线扫射伤害取单位**当前攻击力**（`get_effective_attack()`，含 buff）；为 `false` 时使用固定 `line_attack_damage`
- `UnitStats.crit_rate_percent`：默认 **5%**；`UnitInstance.get_effective_crit_rate()` = 基础 + 战斗 `StatModifierStack` 中 `crit_rate_percent` 加成（clamp 0–100%）
- `UnitStats.attack_range`：普攻 Chebyshev 距离上限（默认 1）；例：枪手 `attack_range = 4`、初始 `crit_rate_percent = 10`

### 1.2 单位内建技能目录

| 单位 | id | 描述（`display_name`） | 资源 |
|------|-----|------------------------|------|
| 蚂蚁 | `faint_buff_random_ally` | 死亡时 对随机其他队友 +1 攻击, +1 生命上限, 恢复 1 生命 | `resources/abilities/faint_buff_random_ally.tres` |
| 蟋蟀 | `faint_summon_cricket` | 死亡时 生成 僵尸蟋蟀（1/1） | `resources/abilities/faint_summon_cricket.tres` |
| 马 | `friend_summoned_buff_atk` | 友方召唤时 对被召唤单位 +1 攻击 | `resources/abilities/friend_summoned_buff_atk.tres` |
| 蚊子 | `combat_start_damage_random_enemy` | 开战时 对随机敌人造成 1 点伤害 | `resources/abilities/combat_start_damage_random_enemy.tres` |
| 猪 | `sell_grant_gold` | 出售时 获得 +1 金 | `resources/abilities/sell_grant_gold.tres` |
| 水獭 | `buy_buff_random_ally_hp` | 购买时 对随机队友 +1 生命上限 | `resources/abilities/buy_buff_random_ally_hp.tres` |
| 鸭子 | `sell_buff_shop_hp` | 出售时 商店角色 +1 生命上限 | `resources/abilities/sell_buff_shop_hp.tres` |
| 河狸 | `sell_buff_two_allies_atk` | 出售时 对两名随机队友 +1 攻击 | `resources/abilities/sell_buff_two_allies_atk.tres` |
| 鱼 | `levelup_buff_two_allies` | 升级时 对两名队友 +1 攻击与 +1 生命上限 | `resources/abilities/levelup_buff_two_allies.tres` |
| 鸽子 | `sell_stock_breadcrumbs` | 出售时 补充免费面包屑 | `resources/abilities/sell_stock_breadcrumbs.tres` |
| 孔雀 | `hurt_gain_attack_peacock` | 受伤时 对自身 +4 攻击 | `resources/abilities/hurt_gain_attack_peacock.tres` |
| 象 | `hurt_gain_attack_elephant` | 受伤时 对自身 +1 攻击 | `resources/abilities/hurt_gain_attack_elephant.tres` |
| 蜘蛛 | `faint_summon_hatchling` | 死亡时 生成 幼蛛（2/2） | `resources/abilities/faint_summon_hatchling.tres` |
| 火烈鸟 | `faint_buff_ally_stats` | 死亡时 对随机其他队友 +1 攻击, +1 生命上限 | `resources/abilities/faint_buff_ally_stats.tres` |
| 刺猬 | `faint_aoe_damage` | 死亡时 对全场造成 2 点伤害 | `resources/abilities/faint_aoe_damage.tres` |
| 枪手 | `gunner_dual_crit` | 受伤时 永久 +5% 暴击；造成暴击时 +10% 暴击 | `resources/abilities/gunner_dual_crit.tres` |
| 螃蟹 | `combat_start_copy_hp` | 开战时 复制最健康队友 50% 生命 | `resources/abilities/combat_start_copy_hp.tres` |
| 战车 | `move_damage_enemy_ahead` | 移动时 对移动方向前 1 格的敌人造成等同于当前攻击力的伤害 | `resources/abilities/move_damage_enemy_ahead.tres` |
| 刺客 | `attack_hit_swap_highest_hp_ally` | 受击前 与当前血量最高的其他队友换位 | `resources/abilities/attack_hit_swap_highest_hp_ally.tres` |
| 皇后 | `line_attack_damage_2` | 攻击时 对所选直线上的每个敌人造成等同于当前攻击力的伤害 | `resources/abilities/line_attack_damage_2.tres` |
| 河豚 | `hurt_damage_random_enemy` | 受伤时 对随机敌人造成 3 点伤害 | `resources/abilities/hurt_damage_random_enemy.tres` |
| 绵羊 | `faint_summon_ram` | 死亡时 生成 公羊（2/2） | `resources/abilities/faint_summon_ram.tres` |
| 鹿 | `faint_summon_bus` | 死亡时 生成 巴士（5/3） | `resources/abilities/faint_summon_bus.tres` |
| 獾 | `faint_aoe_attack_percent` | 死亡时 对全场造成 50% 攻击力伤害（简化：非相邻） | `resources/abilities/faint_aoe_attack_percent.tres` |
| 河马 | `knockout_gain_stats` | 击倒时 对自身 +3 攻击, +3 生命上限 | `resources/abilities/knockout_gain_stats.tres` |
| 犰狳 | `combat_start_buff_all_max_hp` | 开战时 对全场 +8 生命上限 | `resources/abilities/combat_start_buff_all_max_hp.tres` |
| 火鸡 | `friend_summoned_buff_atk_hp` | 友方召唤时 对被召唤单位 +1 攻击, +1 生命上限 | `resources/abilities/friend_summoned_buff_atk_hp.tres` |
| 公鸡 | `faint_summon_chick` | 死亡时 生成 小鸡（3/1） | `resources/abilities/faint_summon_chick.tres` |
| 犀牛 | `knockout_damage_first_enemy` | 击倒时 对前排敌人造成 4 点伤害 | `resources/abilities/knockout_damage_first_enemy.tres` |
| 鳄鱼 | `combat_start_damage_last_enemy` | 开战时 对后排敌人造成 8 点伤害 | `resources/abilities/combat_start_damage_last_enemy.tres` |
| 野猪 | `combat_start_buff_self_atk_hp` | 开战时 对自身 +4 攻击, +2 生命上限（简化：非攻击前） | `resources/abilities/combat_start_buff_self_atk_hp.tres` |
| 鲨鱼 | `friend_death_gain_stats` | 友方死亡时 对自身 +2 攻击, +2 生命上限 | `resources/abilities/friend_death_gain_stats.tres` |
| 狼 | `combat_start_buff_self_atk` | 开战时 对自身 +2 攻击 | `resources/abilities/combat_start_buff_self_atk.tres` |
| 熊 | `hurt_gain_max_hp` | 受伤时 对自身 +2 生命上限 | `resources/abilities/hurt_gain_max_hp.tres` |
| 豹 | `combat_start_attack_random_enemy` | 开战时 对随机敌人造成 50% 攻击力伤害 | `resources/abilities/combat_start_attack_random_enemy.tres` |
| 大猩猩 | `hurt_gain_max_hp_3` | 受伤时 对自身 +3 生命上限（简化：非 Coconut） | `resources/abilities/hurt_gain_max_hp_3.tres` |
| 苍蝇 | `friend_death_summon_zombie_fly` | 友方死亡时 在其位置生成 僵尸蝇（4/4） | `resources/abilities/friend_death_summon_zombie_fly.tres` |
| 猛犸 | `faint_buff_all_allies` | 死亡时 对全体队友 +2 攻击, +2 生命上限, 恢复 2 生命 | `resources/abilities/faint_buff_all_allies.tres` |
| 驯兽师 | `friend_summoned_buff_atk_2` | 友方召唤时 对被召唤单位 +2 攻击 | `resources/abilities/friend_summoned_buff_atk_2.tres` |
| 母羊 | `faint_summon_ram_x2` | 死亡时 生成 2×公羊（2/2） | `resources/abilities/faint_summon_ram_x2.tres` |
| 蝎子 | `summoned_gain_attack` | 被召唤时 对自身 +4 攻击 | `resources/abilities/summoned_gain_attack.tres` |
| 骆驼 | `hurt_buff_ally_behind` | 受伤时 对身后最近队友 +1 攻击, +2 生命上限 | `resources/abilities/hurt_buff_ally_behind.tres` |
| 刺豚 | `hurt_damage_random_enemy_2` | 受伤时 对随机敌人 2 点伤害 | `resources/abilities/hurt_damage_random_enemy_2.tres` |
| 狼獾 | `friends_hurt_aoe` | 受伤时 若本回合友方受伤≥3 次，对全体敌人 2 点伤害 | `resources/abilities/friends_hurt_aoe.tres` |
| 余烬鼠 | `faint_apply_burn_around` | 死亡时 对周围格子施加燃烧（1 回合） | `resources/abilities/faint_apply_burn_around.tres` |
| 灰烬萨满 | `combat_start_random_burn` | 开战时 对 2 个随机格子施加燃烧 | `resources/abilities/combat_start_random_burn.tres` |
| 火塘守卫 | `faint_apply_burn_area` | 死亡时 对自身格与周围格施加燃烧 | `resources/abilities/faint_apply_burn_area.tres` |
| 史莱姆 | `combat_start_split_self` | 开战时 按当前生命分裂为等量分身（继承攻击，1 血） | `resources/abilities/combat_start_split_self.tres` |

### 1.3 已废弃：商店技能卡

以下能力原作为**商店技能卡**（`skill_pool`）出售；`.tres` 资源保留作样本，**引擎可执行但未挂载任何单位**：

| id | 描述（`display_name`） | 状态 |
|----|------------------------|------|
| `rage_on_hit` | 受伤时 对自身 +2 攻击 | 已废弃，未挂载 |
| `spawn_on_death` | 死亡时 生成 僵尸蟋蟀（1/1） | 已废弃，未挂载（蟋蟀内建等价） |
| `heal_on_move` | 移动时 对自身 恢复 1 生命 | 已废弃，未挂载 |
| `round_start_hurt_ally` | 回合开始时 对随机其他队友 造成 1 点伤害 | 已废弃，未挂载 |

详见 [BUFF_SYSTEM.md](./BUFF_SYSTEM.md) §4（首批增益为属性/规则类，非上述战斗联动克隆）。

---

## 2. 数据模型速查

一条联动技能 = **`AbilityData`** → 若干 **`EffectSpec`** → 若干 **`EffectAction`**。

```
AbilityData
├── id / display_name
└── effect_specs[] → EffectSpec
    ├── trigger          # 战斗事件
    ├── target_selector  # 目标选择
    ├── exclude_owner    # RANDOM_ALLY 时是否排除持有者
    └── actions[]        # 效果队列（每个 action 占 1 个战斗 interval）
```

战斗内合并来源：**仅** `unit.ability` + `passives[]`（`UnitInstance.get_all_effect_specs()`）。**不再**合并 `attached_skills`；牌库增益走 [BUFF_SYSTEM.md](./BUFF_SYSTEM.md) 的 `bonus_*` / 规则 flag / 专用战斗钩子。

技能数值按持有者 **Lv1–3** 线性缩放（见 §6 模板「边界条件」）。

---

## 3. 可用触发器（v1）

| 常量 | 中文 | 持有者条件 | 说明 |
|------|------|------------|------|
| `OnCombatStart` | 开战时 | 任意拥有该 spec 的单位 | 战斗开始 emit 一次 |
| `OnFriendSummoned` | 友方召唤时 | 同队且 `payload.target != owner` | `SPAWN_UNIT` 成功后；`payload.target` 为被召唤单位 |
| `OnSummoned` | 被召唤时 | `payload.target == owner` | 单位被 `SPAWN_UNIT` 放置后 emit 一次 |
| `OnFriendDeath` | 友方死亡时 | 同队且 `payload.target != owner` | 单位死亡后；`payload.target` 为死亡单位 |
| `OnRoundStart` | 回合开始时 | 任意拥有该 spec 的单位 | 每个战斗 tick 开始时 |
| `OnDamageTaken` | 受伤时 | `payload.target == owner` | 伤害结算后 |
| `OnDeath` | 死亡时 | `payload.target == owner` | 单位死亡时；增益 `buff_death_gold` 亦用此事件 |
| `OnMove` | 移动时 | `payload.source == owner` | 移动成功后 |
| `OnBuy` | 购买时 | 商店阶段 | 从商店购入该单位后（`ShopEffectResolver`） |
| `OnSell` | 出售时 | 商店阶段 | 从牌库出售该单位前 |
| `OnLevelUp` | 升级时 | 商店阶段 | 牌库合成升级后 |
| `OnDealDamage` | 造成伤害时 | `payload.source == owner` | 已注册，少用 |
| `OnCrit` | 造成暴击时 | `payload.source == owner` | `DamagePipeline` 暴击结算后 emit |
| `OnKill` | 击杀时 | `payload.source == owner` | 已注册，少用 |
| `OnAttackHit` | 受击前 | 攻击命中结算前 | 刺客换位等；UI 文案以 `display_name` 为准 |
| `OnLineAttack` | 直线攻击时 | `payload.source == owner` | 皇后等 `uses_line_attack` 扫射；伤害走 `DamagePipeline`，非 EffectResolver 主路径 |

**未实现（远期）**：EndTurn、StartOfTurn 商店阶段等。

**商店阶段**（`OnBuy` / `OnSell` / `OnLevelUp`）由 [`ShopEffectResolver`](../scripts/core/shop_effect_resolver.gd) 处理，不走战斗 `CombatEventBus`。

---

## 4. 可用目标选择（v1）

| 枚举 | 中文 | 说明 |
|------|------|------|
| `SELF` | 自身 | 效果作用于技能持有者 |
| `EVENT_TARGET` | 事件目标 | 如受伤/死亡对象 |
| `RANDOM_ALLY` | 随机队友 | 同队存活单位；`exclude_owner=true` 时排除持有者；无候选则不触发 |
| `ALL_UNITS` | 全场 | 所有存活单位（友方 + 敌方） |
| `RANDOM_ENEMY` | 随机敌人 | 敌方存活单位 |
| `FIRST_ENEMY` | 前排敌人 | 敌方存活单位，按 `grid_pos.x` 升序（同 x 比 y） |
| `LAST_ENEMY` | 后排敌人 | 敌方存活单位，按 `grid_pos.x` 降序（同 x 比 y） |
| `HEALTHIEST_ALLY` | 最健康队友 | 同队 `max_hp` 最高者，排除持有者 |
| `ALL_ALLIES` | 全体队友 | 同队存活单位；`exclude_owner` 可排除持有者 |
| `RANDOM_DECK_ALLY` | 随机牌库队友 | 商店阶段；`target_count` 可 >1；`exclude_owner` 排除触发者条目 |
| `ALL_SHOP_CHARACTERS` | 商店角色 | 当前商店角色槽内 offer |
| `NEAREST_ALLY_BEHIND` | 身后最近队友 | 同队；按棋盘坐标选持有者「身后」最近 1 只 |
| `CELLS_AROUND_EVENT` | 事件格周围 | 以 `payload.target` 所在格为中心，`radius` 切比雪夫距离 |
| `RANDOM_CELLS` | 随机格子 | 棋盘内非 blocked 格；`target_count` 指定数量 |
| `UNIT_AHEAD_OF_MOVE` | 移动方向前 1 格敌人 | 仅 `OnMove`；目标格 = `to_cell + normalize(to_cell - from_cell)`；仅敌方存活单位；**无法移动且与敌人贴脸时**，战斗 AI 会发起一次「冲撞」（合成 `from_cell = 当前格 - 方向`、`to_cell = 当前格` 的 `OnMove`，不实际位移）以触发该伤害 |

**未实现（远期）**：相邻友军、`allies_with_tag` 等。

---

## 5. 可用效果（v1 + To-Be）

| 类型 | 字段 | 说明 |
|------|------|------|
| `MODIFY_STAT` | `stat_name`, `value` | 本场战斗临时加成（`attack` / `max_hp` / `crit_rate_percent`）；波次结束 `StatModifierStack` 清空 |
| `HEAL` | `value` | 恢复生命，上限为 `get_effective_max_hp()` |
| `SPAWN_UNIT` | `spawn_unit`, `spawn_hp_override`, `spawn_count` | 在死亡格召唤 token；`spawn_count` 可一次多单位 |
| `SPLIT_SELF` | `spawn_unit`, `spawn_hp_override` | 开战等时机：移除持有者，按 `current_hp` 在相邻空格生成分身；继承持有者当前攻击，血量由 `spawn_hp_override`（默认 1） |
| `DEAL_DAMAGE` | `value` / `damage_mode` + `percent` | 经 `DamagePipeline`（含暴击判定）；`OWNER_ATTACK_PERCENT` 按持有者攻击力比例 |
| `SET_HP_FROM_ALLY_PERCENT` | `value` | 将持有者 `current_hp` 设为源目标 max_hp × value% × level |
| `GRANT_GOLD` | `value` | 商店阶段 Run +金（× level） |
| `PERMANENT_DECK_STAT` | `stat_name`, `value` | 写入 `DeckEntry.bonus_*`（× level）；支持 `attack` / `max_hp` / `crit_rate_percent` |
| `STOCK_FREE_BUFF` | `buff_card`, `value` | 向空 buff 槽补充 0 费增益 offer（× level） |
| `SHOP_CHARACTER_BONUS_HP` | `value` | 当前商店角色 offer +永久 HP bonus（× level） |
| `APPLY_CELL_EFFECT` | `cell_effect`, `radius`, `include_center` | 向选定格写入 `CellEffectStack`；每格仅一种效果（新覆盖旧）；持续 `cell_effect.duration_rounds` 回合，每回合移动前结算站格伤害 |
| `FRIENDS_HURT_AOE` | `value`, `threshold` | 本 combat tick 友方 `OnDamageTaken` 次数 ≥ threshold 时对全体敌人造成伤害 |
| `SWAP_POSITIONS` | — | 与 `HEALTHIEST_ALLY` 等目标配合，交换持有者与目标棋盘格（刺客） |

**To-Be（增益卡，见 BUFF_SYSTEM）**：

| 类型 | 说明 |
|------|------|
| `PERMANENT_STAT` | Run 持久写入 `DeckEntry.bonus_*` |
| `DISABLE_MOVE` | 规则：不执行 MOVE，仍可攻击 |
| `GRANT_GOLD_ON_DEATH` | 友方死亡时 Run +N 金 |

**未实现（远期）**：施加状态、商店/回合外效果等。

### 非永久 Buff 约定

- 「本场战斗内」= 写入 `StatModifierStack`，在 [`board_controller._clear_all_stat_modifiers`](../scripts/core/board_controller.gd) 波次结束时清空。
- `+1/+1` 类效果推荐：`MODIFY_STAT attack +1` → `MODIFY_STAT max_hp +1` → `HEAL +1`（三分步，与 interval 对齐）。

---

## 6. 技能设计模板

复制以下块填写新技能策划稿，再对照引擎表确认可实现。

```markdown
### 基本信息
- **id**：（英文 snake_case，与 .tres 文件名一致）
- **display_name**：（中文 UI 名）
- **挂载**：单位内建（`UnitData.ability` 或 `passives`）

### 联动规格（EffectSpec）
| 字段 | 值 |
|------|-----|
| trigger | （见 §3） |
| target_selector | SELF / EVENT_TARGET / RANDOM_ALLY |
| exclude_owner | true / false（仅 RANDOM_ALLY） |
| actions | （见 §5；多 action = 多 interval 步） |

### 边界条件
- 无合法目标时是否不触发：
- 是否可连锁触发其他技能：
- 等级缩放：战斗内 `EffectAction` 数值 × 持有者 `level`（`MODIFY_STAT` / `HEAL` / `DEAL_DAMAGE`）；`SPAWN_UNIT` 不缩放

### 验收清单
- [ ] 创建 `resources/abilities/<id>.tres`
- [ ] 触发器 / 目标 / 效果均已 §3–§5 支持（或先扩展引擎）
- [ ] 在对应 `UnitData.ability` 或 `passives` 引用
- [ ] F5：开战验证触发与分步表现
- [ ] 更新本文档 §1.2 目录表
```

---

## 7. 实现步骤（程序向）

1. 在 `resources/abilities/` 新建 `AbilityData` `.tres`（可复制现有文件改 trigger/actions）。
2. 若需新触发器/目标/效果：扩展 `CombatEvents`、`EffectSpec`、`EffectAction`、`EffectResolver`（见 ARCHITECTURE §3.7）。
3. 在对应 `UnitData.tres` 设置 `ability` / `passives`。
4. 可选：在 [`scripts/data/sample_abilities.gd`](../scripts/data/sample_abilities.gd) 添加运行时构建函数（测试回退）。
5. 更新 [`scripts/ui/unit_info_text.gd`](../scripts/ui/unit_info_text.gd) 的触发器/效果中文（若为新类型）。

**不再**：将 `AbilityData` 加入 `dev_shop_pool.tres` → `skill_pool`（Legacy）。

---

## 8. 维护说明

- 新增或修改单位内建 `.tres` 后，**必须**同步更新 §1.2 目录表，并运行 `py tools/generate_units_roster.py` 更新 [UNITS_ROSTER.md](./UNITS_ROSTER.md)。
- 新技能策划先入 [ABILITY_PROPOSALS.md](./ABILITY_PROPOSALS.md)；实现后迁入 §1.2，并在提案文档标记已实现或删除条目。
- SAP 对照技能见 [Reference/SUPER_AUTO_PETS.md](./Reference/SUPER_AUTO_PETS.md)；SAP 宠物 Lv1/2/3 技能 → 本项目内建于 `UnitData.ability`。
- 增益策划见 [BUFF_SYSTEM.md](./BUFF_SYSTEM.md)。
