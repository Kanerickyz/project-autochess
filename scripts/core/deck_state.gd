class_name DeckState
extends RefCounted

signal deck_changed
## 自动三合一完成：product 为合成体；consumed_seats 为被合三人的座位（可含 -1）。
signal triple_merged(product: DeckEntry, consumed_seats: Array)

## 队伍席位上限硬顶（旗帜扩容上限；与座位网格容量对齐，默认 4×5=20）。
const SEAT_CAP_HARD_MAX := 10

var _config: DeckConfig
var _level_config: LevelConfig
var _entries: Array[DeckEntry] = []
var _next_entry_id: int = 0
## 全局落座时间计数；每次成功 assign/swap 递增。
var _next_seat_seq: int = 0
## 运行时席位上限；-1 表示沿用 DeckConfig.max_size（旗帜写入此字段，避免污染共享 .tres）。
var _seat_cap_override: int = -1
## 三合一装备冲突等随机；可注入以便测试。
var _rng: RandomNumberGenerator


func configure(config: DeckConfig) -> void:
	_config = config
	_seat_cap_override = -1
	if config != null and config.level_config != null:
		_level_config = config.level_config
	else:
		_level_config = null


func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


func _ensure_rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng


func get_level_config() -> LevelConfig:
	return _level_config


func reset_from_config() -> void:
	_entries.clear()
	_next_entry_id = 0
	_next_seat_seq = 0
	_seat_cap_override = -1
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
	return _entries.size() >= get_max_size()


func can_add() -> bool:
	return not is_full()


func get_max_size() -> int:
	if _seat_cap_override >= 0:
		return _seat_cap_override
	if _config == null:
		return 0
	return _config.max_size


func get_seat_cap_hard_max() -> int:
	return SEAT_CAP_HARD_MAX


func is_seat_cap_maxed() -> bool:
	return get_max_size() >= SEAT_CAP_HARD_MAX


## 旗帜：席位上限 +delta，封顶 SEAT_CAP_HARD_MAX。已满则失败。
func try_increase_seat_cap(delta: int = 1) -> bool:
	if delta <= 0:
		return false
	var current := get_max_size()
	if current >= SEAT_CAP_HARD_MAX:
		return false
	if _seat_cap_override < 0:
		_seat_cap_override = current
	_seat_cap_override = mini(SEAT_CAP_HARD_MAX, _seat_cap_override + delta)
	deck_changed.emit()
	return true


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


## 再买一只 level 星同 id 是否会凑满 3 只并触发三合一（满员溢出购买用）。
func would_complete_triple_on_add(unit_data: UnitData, level: int = 1) -> bool:
	if unit_data == null or level < 1 or level >= 3:
		return false
	var count := 0
	for entry in _entries:
		if entry == null or entry.unit == null:
			continue
		if entry.is_fused_enchant() or FusedEnchantIds.is_fused_unit_id(unit_data.id):
			continue
		if entry.get_unit_id() == unit_data.id and entry.level == level:
			count += 1
	return count >= 2


func add_fused_enchant_entry(
	runtime_ability: AbilityData,
	display_attack: int,
	display_max_hp: int,
	base_attack: int,
	base_max_hp: int,
	crit_rate_bonus: int = 0,
) -> DeckEntry:
	if EnchantFusionService.FUSED_UNIT == null or runtime_ability == null:
		return null
	if not can_add():
		return null
	var entry := _create_entry(EnchantFusionService.FUSED_UNIT)
	entry.level = 1
	entry.runtime_main_ability = runtime_ability.duplicate(true) as AbilityData
	entry.bonus_attack = display_attack - base_attack
	entry.bonus_max_hp = display_max_hp - base_max_hp
	entry.bonus_crit_rate_percent = crit_rate_bonus
	_entries.append(entry)
	deck_changed.emit()
	return entry


func add_entry(
	unit_data: UnitData,
	shop_bonus_max_hp: int = 0,
	preferred_seat: int = -1,
) -> DeckEntry:
	if unit_data == null:
		return null
	## 满员但买入可立刻三合一时，允许短暂超出席位上限。
	if not can_add() and not would_complete_triple_on_add(unit_data, 1):
		return null
	var entry := _create_entry(unit_data)
	entry.bonus_max_hp += shop_bonus_max_hp
	_entries.append(entry)
	_place_new_entry(entry, preferred_seat)
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
	var old := _entries[index]
	var inherit_seat := old.seat_index if old != null else -1
	var entry := _create_entry(unit_data)
	entry.bonus_max_hp += shop_bonus_max_hp
	## 满员替换：新人继承被替者座位，并刷新落座时间。
	if inherit_seat >= 0:
		_set_seat(entry, inherit_seat, true)
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
	## 出售 / 移除：腾座（条目离开即可）。
	_entries.remove_at(index)
	deck_changed.emit()
	return true


