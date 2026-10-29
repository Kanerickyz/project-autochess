# Web 部署（GitHub Pages）

浏览器试玩入口：由 GitHub Actions 用 Godot **4.6.3** 导出单线程 HTML5，再部署到 GitHub Pages。

导出预设名：`Web`（见根目录 [`export_presets.cfg`](../export_presets.cfg)）。`variant/thread_support=false`，不依赖 SharedArrayBuffer / COOP-COEP，适合普通 Pages 托管。

## 你需要在 GitHub 网页端做的一次设置

1. 打开仓库 **Settings → Pages**。
2. **Build and deployment → Source** 选 **GitHub Actions**。
3. （可选）确认 **Actions** 已启用；首次部署时若提示授权 `github-pages` environment，点 Approve。

推送到 `main`，或到 **Actions → Deploy Web → Run workflow**，都会构建并尝试部署。

预期地址（仓库名 `project-autochess`）：

`https://kanerickyz.github.io/project-autochess/`

## 部署并发与防卡死

工作流 `.github/workflows/deploy-web.yml` 对齐官方 Pages starter：

- `concurrency.group: pages-deploy`
- **`cancel-in-progress: false`**（禁止改回 `true`）

原因：中途 Cancel / 打断进行中的 `deploy-pages` 容易把 `github-pages` 环境留在 **waiting** / Pages 状态 **building**。该状态不算 in progress，普通 **Cancel** 无效，同组后续 run 会一直 **queued**。

GitHub 在同组有新 run 排队时会取消**更早的 pending**，只保留进行中的那次 + 最新排队；因此连推 `main` 时中间提交会被跳过，最终以最新一次部署为准——这是预期行为。

### 若再次卡住（waiting / queued / Pages building 过久）

1. 对本机有写权限的 `gh` 执行 **force-cancel**（普通 Cancel 对 waiting/queued 常失败）：

```bash
# 先列出未完成的 Deploy Web
gh run list --workflow=deploy-web.yml --limit 10

# 对卡住的 run id：
gh api -X POST repos/OWNER/REPO/actions/runs/RUN_ID/force-cancel
```

网页：打开该 run → 右上角 `···` → **Force cancel workflow**。

2. 确认 **Settings → Pages → Source** 仍为 **GitHub Actions**（不要长期切成 Deploy from a branch，以免和本工作流抢部署）。

3. 若 Pages 状态长时间 **building** 且部署 `error`：把 Source 暂时改成非 GitHub Actions，保存后再改回 **GitHub Actions**，然后 **Actions → Deploy Web → Run workflow**。

4. 不要在 `deploy` 已开始（或环境 waiting）时连点 Cancel；需要中止时用 force-cancel，并准备好重新 **Run workflow**。

## 私有仓库注意

当前仓库是 **Private**。GitHub Pages 对私有库需要 **Pro / Team / Enterprise**（免费账号仅 Public 可用 Pages）。

若 Pages 部署失败（权限 / 套餐），仍可：

1. 打开 **Actions → Deploy Web** 最新成功 run。
2. 下载 Artifact **`web-build`**。
3. 解压后在本地起静态服务，例如：

```bash
cd path/to/web-build
python3 -m http.server 8080
```

浏览器打开 `http://localhost:8080`。

## 项目侧前提

- 渲染器为 **GL Compatibility**（WebGL 2；Forward Plus 无法上浏览器）。
- 本地手动导出（需已装匹配版本的 export templates）：

```bash
godot --headless --path . --import || true
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
```

`build/` 与 `Exported/` 已在 `.gitignore`，不要提交导出产物。

## 已知 Web 差异

- 主菜单 **退出** 在 Web 上隐藏（浏览器无法可靠关标签）。
- 全屏依赖用户手势；启动时不会自动全屏。
- 无声卡 / 浏览器自动播放策略下音频可能需先点一下页面。
- 画布仍用 Adaptive 铺满浏览器；项目默认 viewport 为 **竖屏 393×852**（iPhone 14 Pro 逻辑点），`stretch/aspect=expand`；宽屏浏览器会按 expand 铺满，布局以手机优先。
- 试玩地址（public 库 Pages 已开）：`https://kanerickyz.github.io/project-autochess/`（推 `main` 或手动跑 Deploy Web 后更新）。

## 平衡报告（`/balancereport/`）

静态页：`docs/balancereport/index.html`  
线上：**https://kanerickyz.github.io/project-autochess/balancereport/**

| 触发 | 工作流 | 行为 |
|------|--------|------|
| 推 **`balance-eval`** | `Balance Report Pages` | headless 跑局（默认 100）→ 生成 `summary.json` → 导出 Web → 部署（含游戏根路径 + `/balancereport/`） |
| 推 **`main`** | `Deploy Web` | 导出 Web；若仓库里有 `docs/balancereport/summary.json` 一并打包，否则仅 HTML |

专用评估分支用法：

```bash
git fetch origin
git checkout -b balance-eval origin/main   # 首次
# …改数值 / SimAIProfile / 关卡…
git push -u origin balance-eval
```

手动重跑：Actions → **Balance Report Pages** → Run workflow（可改 runs / seed_start）。

与 Deploy Web 共用 `concurrency.group: pages-deploy`，避免两个部署互相覆盖 Pages 站点。
