class_name BattleLayoutClipboard
extends RefCounted
## 阵容 / 单场布局剪贴板：UTF-8 纯文本，带头版本号；人可读。

const FORMAT_ID := "PAC_BATTLE"
const FORMAT_VERSION := 1

const KIND_ROSTER := "roster"
const KIND_LAYOUT := "layout"

const ENC_COMBAT := "combat"
const ENC_ELITE := "elite"
const ENC_BOSS := "boss"

const UNIT_SCAN_DIRS: Array[String] = [
	"res://resources/units/realtime/",
	"res://resources/units/enemies/",
	"res://resources/units/",
]
const BUFF_DIR := "res://resources/buffs/"

static var _unit_cache: Dictionary = {} # id -> UnitData
static var _buff_cache: Dictionary = {} # id -> BuffCardData
static var _cache_built: bool = false


## 解析结果；ok=false 时 error 有短提示，payload 为 null。
class ParseResult extends RefCounted:
	var ok: bool = false
	var error: String = ""
	var payload: BattleLayoutPayload = null


class BattleLayoutPayload extends RefCounted:
	var kind: String = KIND_ROSTER
	var seat_cap: int = 5
	var seed: int = 0
	var encounter_type: String = ENC_COMBAT
	## 友方：Dictionary keys: unit_id, seat, level, bonus_atk, bonus_hp, bonus_crit, buffs(Array[String]), ability_path
	var allies: Array = []
	## 敌方：Dictionary keys: unit_id, seat, level
	var enemies: Array = []

	func has_enemies() -> bool:
		return not enemies.is_empty()

	func is_layout() -> bool:
		return kind == KIND_LAYOUT or has_enemies()


static func encode_roster(
	entries: Array[DeckEntry],
	seat_cap: int,
) -> String:
	var payload := BattleLayoutPayload.new()
	payload.kind = KIND_ROSTER
	payload.seat_cap = maxi(1, seat_cap)
	payload.allies = _entries_to_ally_rows(entries)
	return encode_payload(payload)


static func encode_layout(
	entries: Array[DeckEntry],
	seat_cap: int,
	enemy_rows: Array,
	seed: int,
	encounter_type: String,
) -> String:
	var payload := BattleLayoutPayload.new()
	payload.kind = KIND_LAYOUT
	payload.seat_cap = maxi(1, seat_cap)
	payload.seed = seed
	payload.encounter_type = encounter_type if not encounter_type.is_empty() else ENC_COMBAT
	payload.allies = _entries_to_ally_rows(entries)
	payload.enemies = enemy_rows.duplicate(true)
	return encode_payload(payload)


static func encode_payload(payload: BattleLayoutPayload) -> String:
	if payload == null:
		return ""
	var lines: PackedStringArray = []
	lines.append("%s v%d" % [FORMAT_ID, FORMAT_VERSION])
	lines.append("kind: %s" % (KIND_LAYOUT if payload.is_layout() else KIND_ROSTER))
	lines.append("seat_cap: %d" % maxi(1, payload.seat_cap))
	if payload.is_layout():
		lines.append("seed: %d" % payload.seed)
		lines.append("encounter: %s" % payload.encounter_type)
	lines.append("# allies")
	for row in payload.allies:
		lines.append(_format_ally_line(row))
	if payload.is_layout():
		lines.append("# enemies")
		for row in payload.enemies:
			lines.append(_format_enemy_line(row))
	return "\n".join(lines) + "\n"


