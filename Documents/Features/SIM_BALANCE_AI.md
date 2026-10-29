# Sim Balance · 决策 AI（批跑专用）

> **范围**：仅 `scripts/sim_balance/` 与 `resources/sim_balance/`；**不是**玩家对战 AI，不影响 `run_game` 主路径。

## 双模式（已定稿）

| 模式 | 行为 | 用途 |
|------|------|------|
| **训练** | `BanditRunAI` + `learning_enabled=true`；每次**战斗遭遇结束**用 **won/lost** 更新 bandit | 产出 checkpoint |
| **评估 / 报告** | 加载 **冻结** `SimBanditCheckpoint`，`learning_enabled=false`；100 局批跑 **不更新** 表 | CI / Pages / 与改数值前后对比 |

**奖励**：只用遭遇胜负（`won=true/false`），不用 Run 通关、金币 shaping。

**信用分配**：自上一场战斗结束到本场战斗结束之间的 **选路 + 招募** 决策，在本场战斗结算时收到同一条胜负反馈。

## As-Is 组件

- `HeuristicRunAI`：默认策略（无学习）。
- `BanditRunAI`：选路 + 招募用 contextual bandit（UCB 探索 / 贪婪评估）；站位、旗帜仍启发式。
- `SimBanditTable` / `SimBanditCheckpoint`：可序列化 `.tres`。
- `SimAIProfile`：启发式权重（bandit 无数据时的 fallback 臂）。

## 命令

```bash
# 训练（默认 400 局，写入 bandit_v1.tres）
bash tools/sim_balance/train_bandit.sh
bash tools/sim_balance/train_bandit.sh --train-runs 800 --checkpoint-out res://resources/sim_balance/checkpoints/bandit_v1.tres

# 评估批跑（冻结 checkpoint，默认 100 局）
bash tools/sim_balance/run_batch.sh 100 1 /tmp/out
godot --headless --path . --script res://scripts/sim_balance/sim_batch_runner.gd -- \
  --runs 100 --seed-start 1 --out /tmp/out \
  --checkpoint res://resources/sim_balance/checkpoints/bandit_v1.tres
```

报告 `meta.ai_profile_id` 使用 checkpoint 的 `policy_id`（如 `bandit-v1`），与 `default` 启发式报告分开存档。

## 状态键（v1）

- **地图**：层号 + 可选节点数 + 节点类型序列 → arm = 候选下标（与启发式排序一致）。
- **招募**：层 + 金币桶 + 人数 + 候选 atk+hp/cost 摘要 → arm = 可负担候选中的下标。

## 未做 / 非目标

- 100 局批跑内在线学习（已明确不做）。
- 神经网络 RL、战斗内微操、商店买装备细粒度决策。
- 默认 Balance Report CI **仍可用** `default` 启发式；bandit 评估需显式 `--checkpoint` 或换 workflow 输入。

## 验收

- 轻量：`godot … sim_bandit_smoke_test_runner.gd` + `run_sim_balance_verify.sh`
- 完全：训练 checkpoint → 100 局 eval → 归档报告对比 `default` vs `bandit-v1`
