# Bandit 训练闭环 · 本次运行报告

**时间（CST / UTC+8）**：2026-10-30 00:07 左右结束（墙钟约 **30+ 分钟**）  
**约束**：未修改 `scripts/`、`resources/`、`scenes/`、`project.godot`；仅 `tools/sim_balance/` 下模型与报告。

## 子代理分工

| 角色 | 任务 | 产出 |
|------|------|------|
| gameplay-engineer | 500 局训练 + 100 局冻结评估 | `runs/iter_001`、`iter_016`、`iter_017` 等 |
| balance-designer | 读 summary/bundle，按 v4 规则写 w/l patch | `reviews/iter_001_plan_balance.json`、`iter_016_plan_balance.json` + 策略 Markdown |
| 主代理 | 集成 patch、`auto_train_loop.sh` 启发式闭环 | `models/active.tres`（本地，未提交，见 `.gitignore`） |

## 目标达成

| 指标 | 结果 |
|------|------|
| **到达 F12+** | **未达成**（`reach_floor_12_rate` 全程为 0） |
| **单局最深** | **F11**（自动循环 `iter_012_bundle.json`）；手动 patch 后常见 **F10** |
| **F4+ Run 占比** | 约 **15% → 39%**（末轮 `iter_054`） |
| **Boss 通关** | 0% |

## 协议与引擎 As-Is 差距

用户要求的「直选池 / 无视价格 / F4 必先扩席再买人」在 **不改游戏代码** 前提下 **无法在 Sim 内生效**：

- v4 仅在 **可负担** 候选上学 `unit_id`（见 `SIM_BALANCE_AI.md`）。
- 扩席依赖启发式 **有钱时买旗帜**，无 F4 强制顺序。

本闭环仅通过 **checkpoint w/l 偏置 + 继续 v4 训练** 优化选人。

## 推荐后续（仍限 tools/）

1. 用 `iter_016_plan_balance.json` + 最新 bundle 再迭代 1–2 轮（当前 F10 遭遇胜率仍为瓶颈）。
2. 若有新 bundle，让 balance-designer 针对 **F6–F9 recruit_picks** 写 seed_rows（F10 无招募窗）。
3. 若必须对齐用户协议，需 **另开** 游戏侧 Sim 开关（超出本次范围）。

## 复现

```bash
export GODOT_BIN=/usr/local/bin/godot
godot --headless --path . --import   # 首次
bash tools/sim_balance/train_eval_round.sh
bash tools/sim_balance/auto_train_loop.sh   # 默认 30 分钟上限
```

详见 [TRAIN_LOOP.md](./TRAIN_LOOP.md)。
