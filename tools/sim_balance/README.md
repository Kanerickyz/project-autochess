# Sim Balance（隔离工具）

与主菜单 / `run_game` **无耦合**：脚本在 `scripts/sim_balance/`，入口为 headless runner。

## 指标

- **遭遇胜率**：按地图层号 `floor` 聚合（每次战斗节点尝试 → wins/attempts）。
- **Run 通关率**：Boss 胜 `RUN_COMPLETE` 占比（辅助）。
- **死亡层**：败局 `death_floor` 直方图 + 众数层。

## 跑 100 局

```bash
bash tools/sim_balance/run_batch.sh 100 1
```

启发式（默认）输出：`.artifacts/sim_balance/latest/summary.json`

**冻结 bandit 评估**（训练后的 checkpoint，不在批跑内学习）：

```bash
godot --headless --path . --script res://scripts/sim_balance/sim_batch_runner.gd -- \
  --runs 100 --seed-start 1 --out .artifacts/sim_balance/bandit_eval \
  --checkpoint res://resources/sim_balance/checkpoints/bandit_v1.tres
```

**训练 checkpoint**（v4 按 **unit_id + 队伍** 学招募，选路启发式；见 [SIM_BALANCE_AI.md](../../Documents/Features/SIM_BALANCE_AI.md)）：

```bash
bash tools/sim_balance/train_bandit.sh --reward-mode v4 --train-runs 2000
```

见 [Documents/Features/SIM_BALANCE_AI.md](../../Documents/Features/SIM_BALANCE_AI.md)。

烟测（1 局）：

```bash
bash tools/run_sim_balance_verify.sh
```

100 局批跑 + JSON：

```bash
bash tools/sim_balance/run_batch.sh 100 1
# 或 SIM_BALANCE_BATCH=1 bash tools/run_sim_balance_verify.sh
```

## 可视化

- **GitHub Pages**：推 **`balance-eval`** 或手动 **Balance Report Pages** → 归档到 `docs/balancereport/runs/` 并 push **`main`** → **Deploy Web** 发布  
  https://kanerickyz.github.io/project-autochess/balancereport/（页内可切换历史报告）
- **本地**：跑批后归档  
  `python3 tools/sim_balance/archive_batch_report.py /path/to/batch_out`  
  再 `cd docs/balancereport && python3 -m http.server 8765` 打开 `index.html`

## 策略

`resources/sim_balance/default_ai_profile.tres`（`SimAIProfile`）：启发式招募 / 旗帜 / 最短路选 Boss / 前排高 HP。效用权重可调，进化或 RL 导出见 [Documents/Features/SIM_BALANCE_AI.md](../../Documents/Features/SIM_BALANCE_AI.md)。

## 核心依赖

仅一条主工程接缝：`RealtimeCombatSim.run_until_finished()`（无 UI 行为变化）。
