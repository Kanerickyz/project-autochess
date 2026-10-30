# Bandit 自动训练闭环（仅 tools/sim_balance）

本目录脚本**不修改** `scripts/`、`resources/`、`scenes/` 等游戏文件；只读写：

- `tools/sim_balance/models/active.tres`（bandit checkpoint）
- `tools/sim_balance/runs/`、`reviews/`、`reports/`（批跑与审阅产物）

## 协议说明（与用户需求的对齐）

| 用户要求 | 当前引擎批跑 As-Is | 本工具如何优化 |
|----------|-------------------|----------------|
| 直选池 / 按 `unit_id` 选人 | bandit **v4** 动作为 `unit_id`，店池为招募短名单 | 训练 `--reward-mode v4`；审阅后 patch checkpoint 的 w/l |
| 无视角色价格 | Sim 仍调用 `can_afford(recruit_cost)` | **无法**在不改游戏的前提下解除；报告会标注 |
| F4 起先扩席再购买 | 启发式在有钱时买旗帜 | 通过 deep/shallow run 的 `recruit_picks` 反推应偏好的单位 |

成功条件（`auto_train_loop.sh`）：**任一局到达 F12+** 或 **≥5% Run 到达 F12**，或 ** wall 30 分钟**。

## 命令

```bash
# 单轮：训练 500 + 评估 100
bash tools/sim_balance/train_eval_round.sh

# 闭环（默认 30 分钟上限，目标 F12）
bash tools/sim_balance/auto_train_loop.sh
```

依赖：PATH 上的 Godot **4.6**（`GODOT_BIN` 可覆盖）；首次需 `godot --headless --path . --import`。

## 子流程

1. `train_eval_round.sh` → `models/active.tres` + `runs/iter_XXX/`
2. `analyze_for_review.py` → `reviews/iter_XXX_bundle.json`
3. `apply_optimization.py` → 根据 bundle 启发式 patch（或由 balance-designer 产出 `--plan` JSON）
