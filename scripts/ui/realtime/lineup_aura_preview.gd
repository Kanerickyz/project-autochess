class_name LineupAuraPreview
extends RefCounted
## 准备/招募座位邻接 aura 预览：纯函数，不写 DeckEntry 永久数值。
## 仅识别旗手/咒刃/盾祷「上场」邻座挂载；备战席不参与（调用方只传入已入座 board）。
## 铁心仍为开战，不进预览。

const ID_BANNER := "combat_start_buff_nearby_allies_mid"
const ID_EDGE := "combat_start_nearby_ally_atk_1"
const ID_SHIELD := "combat_start_nearby_ally_hp_1"

const BANNER_ATK := 4
const EDGE_ATK := 1
const SHIELD_HP := 1


## 从 PrepareSlotBoard 汇总 entry_id → {atk:int, hp:int}。
static func compute_from_board(board: PrepareSlotBoard) -> Dictionary:
	if board == null or board.cells.is_empty():
		return {}
	return compute(board.occupants, board.cells)


## occupants 与 cells 等长；null 占位跳过。仅座位 Chebyshev≤1。
static func compute(occupants: Array, cells: Array) -> Dictionary:
	var bonuses: Dictionary = {}
	var n := mini(occupants.size(), cells.size())
	if n <= 0:
		return bonuses
	for i in n:
		var source: DeckEntry = occupants[i] as DeckEntry
		if source == null:
			continue
		var ability := source.get_main_ability()
		if ability == null or ability.id.is_empty():
			continue
		var mult := UnitInstance.ability_value_multiplier_for(ability, source.level)
		match ability.id:
			ID_BANNER:
				_apply_nearby(bonuses, occupants, cells, i, BANNER_ATK * mult, 0)
			ID_EDGE:
				_apply_nearby(bonuses, occupants, cells, i, EDGE_ATK * mult, 0)
			ID_SHIELD:
				_apply_nearby(bonuses, occupants, cells, i, 0, SHIELD_HP * mult)
			_:
				pass
	return bonuses


static func _apply_nearby(
	bonuses: Dictionary,
	occupants: Array,
	cells: Array,
	source_index: int,
	atk: int,
	hp: int,
) -> void:
	if atk == 0 and hp == 0:
		return
	var origin: Vector2i = cells[source_index]
	var n := mini(occupants.size(), cells.size())
	for j in n:
		if j == source_index:
			continue
		var other: DeckEntry = occupants[j] as DeckEntry
		if other == null:
			continue
		if BoardGrid._chebyshev(origin, cells[j]) > EffectSpec.NEARBY_ALLY_RADIUS:
			continue
		_add_bonus(bonuses, other.entry_id, atk, hp)


static func _add_bonus(bonuses: Dictionary, entry_id: int, atk: int, hp: int) -> void:
	if entry_id < 0:
		return
	var cur: Dictionary = bonuses.get(entry_id, {"atk": 0, "hp": 0})
	bonuses[entry_id] = {
		"atk": int(cur.get("atk", 0)) + atk,
		"hp": int(cur.get("hp", 0)) + hp,
	}
