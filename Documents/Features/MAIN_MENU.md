# 主菜单

> Features · 局外入口 · **【用户新共识 · 2026-10-26】** 动态背景  
> 相关：[GAME_LOOP.md](./GAME_LOOP.md) · [GAME_VISION.md](../GAME_VISION.md) · 实现 `scenes/main/main_menu.tscn`

## 1. 是什么

主菜单是局外 Hub：开始爬塔、无尽、角色库、沙盒、附魔试验场、设置（Web 无退出）。本篇约定**动态背景**的玩家体验与验收；按钮/Logo 布局 As-Is 不变。

## 2. 动态背景【用户新共识】

| 项 | 定稿 |
|----|------|
| **意象** | **甲**：营地 / 城堡**远景**视差（偏尖塔营地感 + 中世纪纸面） |
| **指针视差** | **A**：支持鼠标 / 手指轻微跟手（幅度克制） |
| **层次（To-Be 美术）** | 远：天空/远山/城堡剪影；中：营地/旗/火把；近：纸剪装饰飘过或轻摆；最前：Logo+按钮（安全区少动） |
| **节奏** | 比 Balatro 更慢、更沉；不霓虹刷屏 |
| **性能** | 优先少量全屏分层，控 draw；须兼容 **GL Compatibility** / Web |
| **降级（【建议】v2）** | 设置「菜单动效 高/低/关」；关 = 静态 `menu_background.jpg` |

## 3. As-Is 实现

- 代码：`MainMenuParallaxBackground` + `main_menu_background.gdshader` — 底图 `menu_background.jpg`；**纸面格纹**在 Shader 内自**右上向左下**持续滚动；指针仅轻微改 `pointer_offset`。
- 待美术：分层远景 PNG 仍可作为 `bg_texture` 或额外采样层替换占位图。
- 静态回退：可将场景 `Background` 改回单 `TextureRect`（或接设置关动效）。

## 4. 验收（GUI）

1. 主菜单停留 5s：能明显看到格纹沿右上→左下漂移；中央 Logo/按钮仍可读。  
2. 移动指针/手指：底图与格纹有轻微跟手，无晕眩感。  
3. Web 与桌面：无明显掉帧（目标 30fps+）。  
4. 从主菜单进入各入口再返回：背景状态正常、无泄漏 Tween。
