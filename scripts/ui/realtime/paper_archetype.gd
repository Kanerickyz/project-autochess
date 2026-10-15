class_name PaperArchetype
extends RefCounted
## 旧纸剪贴 archetype。空字符串表示没有合同贴纸，调用方回退椭圆色块。
## 映射只覆盖简报里的四类；其余兵种保持占位。

const KNIGHT_SHIELD := &"knight_shield"
const ARCHER := &"archer"
const HEAVY_AXE := &"heavy_axe"
const CAPTAIN_CAPE := &"captain_cape"


static func from_unit_id(unit_id: String) -> StringName:
	var id := unit_id.to_lower()
	if id.is_empty():
		return &""
	if _has_any(id, ["archer", "crossbow", "horsebow", "musket", "hunter"]):
		return ARCHER
	if _has_any(id, ["maul", "barbarian", "axe"]):
		return HEAVY_AXE
	## 披风队长优先于「knight」子串，避免 giant_knight 被收成盾剑。
	if _has_any(id, ["giant_knight", "valkyrie", "banner"]):
		return CAPTAIN_CAPE
	if _has_any(id, ["knight", "shield", "aegis", "pekka"]):
		return KNIGHT_SHIELD
	return &""


static func _has_any(id: String, needles: Array) -> bool:
	for needle in needles:
		if id.contains(String(needle)):
			return true
	return false
