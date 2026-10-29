# Sim Balance · 决策 AI（批跑专用）

> **范围**：仅 `scripts/sim_balance/` 与 `resources/sim_balance/`；**不是**玩家对战 AI，不影响 `run_game` 主路径。

## 双模式（训练 vs 评估）

| 模式 | 行为 | 用途 |
|------|------|------|
| **训练** | `BanditRunAI` + `learning_enabled=true` | 产出 checkpoint |
| **评估 / 报告** | 加载 **冻结** checkpoint，`learning_enabled=false` | CI / Pages |

## 评估 KPI（优先级）

| 阶段 | 主 KPI | 说明 |
|------|--------|------|
| **M-A** | 败局众数层、F2 占比 | 不低于 default |
| **M-B（主目标）** | **到达 F4+ 的 Run 占比** | 败局 `death_floor≥4` + 通关 Run |
| **M-C** | Boss 通关率 | 参考项 |

固定协议：冻结 checkpoint、`seed_start=1`、**100 局**批跑，`meta.ai_profile_id` = `policy_id`。

## 策略代数（摘要）

| 版本 | 选路 | 招募学什么 | 动作键 |
|------|------|------------|--------|
| v1 | 遭遇胜负 | 遭遇胜负 | 槽位 index |
| v2 | 遭遇胜负 | Run 终局 / 深度 | 槽位 index |
| v3 | 同 v2 | 深度向 Run 终局 + 战力桶 | 槽位 index |
| **v4（推荐）** | **固定启发式** | **Run 终局 / 深度** | **`unit_id`** |

v4 的设计目标：**教会模型在「当前队伍 + 本店可选角色」下招谁更容易打得更远**；队伍写在 state 里，**角色组合**通过同一 state 下的 `unit_id` 统计自然体现，不是全局配对表。

### bandit-v4（`reward_mode=v4`）

**状态键** `recruit4|f{层}|g{金桶}|team={排序 unit_id#level}|shop={排序可选 unit_id}`  

- roster：`DeckEntry.get_unit_id()` + `#level`（L1 可省略 level 时仍带 `#1` 保持一致）
- shop：当前 **可负担** 候选的 `unit_id` 集合（去重、排序）

**动作**：选中的 **`unit_id`**（不是商店槽位 index）。

**奖励**（仅招募；Run 结束且本局 ≥1 战）：

- 通关：每次成功招募 w+**3**
- 败局：`w_add = round((D/F_max)^0.75 × 4)`，`l_add = round(((F_max−D)/F_max)^1.25 × 3)`；**D≥4** 时 `l_add = max(0, l_add−1)`

**选路**：`HeuristicRunAI.pick_map_node`（不写入 bandit 表）。

**评估**：冻结、无 UCB；该 `state_key` 总样本 **&lt; 3** 时回退启发式推荐的 `unit_id`。

批跑 **不更新** 表。Run 记录可含 `recruit_picks: [{unit_id, floor}, …]` 便于看「每局招了谁」。

## 训练

```bash
# v4 新表（推荐 2000 局）
bash tools/sim_balance/train_bandit.sh \
  --reward-mode v4 \
  --train-runs 2000 \
  --seed-start 1 \
  --checkpoint-out res://resources/sim_balance/checkpoints/bandit_v4.tres

# 评估
bash tools/sim_balance/run_batch.sh 100 1 /tmp/out \
  --checkpoint res://resources/sim_balance/checkpoints/bandit_v4.tres
```

- 探索：前 **60%** UCB、后 **40%** 贪心（`--explore-ratio`，默认 `0.6`）。
- 日志：`bandit_updates`、键数、中位 w+l、≥5 占比。

旧版 checkpoint：`bandit_v1.tres` / `bandit_v2.tres`（槽位 bandit + 选路 bandit）。

## 验收

- 轻量：`bash tools/run_sim_balance_verify.sh`
- 对比 default / bandit-v4：F4+ 占比、死亡层、`recruit_picks` 分布
