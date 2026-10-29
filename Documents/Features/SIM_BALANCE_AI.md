# Sim Balance · 决策 AI（批跑专用）

> **范围**：仅 `scripts/sim_balance/` 与 `resources/sim_balance/`；**不是**玩家对战 AI，不影响 `run_game` 主路径。

## 双模式（训练 vs 评估）

| 模式 | 行为 | 用途 |
|------|------|------|
| **训练** | `BanditRunAI` + `learning_enabled=true` | 产出 checkpoint |
| **评估 / 报告** | 加载 **冻结** checkpoint，`learning_enabled=false` | CI / Pages |

## 奖励策略

### bandit-v1（`reward_mode=v1`）

- **选路 + 招募** 均在 **下一场战斗遭遇** 结束时，用 **胜/负** 更新（同一 pending 批次）。

### bandit-v2（`reward_mode=v2`，推荐新训）

| 决策 | 何时更新 | 信号 |
|------|----------|------|
| **选路** | 下一场 **战斗遭遇** 结束 | 胜 → w+1；败 → l+1 |
| **招募** | **整局 Run 结束**（且本局至少 1 场战斗） | 通关：每次成功招募 w+**2**；败局死亡层 **D**、地图 **F_max**：w += round(D/F_max×**3**)，l += round((F_max−D)/F_max×**3**) |

评估批跑 **不更新** 表。

## 命令

```bash
# 训练 v2（示例 2000 局）
bash tools/sim_balance/train_bandit.sh --train-runs 2000 --reward-mode v2

# 评估 / 报告（冻结 v2）
bash tools/sim_balance/run_batch.sh 100 1 /tmp/out \
  --checkpoint res://resources/sim_balance/checkpoints/bandit_v2.tres
```

Checkpoint：`bandit_v1.tres` / `bandit_v2.tres`；报告 `meta.ai_profile_id` 与 `policy_id` 一致。

## 验收

- 轻量：`bash tools/run_sim_balance_verify.sh`
- 对比 default / bandit-v1 / bandit-v2 各 100 局报告（死亡层直方图、分层胜率）
