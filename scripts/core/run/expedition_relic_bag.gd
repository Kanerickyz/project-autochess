class_name ExpeditionRelicBag
extends RefCounted

## 远征行囊：整局最多 6 件圣物；不叠同 id。

const CAPACITY := 6

signal bag_changed

## Array[ExpeditionRelicData]
var _relics: Array = []


func clear() -> void:
	_relics.clear()
	bag_changed.emit()


func get_relics() -> Array:
	return _relics.duplicate()


func get_count() -> int:
	return _relics.size()


func is_full() -> bool:
	return _relics.size() >= CAPACITY


func has_id(relic_id: String) -> bool:
	for r in _relics:
		if r != null and r.id == relic_id:
			return true
	return false


func get_at(index: int) -> ExpeditionRelicData:
	if index < 0 or index >= _relics.size():
		return null
	return _relics[index] as ExpeditionRelicData


## 未满直接追加；已满返回 false。
func try_add(relic: ExpeditionRelicData) -> bool:
	if relic == null or relic.id.is_empty():
		return false
	if is_full():
		return false
	if has_id(relic.id):
		return false
	_relics.append(relic)
	bag_changed.emit()
	return true


## 指定旧槽换下并放入新件；旧件丢弃无金。replace_index 为行囊下标。
func try_replace(relic: ExpeditionRelicData, replace_index: int) -> bool:
	if relic == null or relic.id.is_empty():
		return false
	if replace_index < 0 or replace_index >= _relics.size():
		return false
	if has_id(relic.id) and get_at(replace_index).id != relic.id:
		return false
	_relics[replace_index] = relic
	bag_changed.emit()
	return true


## 拿新：未满可直接入；若 replace_index >= 0 则换下该槽（未满时也可自愿换下）。
func try_take(relic: ExpeditionRelicData, replace_index: int = -1) -> bool:
	if relic == null:
		return false
	if replace_index >= 0:
		if _relics.is_empty():
			return try_add(relic)
		return try_replace(relic, replace_index)
	return try_add(relic)


func try_remove_at(index: int) -> ExpeditionRelicData:
	if index < 0 or index >= _relics.size():
		return null
	var removed: ExpeditionRelicData = _relics[index]
	_relics.remove_at(index)
	bag_changed.emit()
	return removed


func find_index_by_id(relic_id: String) -> int:
	for i in _relics.size():
		var r: ExpeditionRelicData = _relics[i]
		if r != null and r.id == relic_id:
			return i
	return -1


## 招募重置用：浅拷贝引用列表（圣物 Resource 共享）。
func capture_state() -> Array:
	return _relics.duplicate()


func restore_state(saved: Array) -> void:
	_relics.clear()
	for item in saved:
		if item is ExpeditionRelicData:
			_relics.append(item)
	bag_changed.emit()
