#!/usr/bin/env python3
"""Cut the concept-derived paper-cutout art into game assets.

Sources (art_source/paper_cutout/, ignored by Godot):
  arena_background.jpg   empty clearing edited from concept_reference.jpg
  units_sheet_a.jpg      2x2 blue stickers: shield, archer, axe, captain
  units_sheet_b.jpg      2x2 blue stickers: spear, musket, banner, skeleton
  stat_badges_sheet.jpg  attack (sword) and HP (heart) tags without numbers

Output:
  assets/sprites/paper_cutout/env/arena_background.jpg
  assets/sprites/paper_cutout/units/unit_<archetype>_{blue,red}.png
  assets/sprites/paper_cutout/ui/stat_{attack,hp}.png

Red variants recolor only the cobalt cloth so both teams keep identical silhouettes.
"""
from __future__ import annotations

import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "art_source" / "paper_cutout"
ENV = ROOT / "assets" / "sprites" / "paper_cutout" / "env"
UNITS = ROOT / "assets" / "sprites" / "paper_cutout" / "units"
UI = ROOT / "assets" / "sprites" / "paper_cutout" / "ui"

SHEETS = {
	"units_sheet_a.jpg": ["shield", "archer", "axe", "captain"],
	"units_sheet_b.jpg": ["spear", "musket", "banner", "skeleton"],
}
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
		backdrop = np.isin(labels, edge[edge > 0])
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


def cut_sheet(path: Path, names: list[str]) -> None:
	sheet = Image.open(path).convert("RGB")
	rgb = np.array(sheet)
	alpha = key_out_backdrop(rgb)
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


def main() -> None:
	ENV.mkdir(parents=True, exist_ok=True)
	UNITS.mkdir(parents=True, exist_ok=True)
	UI.mkdir(parents=True, exist_ok=True)
	shutil.copyfile(SRC / "arena_background.jpg", ENV / "arena_background.jpg")
	for sheet, names in SHEETS.items():
		cut_sheet(SRC / sheet, names)
	cut_badges(SRC / "stat_badges_sheet.jpg")


if __name__ == "__main__":
	main()
