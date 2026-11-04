class_name ExpeditionRelicData
extends Resource

## 远征圣物 · 数据资源。效果种类用 effect_id 分发；点数见导出字段。
## Content 对照 Documents/Content/EXPEDITION_RELICS_ROSTER.md。

enum Tier { T1 = 1, T2 = 2, T3 = 3 }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_range(1, 3, 1) var tier: int = 1
## 招募出售退金（按 Tier 默认 2/4/6，可覆盖）。
@export_range(0, 99, 1) var sell_gold: int = 2
## 稳定效果键（与 RelicEffectService 分发一致），通常等于 id。
@export var effect_id: String = ""

@export_group("Economy")
@export var bonus_floor_gold: int = 0
@export var map_shop_refresh_cost_delta: int = 0
@export var min_refresh_cost: int = 1
@export var map_shop_price_delta: int = 0
@export var sell_unit_bonus_gold: int = 0
@export var event_gold_cost_reduction: int = 0
@export var shatter_after_first_real_save: bool = false

@export_group("Combat start")
@export var combat_start_temp_max_hp: int = 0
@export var combat_start_temp_attack: int = 0
@export var front_two_rows_temp_attack: int = 0
@export var requires_any_theme_formed: bool = false
@export var per_formed_theme_temp_attack: int = 0
@export var relic_attack_bonus_cap: int = 0
@export var temp_attack_per_bench_unit: int = 0
@export var min_max_hp_after: int = 1

@export_group("Combat triggers")
@export var bonus_temp_attack_after_hurt_ability: int = 0
@export var cap_per_unit_per_round: int = 0
@export var neighbor_buff_extra_attack: int = 0
@export var neighbor_buff_extra_max_hp: int = 0
@export var reflect_damage: int = 0
@export var cap_per_ally_per_round: int = 0
@export var kill_spread_temp_attack: int = 0
@export var cap_per_combat: int = 0
@export var death_nearby_temp_attack: int = 0
@export var half_hp_temp_attack: int = 0
@export var revenge_next_hit_damage_bonus: int = 0
@export var kill_cleave_damage: int = 0
@export var death_team_temp_attack: int = 0
@export var cap_triggers_per_combat: int = 0
@export var ortho_pair_adjacent_enemy_damage_bonus: int = 0
@export var death_damage_to_killer: int = 0
@export var nearby_enemy_thorns: int = 0
@export var thorns_stack_soft_cap_per_enemy: int = 0
@export var cap_death_triggers_per_combat: int = 0


func get_effect_id() -> String:
	if not effect_id.is_empty():
		return effect_id
	return id


func resolve_sell_gold() -> int:
	if sell_gold > 0:
		return sell_gold
	match clampi(tier, 1, 3):
		1:
			return 2
		2:
			return 4
		_:
			return 6
