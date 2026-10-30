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

**训练 checkpoint**（遭遇胜负反馈，默认 400 局）：

```bash
bash tools/sim_balance/train_bandit.sh --train-runs 400
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

## 直选池模式（`--direct-pick`，默认关闭）

招募阶段不走货架/金币：候选 = 当前层解锁档位全部玩家角色（每角色本局 9 份）；F4 起每阶段免费席位 +1（封顶 10）；每阶段最多拿 10 个；加人/三合一走 `DeckState.add_entry`，满员替换走 `DeckState.replace_entry`（`scripts/sim_balance/direct_pick_recruiter.gd`）。

```bash
# 训练 bandit-v5-direct（特征化 state，动作 unit_id，深度奖励目标 F12）
bash tools/sim_balance/train_bandit.sh --train-runs 500 --seed-start 1 --direct-pick --reward-mode v5 \
  --checkpoint-also res://resources/sim_balance/checkpoints/bandit_v5_direct_iter1.tres
# 冻结评估 / 启发式对照
bash tools/sim_balance/run_batch.sh 100 10001 .artifacts/sim_balance/direct_pick/iter1 --direct-pick \
  --checkpoint res://resources/sim_balance/checkpoints/bandit_v5_direct.tres
bash tools/sim_balance/run_batch.sh 100 10001 .artifacts/sim_balance/direct_pick/iter1_heuristic --direct-pick
python3 tools/sim_balance/analyze_direct_pick.py .artifacts/sim_balance/direct_pick/iter1
```

`runs.json` 直选模式额外字段：`recruit_picks`（unit_id/floor/mode/tier）、`final_roster`、`final_seat_cap`；`summary.json` 含 `reached_f12_count`。

## 可视化

- **GitHub Pages**：推 **`balance-eval`** 或手动 **Balance Report Pages** → 归档到 `docs/balancereport/runs/` 并 push **`main`** → **Deploy Web** 发布  
  https://kanerickyz.github.io/project-autochess/balancereport/（页内可切换历史报告）
- **本地**：跑批后归档  
  `python3 tools/sim_balance/archive_batch_report.py /path/to/batch_out`  
  再 `cd docs/balancereport && python3 -m http.server 8765` 打开 `index.html`

## 策略

`resources/sim_balance/default_ai_profile.tres`（`SimAIProfile`）：启发式招募 / 旗帜 / 最短路选 Boss / 前排高 HP。效用权重可调，进化或 RL 导出见 [Documents/Features/SIM_BALANCE_AI.md](../../Documents/Features/SIM_BALANCE_AI.md)。

**自动训练闭环**（仅改 `tools/sim_balance/`）：见 [TRAIN_LOOP.md](./TRAIN_LOOP.md)。

## 核心依赖

仅一条主工程接缝：`RealtimeCombatSim.run_until_finished()`（无 UI 行为变化）。
