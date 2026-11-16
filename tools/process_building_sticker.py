#!/usr/bin/env python3
"""Single wide building sticker (2×1 footprint) from a neutral-backdrop JPEG."""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from process_paper_cutout_art import (  # noqa: E402
	UNITS,
	crop_to_alpha,
	key_out_neutral,
	to_red_team,
)

TARGET_HEIGHT = 256
MIN_ASPECT = 1.85


def process_building_source(src: Path, sprite_key: str) -> None:
	sheet = Image.open(src).convert("RGB")
	rgb = np.array(sheet)
	alpha = key_out_neutral(rgb)
	rgba = Image.fromarray(np.dstack([rgb, alpha]), mode="RGBA")
	tight = crop_to_alpha(rgba, pad=8)
	if tight.height < 1:
		raise RuntimeError("empty alpha after keying %s" % src)
	scaled_w = max(1, round(tight.width * TARGET_HEIGHT / tight.height))
	sprite = tight.resize((scaled_w, TARGET_HEIGHT), Image.Resampling.LANCZOS)
	canvas_w = max(scaled_w, round(TARGET_HEIGHT * MIN_ASPECT))
	canvas = Image.new("RGBA", (canvas_w, TARGET_HEIGHT), (0, 0, 0, 0))
	x = (canvas_w - scaled_w) // 2
	canvas.paste(sprite, (x, 0), sprite)
	UNITS.mkdir(parents=True, exist_ok=True)
	canvas.save(UNITS / f"unit_{sprite_key}_blue.png")
	to_red_team(canvas).save(UNITS / f"unit_{sprite_key}_red.png")
	print(f"unit_{sprite_key}: {canvas.size}")


if __name__ == "__main__":
	SRC = ROOT / "art_source" / "paper_cutout"
	process_building_source(SRC / "ghost_graveyard_building.jpg", "ghost_graveyard")
	process_building_source(SRC / "siege_catapult_building.jpg", "siege_catapult")