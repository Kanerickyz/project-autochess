# Notion 设计文档库与 harness 切换

日期：2026-11-05  
状态：待用户审阅规格  
范围：设计权威源迁到 Notion；仓库 `Documents/` 瘦身为指针；更新项目 harness

## 目标

- Notion 为**游戏设计文档权威源**（含 `Documents/Content/` 下角色等相关文档）。
- 建独立 Hub + 单一数据库「Autochess — 设计文档」，导入现有 Markdown 正文。
- 本地 `Documents/**` 保留路径，正文改为短指针。
- 更新 `AGENTS.md`、规则、工作流、skills、agents，使 Agent 默认读 Notion。
- 本期**不**拆独立「角色行」内容库；后续可复用同一流程另建库。

## 非目标

- 不改玩法代码 / 资源 / 不 bump `application/config/version`。
- 不把角色拆成数据库多行（仍为 Content 类文档页）。
- 不删除旧 Thinkings「Project Auto Chess」随想页（仅不作为根）。

## 架构

```text
Notion: Design Hub
  └── DB「Autochess — 设计文档」(每行 = 一篇规格，body = 正文)

Git: Documents/**/*.md  → 短指针（Doc ID + Notion URL）
     AGENTS / rules / skills / agents → 指向 Hub + 库
     resources/ / scripts/            → 实现权威仍在 git
```

## §1 Hub 与库 schema

### Hub

- 标题：`Project Autochess — Design Hub`
- 内容：权威说明、库入口、如何新增/查找文档、仓库链接、历史随想页链接
- 父级：私人 draft（或用户事后移动）；**不**挂在 Thinkings 旧页下

### 数据库：`Autochess — 设计文档`

| 属性 | 类型 | 说明 |
|------|------|------|
| Name | title | 文档标题 |
| Kind | select | `Vision` / `Feature` / `Content` / `Reference` / `Process` / `Arch` / `Note` / `Ops` |
| Status | select | `Canonical` / `Draft` / `Deprecated` |
| Repo Path | text | 如 `Documents/Features/COMBAT.md` |
| Doc ID | text | 稳定 kebab-case id，供 Agent 检索 |
| Summary | text | 一行摘要 |
| Last Synced | date | 从 git 迁入日期 |

视图：按 Kind 分组；另加 Content-only、Features-only、Canonical-only。

`WEB_DEPLOY.md` 归 Kind=`Ops`（部署说明，非玩法规格）。

## §2 本地指针与 harness

### 指针页模板

每个原路径保留文件，正文约 5–15 行：

- 标题与 Doc ID
- Notion 页 URL
- 一句：权威在 Notion；勿在此修改规格
- 可选一行 Summary

`Documents/INDEX.md`：Hub URL、库说明、按 Kind 的 Notion 链接表。

### harness 改动清单

| 路径 | 改动 |
|------|------|
| `AGENTS.md` | 设计意图以 Notion 库为准；本地仅指针；写入 Hub/库 URL |
| `.cursor/rules/project.mdc` | 同上 |
| `Documents/DEVELOPMENT_WORKFLOW.md` | 规格写 Notion；git 只维护指针；养成规范仍适用 |
| `CONTRIBUTING.md` | 文档贡献改为 Notion 优先 |
| `.cursor/skills/characterdesign/` 等 | 读规格改 Notion Doc ID；实现仍写 `resources/` |
| `.cursor/skills/design-brainstorm/` 等 | 同上 |
| `.cursor/agents/*.md` | 入口改为 Notion + 指针 INDEX |

## §3 迁移与冲突

### 步骤

1. 创建 Hub + 数据库  
2. 导入全部 `Documents/**/*.md`（约 42 篇）  
3. 回写本地指针 + INDEX  
4. 更新 harness  
5. Hub 写使用说明  

### 冲突规则

| 情况 | 规则 |
|------|------|
| Notion ≠ 本地旧正文 | 以 Notion 为准 |
| Agent 改设计 | 只改 Notion；新建则同步指针 + INDEX |
| 代码 / `.tres` | 以 git 为准 |
| As-Is 实现 vs To-Be 规格 | 规格在 Notion；交付须标明差距 |
| Notion MCP 不可用 | 可读指针 Summary；**不得**把指针当规格改完合入 |

### Doc ID 映射（导入清单）

