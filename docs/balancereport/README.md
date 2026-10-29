# 平衡报告（GitHub Pages）

线上地址（仓库名 `project-autochess`）：

**https://kanerickyz.github.io/project-autochess/balancereport/**

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

| 分支 | 作用 |
|------|------|
| `balance-eval` | push → **Balance Report Pages**（100 局 + 部署） |
| `main` | **Deploy Web** 打包静态 `index.html` + `report.js` |

本地生成： `bash tools/run_sim_balance_verify.sh` 或 `run_batch.sh` → 用 `tools/sim_balance/sim_report.html` + `report.js` 打开 `summary.json`。
