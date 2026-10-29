# Sim Balance · 决策 AI（批跑专用）

> **范围**：仅 `scripts/sim_balance/` 与 `resources/sim_balance/`；**不是**玩家对战 AI，不影响 `run_game` 主路径。

## 双模式（训练 vs 评估）

| 模式 | 行为 | 用途 |
|------|------|------|
| **训练** | `BanditRunAI` + `learning_enabled=true` | 产出 / 续训 checkpoint |
| **评估 / 报告** | 加载 **冻结** checkpoint，`learning_enabled=false` | CI / Pages |

## 评估 KPI（优先级）

| 阶段 | 主 KPI | 说明 |
|------|--------|------|
| **M-A** | 败局众数层、F2 占比 | 不低于 default；避免 v1 式「死在 F2」 |
| **M-B（当前主目标）** | **到达 F4+ 的 Run 占比** | 败局 `death_floor≥4` + 通关 Run；对比 default / 上一版 checkpoint |
| **M-C** | Boss 通关率 | 参考项；数值难度未调时可为 0%，不单独堆训练局数 |

固定协议：冻结 checkpoint、`seed_start=1`、**100 局**批跑，报告 `meta.ai_profile_id` 与 `policy_id` 一致。

## 奖励策略

### bandit-v1（`reward_mode=v1`）

- **选路 + 招募** 均在 **下一场战斗遭遇** 结束时，用 **胜/负** 更新（同一 pending 批次）。

### bandit-v2

| 决策 | 何时更新 | 信号 |
|------|----------|------|
| **选路** | 下一场 **战斗遭遇** 结束 | 胜 → w+1；败 → l+1 |
| **招募** | **整局 Run 结束**（且本局至少 1 场战斗） | 通关：每次成功招募 w+**2**；败局：w/l 按死亡层 **D** 与地图 **F_max** 线性分配（各至多 **3**） |

### bandit-v3（`reward_mode=v3`，**推荐续训与评估**）

- **选路**：与 v2 **相同**（仅下一场遭遇胜负）；**不**引入 Run 级选路信号。
- **招募**：仍仅在 Run 终局更新；**强化「更深更好、浅层更差」**，对齐 M-B：
  - 通关：每次成功招募 w+**3**
  - 败局：  
    - `w_add = round((D/F_max)^0.75 × 4)`  
    - `l_add = round(((F_max−D)/F_max)^1.25 × 3)`；若 **D≥4** 则 `l_add = max(0, l_add−1)`
- **状态键（招募）**：`recruit3|…` 桶化（战力 / 费用档），降低键爆炸；**选路键**仍为 `map|…`（与 v2 共用表内 map 条目，可从 v2 **续训**）。

### 评估行为（v3）

- 冻结表、**无 UCB**；某 `state_key` 累计样本 **&lt; 3** 时 **回退启发式 arm**（与训练时的 fallback 一致）。

评估批跑 **不更新** 表。

## 训练

```bash
# 从 v2 续训 v3（推荐：新增 2000 局，seed 2001 起，避免重复 seed 1..2000）
bash tools/sim_balance/train_bandit.sh \
  --reward-mode v3 \
  --train-runs 2000 \
  --seed-start 2001 \
  --checkpoint-in res://resources/sim_balance/checkpoints/bandit_v2.tres \
  --checkpoint-out res://resources/sim_balance/checkpoints/bandit_v3.tres

# 评估 / 报告（冻结 v3）
bash tools/sim_balance/run_batch.sh 100 1 /tmp/out \
  --checkpoint res://resources/sim_balance/checkpoints/bandit_v3.tres
```

- **探索**：训练前 **60%** 局 UCB 探索，后 **40%** 仅贪心填表（`--explore-ratio`，默认 `0.6`）。
- 日志输出 `bandit_updates` 与 **表覆盖率**（键数、中位 w+l、≥5 占比）。
- 新训 v2：`--reward-mode v2`（默认输出 `bandit_v2.tres`）。

Checkpoint：`bandit_v1.tres` / `bandit_v2.tres` / `bandit_v3.tres`。

## 验收

- 轻量：`bash tools/run_sim_balance_verify.sh`
- 对比 default / bandit-v2 / bandit-v3 各 100 局（死亡层直方图、**F4+ Run 占比**、分层胜率）