| Repo Path | Doc ID | Kind |
|-----------|--------|------|
| Documents/INDEX.md | `docs-index` | Process |
| Documents/GAME_VISION.md | `game-vision` | Vision |
| Documents/ARCHITECTURE.md | `arch-overview` | Arch |
| Documents/BUFF_SYSTEM.md | `buff-system` | Feature |
| Documents/DEVELOPMENT_WORKFLOW.md | `process-dev-workflow` | Process |
| Documents/WEB_DEPLOY.md | `ops-web-deploy` | Ops |
| Documents/Content/INDEX.md | `content-index` | Content |
| Documents/Content/UNITS_ROSTER.md | `content-units-roster` | Content |
| Documents/Content/UNIT_ABILITIES_ROSTER.md | `content-unit-abilities-roster` | Content |
| Documents/Content/BOSS_ROSTER.md | `content-boss-roster` | Content |
| Documents/Content/CHARACTER_DESIGN.md | `content-character-design` | Content |
| Documents/Content/EXPEDITION_RELICS_ROSTER.md | `content-expedition-relics-roster` | Content |
| Documents/Content/PAPER_CUTOUT_ART_BRIEF.md | `content-paper-cutout-art-brief` | Content |
| Documents/Content/UNIT_PARTY_BARKS_ROSTER.md | `content-unit-party-barks-roster` | Content |
| Documents/DesignNotes/EXPEDITION_RELICS_CONSENSUS.md | `note-expedition-relics-consensus` | Note |
| Documents/Features/BOSS.md | `feature-boss` | Feature |
| Documents/Features/COMBAT.md | `feature-combat` | Feature |
| Documents/Features/COMBAT_FEEDBACK.md | `feature-combat-feedback` | Feature |
| Documents/Features/COMBAT_STATUS.md | `feature-combat-status` | Feature |
| Documents/Features/COMBATLEVEL.md | `feature-combatlevel` | Feature |
| Documents/Features/ENCHANT.md | `feature-enchant` | Feature |
| Documents/Features/ENDLESS.md | `feature-endless` | Feature |
| Documents/Features/ENEMY_SPAWN_BUDGET.md | `feature-enemy-spawn-budget` | Feature |
| Documents/Features/EXPEDITION_RELICS.md | `feature-expedition-relics` | Feature |
| Documents/Features/GAME_LOOP.md | `feature-game-loop` | Feature |
| Documents/Features/MAIN_MENU.md | `feature-main-menu` | Feature |
| Documents/Features/MAP.md | `feature-map` | Feature |
| Documents/Features/MAP_SHOP.md | `feature-map-shop` | Feature |
| Documents/Features/MATCH_HISTORY.md | `feature-match-history` | Feature |
| Documents/Features/PLAYER.md | `feature-player` | Feature |
| Documents/Features/RECRUIT.md | `feature-recruit` | Feature |
| Documents/Features/RECRUIT_SHOP.md | `feature-recruit-shop` | Feature |
| Documents/Features/SANDBOX.md | `feature-sandbox` | Feature |
| Documents/Features/SIM_BALANCE_AI.md | `feature-sim-balance-ai` | Feature |
| Documents/Features/UNITS.md | `feature-units` | Feature |
| Documents/Features/UNIT_ABILITIES.md | `feature-unit-abilities` | Feature |
| Documents/Features/UNIT_PARTY_BARKS.md | `feature-unit-party-barks` | Feature |
| Documents/Features/UNIT_THEME_BONDS.md | `feature-unit-theme-bonds` | Feature |
| Documents/Reference/SUPER_AUTO_PETS.md | `reference-super-auto-pets` | Reference |
| Documents/Reference/SAP_SHOP_SYSTEM.md | `reference-sap-shop-system` | Reference |
| Documents/Reference/RISK_OF_RAIN_2.md | `reference-risk-of-rain-2` | Reference |
| Documents/Reference/MASTER_OF_PIECE.md | `reference-master-of-piece` | Reference |

导入后在 Hub 固定写上：**Database URL** 与各 Canonical 页 URL，供 harness 引用。

## 验收

轻量文档验收（无 Godot runner 要求）：

1. Notion 库行数 = 上表条目数；抽查 Vision / Feature / Content 正文可读  
2. 用 Notion 搜索 `Doc ID`（如 `game-vision`）可定位  
3. 本地任意原路径打开为指针且链接有效  
4. `AGENTS.md` / `project.mdc` 明确 Notion 权威  

## 回滚

还原 git 中指针与 harness；Notion 库保留，需人工决定是否归档。

## Runtime IDs（实施后）

| Key | Value |
|-----|-------|
| HUB_URL | https://app.notion.com/p/40ff89936db681b5880cec3af0087789 |
| HUB_PAGE_ID | 40ff8993-6db6-81b5-880c-ec3af0087789 |
| DB_URL | https://app.notion.com/p/9293e582b53d437dbe88b28d21251a5f |
| DATA_SOURCE_ID | collection://49890a10-9fb5-4516-b48f-440f7bd41075 |