static func parse(text: String) -> ParseResult:
	var result := ParseResult.new()
	if text == null or text.strip_edges().is_empty():
		result.error = "剪贴板为空"
		return result
	var lines := text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	if lines.is_empty():
		result.error = "格式无效"
		return result
	var header := String(lines[0]).strip_edges()
	var header_parts := header.split(" ")
	if header_parts.size() < 2 or header_parts[0] != FORMAT_ID:
		result.error = "不是阵容/布局文本"
		return result
	var ver_token := String(header_parts[1])
	if ver_token.begins_with("v"):
		ver_token = ver_token.substr(1)
	var version := int(ver_token)
	if version != FORMAT_VERSION:
		result.error = "版本不匹配（需要 v%d）" % FORMAT_VERSION
		return result

	var payload := BattleLayoutPayload.new()
	payload.kind = KIND_ROSTER
	var section := ""
	for i in range(1, lines.size()):
		var raw := String(lines[i]).strip_edges()
		if raw.is_empty():
			continue
		if raw.begins_with("#"):
			var tag := raw.substr(1).strip_edges().to_lower()
			if tag.begins_with("ally"):
				section = "allies"
			elif tag.begins_with("enem"):
				section = "enemies"
			else:
				section = ""
			continue
		if ":" in raw and not raw.begins_with("A ") and not raw.begins_with("E "):
			var kv := raw.split(":", false, 1)
			if kv.size() != 2:
				continue
			var key := String(kv[0]).strip_edges().to_lower()
			var val := String(kv[1]).strip_edges()
			match key:
				"kind":
					payload.kind = KIND_LAYOUT if val == KIND_LAYOUT else KIND_ROSTER
				"seat_cap":
					payload.seat_cap = maxi(1, int(val))
				"seed":
					payload.seed = int(val)
				"encounter":
					payload.encounter_type = _normalize_encounter(val)
			continue
		if raw.begins_with("A ") or section == "allies":
			var ally := _parse_ally_line(raw)
			if ally.is_empty():
				result.error = "友方行无法解析"
				return result
			if String(ally.get("unit_id", "")).is_empty():
				result.error = "友方缺少单位 id"
				return result
			payload.allies.append(ally)
			continue
		if raw.begins_with("E ") or section == "enemies":
			var enemy := _parse_enemy_line(raw)
			if enemy.is_empty():
				result.error = "敌方行无法解析"
				return result
			if String(enemy.get("unit_id", "")).is_empty():
				result.error = "敌方缺少单位 id"
				return result
			payload.enemies.append(enemy)
			continue

	if payload.allies.is_empty():
		result.error = "没有友方单位"
		return result
	_ensure_caches()
	for row in payload.allies:
		var uid := String(row.get("unit_id", ""))
		if resolve_unit(uid) == null:
			result.error = "未知友方单位：%s" % uid
			return result
	for row in payload.enemies:
		var eid := String(row.get("unit_id", ""))
		if resolve_unit(eid) == null:
			result.error = "未知敌方单位：%s" % eid
			return result
	if payload.has_enemies():
		payload.kind = KIND_LAYOUT
	result.ok = true
	result.payload = payload
	return result


static func resolve_unit(unit_id: String) -> UnitData:
	if unit_id.is_empty():
		return null
	_ensure_caches()
	return _unit_cache.get(unit_id) as UnitData


static func resolve_buff(buff_id: String) -> BuffCardData:
	if buff_id.is_empty():
		return null
	_ensure_caches()
	return _buff_cache.get(buff_id) as BuffCardData


## 将 payload 友方建成可 restore_roster 的条目数组（不做三合一）。
static func build_deck_entries(payload: BattleLayoutPayload) -> Array[DeckEntry]:
	var out: Array[DeckEntry] = []
	if payload == null:
		return out
	var next_id := 0
	var next_seq := 0
	for row in payload.allies:
		var unit := resolve_unit(String(row.get("unit_id", "")))
		if unit == null:
			continue
		var entry := DeckEntry.new()
		entry.entry_id = next_id
		next_id += 1
		entry.unit = unit
		entry.level = clampi(int(row.get("level", 1)), 1, 3)
		entry.bonus_attack = int(row.get("bonus_atk", 0))
		entry.bonus_max_hp = int(row.get("bonus_hp", 0))
		entry.bonus_crit_rate_percent = int(row.get("bonus_crit", 0))
		entry.seat_index = int(row.get("seat", -1))
		next_seq += 1
		entry.seat_assign_seq = next_seq
		var buff_ids: Array = row.get("buffs", [])
		for bid in buff_ids:
			var buff := resolve_buff(String(bid))
			if buff != null:
				entry.attached_buffs.append(buff)
				## 规则类增益写入 flag；攻血已在 bonus_* 固化，不再 BuffApplicator 叠加。
				if buff.effect_type == BuffCardData.EffectType.CANNOT_MOVE:
					entry.rule_flags["cannot_move"] = true
		var ability_path := String(row.get("ability_path", ""))
		if not ability_path.is_empty() and ResourceLoader.exists(ability_path):
			var ab := load(ability_path) as AbilityData
			if ab != null:
				entry.runtime_main_ability = ab.duplicate(true) as AbilityData
		out.append(entry)
	return out


static func encounter_type_from_node(node_type: int) -> String:
	match node_type:
		MapNodeType.Type.ELITE:
			return ENC_ELITE
		MapNodeType.Type.BOSS:
			return ENC_BOSS
		_:
			return ENC_COMBAT


static func node_type_from_encounter(enc: String) -> MapNodeType.Type:
	match _normalize_encounter(enc):
		ENC_ELITE:
			return MapNodeType.Type.ELITE
		ENC_BOSS:
			return MapNodeType.Type.BOSS
		_:
			return MapNodeType.Type.COMBAT


static func _entries_to_ally_rows(entries: Array[DeckEntry]) -> Array:
	var rows: Array = []
	for entry in entries:
		if entry == null or entry.unit == null:
			continue
		var buffs: Array[String] = []
		for buff in entry.attached_buffs:
			if buff != null and not buff.id.is_empty():
				buffs.append(buff.id)
		var ability_path := ""
		if entry.runtime_main_ability != null:
			ability_path = entry.runtime_main_ability.resource_path
		rows.append({
			"unit_id": entry.get_unit_id(),
			"seat": entry.seat_index,
			"level": clampi(entry.level, 1, 3),
			"bonus_atk": entry.bonus_attack,
			"bonus_hp": entry.bonus_max_hp,
			"bonus_crit": entry.bonus_crit_rate_percent,
			"buffs": buffs,
			"ability_path": ability_path,
		})
	return rows


