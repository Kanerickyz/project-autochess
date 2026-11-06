class_name StageChoiceBoard
extends RefCounted
## 上半场「选项卡片」几何：把纯 UI 选择题平铺到敌半场格子上。
## 每张卡：{id, label, summary?, selected?, cell, meta?}

static func build_row_cells(count: int, board_size: Vector2i, row_from_top: int = 0) -> Array[Vector2i]:
	var n := maxi(0, count)
	var cells: Array[Vector2i] = []
	if n <= 0:
		return cells
	var mid := BoardHalf.midline_row(board_size.y)
	var y := clampi(row_from_top, 0, maxi(0, mid - 1))
	var gap := 1 if n <= 3 else 0
	var block_w := n + (n - 1) * gap
	if block_w > board_size.x:
		gap = 0
		block_w = mini(n, board_size.x)
	var start_x := (board_size.x - block_w) / 2
	start_x = clampi(start_x, 0, maxi(0, board_size.x - 1))
	for i in n:
		var x := clampi(start_x + i * (1 + gap), 0, maxi(0, board_size.x - 1))
		cells.append(Vector2i(x, y))
	return cells


## 把选项数组补上 cell（上半场一行）。保留原 id/label/summary/selected/meta。
static func layout_choices(choices: Array, board_size: Vector2i, row_from_top: int = 0) -> Array:
	var out: Array = []
	var cells := build_row_cells(choices.size(), board_size, row_from_top)
	for i in choices.size():
		var src: Variant = choices[i]
		if not (src is Dictionary):
			continue
		var d: Dictionary = (src as Dictionary).duplicate(true)
		d["index"] = i
		d["cell"] = cells[i] if i < cells.size() else Vector2i(-1, -1)
		out.append(d)
	return out


## 点选：先精确格，再同列上半场（卡片视觉占满敌半场高度）。
## 卡片面短摘要；完整说明放 detail / 长按信息卡。
static func truncate_preview(text: String, max_chars: int = 14) -> String:
	var t := text.strip_edges()
	if t.is_empty() or max_chars <= 0:
		return t
	## 只取首行，避免换行撑破单格。
	var nl := t.find("\n")
	if nl >= 0:
		t = t.substr(0, nl).strip_edges()
	if t.length() <= max_chars:
		return t
	return t.substr(0, maxi(1, max_chars - 1)) + "…"


static func find_index_at(cards: Array, cell: Vector2i, board_size: Vector2i = Vector2i(5, 4)) -> int:
	if cell.x < 0 or cell.y < 0:
		return -1
	var mid := BoardHalf.midline_row(board_size.y)
	if cell.y >= mid:
		return -1
	for i in cards.size():
		var info: Variant = cards[i]
		if not (info is Dictionary):
			continue
		var c: Vector2i = (info as Dictionary).get("cell", Vector2i(-1, -1))
		if c == cell:
			return i
	for i in cards.size():
		var info2: Variant = cards[i]
		if not (info2 is Dictionary):
			continue
		var c2: Vector2i = (info2 as Dictionary).get("cell", Vector2i(-1, -1))
		if c2.x == cell.x and c2.y >= 0 and c2.y < mid:
			return i
	return -1
