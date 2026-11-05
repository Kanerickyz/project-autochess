# Notion 设计文档库迁移 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `Documents/` 设计正文迁入 Notion 单库「Autochess — 设计文档」，本地改为指针，并更新项目 harness，使 Notion 成为设计权威源。

**Architecture:** 先建私人 Hub 页，再在其下建数据库；按规格 Doc ID 表逐批 `create-pages` 导入正文；回写本地指针与 INDEX；最后改 `AGENTS.md` / rules / workflow / skills / agents，并在 Hub 写入库 URL。

**Tech Stack:** Notion MCP（`notion-create-pages`、`notion-create-database`、`notion-fetch`、`notion-search`、`notion-update-page`）；仓库 Markdown / Cursor harness。

**Spec:** `docs/superpowers/specs/2026-11-05-notion-design-docs-hub-design.md`

## Global Constraints

- Notion = 设计权威；git `Documents/` = 指针 only。
- 单一数据库；Content（含角色文档）同库，不拆角色行库。
- 不改玩法代码 / 不 bump `application/config/version`。
- 导入 Kind / Doc ID / Repo Path 必须与规格映射表一致。
- 验收：轻量文档验收（无 Godot runner）。

---

## File map

| 路径 | 职责 |
|------|------|
| Notion Hub `Project Autochess — Design Hub` | 权威说明 + 库入口 URL |
| Notion DB `Autochess — 设计文档` | 每行一篇规格，body=正文 |
| `Documents/**/*.md` | 全部改为指针模板 |
| `Documents/INDEX.md` | Hub/库入口 + Kind 链接表 |
| `AGENTS.md`, `.cursor/rules/project.mdc`, `CONTRIBUTING.md`, `Documents/DEVELOPMENT_WORKFLOW.md` | harness 权威源切换 |
| `.cursor/skills/characterdesign/SKILL.md`, `design-brainstorm/SKILL.md` | 读规格改 Notion Doc ID |
| `.cursor/agents/*.md` | 入口句改 Notion + 指针 INDEX |
| `docs/superpowers/specs/...-design.md` | 回填 Hub/DB URL（实施后） |

---

### Task 1: 创建 Hub 与数据库

**Files:**
- Create (Notion): Hub page + database
- Modify: none in git yet

**Interfaces:**
- Produces: `HUB_URL`, `DB_URL`, `DATA_SOURCE_ID` (`collection://...`) — 后续任务必须写入 harness / INDEX / 规格

- [ ] **Step 1: 创建 Hub draft 页**

用 Notion MCP `notion-create-pages`：

```json
{
  "creation_mode": "draft",
  "pages": [{
    "properties": { "title": "Project Autochess — Design Hub" },
    "content": "## 权威源\n\n本 Hub 与下方「Autochess — 设计文档」库是 Project Autochess **设计规格权威源**。仓库 `Documents/` 仅保留指针。\n\n## 库入口\n\n（导入完成后回填 database mention / URL）\n\n## 如何新增文档\n\n1. 在库中新建一行，填 Kind / Doc ID / Repo Path / Summary\n2. 在仓库对应路径新增指针 md\n3. 更新 `Documents/INDEX.md`\n\n## 历史\n\n旧 Thinkings 随想页不作根：[Project Auto Chess](https://app.notion.com/p/36df89936db68074ae15fbd88c5ec6d7)\n"
  }]
}
```

记录返回的 Hub page URL / id → `HUB_URL` / `HUB_PAGE_ID`。

- [ ] **Step 2: 在 Hub 下创建数据库**

`notion-create-database`：

```text
parent: { "page_id": "<HUB_PAGE_ID>", "type": "page_id" }
title: Autochess — 设计文档
description: Project Autochess 设计规格权威库（含 Features / Content / Reference）
schema:
CREATE TABLE (
  "Name" TITLE,
  "Kind" SELECT('Vision':blue, 'Feature':green, 'Content':purple, 'Reference':gray, 'Process':yellow, 'Arch':orange, 'Note':brown, 'Ops':red),
  "Status" SELECT('Canonical':green, 'Draft':yellow, 'Deprecated':red),
  "Repo Path" RICH_TEXT,
  "Doc ID" RICH_TEXT,
  "Summary" RICH_TEXT,
  "Last Synced" DATE
)
```

记录 `DB_URL` 与 `<data-source url="collection://...">` → `DATA_SOURCE_ID`。

- [ ] **Step 3: 冒烟**

`notion-fetch` Hub 与 data source；确认 schema 含全部列。

- [ ] **Step 4: 记录到工作笔记**

把 `HUB_URL`、`DB_URL`、`DATA_SOURCE_ID` 写进本 plan 文末「Runtime IDs」小节（同 commit 或下一 commit）。

- [ ] **Step 5: Commit（git 暂无文件变更可跳过；若已改 plan 则 commit）**

