class_name SimBanditCheckpoint
extends Resource
## 冻结 bandit 策略快照；批跑 eval 只读，训练结束写入。

const SCHEMA_VERSION := 2

@export var policy_id: String = "bandit-v1"
@export var schema_version: int = SCHEMA_VERSION
## v1 = 招募也吃下一场胜负；v2/v3 = 选路吃胜负，招募吃 Run 终局（v3 强化深度奖励 + recruit3 状态桶）
@export var reward_mode: String = "v1"
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
