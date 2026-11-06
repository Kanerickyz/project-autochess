# UI Kit（里程碑 B）

统一 Panel / Popup / Button 样式与工厂。**禁止**新屏 `StyleBoxFlat.new()` 充当主题色。

## 快速用法

```gdscript
# 1) 挂 Theme
UiKit.apply_shell_theme(self)  # 或 theme = UiKit.shell_theme()

# 2) 壳内常驻块
var dock := UiKit.make_dock_panel()
var hero := UiKit.make_hero_panel()

# 3) 按钮（每阶段只强调一个 Primary）
var go := UiKit.make_primary_button("开战")
var back := UiKit.make_secondary_button("返回")

# 4) Popup（主右/次左；dismiss_on_dim 可关）
var popup := UiKit.instantiate_popup()
add_child(popup)
popup.configure("确认出售", "该单位将离开队伍", "出售", "取消")
popup.dismiss_on_dim = true
popup.primary_pressed.connect(_on_sell)
popup.open()
```

## Theme 变体

| 变体 | 基类 | 用途 |
|------|------|------|
| `ShellPanel` | PanelContainer | 壳内常驻 |
| `FloatingPanel` | PanelContainer | 单位信息卡等 |
| `KitPopupPanel` | PanelContainer | Popup 内容板（引擎已占用 `PopupPanel` 类名） |
| `DockPanel` | PanelContainer | ActionDock |
| `HeroPanel` | PanelContainer | 敌/我英雄信息带 |
| `ToastPanel` | PanelContainer | Toast |
| `Primary` / `Secondary` / `Icon` | Button | CTA 层级 |

资源：`res://resources/ui/ui_shell_theme.tres`  
色 token：`UiKit.COLOR_HP_ENEMY` / `COLOR_HP_ALLY` / `COLOR_GOLD` / `COLOR_DIM`

## 其它 Widget

- `ModalScreen`：近全屏重流程，默认点遮罩不关，须有关闭钮
- `GameToast`：自动消失提示
- `ShellPanel`：场景可挂脚本并选 `panel_kind`
- `UiMotion`：按下缩放 / 面板淡入淡出共用参数

## 接到 realtime_battle

主代理后续：根 `Control` 设 `theme = UiKit.shell_theme()`；Hero/Dock 换 `ShellPanel`/`DockPanel`；店\|事与确认改用 `GamePopup`；逐步删 `StyleBoxFlat.new()`。