static func _format_ally_line(row: Dictionary) -> String:
	var parts: PackedStringArray = []
	parts.append("A")
	parts.append(String(row.get("unit_id", "")))
	parts.append("seat=%d" % int(row.get("seat", -1)))
	parts.append("lv=%d" % int(row.get("level", 1)))
	parts.append("atk+=%d" % int(row.get("bonus_atk", 0)))
	parts.append("hp+=%d" % int(row.get("bonus_hp", 0)))
	parts.append("crit+=%d" % int(row.get("bonus_crit", 0)))
	var buffs: Array = row.get("buffs", [])
	if not buffs.is_empty():
		var ids: PackedStringArray = []
		for b in buffs:
			ids.append(String(b))
		parts.append("buffs=%s" % ",".join(ids))
	var ability_path := String(row.get("ability_path", ""))
	if not ability_path.is_empty():
		parts.append("ability=%s" % ability_path)
	return " ".join(parts)


static func _format_enemy_line(row: Dictionary) -> String:
	var parts: PackedStringArray = []
	parts.append("E")
	parts.append(String(row.get("unit_id", "")))
	parts.append("seat=%d" % int(row.get("seat", -1)))
	parts.append("lv=%d" % clampi(int(row.get("level", 1)), 1, 3))
	return " ".join(parts)


static func _parse_ally_line(raw: String) -> Dictionary:
	var line := raw.strip_edges()
	if line.begins_with("A "):
		line = line.substr(2).strip_edges()
	var tokens := line.split(" ", false)
	if tokens.is_empty():
		return {}
	var unit_id := String(tokens[0])
	var row := {
		"unit_id": unit_id,
		"seat": -1,
		"level": 1,
		"bonus_atk": 0,
		"bonus_hp": 0,
		"bonus_crit": 0,
		"buffs": [],
		"ability_path": "",
	}
	for i in range(1, tokens.size()):
		var tok := String(tokens[i])
		if tok.begins_with("seat="):
			row["seat"] = int(tok.substr(5))
		elif tok.begins_with("lv="):
			row["level"] = clampi(int(tok.substr(3)), 1, 3)
		elif tok.begins_with("atk+="):
			row["bonus_atk"] = int(tok.substr(5))
		elif tok.begins_with("hp+="):
			row["bonus_hp"] = int(tok.substr(4))
		elif tok.begins_with("crit+="):
			row["bonus_crit"] = int(tok.substr(6))
		elif tok.begins_with("buffs="):
			var list: Array[String] = []
			for b in tok.substr(6).split(",", false):
				var bid := String(b).strip_edges()
				if not bid.is_empty():
					list.append(bid)
			row["buffs"] = list
		elif tok.begins_with("ability="):
			row["ability_path"] = tok.substr(8)
	return row


static func _parse_enemy_line(raw: String) -> Dictionary:
	var line := raw.strip_edges()
	if line.begins_with("E "):
		line = line.substr(2).strip_edges()
	var tokens := line.split(" ", false)
	if tokens.is_empty():
		return {}
	var row := {
		"unit_id": String(tokens[0]),
		"seat": -1,
		"level": 1,
	}
	for i in range(1, tokens.size()):
		var tok := String(tokens[i])
		if tok.begins_with("seat="):
			row["seat"] = int(tok.substr(5))
		elif tok.begins_with("lv="):
			row["level"] = clampi(int(tok.substr(3)), 1, 3)
	return row


static func _normalize_encounter(val: String) -> String:
	var v := val.strip_edges().to_lower()
	match v:
		"elite", "精英":
			return ENC_ELITE
		"boss", "首领":
			return ENC_BOSS
		_:
			return ENC_COMBAT


static func _ensure_caches() -> void:
	if _cache_built:
		return
	_unit_cache.clear()
	_buff_cache.clear()
	for dir_path in UNIT_SCAN_DIRS:
		_scan_unit_dir(dir_path)
	_scan_buff_dir(BUFF_DIR)
	_cache_built = true


static func _scan_unit_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".tres"):
			var path := dir_path.path_join(name)
			var data := load(path) as UnitData
			if data != null and not data.id.is_empty() and not _unit_cache.has(data.id):
				_unit_cache[data.id] = data
		name = dir.get_next()
	dir.list_dir_end()


static func _scan_buff_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".tres"):
			var path := dir_path.path_join(name)
			var data := load(path) as BuffCardData
			if data != null and not data.id.is_empty():
				_buff_cache[data.id] = data
		name = dir.get_next()
	dir.list_dir_end()
