class_name PartyBarkLine
extends Resource
## 单条队伍羁绊台词（纯表现；不进技能管线）。

@export var id: String = ""
@export var speaker_unit_id: String = ""
@export var required_unit_ids: PackedStringArray = PackedStringArray()
@export var line: String = ""
## 本版恒为 true；保留字段便于以后扩展。
@export var once_per_run: bool = true
