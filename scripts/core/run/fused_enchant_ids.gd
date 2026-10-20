class_name FusedEnchantIds
extends RefCounted

const UNIT_ID := &"fused_enchant"
const DISPLAY_NAME := "熔印者"


static func is_fused_unit_id(unit_id: String) -> bool:
	return StringName(unit_id) == UNIT_ID
