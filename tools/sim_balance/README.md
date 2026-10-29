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

输出：`.artifacts/sim_balance/latest/{runs,encounters,summary}.json`

烟测（1 局）：

```bash
godot --headless --path . --script res://scripts/sim_balance/sim_balance_smoke_test_runner.gd
```

## 可视化

1. `cd tools/sim_balance && python3 -m http.server 8765`
2. 浏览器打开 `http://127.0.0.1:8765/sim_report.html`
3. 选择 `.artifacts/sim_balance/latest/summary.json`，或把该文件拷到同目录命名为 `summary.json`

## 策略

`resources/sim_balance/default_ai_profile.tres`（`SimAIProfile`）：启发式招募 / 旗帜 / 最短路选 Boss / 前排高 HP。

## 核心依赖

仅一条主工程接缝：`RealtimeCombatSim.run_until_finished()`（无 UI 行为变化）。