```bash
git add docs/superpowers/plans/2026-11-05-notion-design-docs-hub.md
git commit -m "docs: record Notion hub/db runtime IDs in migration plan"
```

---

### Task 2: 批量导入设计正文到 Notion

**Files:**
- Read: 全部 `Documents/**/*.md`（导入前的完整正文）
- Create (Notion): 每文件一行，parent=`data_source_id`

**Interfaces:**
- Consumes: `DATA_SOURCE_ID`；规格 Doc ID 映射表
- Produces: 每 Doc ID → Notion page URL 映射表（写入 `Documents/INDEX.md` 与指针页）

**导入规则：**
- 属性：`Name`=文件主标题或文件名；`Kind`/`Doc ID`/`Repo Path` 按规格表；`Status`=`Canonical`（`DesignNotes` → `Draft`）；`Summary`=文件首段或 INDEX 表说明截断至 ≤200 字；`date:Last Synced:start`=`2026-11-05`，`date:Last Synced:is_datetime`=`0`
- `content`：去掉 YAML 无关；尽量保留 Markdown 标题；相对链接改为 ``Doc ID `xxx` `` 或稍后第二轮替换为 Notion URL
- 分批：大文件（>20KB）每次 1–2 页；小文件每次最多 5 页；`allow_async` 仅在返回 async 时用 `get_async_task` 等待
- 失败重试单页；不要静默跳过

映射表（必须全部导入）：见规格 § Doc ID 映射（42 行，含 INDEX / WEB_DEPLOY / DesignNotes）。

- [ ] **Step 1: 从仓库读取并生成导入清单 JSON（本地临时文件）**

```bash
# 工作目录：仓库根。输出 /tmp/autochess-notion-import-manifest.json
# 字段：repo_path, doc_id, kind, name, summary, content_path
python3 - <<'PY'
# 脚本内嵌规格映射；读各 md；写 manifest
PY
```

（实现时用完整映射表；禁止漏文件。）

- [ ] **Step 2: 按批 `notion-create-pages`**

每页：

```json
{
  "parent": { "type": "data_source_id", "data_source_id": "<DATA_SOURCE_ID>" },
  "pages": [{
    "properties": {
      "Name": "GAME_VISION",
      "Kind": "Vision",
      "Status": "Canonical",
      "Repo Path": "Documents/GAME_VISION.md",
      "Doc ID": "game-vision",
      "Summary": "…",
      "date:Last Synced:start": "2026-11-05",
      "date:Last Synced:is_datetime": 0
    },
    "content": "<markdown body>"
  }]
}
```

- [ ] **Step 3: 校验行数**

`notion-search` query=`Autochess` 或 `query-data-sources` 计数 = 42；缺的补导。

- [ ] **Step 4: 写出 URL 映射**

保存 `/tmp/autochess-notion-url-map.json`：`{ "game-vision": "https://...", ... }`，供 Task 3 写指针。

- [ ] **Step 5: Commit 映射进仓库（便于 harness）**

创建：`Documents/NOTION_DOC_MAP.md`（表：Doc ID | Notion URL | Repo Path）——这是**映射索引**，不是规格正文。

```bash
git add Documents/NOTION_DOC_MAP.md
git commit -m "docs: add Notion Doc ID to URL map after import"
```

---

### Task 3: 本地 Documents 瘦身为指针

**Files:**
- Modify: 每一个原 `Documents/**/*.md`
- Modify: `Documents/INDEX.md`（总入口）
- Keep: `Documents/NOTION_DOC_MAP.md`

**指针模板（每个文件）：**

```markdown
# <原标题>

> **权威源在 Notion。** 请勿在此文件修改规格正文。

| 字段 | 值 |
|------|-----|
| Doc ID | `<doc-id>` |
| Notion | <URL> |
| Kind | `<Kind>` |

一句话：<Summary>

Hub：<HUB_URL>
```

- [ ] **Step 1: 用映射批量改写所有指针页**（脚本或逐文件 Write；保留路径）

- [ ] **Step 2: 重写 `Documents/INDEX.md`**

必须包含：Hub URL、数据库 URL、按 Kind 分组的 Notion 链接表、指向 `NOTION_DOC_MAP.md`、说明「实现权威仍在 git `resources/`」。

- [ ] **Step 3: 抽查 3 个路径**

打开 `GAME_VISION.md`、`Features/COMBAT.md`、`Content/UNITS_ROSTER.md`，确认是指针且 URL 非空。

- [ ] **Step 4: Commit**

```bash
git add Documents/
git commit -m "docs: replace Documents bodies with Notion pointer stubs"
```

---

### Task 4: 更新 harness（AGENTS / rules / workflow / CONTRIBUTING）

