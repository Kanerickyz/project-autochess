# Fonts

UI Theme: `res://resources/ui/project_theme.tres`  
Composite font: `res://resources/ui/ui_font.tres` (FontVariation)

| File | Role |
|------|------|
| `NotoSans-Regular.ttf` | Latin / digits base (OFL Noto Sans) |
| `DroidSansFallback.ttf` | CJK fallback (Apache/Android) |

`DroidSansFallback` in this repo is CJK-only (no ASCII digits). Theme default font must be the FontVariation so numbers and Chinese both render on Web/desktop without system fonts.
