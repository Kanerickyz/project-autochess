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
	## 兼容旧调用；实时主路径请用 get_deploy_cap()（本场上场人数上限）。
	return get_deploy_cap()


func get_deploy_cap() -> int:
	if _config == null:
		return DeckConfig.DEFAULT_DEPLOY_CAP
	return _config.get_deploy_cap()


func get_draw_count() -> int:
	## Legacy prepare draw; 遭遇内请用 get_hand_width()。
	if _config == null:
		return DeckConfig.DEFAULT_HAND_WIDTH
	return _config.draw_count


func get_hand_width() -> int:
	if _config == null:
		return EncounterCardFlow.DEFAULT_HAND_WIDTH
	return _config.get_hand_width()


func get_seat_rows() -> int:
	if _config == null:
		return DeckConfig.DEFAULT_SEAT_ROWS
	return _config.get_seat_rows()


func get_seat_cols() -> int:
	if _config == null:
		return DeckConfig.DEFAULT_SEAT_COLS
	return _config.get_seat_cols()


func get_slot_count() -> int:
	if _config == null:
		return DeckConfig.DEFAULT_SEAT_ROWS * DeckConfig.DEFAULT_SEAT_COLS
	return _config.get_slot_count()


func get_enter_hand_cooldown() -> float:
	if _config == null:
		return EncounterCardFlow.DEFAULT_ENTER_HAND_COOLDOWN
	return _config.get_enter_hand_cooldown()


func get_config() -> DeckConfig:
	return _config


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
	var survivor := _resolve_after_auto_merge(entry)
	deck_changed.emit()
	return survivor


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
	var survivor := _resolve_after_auto_merge(entry)
	deck_changed.emit()
	return survivor


## 队伍自动三合一：同 unit.id + 同 level 满 3 且 level < 3 立刻合成。
## 可在外部改队伍后手动调用；add/replace 末尾已统一触发。
func try_auto_merge() -> bool:
	var changed := _run_auto_merges()
	if changed:
		deck_changed.emit()
	return changed


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


func _resolve_after_auto_merge(seed: DeckEntry) -> DeckEntry:
	if seed == null:
		return null
	var track_id := seed.entry_id
	var track_unit := seed.get_unit_id()
	_run_auto_merges()
	var still := get_entry(track_id)
	if still != null:
		return still
	var best: DeckEntry = null
	for entry in _entries:
		if entry == null or entry.get_unit_id() != track_unit:
			continue
		if best == null or entry.level > best.level or (
			entry.level == best.level and entry.entry_id > best.entry_id
		):
			best = entry
	return best if best != null else seed


func _run_auto_merges() -> bool:
	var changed := false
	while true:
		var group := _find_mergeable_triple()
		if group.is_empty():
			break
		_apply_triple_merge(group)
		changed = true
	return changed


## 返回可合成的三只 DeckEntry（同 id 同星且未满 3 星）；无可合则空数组。
func _find_mergeable_triple() -> Array[DeckEntry]:
	var buckets: Dictionary = {}
	for entry in _entries:
		if entry == null or entry.unit == null:
			continue
		if entry.level >= 3:
			continue
		var key := "%s#%d" % [entry.get_unit_id(), entry.level]
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(entry)
	for key in buckets.keys():
		var group: Array = buckets[key]
		if group.size() < 3:
			continue
		var out: Array[DeckEntry] = []
		out.append(group[0] as DeckEntry)
		out.append(group[1] as DeckEntry)
		out.append(group[2] as DeckEntry)
		return out
	return []


func _apply_triple_merge(group: Array[DeckEntry]) -> DeckEntry:
	if group.size() < 3:
		return null
	var a := group[0]
	var b := group[1]
	var c := group[2]
	if a == null or b == null or c == null or a.unit == null:
		return null
	var base_atk := 0
	var base_hp := 0
	if a.unit.stats != null:
		base_atk = a.unit.stats.attack
		base_hp = a.unit.stats.max_hp
	var sum_atk := (
		DeckUpgradeService.get_display_attack(a)
		+ DeckUpgradeService.get_display_attack(b)
		+ DeckUpgradeService.get_display_attack(c)
	)
	var sum_hp := (
		DeckUpgradeService.get_display_max_hp(a)
		+ DeckUpgradeService.get_display_max_hp(b)
		+ DeckUpgradeService.get_display_max_hp(c)
	)
	var product := _create_entry(a.unit)
	product.level = a.level + 1
	product.experience = 0
	product.bonus_attack = sum_atk - base_atk
	product.bonus_max_hp = sum_hp - base_hp
	product.bonus_crit_rate_percent = (
		a.bonus_crit_rate_percent + b.bonus_crit_rate_percent + c.bonus_crit_rate_percent
	)
	_merge_attached_buffs(product, [a, b, c])
	_merge_attached_abilities(product, [a, b, c])
	_remove_entries_by_ids([a.entry_id, b.entry_id, c.entry_id])
	_entries.append(product)
	return product


func _merge_attached_buffs(product: DeckEntry, sources: Array) -> void:
	var seen: Dictionary = {}
	for source in sources:
		var entry := source as DeckEntry
		if entry == null:
			continue
		for buff in entry.attached_buffs:
			if buff == null:
				continue
			var key := buff.id if not buff.id.is_empty() else str(buff.get_instance_id())
			if seen.has(key):
				continue
			seen[key] = true
			product.attached_buffs.append(buff)


func _merge_attached_abilities(product: DeckEntry, sources: Array) -> void:
	var seen: Dictionary = {}
	if product.unit != null and product.unit.ability != null and not product.unit.ability.id.is_empty():
		seen[product.unit.ability.id] = true
	for source in sources:
		var entry := source as DeckEntry
		if entry == null:
			continue
		for ability in entry.attached_abilities:
			if ability == null or ability.id.is_empty() or seen.has(ability.id):
				continue
			seen[ability.id] = true
			product.attached_abilities.append(ability)


func _remove_entries_by_ids(ids: Array) -> void:
	var remove_set: Dictionary = {}
	for entry_id in ids:
		remove_set[int(entry_id)] = true
	var kept: Array[DeckEntry] = []
	for entry in _entries:
		if entry != null and not remove_set.has(entry.entry_id):
			kept.append(entry)
	_entries = kept


## 招募进门快照：深拷贝条目（含 entry_id / 等级 / 增益）。
func capture_roster() -> Dictionary:
	var copies: Array[DeckEntry] = []
	for entry in _entries:
		if entry != null:
			copies.append(_clone_entry(entry))
	return {
		"entries": copies,
		"next_entry_id": _next_entry_id,
	}


func restore_roster(snapshot: Dictionary) -> void:
	_entries.clear()
	var source: Array = snapshot.get("entries", [])
	for item in source:
		if item is DeckEntry:
			_entries.append(_clone_entry(item as DeckEntry))
	_next_entry_id = int(snapshot.get("next_entry_id", _next_entry_id))
	deck_changed.emit()


func _clone_entry(source: DeckEntry) -> DeckEntry:
	var entry := DeckEntry.new()
	entry.entry_id = source.entry_id
	entry.unit = source.unit
	entry.attached_buffs = source.attached_buffs.duplicate()
	entry.attached_abilities = source.attached_abilities.duplicate()
	entry.rule_flags = source.rule_flags.duplicate(true)
	entry.level = source.level
	entry.experience = source.experience
	entry.bonus_attack = source.bonus_attack
	entry.bonus_max_hp = source.bonus_max_hp
	entry.bonus_crit_rate_percent = source.bonus_crit_rate_percent
	return entry
