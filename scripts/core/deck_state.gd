class_name DeckState
extends RefCounted

signal deck_changed

var _config: DeckConfig
var _level_config: LevelConfig
var _entries: Array[DeckEntry] = []
var _next_entry_id: int = 0


func configure(config: DeckConfig) -> void:
	_config = config
	if config != null and config.level_config != null:
		_level_config = config.level_config
	else:
		_level_config = null


func get_level_config() -> LevelConfig:
	return _level_config


func reset_from_config() -> void:
	_entries.clear()
	_next_entry_id = 0
	if _config == null:
		deck_changed.emit()
		return
	if not _config.starting_units.is_empty():
		for unit_data in _config.starting_units:
			if unit_data != null:
				add_entry(unit_data)
		return
	if _config.starting_unit == null:
		deck_changed.emit()
		return
	for _i in _config.starting_count:
		add_entry(_config.starting_unit)


func get_entries() -> Array[DeckEntry]:
	return _entries.duplicate()


func get_entry(entry_id: int) -> DeckEntry:
	for entry in _entries:
		if entry.entry_id == entry_id:
			return entry
	return null


func size() -> int:
	return _entries.size()


func is_full() -> bool:
	if _config == null:
		return false
	return _entries.size() >= _config.max_size


func can_add() -> bool:
	return not is_full()


func get_max_size() -> int:
	if _config == null:
		return 0
	return _config.max_size


func get_max_board_units() -> int:
	if _config == null:
		return 5
	return _config.max_board_units


func get_draw_count() -> int:
	if _config == null:
		return 5
	return _config.draw_count


func try_merge_from_shop(unit_data: UnitData, shop_bonus_max_hp: int = 0) -> Dictionary:
	var result := {"ok": false, "level_up": false, "entry": null}
	if unit_data == null:
		return result

	var target := DeckUpgradeService.find_merge_target(self, unit_data.id)
	if target == null:
		return result

	target.bonus_max_hp += shop_bonus_max_hp
	var leveled := DeckUpgradeService.add_experience(target, _level_config)
	result["ok"] = true
	result["level_up"] = leveled
	result["entry"] = target
	deck_changed.emit()
	return result


func add_entry(unit_data: UnitData, shop_bonus_max_hp: int = 0) -> DeckEntry:
	if unit_data == null or not can_add():
		return null
	var entry := _create_entry(unit_data)
	entry.bonus_max_hp += shop_bonus_max_hp
	_entries.append(entry)
	deck_changed.emit()
	return entry


func replace_entry(
	replace_id: int,
	unit_data: UnitData,
	shop_bonus_max_hp: int = 0,
) -> DeckEntry:
	if unit_data == null:
		return null
	var index := _find_index(replace_id)
	if index < 0:
		return null
	var entry := _create_entry(unit_data)
	entry.bonus_max_hp += shop_bonus_max_hp
	_entries[index] = entry
	deck_changed.emit()
	return entry


func attach_buff(entry_id: int, buff: BuffCardData) -> bool:
	if buff == null:
		return false
	var entry := get_entry(entry_id)
	if entry == null:
		return false
	entry.attached_buffs.append(buff)
	BuffApplicator.apply_on_attach(entry, buff)
	deck_changed.emit()
	return true


func remove_entry(entry_id: int) -> bool:
	var index := _find_index(entry_id)
	if index < 0:
		return false
	_entries.remove_at(index)
	deck_changed.emit()
	return true


func sacrifice_transfer_ability(donor_id: int, recipient_id: int) -> bool:
	if donor_id == recipient_id:
		return false
	var donor := get_entry(donor_id)
	var recipient := get_entry(recipient_id)
	if donor == null or recipient == null or donor.unit == null or recipient.unit == null:
		return false

	var ability := donor.unit.ability
	if ability != null and not _entry_has_ability(recipient, ability.id):
		recipient.attached_abilities.append(ability)

	if not remove_entry(donor_id):
		return false
	return true


func _entry_has_ability(entry: DeckEntry, ability_id: String) -> bool:
	if entry == null or entry.unit == null or ability_id.is_empty():
		return false
	if entry.unit.ability != null and entry.unit.ability.id == ability_id:
		return true
	for attached in entry.attached_abilities:
		if attached != null and attached.id == ability_id:
			return true
	for passive in entry.unit.passives:
		if passive != null and passive.id == ability_id:
			return true
	return false


func _create_entry(unit_data: UnitData) -> DeckEntry:
	var entry := DeckEntry.new()
	entry.entry_id = _next_entry_id
	_next_entry_id += 1
	entry.unit = unit_data
	return entry


func _find_index(entry_id: int) -> int:
	for i in _entries.size():
		if _entries[i].entry_id == entry_id:
			return i
	return -1
