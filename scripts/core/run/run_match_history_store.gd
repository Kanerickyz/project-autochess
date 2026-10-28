class_name RunMatchHistoryStore
extends RefCounted

const STORAGE_PATH := "user://run_match_history.json"
const MAX_RECORDS := 30


class ListEntry extends RefCounted:
	var id: String = ""
	var saved_at: int = 0
	var title: String = ""
	var subtitle: String = ""


static func append_snapshot(snapshot: RunStatsSnapshot) -> void:
	if snapshot == null:
		return
	var root := _load_root()
	var records: Array = root.get("records", [])
	var now := int(Time.get_unix_time_from_system())
	var record_id := "%d-%d" % [now, randi()]
	var encoded := RunMatchHistoryCodec.encode_snapshot(snapshot, now, record_id)
	records.insert(0, encoded)
	while records.size() > MAX_RECORDS:
		records.pop_back()
	root["records"] = records
	root["format_version"] = RunMatchHistoryCodec.FORMAT_VERSION
	_save_root(root)


static func list_entries() -> Array[ListEntry]:
	var out: Array[ListEntry] = []
	var records: Array = _load_root().get("records", [])
	for raw in records:
		if raw is not Dictionary:
			continue
		var record := raw as Dictionary
		var summary := RunMatchHistoryCodec.summary_for_record(record)
		var item := ListEntry.new()
		item.id = String(record.get("id", ""))
		item.saved_at = int(record.get("saved_at", 0))
		item.title = String(summary.get("title", ""))
		item.subtitle = String(summary.get("subtitle", ""))
		out.append(item)
	return out


static func load_snapshot_by_id(record_id: String) -> RunStatsSnapshot:
	if record_id.is_empty():
		return null
	for raw in _load_root().get("records", []):
		if raw is not Dictionary:
			continue
		var record := raw as Dictionary
		if String(record.get("id", "")) == record_id:
			return RunMatchHistoryCodec.decode_snapshot(record)
	return null


static func clear_all() -> void:
	_save_root({"format_version": RunMatchHistoryCodec.FORMAT_VERSION, "records": []})


static func _load_root() -> Dictionary:
	if not FileAccess.file_exists(STORAGE_PATH):
		return {"format_version": RunMatchHistoryCodec.FORMAT_VERSION, "records": []}
	var file := FileAccess.open(STORAGE_PATH, FileAccess.READ)
	if file == null:
		return {"format_version": RunMatchHistoryCodec.FORMAT_VERSION, "records": []}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {"format_version": RunMatchHistoryCodec.FORMAT_VERSION, "records": []}


static func _save_root(root: Dictionary) -> void:
	var file := FileAccess.open(STORAGE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("RunMatchHistoryStore: cannot write %s" % STORAGE_PATH)
		return
	file.store_string(JSON.stringify(root, "\t"))
	file.close()
