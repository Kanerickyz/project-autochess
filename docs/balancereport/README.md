# 平衡报告（GitHub Pages）

线上地址（仓库名 `project-autochess`）：

**https://kanerickyz.github.io/project-autochess/balancereport/**

## 分支与工作流

| 分支 | 作用 |
|------|------|
| `main` | 游戏 Web 导出 + 静态报告页（无新 summary 时仅 HTML） |
| **`balance-eval`** | 平衡性评估专用：push 触发 **Balance Report Pages**，headless 跑 100 局 → 刷新 `summary.json` → 与 Web 一并部署 |

手动重跑：GitHub **Actions → Balance Report Pages → Run workflow**（可选 runs / seed）。

## 本地

与 `tools/sim_balance/run_batch.sh` 输出一致；Pages 使用本目录的 `index.html` + CI 生成的 `summary.json`（不入库亦可，由 Actions 打进 Pages artifact）。
