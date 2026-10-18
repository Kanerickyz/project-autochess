#!/usr/bin/env python3
"""从 paper_cutout 源 spritesheet 仅提取角色格，写入 unit_*_blue/red.png。

不生成 sheet 以外的新角色剪影；红方为提取结果的阵营色相重映射。
用法：python3 tools/extract_medieval_unit_spritesheet.py
"""
from __future__ import annotations

import colorsys
import os
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(
	ROOT, "assets/sprites/paper_cutout/source/medieval_unit_spritesheet.jpg"
)
OUT_DIR = os.path.join(ROOT, "assets/sprites/paper_cutout/units")
TARGET_H = 320
PAD = 2

# 7×4 行优先，与 UNITS_ROSTER 剪影一一对应
ARCHETYPES = [
	"skeleton",
	"archer",
	"axe",
	"goblin",
	"spear_goblin",
	"shield",
	"musket",
	"rider",
	"captain",
	"valkyrie",
	"spike_shield",
	"rune_plate",
	"banner",
	"relic_aegis",
	"dirge_horn",
	"wardrum",
	"crossbow",
	"hunter",
	"maul",
	"gravewright",
	"soulcaller",
	"echo_spear",
	"blood_acolyte",
	"vita_keeper",
	"iron_heart",
	"mend_friar",
	"mirror_warden",
	"horsebow",
]
# 仅复用已提取剪影（召唤代理 / 默认矛）
ALIASES = {"spear": "spear_goblin"}


def _is_bg(r: int, g: int, b: int, thresh: int = 248, chroma: int = 20) -> bool:
	mx, mn = max(r, g, b), min(r, g, b)
	return mx >= thresh and (mx - mn) <= chroma


def flood_alpha(im: Image.Image) -> Image.Image:
	"""从边缘洪水填充去白底，保留骷髅等角色内部浅色像素。"""
	rgba = im.convert("RGBA")
	w, h = rgba.size
	px = rgba.load()
	bg = [[False] * w for _ in range(h)]
	q: deque[tuple[int, int]] = deque()
	for x in range(w):
		for y in (0, h - 1):
			r, g, b, _a = px[x, y]
			if _is_bg(r, g, b):
				bg[y][x] = True
				q.append((x, y))
	for y in range(h):
		for x in (0, w - 1):
			if bg[y][x]:
				continue
			r, g, b, _a = px[x, y]
			if _is_bg(r, g, b):
				bg[y][x] = True
				q.append((x, y))
	while q:
		x, y = q.popleft()
		for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
			if nx < 0 or ny < 0 or nx >= w or ny >= h or bg[ny][nx]:
				continue
			r, g, b, _a = px[nx, ny]
			if _is_bg(r, g, b) or _is_bg(r, g, b, thresh=242, chroma=28):
				bg[ny][nx] = True
				q.append((nx, ny))
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if bg[y][x]:
				px[x, y] = (r, g, b, 0)
			else:
				pale = max(r, g, b) >= 235 and (max(r, g, b) - min(r, g, b)) <= 30
				if pale:
					for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
						if 0 <= nx < w and 0 <= ny < h and bg[ny][nx]:
							px[x, y] = (r, g, b, int(a * 0.35))
							break
	return rgba


def trim_content(im: Image.Image) -> Image.Image:
	bbox = im.split()[-1].getbbox()
	return im.crop(bbox) if bbox else im


def fit_canvas(im: Image.Image) -> Image.Image:
	_w, h = im.size
	scale = (TARGET_H - PAD * 2) / float(h)
	nw = max(1, int(round(_w * scale)))
	nh = max(1, int(round(h * scale)))
	resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
	out = Image.new("RGBA", (nw + PAD * 2, TARGET_H), (0, 0, 0, 0))
	out.paste(resized, (PAD, TARGET_H - nh - PAD), resized)
	return out


def recolor_to_enemy(im: Image.Image) -> Image.Image:
	"""阵营色：蓝系披风/盾 → 红系；不改剪影。"""
	rgba = im.copy()
	px = rgba.load()
	w, h = rgba.size
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if a < 8:
				continue
			mx, mn = max(r, g, b), min(r, g, b)
			if (mx - mn) / 255.0 < 0.12:
				continue
			h_, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
			if 0.50 <= h_ <= 0.72 and s >= 0.18:
				nh = (h_ - 0.58) * 0.15
				if nh < 0:
					nh += 1.0
				rr, gg, bb = colorsys.hsv_to_rgb(
					nh, min(1.0, s * 1.05), min(1.0, v * 0.98)
				)
				px[x, y] = (int(rr * 255), int(gg * 255), int(bb * 255), a)
			elif 0.48 <= h_ <= 0.70 and s >= 0.10 and v < 0.85:
				rr, gg, bb = colorsys.hsv_to_rgb(0.02, min(1.0, s * 1.1), v)
				px[x, y] = (int(rr * 255), int(gg * 255), int(bb * 255), a)
	return rgba


def main() -> None:
	sheet = Image.open(SRC).convert("RGB")
	W, H = sheet.size
	cols, rows = 4, 7
	cw, ch = W // cols, H // rows
	assert len(ARCHETYPES) == cols * rows
	os.makedirs(OUT_DIR, exist_ok=True)
	extracted: dict[str, Image.Image] = {}
	for i, name in enumerate(ARCHETYPES):
		col, row = i % cols, i // cols
		cell = sheet.crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch))
		fitted = fit_canvas(trim_content(flood_alpha(cell)))
		extracted[name] = fitted
		fitted.save(os.path.join(OUT_DIR, f"unit_{name}_blue.png"), "PNG")
		recolor_to_enemy(fitted).save(os.path.join(OUT_DIR, f"unit_{name}_red.png"), "PNG")
		print(f"{name}: {fitted.size}")
	for alias, src_name in ALIASES.items():
		src = extracted[src_name]
		src.save(os.path.join(OUT_DIR, f"unit_{alias}_blue.png"), "PNG")
		recolor_to_enemy(src).save(os.path.join(OUT_DIR, f"unit_{alias}_red.png"), "PNG")
		print(f"alias {alias} <- {src_name}")


if __name__ == "__main__":
	main()
