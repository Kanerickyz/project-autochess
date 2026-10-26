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
	## 将技能持有者瞬移至目标邻格（切比雪夫=1）；无空位则跳过。
	TELEPORT_ADJACENT_TO_TARGET,
	## 击杀续动：重置持有者本动步数并允许再普攻（由战斗层处理；不触发 OnRoundStart）。
	GRANT_ACTOR_TURN_REFRESH,
	## 吞噬：将目标当前有效攻击与生命上限加到持有者本场临时层，并经伤害管线消灭目标（触发死亡/友亡）。
	## 转移量不走 merge_value_mult / 全局 ×6。
	ABSORB_STATS_AND_KILL,
	## 开战读金加身：攻/血各 +⌊玩家当前金/2⌋（不扣金；不加升星倍率；仅玩家友方）。
	BUFF_STATS_FROM_GOLD_HALF,
	## 一动结束存活时 +1 续动充能（上限由持有者星级与技能 merge_value_mult 决定）。
	ADD_BANKED_TURN_REFRESH_CHARGE,
	## 自己回合开始时消耗 1 充能，本动正常段结束后获得完整再动（战斗层处理）。
	CONSUME_BANKED_TURN_REFRESH_FOR_BONUS_TURN,
}

enum DamageMode { FIXED, OWNER_ATTACK_PERCENT }

const STAT_NAMES: Array[StringName] = [
	&"attack",
	&"max_hp",
	&"attack_range",
	&"move_range",
	&"steps_per_turn",
]

@export var action_type: Type = Type.MODIFY_STAT
@export var stat_name: StringName = &"attack"
@export var value: int = 0
@export var damage_mode: DamageMode = DamageMode.FIXED
@export_range(0, 200, 1) var percent: int = 100
@export var spawn_unit: UnitData
@export var spawn_hp_override: int = 0
@export_range(1, 8, 1) var spawn_count: int = 1
## >0 时按事件目标（死者）基础身体攻/血百分比生成，忽略本场临时层；0 = 用 spawn_unit 原值。
@export_range(0, 100, 5) var spawn_owner_base_percent: int = 0
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
