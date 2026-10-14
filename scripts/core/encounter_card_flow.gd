class_name EncounterCardFlow
extends RefCounted
## 遭遇内抽牌堆 / 手牌 / 弃牌堆与入手冷却（见 Documents/Features/PLAYER.md）。

signal hand_changed

const DEFAULT_HAND_WIDTH := 4
const DEFAULT_ENTER_HAND_COOLDOWN := 1.0

var hand_width: int = DEFAULT_HAND_WIDTH
var enter_hand_cooldown: float = DEFAULT_ENTER_HAND_COOLDOWN

var _draw_pile: Array[DeckEntry] = []
var _hand: Array[DeckEntry] = []
var _discard: Array[DeckEntry] = []
## entry_id -> remaining seconds
var _cooldown_remaining: Dictionary = {}


func clear() -> void:
	_draw_pile.clear()
	_hand.clear()
	_discard.clear()
	_cooldown_remaining.clear()
	hand_changed.emit()


func configure_from_deck_config(config: DeckConfig) -> void:
	if config == null:
		hand_width = DEFAULT_HAND_WIDTH
		enter_hand_cooldown = DEFAULT_ENTER_HAND_COOLDOWN
		return
	hand_width = config.get_hand_width()
	enter_hand_cooldown = config.get_enter_hand_cooldown()


## 由构筑库生成本场抽牌堆（洗乱），弃牌清空，抽满手牌并挂入手冷却。
func begin_from_deck(deck: DeckState, rng: RandomNumberGenerator = null) -> void:
	clear()
	if deck == null:
		return
	var local_rng := rng
	if local_rng == null:
		local_rng = RandomNumberGenerator.new()
		local_rng.randomize()
	_draw_pile = deck.get_entries()
	_shuffle(_draw_pile, local_rng)
	_fill_hand()
	hand_changed.emit()


func tick(delta: float) -> void:
	if delta <= 0.0 or _cooldown_remaining.is_empty():
		return
	var finished: Array[int] = []
	for entry_id in _cooldown_remaining.keys():
		var left: float = float(_cooldown_remaining[entry_id]) - delta
		if left <= 0.0:
			finished.append(int(entry_id))
		else:
			_cooldown_remaining[entry_id] = left
	for entry_id in finished:
		_cooldown_remaining.erase(entry_id)
	if not finished.is_empty():
		hand_changed.emit()


func get_hand() -> Array[DeckEntry]:
	return _hand.duplicate()


func get_draw_count() -> int:
	return _draw_pile.size()


func get_discard_count() -> int:
	return _discard.size()


func has_cards_remaining() -> bool:
	return not _hand.is_empty() or not _draw_pile.is_empty() or not _discard.is_empty()


func is_in_hand(entry_id: int) -> bool:
	return _find_hand_index(entry_id) >= 0


func is_ready(entry_id: int) -> bool:
	if not is_in_hand(entry_id):
		return false
	return get_cooldown_remaining(entry_id) <= 0.0


func get_cooldown_remaining(entry_id: int) -> float:
	if not _cooldown_remaining.has(entry_id):
		return 0.0
	return maxf(0.0, float(_cooldown_remaining[entry_id]))


## 打出成功：牌进弃牌、补抽；返回被打出的条目。失败返回 null。
func try_play(entry_id: int) -> DeckEntry:
	if not is_ready(entry_id):
		return null
	var index := _find_hand_index(entry_id)
	if index < 0:
		return null
	var entry := _hand[index]
	_hand.remove_at(index)
	_cooldown_remaining.erase(entry_id)
	_discard.append(entry)
	_draw_one_to_hand()
	hand_changed.emit()
	return entry


func _fill_hand() -> void:
	while _hand.size() < hand_width:
		if not _draw_one_to_hand():
			break


func _draw_one_to_hand() -> bool:
	if _hand.size() >= hand_width:
		return false
	if _draw_pile.is_empty():
		_reshuffle_discard_into_draw()
	if _draw_pile.is_empty():
		return false
	var entry: DeckEntry = _draw_pile.pop_back() as DeckEntry
	if entry == null:
		return false
	_hand.append(entry)
	_start_cooldown(entry.entry_id)
	return true


func _reshuffle_discard_into_draw() -> void:
	if _discard.is_empty():
		return
	_draw_pile.append_array(_discard)
	_discard.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_shuffle(_draw_pile, rng)


func _start_cooldown(entry_id: int) -> void:
	if enter_hand_cooldown <= 0.0:
		_cooldown_remaining.erase(entry_id)
		return
	_cooldown_remaining[entry_id] = enter_hand_cooldown


func _find_hand_index(entry_id: int) -> int:
	for i in _hand.size():
		if _hand[i] != null and _hand[i].entry_id == entry_id:
			return i
	return -1


static func _shuffle(entries: Array[DeckEntry], rng: RandomNumberGenerator) -> void:
	for i in range(entries.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := entries[i]
		entries[i] = entries[j]
		entries[j] = tmp
