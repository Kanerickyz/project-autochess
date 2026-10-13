# Fonts

UI Theme: `res://resources/ui/project_theme.tres`  
Composite font: `res://resources/ui/ui_font.tres` (FontVariation)

| File | Role |
|------|------|
| `NotoSans-Regular.ttf` | Latin / digits base (OFL Noto Sans) |
| `DroidSansFallback.ttf` | CJK fallback（Apache/Android；**已按仓库文案子集化**，显著减小 Web 包与启动解析） |

`DroidSansFallback` 在此仓库为 CJK 子集（无完整字库）。Theme 默认字体必须是 FontVariation，这样 Web/桌面都能同时显示数字与中文，不依赖系统字体。

若 UI 出现缺字方框：把缺字补进文案后，用 `fontTools.pyftsubset` 以仓库 `.gd/.tscn/.tres` 中的非 ASCII 字符重新子集，覆盖本文件并重新 import。
