#!/usr/bin/env python3
"""Generate aged-paper cutout stickers for the Run arena (brief: Documents/Content/PAPER_CUTOUT_ART_BRIEF.md).

Output (transparent PNG, cream edge + charcoal ink baked in):
  assets/sprites/paper_cutout/env/arena_paper_base.png
  assets/sprites/paper_cutout/env/arena_border_trees_left.png
  assets/sprites/paper_cutout/env/arena_border_trees_right.png
  assets/sprites/paper_cutout/env/arena_ground_doodles.png
  assets/sprites/paper_cutout/units/unit_*_{blue,red}.png
"""
from __future__ import annotations

import os
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ENV = ROOT / "assets" / "sprites" / "paper_cutout" / "env"
UNITS = ROOT / "assets" / "sprites" / "paper_cutout" / "units"

PAPER = (232, 220, 196, 255)
CREAM = (245, 240, 228, 255)
INK = (42, 36, 32, 255)
COBALT = (47, 95, 191, 255)
BRICK = (176, 58, 50, 255)
ARMOR = (216, 208, 196, 255)
ARMOR_DK = (168, 156, 140, 255)
SKIN = (212, 165, 116, 255)
WOOD = (139, 105, 20, 255)
BLADE = (200, 194, 180, 255)
MOSS = (107, 143, 78, 255)
OLIVE = (74, 107, 58, 255)
LEAF_DK = (58, 82, 46, 255)
ROCK = (154, 144, 128, 255)
ROCK_DK = (122, 112, 98, 255)
GRASS = (122, 154, 85, 255)
STAIN = (196, 176, 140, 255)


def _max_filter(mask: Image.Image, radius: int) -> Image.Image:
	size = radius * 2 + 1
	return mask.filter(ImageFilter.MaxFilter(size))


def _min_filter(mask: Image.Image, radius: int) -> Image.Image:
	size = radius * 2 + 1
	return mask.filter(ImageFilter.MinFilter(size))


