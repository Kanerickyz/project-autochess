---
name: generate-balance-report
description: Sync balance-eval with main, ask run count, archive sim batch under docs/balancereport only, push to main, wait for Pages deploy, return report URL. Use when the user wants a balance report on GitHub Pages or to refresh /balancereport/ data.
---

# generate-balance-report

在 **`balance-eval`** 上对齐最新 **`main`**，跑 headless 批量模拟，**只**改 `docs/balancereport/` 并推到 **`main`**，等 **Deploy Web** 成功后把 Pages 网址交给用户。

与主游戏路径隔离：跑局在 `scripts/sim_balance/`；归档脚本 `tools/sim_balance/archive_batch_report.py`；**禁止**在报告流程里改 `scripts/`、`resources/`、`project.godot`（版本号）、场景等。

## 开工前（主代理必做）

1. **确认分支**：工作在 **`balance-eval`**（首次：`git fetch origin && git checkout -B balance-eval origin/main`）。
2. **询问局数**：「要跑几次？」默认 **100**；未回答则用 100。
3. **必须询问 Sim 策略**（未回答则停步再问）：
   - **默认启发式**（`default`，不传 checkpoint）
   - **bandit-v1** / **bandit-v2**（旧：槽位 bandit + 选路 bandit）
   - **bandit-v4**（推荐：`bandit_v4.tres`，**按 unit_id 招募** + 当前队伍 state；选路启发式）
4. **可选询问**（用户未提则不主动拖长）：起始 seed，默认 **1**（与 CI `BALANCE_SEED_START` 一致）。
5. **验收方式**：本技能默认 **轻量**（跑批 + 归档 + 部署）；不代做 GUI 图表审美验收。

## 与 main 同步（步骤 1）

在 **`balance-eval`** 上，动手跑局**之前**：

```bash
git fetch origin main
git merge origin/main
# 有冲突：按 CONTRIBUTING 解决后再继续；不要带着未解决冲突跑批
```

禁止在陈旧、未 merge `origin/main` 的 `balance-eval` 上直接跑批（避免报告与线上代码版本错位）。

## 生成报告

### 路径 A — 本地跑批 + 只提交报告目录（代理有 Godot 时）

```bash
RUNS=100          # 来自用户回答，默认 100
SEED_START=1
# SIM_POLICY: default | bandit-v1 | bandit-v2 | bandit-v4
SIM_POLICY=bandit-v4
BATCH_OUT="$(mktemp -d)/sim_balance_batch"
mkdir -p "$BATCH_OUT"

if [ "$SIM_POLICY" = "bandit-v4" ]; then
  CKPT="res://resources/sim_balance/checkpoints/bandit_v4.tres"
  bash tools/sim_balance/run_batch.sh "$RUNS" "$SEED_START" "$BATCH_OUT" --checkpoint "$CKPT"
elif [ "$SIM_POLICY" = "bandit-v2" ]; then
  CKPT="res://resources/sim_balance/checkpoints/bandit_v2.tres"
  bash tools/sim_balance/run_batch.sh "$RUNS" "$SEED_START" "$BATCH_OUT" --checkpoint "$CKPT"
elif [ "$SIM_POLICY" = "bandit-v1" ]; then
  CKPT="res://resources/sim_balance/checkpoints/bandit_v1.tres"
  bash tools/sim_balance/run_batch.sh "$RUNS" "$SEED_START" "$BATCH_OUT" --checkpoint "$CKPT"
else
  bash tools/sim_balance/run_batch.sh "$RUNS" "$SEED_START" "$BATCH_OUT"
fi
test -f "$BATCH_OUT/summary.json"

export GITHUB_REF_NAME=balance-eval
export GITHUB_SHA="$(git rev-parse HEAD)"
RUN_ID="$(python3 tools/sim_balance/archive_batch_report.py "$BATCH_OUT" "$PWD")"
test -f "docs/balancereport/runs/${RUN_ID}/summary.json"
```

归档行为（勿重复实现）：

- 新增 `docs/balancereport/runs/<run_id>/summary.json`
- 更新 `docs/balancereport/manifest.json`（**最多保留 100 份**，更旧目录会被脚本删除）
- 覆盖 `docs/balancereport/summary.json`（仅「最新一次」镜像，不是历史删除）

