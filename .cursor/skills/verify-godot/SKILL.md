---
name: verify-godot
description: Runs Godot light smoke or full SceneTree test runners and reports exit codes plus SCRIPT ERROR. Use when implementing gameplay, changing resources, or claiming L2+ done under full acceptance.
---

# verify-godot

跑项目验证时用这个技能。先确认合同**验收方式**（轻量 / 完全）。仓库尚无统一 `tools/verify.ps1`，不要另起空入口假装通过。

## 入口

### 轻量验收

```bash
bash tools/run_light_verify.sh
```

仅 import + 关键场景加载烟测。通过即可交付实现；效果由用户验收。不要用本技能冒充完全验收。

### 完全验收

按改动选择现有 runner。聚合入口：

```bash
bash tools/run_verify_runners.sh
```

或单独例如：

```powershell
godot --headless --path . --script res://scripts/combat/effect_resolver_faint_test_runner.gd
godot --headless --path . --script res://scripts/combat/effect_resolver_bomber_test_runner.gd
godot --headless --path . --script res://scripts/combat/grid_movement_test_runner.gd
godot --headless --path . --script res://scripts/combat/attack_range_preview_test_runner.gd
godot --headless --path . --script res://scripts/combat/combat_bus_lifecycle_test_runner.gd
godot --headless --path . --script res://scripts/core/board_grid_distance_test_runner.gd
godot --headless --path . --script res://scripts/core/run/map_generator_test_runner.gd
godot --headless --path . --script res://scripts/core/run/sacrifice_service_test_runner.gd
godot --headless --path . --script res://scripts/core/wfc/wfc_generator_test_runner.gd
```

可用环境变量 `GODOT_BIN` 覆盖引擎路径。共享单位、技能或棋盘资源变更时，跑所有受影响的 `scripts/**/*_test_runner.gd`。同目录若还有 SceneTree runner（如 `combat_movement_tests_runner.gd`），一并列入。

## 判定

- 退出码必须为 0。
- 日志可写 `.artifacts/validation/`，不提交。
- 扫描 `SCRIPT ERROR`、`Parse Error`、`ERROR:`。
- 不删断言、不屏蔽错误、不与编辑器资源导入并行。
- 只报告实跑命令、退出码和未覆盖项。Headless 通过不等于 GUI 通过。