def paper_finish(im: Image.Image, seed: int, edge: int = 10) -> Image.Image:
	"""Bake an irregular cream cutout edge and a charcoal ink contour."""
	im = im.convert("RGBA")
	alpha = im.getchannel("A")
	mask = alpha.point(lambda p: 255 if p > 24 else 0)
	paper = _max_filter(mask, edge)
	rng = np.random.RandomState(seed)
	paper_a = np.array(paper)
	noise = rng.rand(*paper_a.shape)
	# Nibble only the outer ring so the edge looks hand-cut, not a perfect offset.
	outer = np.array(_max_filter(mask, edge)) > 0
	inner = np.array(_max_filter(mask, max(1, edge - 4))) > 0
	ring = outer & ~inner
	paper_a[ring & (noise < 0.42)] = 0
	# A few worn bites closer in.
	mid = inner & ~(np.array(_max_filter(mask, max(1, edge - 7))) > 0)
	paper_a[mid & (noise < 0.12)] = 0
	paper_img = Image.fromarray(paper_a, mode="L")

	ink_band = np.array(_max_filter(mask, 3)) > 0
	core = np.array(_min_filter(mask, 1)) > 0
	ink = ink_band & ~core
	# Break the line so width feels hand-drawn.
	ink_noise = rng.rand(*paper_a.shape)
	ink_arr = np.zeros_like(paper_a)
	ink_arr[ink & (ink_noise > 0.08)] = 255
	ink_img = Image.fromarray(ink_arr, mode="L")

	h, w = paper_a.shape
	fiber = rng.randint(-10, 11, size=(h, w))
	cream = np.zeros((h, w, 4), dtype=np.uint8)
	cream[..., 0] = np.clip(CREAM[0] + fiber, 0, 255)
	cream[..., 1] = np.clip(CREAM[1] + fiber, 0, 255)
	cream[..., 2] = np.clip(CREAM[2] + (fiber // 2), 0, 255)
	cream[..., 3] = paper_a
	cream_img = Image.fromarray(cream, mode="RGBA")

	ink_rgba = Image.new("RGBA", im.size, INK)
	ink_rgba.putalpha(ink_img)

	out = Image.alpha_composite(cream_img, im)
	out = Image.alpha_composite(out, ink_rgba)
	return _crop_alpha(out, pad=10)


def _crop_alpha(im: Image.Image, pad: int = 8) -> Image.Image:
	bbox = im.getbbox()
	if bbox is None:
		return im
	x0, y0, x1, y1 = bbox
	x0 = max(0, x0 - pad)
	y0 = max(0, y0 - pad)
	x1 = min(im.width, x1 + pad)
	y1 = min(im.height, y1 + pad)
	return im.crop((x0, y0, x1, y1))


def _tilt(im: Image.Image, degrees: float) -> Image.Image:
	return im.rotate(degrees, resample=Image.Resampling.BICUBIC, expand=False)


class Sheet:
	def __init__(self, w: int, h: int) -> None:
		self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
		self.d = ImageDraw.Draw(self.im)

	def blob(self, box, fill, seed: int) -> None:
		rng = np.random.RandomState(seed)
		x0, y0, x1, y1 = box
		for _ in range(4):
			jx = int(rng.randint(-3, 4))
			jy = int(rng.randint(-3, 4))
			self.d.ellipse([x0 + jx, y0 + jy, x1 + jx, y1 + jy], fill=fill)

	def poly(self, pts, fill) -> None:
		self.d.polygon(pts, fill=fill)

	def line(self, a, b, fill, width: int = 3) -> None:
		self.d.line([a, b], fill=fill, width=width)

	def finish(self, seed: int, tilt: float = 0.0, edge: int = 10) -> Image.Image:
		im = paper_finish(self.im, seed, edge=edge)
		if abs(tilt) > 0.05:
			im = _tilt(im, tilt)
		return im


def _unit_base(cloth) -> Sheet:
	s = Sheet(384, 384)
	# Shadow is drawn at runtime; keep the sticker itself flat.
	s.blob((118, 168, 262, 300), cloth, 3)  # tunic
	s.blob((132, 248, 188, 330), ARMOR, 4)  # left leg
	s.blob((196, 250, 250, 334), ARMOR_DK, 5)
	s.blob((146, 78, 246, 196), ARMOR, 2)  # helmet / head
	s.blob((168, 150, 230, 188), SKIN, 6)  # face
	s.d.rectangle((172, 118, 222, 132), fill=INK)  # visor
	return s


def knight(cloth, seed: int) -> Image.Image:
	s = _unit_base(cloth)
	# Shield
	s.poly([(78, 168), (150, 150), (158, 292), (86, 300)], cloth)
	s.poly([(104, 176), (136, 168), (140, 270), (108, 276)], ARMOR)
	s.line((122, 186), (122, 258), INK, 4)
	s.line((100, 220), (146, 214), INK, 4)
	# Sword, kept clear of the visor so the helmet reads at small size.
	s.poly([(268, 118), (300, 102), (312, 168), (278, 178)], BLADE)
	s.line((274, 168), (236, 236), WOOD, 6)
	s.blob((228, 214, 262, 242), WOOD, 8)
	return s.finish(seed, tilt=-2.4)


def archer(cloth, seed: int) -> Image.Image:
	s = Sheet(384, 384)
	s.blob((132, 186, 250, 312), cloth, 11)
	s.poly([(150, 70), (250, 86), (214, 176), (132, 160)], cloth)  # hood
	s.blob((156, 118, 228, 186), SKIN, 12)
	s.d.ellipse((176, 132, 190, 146), fill=INK)
	s.d.ellipse((200, 130, 214, 144), fill=INK)
	# Bow
	s.d.arc((230, 120, 330, 320), 200, 340, fill=WOOD, width=8)
	s.line((268, 132), (268, 300), INK, 2)
	# Arrow
	s.line((168, 210), (300, 196), WOOD, 3)
	s.poly([(292, 186), (322, 196), (292, 208)], BLADE)
	# Quiver
	s.poly([(118, 200), (150, 190), (156, 268), (122, 274)], WOOD)
	return s.finish(seed, tilt=2.2)


def heavy_axe(cloth, seed: int) -> Image.Image:
	s = _unit_base(cloth)
	s.blob((108, 176, 276, 318), cloth, 21)  # thicker torso
	# Axe haft
	s.line((250, 120), (214, 300), WOOD, 8)
	# Double head
	s.poly([(214, 96), (300, 78), (292, 150), (220, 156)], BLADE)
	s.poly([(200, 150), (292, 156), (286, 214), (206, 196)], BLADE)
	s.line((230, 118), (270, 108), ARMOR_DK, 2)
	s.line((228, 176), (268, 184), ARMOR_DK, 2)
	return s.finish(seed, tilt=-1.6, edge=11)


def captain(cloth, seed: int) -> Image.Image:
	s = Sheet(384, 384)
	# Cape first so it sits behind the body.
	s.poly([(120, 150), (270, 132), (304, 330), (86, 318)], cloth)
	s.blob((132, 176, 252, 300), ARMOR, 31)
	s.blob((150, 70, 246, 188), ARMOR, 32)
	s.d.rectangle((168, 112, 226, 128), fill=INK)
	s.blob((170, 146, 226, 180), SKIN, 33)
	# Greatsword
	s.poly([(236, 40), (268, 28), (286, 210), (250, 214)], BLADE)
	s.line((248, 70), (270, 188), ARMOR_DK, 2)
	s.blob((228, 196, 292, 224), WOOD, 34)
	return s.finish(seed, tilt=1.5, edge=12)


def grass_sheet() -> Image.Image:
	s = Sheet(96, 72)
	s.line((28, 58), (22, 18), GRASS, 3)
	s.line((40, 62), (46, 12), OLIVE, 3)
	s.line((52, 60), (62, 20), GRASS, 3)
	s.line((36, 64), (34, 28), LEAF_DK, 2)
	# Thin doodles, no cream sticker edge — a paper rim would turn them into blobs.
	return s.im


def _tree_blob(s: Sheet, cx: int, cy: int, r: int, seed: int, fill) -> None:
	s.blob((cx - r, cy - int(r * 0.85), cx + r, cy + int(r * 0.9)), fill, seed)


def _one_tree(seed: int) -> Image.Image:
	s = Sheet(220, 200)
	rng = np.random.RandomState(seed)
	fills = [MOSS, OLIVE, LEAF_DK]
	for i in range(3):
		r = int(rng.randint(28, 48))
		cx = 70 + int(rng.randint(-8, 28))
		cy = 70 + i * 28
		_tree_blob(s, cx, cy, r, seed + i, fills[i % 3])
		s.line((cx - 6, cy), (cx + int(rng.randint(-8, 9)), cy + 6), LEAF_DK, 2)
	return s.finish(seed, tilt=float(rng.randint(-4, 5)), edge=7)


def _one_rock(seed: int) -> Image.Image:
	s = Sheet(160, 110)
	rng = np.random.RandomState(seed)
	s.blob((24, 28, 130, 96), ROCK, seed)
	s.line((40, 48), (100, 70), ROCK_DK, 2)
	s.blob((48, 40, 90, 62), ARMOR, seed + 3)
	return s.finish(seed, tilt=float(rng.randint(-6, 7)), edge=6)


def border_strip(side: str) -> Image.Image:
	w, h = 220, 1280
	im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	rng = np.random.RandomState(4 if side == "left" else 9)
	y = 8
	i = 0
	while y < h - 30:
		if rng.rand() < 0.72:
			piece = _one_tree(300 + i * 17 + (0 if side == "left" else 9))
		else:
			piece = _one_rock(500 + i * 13)
		x = 0 if side == "left" else max(0, w - piece.width)
		im.alpha_composite(piece, (x, min(y, h - piece.height)))
		y += int(piece.height * 0.72)
		i += 1
	if side == "right":
		im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
	return im


def paper_base() -> Image.Image:
	w, h = 512, 1024
	rng = np.random.RandomState(16015)
	arr = np.zeros((h, w, 4), dtype=np.uint8)
	fiber = rng.randint(-8, 9, size=(h, w))
	arr[..., 0] = np.clip(PAPER[0] + fiber, 0, 255)
	arr[..., 1] = np.clip(PAPER[1] + fiber, 0, 255)
	arr[..., 2] = np.clip(PAPER[2] + fiber // 2, 0, 255)
	arr[..., 3] = 255
	im = Image.fromarray(arr, mode="RGBA")
	d = ImageDraw.Draw(im, "RGBA")
	for i in range(8):
		x = int(rng.randint(0, w))
		y = int(rng.randint(0, h))
		rx = int(rng.randint(14, 40))
		ry = int(rng.randint(8, 18))
		d.ellipse((x, y, x + rx, y + ry), fill=(STAIN[0], STAIN[1], STAIN[2], 16))
	# Sparse grass doodles on the sheet itself stay very light; runtime also stamps tufts.
	for i in range(26):
		x = int(rng.randint(40, w - 40))
		y = int(rng.randint(40, h - 40))
		d.line((x, y, x + int(rng.randint(-4, 5)), y - int(rng.randint(8, 16))), fill=(*GRASS[:3], 140), width=2)
	return im


def main() -> None:
	ENV.mkdir(parents=True, exist_ok=True)
	UNITS.mkdir(parents=True, exist_ok=True)
	paper_base().save(ENV / "arena_paper_base.png")
	border_strip("left").save(ENV / "arena_border_trees_left.png")
	border_strip("right").save(ENV / "arena_border_trees_right.png")
	# A small sheet of tufts (transparent); the view stamps it sparsely.
	sheet = Image.new("RGBA", (512, 128), (0, 0, 0, 0))
	tuft = grass_sheet()
	for i, x in enumerate(range(8, 500, 64)):
		piece = tuft.rotate((i * 17) % 11 - 5, resample=Image.Resampling.BICUBIC, expand=True)
		sheet.alpha_composite(piece, (x, 16))
	sheet.save(ENV / "arena_ground_doodles.png")
	pairs = {
		"unit_knight_shield": knight,
		"unit_archer": archer,
		"unit_heavy_axe": heavy_axe,
		"unit_captain_cape": captain,
	}
	for name, fn in pairs.items():
		fn(COBALT, 40).save(UNITS / f"{name}_blue.png")
		fn(BRICK, 41).save(UNITS / f"{name}_red.png")
	print("wrote", ENV, "and", UNITS)


if __name__ == "__main__":
	main()