**Files:**
- Modify: `AGENTS.md`（「开始工作」段）
- Modify: `.cursor/rules/project.mdc`
- Modify: `Documents/DEVELOPMENT_WORKFLOW.md`（养成规范 + 文首权威说明）
- Modify: `CONTRIBUTING.md`（文档贡献）
- Modify: `docs/superpowers/specs/2026-11-05-notion-design-docs-hub-design.md`（回填 Runtime URLs）

**文案要点（必须出现）：**
- 设计意图以 Notion「Autochess — 设计文档」为准；用 Doc ID / Notion search 检索
- 本地 `Documents/` 仅指针；冲突以 Notion 为准
- Hub / DB URL 写死在 AGENTS
- 代码与 `.tres` 仍以 git 为准
- 养成规范「当前不做的默认不写进规格」仍适用，写入目标改为 Notion 页

- [ ] **Step 1: 改 `AGENTS.md` 开始工作列表前 3 条为 Notion 优先**

- [ ] **Step 2: 改 `project.mdc` 同步**

- [ ] **Step 3: 改 `DEVELOPMENT_WORKFLOW.md` 与 `CONTRIBUTING.md`**

- [ ] **Step 4: 规格文末追加 Runtime IDs**

- [ ] **Step 5: Commit**

```bash
git add AGENTS.md .cursor/rules/project.mdc Documents/DEVELOPMENT_WORKFLOW.md CONTRIBUTING.md docs/superpowers/specs/2026-11-05-notion-design-docs-hub-design.md
git commit -m "docs: point project harness at Notion design docs DB"
```

---

### Task 5: 更新 skills 与 agents 入口

**Files:**
- Modify: `.cursor/skills/characterdesign/SKILL.md`
- Modify: `.cursor/skills/design-brainstorm/SKILL.md`
- Modify: `.cursor/skills/build-multiplicative-design/SKILL.md`（若引用 Documents 规格路径）
- Modify: `.cursor/skills/apple-hig/SKILL.md`、`implement/SKILL.md`、`vertical-slice/SKILL.md`、`gui-acceptance/SKILL.md`、`verify-godot/SKILL.md`、`generate-balance-report/SKILL.md`（凡写「以 Documents/… 为准」处改为 Notion Doc ID + 指针路径）
- Modify: `.cursor/agents/*.md`（11 个）入口句

**统一替换模式：**
- 「先读 `Documents/GAME_VISION.md`」→「先用 Notion 检索 Doc ID `game-vision`（指针：`Documents/GAME_VISION.md`）」
- characterdesign checklist → Notion `content-character-design`
- agents：`先读 AGENTS.md 与 Notion 设计库（入口 Documents/INDEX.md / DEVELOPMENT_WORKFLOW 指针）`

- [ ] **Step 1: Grep 全库 `.cursor` 与根 md 中的 `Documents/` 设计引用并改完**

```bash
rg -n "Documents/(GAME_VISION|Features|Content|DEVELOPMENT)" .cursor AGENTS.md CONTRIBUTING.md
```

- [ ] **Step 2: 改 skills**

- [ ] **Step 3: 改全部 agents**

- [ ] **Step 4: Commit**

```bash
git add .cursor/
git commit -m "docs: retarget skills and agents to Notion Doc IDs"
```

---

### Task 6: Hub 回填 + 验收

**Files:**
- Update (Notion): Hub content with DB mention + 使用说明
- Verify: Notion search + 本地指针

- [ ] **Step 1: `notion-update-page` Hub**，嵌入 database / 写清 Doc ID 检索约定

- [ ] **Step 2: 验收清单**

1. Notion 行数 = 42  
2. 搜索 `game-vision`、`content-units-roster`、`feature-combat` 命中  
3. 本地三指针 URL 可打开  
4. `AGENTS.md` 含 Hub/DB URL  

- [ ] **Step 3: Push + 更新 PR 描述（含 Hub/DB 链接）**

```bash
git push -u origin cursor/notion-design-docs-hub-1f33
```

- [ ] **Step 4: 交付说明（中文）**：权威源切换结果、Hub/DB URL、未覆盖项（独立角色行库未做）

---

## Runtime IDs

| Key | Value |
|-----|-------|
| HUB_URL | _(fill after Task 1)_ |
| HUB_PAGE_ID | _(fill after Task 1)_ |
| DB_URL | _(fill after Task 1)_ |
| DATA_SOURCE_ID | _(fill after Task 1)_ |

---

## Spec coverage check

| Spec 要求 | Task |
|-----------|------|
| Hub + 单库 schema | Task 1 |
| 全量导入含 Content | Task 2 |
| 本地指针 + INDEX | Task 3 |
| harness AGENTS/rules/workflow/CONTRIBUTING | Task 4 |
| skills/agents | Task 5 |
| 验收与冲突规则落地 | Task 6 |
| 不拆角色行库 / 不改代码版本 | Global Constraints |
