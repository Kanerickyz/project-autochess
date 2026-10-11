class_name EffectAction
extends Resource

enum Type {
	MODIFY_STAT,
	HEAL,
	SPAWN_UNIT,
	DEAL_DAMAGE,
	SET_HP_FROM_ALLY_PERCENT,
	GRANT_GOLD,
	PERMANENT_DECK_STAT,
	STOCK_FREE_BUFF,
	SHOP_CHARACTER_BONUS_HP,
	APPLY_CELL_EFFECT,
	FRIENDS_HURT_AOE,
	SWAP_POSITIONS,
	SPLIT_SELF,
	FUSE_EXPLODE,
}

enum DamageMode { FIXED, OWNER_ATTACK_PERCENT }

const STAT_NAMES: Array[StringName] = [
	&"attack",
	&"max_hp",
	&"crit_rate_percent",
	&"attack_range",
	&"move_range",
]

@export var action_type: Type = Type.MODIFY_STAT
@export var stat_name: StringName = &"attack"
@export var value: int = 0
@export var damage_mode: DamageMode = DamageMode.FIXED
@export_range(0, 200, 1) var percent: int = 100
@export var spawn_unit: UnitData
@export var spawn_hp_override: int = 0
@export_range(1, 8, 1) var spawn_count: int = 1
@export var buff_card: BuffCardData
@export var cell_effect: CellEffectData
@export_range(0, 3, 1) var radius: int = 1
@export var include_center: bool = true
@export_range(0, 16, 1) var threshold: int = 0


func is_known_stat_name() -> bool:
	return stat_name in STAT_NAMES


## Returns human-readable validation issues for editor / tooling.
func validate_config() -> PackedStringArray:
	var issues: PackedStringArray = []
	match action_type:
		Type.MODIFY_STAT, Type.PERMANENT_DECK_STAT:
			if not is_known_stat_name():
				issues.append("stat_name '%s' is not in whitelist" % String(stat_name))
		Type.SPAWN_UNIT, Type.SPLIT_SELF:
			if spawn_unit == null and action_type == Type.SPAWN_UNIT:
				issues.append("SPAWN_UNIT requires spawn_unit")
		Type.STOCK_FREE_BUFF:
			if buff_card == null:
				issues.append("STOCK_FREE_BUFF requires buff_card")
		Type.APPLY_CELL_EFFECT:
			if cell_effect == null:
				issues.append("APPLY_CELL_EFFECT requires cell_effect")
		_:
			pass
	return issues
