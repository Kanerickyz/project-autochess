# 平衡报告（GitHub Pages）

线上地址（仓库名 `project-autochess`）：

**https://kanerickyz.github.io/project-autochess/balancereport/**

## 归档（不覆盖历史）

每次 CI 跑局会新增一份报告，**不会删除旧报告**：

| 路径 | 含义 |
|------|------|
| `runs/<run_id>/summary.json` | 单次批量模拟的完整 Schema 1.0 报告（永久保留在 Git） |
| `manifest.json` | 索引：`runs[]` 列表 + `latest_run_id` |
| `summary.json` | 与最新一次归档相同（兼容旧链接 / 默认加载） |

`run_id` 示例：`2026-10-29T13-02-00Z_100runs_v0.5.254_abc1234`（时间、局数、游戏版本、提交短 SHA）。

报告页可通过下拉框切换历史 `runs/` 中的任意一份。

## summary.json 规范（Schema 1.0）

每份报告必须包含：

| 字段 | 含义 |
|------|------|
| `report_schema_version` | 当前 `"1.0"` |
| `game_version` | `project.godot` → `application/config/version`（与主菜单 `v…` 一致） |
| `kpis[]` | 顶栏 KPI：`id` / `label` / `value` / `format` |
| `charts[]` | 规范图表块，报告页按此渲染 |

每个 `charts[]` 元素：

| 字段 | 含义 |
|------|------|
| `id` | 稳定标识（如 `encounter_win_rate_by_floor`） |
| `title` | 图表标题 |
| `chart_type` | `bar` / `line` / `doughnut` |
| `x_label` / `y_label` | 轴说明 |
| `description` | 指标定义（人读） |
| `labels` | X 轴类目 |
| `datasets[]` | `{ series_id, label, values }` |

默认 5 张图：遭遇胜率、遭遇失败率、样本量、死亡层直方图、Run 结局环图。

## 分支与工作流

| 触发 | 工作流 | 行为 |
|------|--------|------|
| 推 **`balance-eval`** 或手动 **Balance Report Pages** | 跑局 → 写入 `docs/balancereport/runs/` + 更新 `manifest.json` → **提交并 push `main`** |
| 推 **`main`** | **Deploy Web** | 导出试玩 + 打包整个 `docs/balancereport/`（含全部历史 `runs/`） |

本地生成并归档：

```bash
bash tools/sim_balance/run_batch.sh 100 1 /tmp/batch
python3 tools/sim_balance/archive_batch_report.py /tmp/batch
```

然后用 `tools/sim_balance/sim_report.html` 或本目录 `index.html` 查看（需本地静态服务）。
