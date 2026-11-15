class_name EnchantTraitCatalog
extends RefCounted
## 附魔神龛：战斗词条池（开战层数；技能升星倍率不走附魔）。

const OFFER_COUNT := 3


static func roll_offers(rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var pick_rng := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		pick_rng.randomize()
	var pool := _POOL.duplicate()
	var out: Array[Dictionary] = []
	for _i in OFFER_COUNT:
		if pool.is_empty():
			break
		var idx := pick_rng.randi_range(0, pool.size() - 1)
		out.append(pool[idx].duplicate())
		pool.remove_at(idx)
	return out


static func get_display_name(status_id: StringName) -> String:
	for row in _POOL:
		if row.get("id", &"") == status_id:
			return str(row.get("name", status_id))
	return CombatStatusStack.get_display_name(status_id)


static func is_allowed(status_id: StringName) -> bool:
	if not CombatStatusStack.is_valid_id(status_id):
		return false
	for row in _POOL:
		if row.get("id", &"") == status_id:
			return true
	return false


const _POOL: Array[Dictionary] = [
	{"id": CombatStatusStack.ID_VOLATILE, "name": "易燃易爆", "stacks": 1},
	{"id": CombatStatusStack.ID_BERSERK, "name": "狂暴", "stacks": 2},
	{"id": CombatStatusStack.ID_WEAK, "name": "虚弱", "stacks": 2},
]