可选烟测（改 sim 代码后）：`bash tools/run_sim_balance_verify.sh`（1 局，快）。

Sim 策略见 `Documents/Features/SIM_BALANCE_AI.md`。Bandit **仅评估**：checkpoint 冻结，100 局内不更新表；与 `default` 报告分 `ai_profile_id` 存档。

### 路径 B — 交给 CI（本地无 Godot 或用户指定 Actions）

1. 确保 **`balance-eval`** 已 merge **`origin/main`** 并已 push 评估分支上的**玩法/数值改动**（若有）。
2. GitHub → **Actions → Balance Report Pages → Run workflow**，填写 **runs**（默认 100）、**seed_start**（默认 1）；或 **`git push origin balance-eval`** 触发。
3. CI 会在 runner 上跑批、归档，并 **只** commit `docs/balancereport/**` 到 **`main`**（见 `.github/workflows/balance-report-pages.yml`）。

路径 A 与 B **二选一**；不要同一次任务里又本地 push `main` 又 push `balance-eval` 触发 CI，避免重复跑 100 局、重复归档。

## 推送到 main（步骤 3 — 仅路径 A）

**只允许**下列路径进入 commit：

- `docs/balancereport/manifest.json`
- `docs/balancereport/summary.json`
- `docs/balancereport/runs/<run_id>/`（及 retention 导致的 `runs/` 下删除）

推荐与 CI 相同的安全写法（避免把 `balance-eval` 上其它改动带进 `main`）：

```bash
RUN_ID="<上一步输出的 id>"

STAGING="$(mktemp -d)/balancereport-staging"
mkdir -p "$STAGING/runs/${RUN_ID}"
cp docs/balancereport/manifest.json docs/balancereport/summary.json "$STAGING/"
cp "docs/balancereport/runs/${RUN_ID}/summary.json" "$STAGING/runs/${RUN_ID}/"

git fetch origin main
git checkout main
git pull --ff-only origin main

mkdir -p "docs/balancereport/runs/${RUN_ID}"
cp "$STAGING/manifest.json" "$STAGING/summary.json" docs/balancereport/
cp "$STAGING/runs/${RUN_ID}/summary.json" "docs/balancereport/runs/${RUN_ID}/"

git add docs/balancereport/manifest.json docs/balancereport/summary.json docs/balancereport/runs/
git diff --staged --stat
# 确认：staged 文件全部在 docs/balancereport/ 下；若有其它路径 → 中止并修复

git commit -m "chore(balancereport): archive sim batch ${RUN_ID}"
git push origin main
```

**不要**：

- `git push origin balance-eval:main` 或把整分支推到 `main`
- 在报告 commit 里 bump `project.godot` 版本号
- 提交 `.artifacts/`、`build/`、`.godot/`

## 等待部署（步骤 4）

固定 Pages 地址（仓库名 `project-autochess`）：

**https://kanerickyz.github.io/project-autochess/balancereport/**

| 触发方式 | 要等的 workflow |
|----------|-----------------|
| **路径 A**：人/代理 `git push origin main` | **Deploy Web**（`push` → `main`） |
| **路径 B**：CI 归档 commit（`github-actions[bot]`） | 先 **Balance Report Pages** 成功，再 **Deploy Web**（`workflow_run`；bot 的 push **不会**触发普通 `push` 部署） |

用 `gh run watch` 或 Actions UI 等到 **Deploy Web** `conclusion=success`。可选校验：

```bash
curl -sf "https://kanerickyz.github.io/project-autochess/balancereport/manifest.json" | head
curl -sf "https://kanerickyz.github.io/project-autochess/balancereport/summary.json" | head
```

交付给用户：

- 报告页 URL（上）
- 本次 `run_id`、`game_version`、局数、`run_complete_rate` 等一两句摘要
- 若 Deploy 失败或 `summary.json` 404：说明卡在哪条 workflow，**不要**声称已发布

## 相关文档

- `docs/balancereport/README.md` — Schema 1.0、目录约定
- `Documents/WEB_DEPLOY.md` — Pages 并发、`workflow_run` 说明
- `tools/sim_balance/README.md` — 本地批跑与归档
