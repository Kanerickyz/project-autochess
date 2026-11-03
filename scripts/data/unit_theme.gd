class_name UnitTheme
extends RefCounted
## 主题羁绊八主题 id 与显示名（Features/UNIT_THEME_BONDS）。

const GUARD := &"guard"
const KNIGHT_ORDER := &"knight_order"
const WARRIOR := &"warrior"
const ARTISAN := &"artisan"
const UNDEAD := &"undead"
const BAND := &"band"
const ARCANE := &"arcane"
const MERCENARY := &"mercenary"

const ALL_IDS: Array[StringName] = [
	GUARD,
	KNIGHT_ORDER,
	WARRIOR,
	ARTISAN,
	UNDEAD,
	BAND,
	ARCANE,
	MERCENARY,
]

const DISPLAY_NAMES := {
	GUARD: "护卫",
	KNIGHT_ORDER: "骑士团",
	WARRIOR: "战士",
	ARTISAN: "工匠",
	UNDEAD: "亡灵",
	BAND: "军乐队",
	ARCANE: "秘术",
	MERCENARY: "佣兵",
}


static func is_valid_id(theme_id: StringName) -> bool:
	if theme_id == &"":
		return false
	return theme_id in ALL_IDS


static func display_name(theme_id: StringName) -> String:
	if theme_id == &"":
		return ""
	return String(DISPLAY_NAMES.get(theme_id, String(theme_id)))


## 主必有（非空且合法）；辅空或合法。返回问题文案，空=通过。
static func validate_pair(primary: StringName, secondary: StringName) -> PackedStringArray:
	var issues: PackedStringArray = []
	if primary == &"":
		issues.append("theme_primary is required")
	elif not is_valid_id(primary):
		issues.append("theme_primary '%s' is not a known theme" % String(primary))
	if secondary != &"" and not is_valid_id(secondary):
		issues.append("theme_secondary '%s' is not a known theme" % String(secondary))
	if secondary != &"" and secondary == primary:
		issues.append("theme_secondary must differ from theme_primary")
	return issues
