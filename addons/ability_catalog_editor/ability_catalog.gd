@tool
class_name AbilityCatalog
extends RefCounted

const ABILITIES_DIR := "res://resources/abilities"
const UNITS_DIR := "res://resources/units"

enum Domain { COMBAT, SHOP, ALL }

const SHOP_TRIGGERS: Array[StringName] = [
	ShopEvents.ON_BUY,
	ShopEvents.ON_SELL,
	ShopEvents.ON_LEVEL_UP,
]

const COMBAT_TRIGGERS: Array[StringName] = [
	CombatEvents.ON_COMBAT_START,
	CombatEvents.ON_COMBAT_END,
	CombatEvents.ON_FRIEND_SUMMONED,
	CombatEvents.ON_FRIEND_DEATH,
	CombatEvents.ON_ROUND_START,
	CombatEvents.ON_DAMAGE_TAKEN,
	CombatEvents.ON_DEAL_DAMAGE,
	CombatEvents.ON_KILL,
	CombatEvents.ON_DEATH,
	CombatEvents.ON_ATTACK_HIT,
	CombatEvents.ON_MOVE,
]


static func scan_abilities(dir: String = ABILITIES_DIR) -> Array:
	var result: Array = []
	var access := DirAccess.open(dir)
	if access == null:
		return result
	access.list_dir_begin()
	var name := access.get_next()
	while name != "":
		if not access.current_is_dir() and name.ends_with(".tres"):
			var full := dir.path_join(name)
			var ability := ResourceLoader.load(
				full,
				"",
				ResourceLoader.CACHE_MODE_REUSE,
			) as AbilityData
			if ability != null:
				result.append({"path": full, "data": ability})
		name = access.get_next()
	access.list_dir_end()
	result.sort_custom(func(a, b) -> bool:
		var da: AbilityData = a.get("data")
		var db: AbilityData = b.get("data")
		if da == null or db == null:
			return false
		var na := da.display_name if not da.display_name.is_empty() else da.id
		var nb := db.display_name if not db.display_name.is_empty() else db.id
		return na < nb
	)
	return result


static func scan_abilities_only() -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	for entry in scan_abilities():
		var data: AbilityData = entry.get("data")
		if data != null:
			result.append(data)
	return result


static func is_shop_trigger(trigger: StringName) -> bool:
	return trigger in SHOP_TRIGGERS


static func is_combat_trigger(trigger: StringName) -> bool:
	return trigger in COMBAT_TRIGGERS


static func get_primary_trigger(ability: AbilityData) -> StringName:
	if ability == null or ability.effect_specs.is_empty():
		return &""
	var spec := ability.effect_specs[0]
	if spec == null:
		return &""
	return spec.trigger


static func filter_by_domain(entries: Array, domain: Domain) -> Array:
	if domain == Domain.ALL:
		return entries.duplicate()
	var filtered: Array = []
	for entry in entries:
		var data: AbilityData = entry.get("data")
		if data == null:
			continue
		var trigger := get_primary_trigger(data)
		match domain:
			Domain.COMBAT:
				if trigger.is_empty() or is_combat_trigger(trigger):
					filtered.append(entry)
			Domain.SHOP:
				if is_shop_trigger(trigger):
					filtered.append(entry)
	return filtered


static func find_unit_references(ability_id: String) -> Array[String]:
	var paths: Array[String] = []
	if ability_id.is_empty():
		return paths
	for entry in UnitCatalog.scan_units():
		var data: UnitData = entry.get("data")
		if data == null or data.ability == null:
			continue
		if data.ability.id == ability_id:
			var path: String = entry.get("path", "")
			if not path.is_empty():
				paths.append(path)
	return paths
