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
