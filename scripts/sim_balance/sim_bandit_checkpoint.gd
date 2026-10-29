class_name SimBanditCheckpoint
extends Resource
## 冻结 bandit 策略快照；批跑 eval 只读，训练结束写入。

const SCHEMA_VERSION := 1

@export var policy_id: String = "bandit-v1"
@export var schema_version: int = SCHEMA_VERSION
@export var stats_json: String = "{}"


func apply_to(table: SimBanditTable) -> void:
	if table == null:
		return
	var parsed: Variant = JSON.parse_string(stats_json)
	if typeof(parsed) != TYPE_DICTIONARY:
		table.clear()
		return
	table.import_dict(parsed)


func capture_from(table: SimBanditTable) -> void:
	if table == null:
		stats_json = "{}"
		return
	stats_json = JSON.stringify(table.export_dict(), "\t")


func duplicate_checkpoint() -> SimBanditCheckpoint:
	var copy: SimBanditCheckpoint = duplicate(true)
	return copy
