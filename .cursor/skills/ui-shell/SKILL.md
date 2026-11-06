---
name: ui-shell
description: Enforces BattleShell band layout, Panel/Popup widget contracts, and cross-phase ally-board persistence for Project Autochess UI work.
---

# ui-shell（战斗壳与 Widget 契约）

权威规格：Notion Doc ID `feature-ui-shell`（指针 `Documents/Features/UI_SHELL.md`）。棋盘几何：Doc ID `feature-combatlevel`（**5×4** 逻辑格，每侧座位 **2×5**）。触控/动效可读性另遵 **`apple-hig`**。

## 何时用

改 `realtime_battle` 壳、HUD、Dock、招募/地图商店/附魔半场布局、Popup/Modal、Theme 样式、玩家/敌方面板时**必须**读本技能。

## 硬约束（违反即退回）

1. **友方半场常驻底部**：准备 / 战斗 / 招募 / 地图商店 / 附魔不得把 AllyBoard slide 出屏，不得把队伍画到上半场（禁止 `configure_grid(..., enemy_side=true)` 仅用于「把队伍画上去」）。
2. **阶段内容占上半场**：招募候选人、商店货架、熔炉槽 → EnemyOrStageBoard；AllyBoard 只绑友方座位数据源。
2b. **玩家选择题优先上半场卡片**：店|事、主题三选一、圣物三选一等用 `StageChoiceBoard` / `enter_stage_choice` 画在敌半场；**禁止**再弹全屏纯 UI 选择题窗（Run 结束结算除外）。
3. **棋盘几何**：默认 `board_size = Vector2i(5, 4)`；`DeckConfig` 座位默认 `seat_rows=2`、`seat_cols=5`。
4. **Widget 分层**：ShellPanel / FloatingPanel / Popup / ModalScreen / Toast——见 `feature-ui-shell`；新 UI **禁止**脚本内私建 `StyleBoxFlat.new()` 充当主题色，须 Theme type variation 或 `scripts/ui/kit/` 工厂。
5. **Primary CTA 唯一**：每阶段 Dock/浮层只强调一个主按钮样式（`Primary`）。
6. **纸片风**：布局可参考大巴扎平铺；材质跟 `content-paper-cutout-art-brief`，不擅自换成木纹 UI 包。

## 壳带顺序（上→下）

`StageChrome` → `EnemyHeroPanel` → `EnemyOrStageBoard(2×5)` → Midline → `AllyBoard(2×5)★` → `PlayerHeroPanel` → `ActionDock`

## 对子代理合同须写明

- 验收方式（本切片默认跟随主合同；UI 改动在**完全**模式下须 GUI 证据）
- 允许写入的场景/脚本白名单；`project.godot` 与共享枚举归主代理
- 是否触达几何常量（若触达须同步测试里所有 `5×8` / `4×5` 断言）

## 不要做

- 把单位改成大巴扎「固定物品不对撞」规则
- 为「好看」拆掉半场常驻去换全屏独立商店/招募页（除非规格另开）
- 在本地 `Documents/*.md` 写规格正文（权威在 Notion；本地仅指针）
