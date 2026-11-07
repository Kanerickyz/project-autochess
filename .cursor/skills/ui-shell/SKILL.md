---
name: ui-shell
description: Enforces BattleShell band layout, Panel/Popup widget contracts, StageChoice cards, unified inspect cards, and cross-phase ally-board persistence for Project Autochess UI work.
---

# ui-shell（战斗壳与 Widget 契约）

权威规格：Notion Doc ID `feature-ui-shell`（指针 `Documents/Features/UI_SHELL.md`）。棋盘几何：Doc ID `feature-combatlevel`（**5×4** 逻辑格，每侧座位 **2×5**）。圣物拥有规则：Doc ID `feature-expedition-relics`。触控/动效可读性另遵 **`apple-hig`**。

## 何时用

改 `realtime_battle` 壳、HUD、Dock、招募/地图商店/附魔半场布局、StageChoice、圣物徽章/介绍、Popup/Modal、Theme 样式、玩家/敌方面板时**必须**读本技能。

## 硬约束（违反即退回）

1. **友方半场常驻底部**：准备 / 战斗 / 招募 / 地图商店 / 附魔 / StageChoice 不得把 AllyBoard slide 出屏，不得把队伍画到上半场（禁止 `configure_grid(..., enemy_side=true)` 仅用于「把队伍画上去」）。
2. **阶段内容占上半场**：招募候选人、商店货架、熔炉槽、**StageChoice 选项卡** → EnemyOrStageBoard；AllyBoard 只绑友方座位数据源。
3. **玩家选择题优先上半场卡片**：店|事、圣物三选一等用 `StageChoiceBoard` / `enter_stage_choice` 画在敌半场；**禁止**再弹全屏纯 UI 选择题窗（Run 结束结算除外）。**本版招募不做主题三选一**。
4. **检视统一信息卡**：单位 / 候选人 / 商店货架 / StageChoice 选项 / **圣物** 的详情一律走 Arena `RealtimeUnitInfoCard`（FloatingPanel 契约）。  
   - 圣物文案工厂：`ExpeditionRelicInfo`（徽章长按与 StageChoice 圣物卡共用）。  
   - **禁止**再弹独立 `PopupPanel` / 另起一套圣物详情窗。
5. **棋盘几何**：默认 `board_size = Vector2i(5, 4)`；`DeckConfig` 座位默认 `seat_rows=2`、`seat_cols=5`。
6. **Widget 分层**：ShellPanel / FloatingPanel / Popup / ModalScreen / Toast——见 `feature-ui-shell`；新 UI **禁止**脚本内私建 `StyleBoxFlat.new()` 充当主题色，须 Theme type variation 或 `scripts/ui/kit/` 工厂。
7. **Primary CTA 唯一**：每阶段 Dock/浮层只强调一个主按钮样式（`Primary`）。
8. **纸片风**：布局可参考大巴扎平铺；材质跟 `content-paper-cutout-art-brief`，不擅自换成木纹 UI 包。

## 壳带顺序（上→下）

`StageChrome` → `EnemyHeroPanel` → `EnemyOrStageBoard(2×5)` → Midline → `AllyBoard(2×5)★` → `PlayerHeroPanel`（含右上/行内圣物徽章条）→ `ActionDock`

## UX：StageChoice（上半场选项卡）

| 规则 | 说明 |
|------|------|
| 布局 | 选项平铺在**敌半场**；视觉可占满上半场高度；短摘要可截断 |
| 短按 | 确认选择（主题提交 / 店\|事去向 / 圣物高亮等） |
| 长按 | 打开统一信息卡看完整 `detail`；**松手不代表确认选择** |
| 友方半场 | StageChoice 期间仍可拖换座、长按看角色信息（输入不得被选项路径整屏吞掉） |
| Dock | 需要次级操作时挂 Dock（圣物跳过/放入/换下）；主 CTA 仍唯一强调 |
| 代码 | `StageChoiceBoard`、`RealtimeBattleController.enter_stage_choice`、`stage_choice_pressed` |

## UX：统一检视（长按信息卡）

与单位长按同一套 `RealtimeUnitInfoCard`：

| 对象 | 手势 | 文案/入口 |
|------|------|-----------|
| 场上/队伍单位 | 长按 | Arena `inspect_at` / `_info_from_entry` |
| 招募候选人、商店货架 | 长按 | 既有 recruit / map_shop inspect |
| StageChoice 选项卡 | 长按 | 字典 `detail`（无则回落 `summary`） |
| **行囊圣物徽章**（PlayerHeroPanel） | **长按** | `ExpeditionRelicInfo` → `arena.show_relic_info` |
| StageChoice 圣物卡 | 长按 | 同上 `ExpeditionRelicInfo.detail_text` / `stage_choice_dict` |

圣物信息卡字段约定（`is_item`）：`name`、`kind_label=圣物`、`tier`、`cost=出售金`、`skills=完整说明`。卡片面只露短 `summary`。

**禁止**：徽章点击弹 `RelicDetailPopup`；为圣物另写 Label 浮层当主介绍路径。

## 对子代理合同须写明

- 验收方式（本切片默认跟随主合同；UI 改动在**完全**模式下须 GUI 证据）
- 允许写入的场景/脚本白名单；`project.godot` 与共享枚举归主代理
- 是否触达几何常量（若触达须同步测试里所有 `5×8` / `4×5` 断言）
- 若改检视/圣物介绍：须同步 `ExpeditionRelicInfo` 与 StageChoice/徽章两侧，并跑 `expedition_relic_info` / `expedition_relic_badge_strip` / `stage_choice_*` runners

## 不要做

- 把单位改成大巴扎「固定物品不对撞」规则
- 为「好看」拆掉半场常驻去换全屏独立商店/招募页（除非规格另开）
- 在本地 `Documents/*.md` 写规格正文（权威在 Notion；本地仅指针）
- 为圣物/选项再开一套独立详情 Popup