## 第一个空友方座位：先前排到后排，同行中心向外（5 列序 53124）；无空返回 -1。
func find_first_empty_seat() -> int:
	var occupied := _occupied_seat_set()
	var rows := get_seat_rows()
	var cols := get_seat_cols()
	var n := get_slot_count()
	for seat_i in SeatLayout.iter_seats_center_out(rows, cols):
		if seat_i < 0 or seat_i >= n:
			continue
		if not occupied.has(seat_i):
			return seat_i
	## 网格外残留空座（配置异常时兜底）
	for i in n:
		if not occupied.has(i):
			return i
	return -1



func is_seat_free(seat_index: int) -> bool:
	if seat_index < 0 or seat_index >= get_slot_count():
		return false
	return not _occupied_seat_set().has(seat_index)


## 将成员放到指定空座（或保持原座）；成功刷新落座时间。目标被他人占用时失败。
func assign_seat(entry_id: int, seat_index: int) -> bool:
	var entry := get_entry(entry_id)
	if entry == null:
		return false
	if seat_index < 0 or seat_index >= get_slot_count():
		return false
	if entry.seat_index == seat_index:
		_set_seat(entry, seat_index, true)
		deck_changed.emit()
		return true
	var occupant := get_entry_at_seat(seat_index)
	if occupant != null and occupant.entry_id != entry_id:
		return false
	_set_seat(entry, seat_index, true)
	deck_changed.emit()
	return true


## 换座：目标空则移入；目标有人则互换。双方（或移动者）刷新落座时间。
func swap_seats(entry_id: int, target_seat: int) -> bool:
	var entry := get_entry(entry_id)
	if entry == null:
		return false
	if target_seat < 0 or target_seat >= get_slot_count():
		return false
	if entry.seat_index == target_seat:
		_set_seat(entry, target_seat, true)
		deck_changed.emit()
		return true
	var other := get_entry_at_seat(target_seat)
	var from_seat := entry.seat_index
	if other == null:
		_set_seat(entry, target_seat, true)
		deck_changed.emit()
		return true
	## 先清标记再写入，避免短暂双占干扰空座查找。
	entry.seat_index = -1
	other.seat_index = -1
	_set_seat(entry, target_seat, true)
	if from_seat >= 0:
		_set_seat(other, from_seat, true)
	else:
		var empty := find_first_empty_seat()
		if empty >= 0:
			_set_seat(other, empty, true)
		else:
			other.seat_assign_seq = 0
	deck_changed.emit()
	return true


func clear_seat(entry_id: int) -> bool:
	var entry := get_entry(entry_id)
	if entry == null:
		return false
	if entry.seat_index < 0:
		return true
	entry.seat_index = -1
	entry.seat_assign_seq = 0
	deck_changed.emit()
	return true


func get_entry_at_seat(seat_index: int) -> DeckEntry:
	if seat_index < 0:
		return null
	for entry in _entries:
		if entry != null and entry.seat_index == seat_index:
			return entry
	return null


## 已占用座位下标，按落座时间序（早→晚）。
func get_occupied_seat_indices_by_order() -> Array[int]:
	var seated: Array[DeckEntry] = []
	for entry in _entries:
		if entry != null and entry.seat_index >= 0:
			seated.append(entry)
	seated.sort_custom(_compare_seat_seq)
	var out: Array[int] = []
	for entry in seated:
		out.append(entry.seat_index)
	return out


