# Fonts

UI Theme: `res://resources/ui/project_theme.tres`  
Composite fonts (FontVariation + CJK fallback):
- `res://resources/ui/ui_font.tres` — Theme default
- `res://resources/ui/stat_badge_font.tres` — battle stat badges / info-card titles (emboldened)

| File | Role |
|------|------|
| `NotoSans-Regular.ttf` | Latin / digits base (OFL Noto Sans) |
| `DroidSansFallback.ttf` | CJK fallback (Apache/Android) |

`DroidSansFallback` in this repo is CJK-only (no ASCII digits). Theme and badge fonts must keep the FontVariation + fallback so numbers and Chinese both render on Web/desktop without system fonts.
