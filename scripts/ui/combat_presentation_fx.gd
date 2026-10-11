class_name CombatPresentationFx
extends RefCounted
## Shared presentation timing helpers (keeps CombatPresentation thinner).


static func pace_scale(pace_config: CombatPaceConfig, combat_tick: int) -> float:
	if pace_config == null:
		return 1.0
	return pace_config.get_pace_scale(combat_tick)


static func scaled_duration(base_sec: float, pace_config: CombatPaceConfig, combat_tick: int) -> float:
	if pace_config == null:
		return base_sec
	return pace_config.scaled_duration(base_sec, combat_tick)