func _compare_seat_seq(a: DeckEntry, b: DeckEntry) -> bool:
	if a.seat_assign_seq == b.seat_assign_seq:
		return a.seat_index < b.seat_index
	return a.seat_assign_seq < b.seat_assign_seq


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
		if entry.is_fused_enchant():
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
	## PLAYER §4.1：合成体占三只中落座时间最早者座位；另两座随移除变空。
	var earliest := _earliest_seated_among([a, b, c])
	if earliest != null and earliest.seat_index >= 0:
		product.seat_index = earliest.seat_index
		product.seat_assign_seq = earliest.seat_assign_seq
	var consumed_seats: Array = []
	for src in [a, b, c]:
		consumed_seats.append(src.seat_index if src != null else -1)
	## MAP_SHOP §5.2：参与合成成员的装备中随机留一件，其余消失不退金。
	var merged_eq := _pick_merge_equipment([a, b, c])
	product.equipment = merged_eq
	if merged_eq != null:
		product.equipment_armor_max = merged_eq.get_armor_block()
	_merge_attached_buffs(product, [a, b, c])
	_merge_attached_abilities(product, [a, b, c])
	_remove_entries_by_ids([a.entry_id, b.entry_id, c.entry_id])
	_entries.append(product)
	triple_merged.emit(product, consumed_seats)
	return product


func _pick_merge_equipment(sources: Array) -> EquipmentData:
	var candidates: Array[EquipmentData] = []
	for item in sources:
		var entry := item as DeckEntry
		if entry != null and entry.equipment != null:
			candidates.append(entry.equipment)
	if candidates.is_empty():
		return null
	var picked: EquipmentData
	if candidates.size() == 1:
		picked = candidates[0]
	else:
		var rng := _ensure_rng()
		picked = candidates[rng.randi_range(0, candidates.size() - 1)]
	## 合成结果持有独立副本，避免与源条目或池资源串改。
	return picked.duplicate(true) as EquipmentData if picked != null else null


## 落座时间最早（seq 最小且 >0）；皆未入座则 null。
func _earliest_seated_among(group: Array) -> DeckEntry:
	var best: DeckEntry = null
	for item in group:
		var entry := item as DeckEntry
		if entry == null or entry.seat_index < 0 or entry.seat_assign_seq <= 0:
			continue
		if best == null:
			best = entry
			continue
		if entry.seat_assign_seq < best.seat_assign_seq:
			best = entry
		elif entry.seat_assign_seq == best.seat_assign_seq and entry.seat_index < best.seat_index:
			best = entry
	return best


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


## 招募进门快照：深拷贝条目（含 entry_id / 等级 / 增益 / 持久占位 / 席位上限）。
func capture_roster() -> Dictionary:
	var copies: Array[DeckEntry] = []
	for entry in _entries:
		if entry != null:
			copies.append(_clone_entry(entry))
	return {
		"entries": copies,
		"next_entry_id": _next_entry_id,
		"next_seat_seq": _next_seat_seq,
		"seat_cap_override": _seat_cap_override,
	}


func restore_roster(snapshot: Dictionary) -> void:
	_entries.clear()
	var source: Array = snapshot.get("entries", [])
	for item in source:
		if item is DeckEntry:
			_entries.append(_clone_entry(item as DeckEntry))
	_next_entry_id = int(snapshot.get("next_entry_id", _next_entry_id))
	_next_seat_seq = int(snapshot.get("next_seat_seq", 0))
	_seat_cap_override = int(snapshot.get("seat_cap_override", -1))
	if _next_seat_seq <= 0:
		for entry in _entries:
			if entry != null:
				_next_seat_seq = maxi(_next_seat_seq, entry.seat_assign_seq)
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
	if source.equipment != null:
		entry.equipment = source.equipment.duplicate(true) as EquipmentData
	else:
		entry.equipment = null
	entry.seat_index = source.seat_index
	entry.seat_assign_seq = source.seat_assign_seq
	if source.runtime_main_ability != null:
		entry.runtime_main_ability = source.runtime_main_ability.duplicate(true) as AbilityData
	return entry


func _place_new_entry(entry: DeckEntry, preferred_seat: int) -> void:
	if entry == null:
		return
	var seat := preferred_seat
	if seat < 0 or seat >= get_slot_count() or not is_seat_free(seat):
		seat = find_first_empty_seat()
	if seat >= 0:
		_set_seat(entry, seat, true)


func _set_seat(entry: DeckEntry, seat_index: int, refresh_seq: bool) -> void:
	if entry == null:
		return
	entry.seat_index = seat_index
	if refresh_seq:
		_next_seat_seq += 1
		entry.seat_assign_seq = _next_seat_seq
	elif entry.seat_assign_seq <= 0:
		_next_seat_seq += 1
		entry.seat_assign_seq = _next_seat_seq


func _occupied_seat_set() -> Dictionary:
	var occupied := {}
	for entry in _entries:
		if entry != null and entry.seat_index >= 0:
			occupied[entry.seat_index] = true
	return occupied
