#!/usr/bin/env python3
"""Cut the concept-derived paper-cutout art into game assets.

Sources (art_source/paper_cutout/, ignored by Godot):
  arena_background.jpg   empty clearing edited from concept_reference.jpg
  units_sheet_a.jpg      2x2 blue stickers: shield, archer, axe, captain
  units_sheet_b.jpg      2x2 blue stickers: spear, musket, banner, skeleton
  units_sheet_c..g.jpg   2x2 blue stickers, one per remaining unit (see SHEETS)
  stat_badges_sheet.jpg  attack (sword) and HP (heart) tags without numbers

Output:
  assets/sprites/paper_cutout/env/arena_background.jpg
  assets/sprites/paper_cutout/units/unit_<sprite_key>_{blue,red}.png
  assets/sprites/paper_cutout/ui/stat_{attack,hp}.png

Red variants recolor only the cobalt cloth so both teams keep identical silhouettes.

units_sheet_h.jpg is a 4×3 neutral-gray grid (256px cells) for the twelve
units that used the DEV placeholder. `python3 tools/process_paper_cutout_art.py sheet-h`
writes only those stickers. Canvas height matches the other unit stickers (320px).
The figure itself is drawn at CONTENT_SCALE and narrow stickers are padded out to
MIN_ASPECT, because the battlefield sizes a sprite by its texture aspect and a
narrow sticker would otherwise stand taller than the other infantry. Feet stay
on the bottom edge of the canvas.
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "art_source" / "paper_cutout"
ENV = ROOT / "assets" / "sprites" / "paper_cutout" / "env"
UNITS = ROOT / "assets" / "sprites" / "paper_cutout" / "units"
UI = ROOT / "assets" / "sprites" / "paper_cutout" / "ui"

## (sheet, 2x2 sprite keys, edge_connected_only keying). Sheets c-g are one sprite per unit.
SHEETS = [
	("units_sheet_a.jpg", ["shield", "archer", "axe", "captain"], False),
	("units_sheet_b.jpg", ["spear", "musket", "banner", "skeleton"], False),
	("units_sheet_c.jpg", ["crossbow", "horsebow", "rider", "hunter"], True),
	("units_sheet_d.jpg", ["maul", "valkyrie", "giant_knight", "spike_shield"], True),
	("units_sheet_e.jpg", ["rune_plate", "relic_aegis", "mirror_warden", "dirge_horn"], True),
	("units_sheet_f.jpg", ["wardrum", "echo_spear", "spear_goblin", "goblin"], True),
	("units_sheet_g.jpg", ["gravewright", "soulcaller", "ram", "slime"], True),
]
UNIT_MAX_HEIGHT = 320
BADGES = ["attack", "hp"]
BADGE_SIZE = (192, 120)
## Brick red from the art brief (#B03A32), as HSV hue in [0, 1).
BRICK_HUE = 4.0 / 360.0


def key_out_backdrop(rgb: np.ndarray, edge_connected_only: bool = False) -> np.ndarray:
	"""Alpha mask that drops the flat magenta backdrop and keeps the cream sticker edge.

	edge_connected_only keeps magenta-like pixels inside the sticker (red hearts, coral fill).
	"""
	r = rgb[..., 0].astype(np.int32)
	g = rgb[..., 1].astype(np.int32)
	b = rgb[..., 2].astype(np.int32)
	backdrop = (r > 140) & (g < 90) & (r - g > 110) & (b > 50) & (b < 170)
	if edge_connected_only:
		labels, _count = ndimage.label(backdrop)
		edge = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
		outside = np.isin(labels, edge[edge > 0])
		# Enclosed gaps (inside a bow string, under a lance) have a backdrop-coloured median;
		# red props (hearts, embers) do not.
		ref = np.median(rgb[outside], axis=0).astype(np.int32)
		for idx in range(1, _count + 1):
			if idx in edge:
				continue
			region = labels == idx
			median = np.median(rgb[region], axis=0).astype(np.int32)
			if np.abs(median - ref).max() < 30:
				outside |= region
		# JPEG fringe: magenta-tinted pixels hugging a removed area.
		fringe = (r - g > 80) & (g < 110) & (b > 45) & (b - g > 20)
		backdrop = outside | (ndimage.binary_dilation(outside, iterations=3) & fringe)
	keep = Image.fromarray(np.where(backdrop, 0, 255).astype(np.uint8), mode="L")
	# Eat the 1px pink fringe JPEG leaves around the cream border, then soften.
	keep = keep.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
	return np.array(keep)


def keep_largest_blob(im: Image.Image) -> Image.Image:
	"""Drop slivers of neighbouring stickers that cross the quadrant line."""
	rgba = np.array(im)
	solid = rgba[..., 3] > 16
	labels, count = ndimage.label(solid)
	if count <= 1:
		return im
	sizes = ndimage.sum(solid, labels, range(1, count + 1))
	main = int(np.argmax(sizes)) + 1
	rgba[..., 3] = np.where(labels == main, rgba[..., 3], 0)
	return Image.fromarray(rgba, mode="RGBA")


def crop_to_alpha(im: Image.Image, pad: int = 4) -> Image.Image:
	bbox = im.getchannel("A").point(lambda a: 255 if a > 16 else 0).getbbox()
	if bbox is None:
		return im
	x0, y0, x1, y1 = bbox
	return im.crop((max(0, x0 - pad), max(0, y0 - pad), min(im.width, x1 + pad), min(im.height, y1 + pad)))


def to_red_team(im: Image.Image) -> Image.Image:
	rgba = np.array(im.convert("RGBA"))
	hsv = np.array(im.convert("RGB").convert("HSV")).astype(np.float32) / 255.0
	h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
	cloth = (h > 0.54) & (h < 0.75) & (s > 0.28) & (v > 0.12)
	h = np.where(cloth, BRICK_HUE, h)
	s = np.where(cloth, np.clip(s * 0.92, 0.0, 1.0), s)
	v = np.where(cloth, np.clip(v * 0.94, 0.0, 1.0), v)
	out = np.stack([h, s, v], axis=-1)
	rgb = np.array(Image.fromarray((out * 255.0).astype(np.uint8), mode="HSV").convert("RGB"))
	rgba[..., :3] = np.where(cloth[..., None], rgb, rgba[..., :3])
	return Image.fromarray(rgba, mode="RGBA")


def cut_sheet(path: Path, names: list[str], edge_connected_only: bool) -> None:
	sheet = Image.open(path).convert("RGB")
	rgb = np.array(sheet)
	alpha = key_out_backdrop(rgb, edge_connected_only)
	rgba = np.dstack([rgb, alpha])
	full = Image.fromarray(rgba, mode="RGBA")
	half_w, half_h = sheet.width // 2, sheet.height // 2
	for i, name in enumerate(names):
		x = (i % 2) * half_w
		y = (i // 2) * half_h
		piece = crop_to_alpha(keep_largest_blob(full.crop((x, y, x + half_w, y + half_h))))
		if piece.height > UNIT_MAX_HEIGHT:
			w = round(piece.width * UNIT_MAX_HEIGHT / piece.height)
			piece = piece.resize((w, UNIT_MAX_HEIGHT), Image.Resampling.LANCZOS)
		piece.save(UNITS / f"unit_{name}_blue.png")
		to_red_team(piece).save(UNITS / f"unit_{name}_red.png")
		print(f"unit_{name}: {piece.size}")


def cut_badges(path: Path) -> None:
	"""Left half = attack tag, right half = HP tag; both resized to one size so every badge matches."""
	sheet = Image.open(path).convert("RGB")
	rgb = np.array(sheet)
	full = Image.fromarray(np.dstack([rgb, key_out_backdrop(rgb, edge_connected_only=True)]), mode="RGBA")
	half_w = sheet.width // 2
	for i, name in enumerate(BADGES):
		piece = crop_to_alpha(keep_largest_blob(full.crop((i * half_w, 0, (i + 1) * half_w, sheet.height))), pad=2)
		piece = piece.resize(BADGE_SIZE, Image.Resampling.LANCZOS)
		piece.save(UI / f"stat_{name}.png")
		print(f"stat_{name}: {piece.size}")


## 4×3, row-major, one sticker per 256 cell. Neutral backdrop (not magenta).
SHEET_H_NAMES = [
	"shinobi", "devour", "blade_mender", "aftershock",
	"edge_hex", "shield_boon", "paymaster", "wergild",
	"coffer_ward", "blood_wage", "scatter_hex", "funeral_pyre",
]
SHEET_H_CELL = 256
## Canvas height matches existing stickers. The figure is slightly smaller inside
## that canvas so these twelve read the same size as the other infantry.
STICKER_HEIGHT = 320
STICKER_PAD = 2
CONTENT_SCALE = 0.88
## tex width / height. Below this, the battlefield width cap stretches the sprite taller.
MIN_ASPECT = 1.0


def key_out_neutral(rgb: np.ndarray) -> np.ndarray:
	"""Drop a flat light backdrop sampled from the corner. Keep the cream sticker edge."""
	bg = np.median(rgb[:12, :12], axis=(0, 1)).astype(np.int32)
	diff = np.max(np.abs(rgb.astype(np.int32) - bg.reshape(1, 1, 3)), axis=-1)
	rough = diff <= 18
	labels, count = ndimage.label(rough)
	edge = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
	outside = np.isin(labels, edge[edge > 0])
	ref = np.median(rgb[outside], axis=0).astype(np.int32)
	edge_ids = set(int(v) for v in edge.tolist())
	for idx in range(1, count + 1):
		if idx in edge_ids:
			continue
		region = labels == idx
		if int(region.sum()) > 8000:
			continue
		median = np.median(rgb[region], axis=0).astype(np.int32)
		if np.abs(median - ref).max() <= 14:
			outside |= region
	sat = rgb.astype(np.int32)
	sat = sat.max(axis=-1) - sat.min(axis=-1)
	fringe = (diff <= 36) & ndimage.binary_dilation(outside, iterations=2) & (sat < 28)
	backdrop = outside | fringe
	keep = Image.fromarray(np.where(backdrop, 0, 255).astype(np.uint8), mode="L")
	keep = keep.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.55))
	return np.array(keep)


def _fit_sticker_height(im: Image.Image) -> Image.Image:
	"""Fit one sticker: feet on the bottom, figure at CONTENT_SCALE, canvas at least square."""
	tight = crop_to_alpha(im, pad=0)
	full_h = STICKER_HEIGHT - STICKER_PAD * 2
	full_w = max(1, round(tight.width * full_h / max(1, tight.height)))
	scaled_h = max(1, round(full_h * CONTENT_SCALE))
	scaled_w = max(1, round(full_w * CONTENT_SCALE))
	sprite = tight.resize((scaled_w, scaled_h), Image.Resampling.LANCZOS)
	canvas_h = STICKER_HEIGHT
	canvas_w = max(full_w + STICKER_PAD * 2, round(canvas_h * MIN_ASPECT))
	canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
	x = (canvas_w - scaled_w) // 2
	y = canvas_h - STICKER_PAD - scaled_h
	canvas.paste(sprite, (x, y), sprite)
	return canvas


def cut_neutral_grid(path: Path, names: list[str], cell: int) -> None:
	sheet = Image.open(path).convert("RGB")
	rgb = np.array(sheet)
	alpha = key_out_neutral(rgb)
	full = Image.fromarray(np.dstack([rgb, alpha]), mode="RGBA")
	cols = sheet.width // cell
	for i, name in enumerate(names):
		x = (i % cols) * cell
		y = (i // cols) * cell
		piece = _fit_sticker_height(full.crop((x, y, x + cell, y + cell)))
		piece.save(UNITS / f"unit_{name}_blue.png")
		to_red_team(piece).save(UNITS / f"unit_{name}_red.png")
		print(f"unit_{name}: {piece.size}")


def main() -> None:
	ENV.mkdir(parents=True, exist_ok=True)
	UNITS.mkdir(parents=True, exist_ok=True)
	UI.mkdir(parents=True, exist_ok=True)
	shutil.copyfile(SRC / "arena_background.jpg", ENV / "arena_background.jpg")
	for sheet, names, edge_only in SHEETS:
		cut_sheet(SRC / sheet, names, edge_only)
	cut_badges(SRC / "stat_badges_sheet.jpg")


if __name__ == "__main__":
	if len(sys.argv) > 1 and sys.argv[1] == "sheet-h":
		UNITS.mkdir(parents=True, exist_ok=True)
		cut_neutral_grid(SRC / "units_sheet_h.jpg", SHEET_H_NAMES, SHEET_H_CELL)
	else:
		main()
