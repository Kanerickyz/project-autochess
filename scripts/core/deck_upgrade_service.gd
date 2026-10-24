class_name DeckUpgradeService
extends RefCounted


static func get_level_config(deck: DeckState) -> LevelConfig:
	if deck == null:
		return null
	return deck.get_level_config()


static func find_merge_target(deck: DeckState, unit_id: String) -> DeckEntry:
	if deck == null or unit_id.is_empty():
		return null
	var config := get_level_config(deck)
	var best: DeckEntry = null
	for entry in deck.get_entries():
		if entry == null or entry.unit == null:
			continue
		if entry.get_unit_id() != unit_id:
			continue
		if is_max_level(entry, config):
			continue
		if best == null or entry.level < best.level:
			best = entry
		elif entry.level == best.level and entry.experience < best.experience:
			best = entry
	return best


static func has_merge_target(deck: DeckState, unit_id: String) -> bool:
	return find_merge_target(deck, unit_id) != null


static func is_max_level(entry: DeckEntry, config: LevelConfig) -> bool:
	if entry == null:
		return true
	if config == null:
		return entry.level >= 3
	return entry.level >= config.max_level


static func get_xp_to_next_level(entry: DeckEntry, config: LevelConfig) -> int:
	if entry == null or config == null or is_max_level(entry, config):
		return 0
	if entry.level <= 1:
		return config.xp_to_reach_level_2
	if entry.level == 2:
		return config.xp_to_reach_level_3
	return 0


static func add_experience(entry: DeckEntry, config: LevelConfig) -> bool:
	if entry == null or config == null or is_max_level(entry, config):
		return false

	entry.experience += 1
	var leveled := false
	while not is_max_level(entry, config):
		var needed := get_xp_to_next_level(entry, config)
		if needed <= 0 or entry.experience < needed:
			break
		entry.experience -= needed
		_apply_level_up(entry, config)
		leveled = true
	return leveled


## 出售价 = 角色招募原价 × 3^(星级−1)：1★ 原价，2★ 三合一后 3×，3★ 9×。
static func get_sell_price(entry: DeckEntry, _config: LevelConfig = null) -> int:
	if entry == null or entry.unit == null:
		return 0
	var base_cost := entry.unit.cost
	if base_cost <= 0:
		base_cost = 1
	var level := maxi(1, entry.level)
	var mult := 1
	for _i in range(level - 1):
		mult *= 3
	return base_cost * mult


static func get_display_attack(entry: DeckEntry) -> int:
	if entry == null or entry.unit == null or entry.unit.stats == null:
		return 0
	return entry.unit.stats.attack + entry.bonus_attack


static func get_display_max_hp(entry: DeckEntry) -> int:
	if entry == null or entry.unit == null or entry.unit.stats == null:
		return 0
	return entry.unit.stats.max_hp + entry.bonus_max_hp


static func _apply_level_up(entry: DeckEntry, config: LevelConfig) -> void:
	entry.level += 1
	entry.bonus_attack += config.bonus_attack_per_level_up
	entry.bonus_max_hp += config.bonus_max_hp_per_level_up
