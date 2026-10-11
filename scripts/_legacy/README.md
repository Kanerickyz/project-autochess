# Legacy（非热路径）

此处存放主流程已不再引用的实现，仅供对照或迁移参考。

| 路径 | 说明 |
|------|------|
| `ui/board_view.gd` + `scenes/_legacy/ui/board_view.tscn` | 旧 2D 棋盘视图；现行为 `BoardWorld` / `BoardScene3D` |
| `ui/board_combat_stage.gd` + 对应场景 | 旧 2D 战斗舞台过渡 |

**不要**在 `main.tscn` / `run_game.tscn` / `sandbox.tscn` 中重新挂载这些场景。
