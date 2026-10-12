class_name UnitBoardDisplay
extends Node2D

const CARD_SCENE := preload("res://scenes/ui/unit_card_display.tscn")
const PROJECT_THEME := preload("res://resources/ui/project_theme.tres")

var _card: UnitCardDisplay
var _unit: UnitInstance
var _cell_size: int = 64
var _home_position: Vector2 = Vector2.ZERO
var _motion_tween: Tween
var _fx_tween: Tween
var _move_start: Vector2 = Vector2.ZERO
var _move_end: Vector2 = Vector2.ZERO
var _move_hop_height: float = 0.0
var _hovered: bool = false
var _acting: bool = false

const COLOR_HOVER := Color(1.18, 1.18, 1.08)
const COLOR_ACTING := Color(1.38, 1.30, 0.82)


func _ready() -> void:
	if _card == null:
		_ensure_card()
	if _cell_size > 0:
		configure(_cell_size)


func configure(
	cell_size: int,
	width_ratio: float = 0.9,
	height_ratio: float = 1.05,
	portrait_fill: float = -1.0,
	character_cy_ratio: float = -1.0,
) -> void:
	_cell_size = cell_size
	_ensure_card()
	var card_size := Vector2(float(cell_size) * width_ratio, float(cell_size) * height_ratio)
	_card.configure(card_size)
	if portrait_fill > 0.0:
		_card.set_portrait_fill_ratio(portrait_fill, character_cy_ratio)
	if portrait_fill > 0.0:
		_card.set_portrait_fill_ratio(portrait_fill, character_cy_ratio)
	_card.position = -card_size * 0.5


func set_character_phase(phase: UnitCardDisplay.CharacterPhase) -> void:
	if _card != null:
		_card.set_character_phase(phase)


func play_body_reveal(duration: float = -1.0) -> Tween:
	if _card == null:
		return null
	return _card.play_body_reveal(duration)


func play_body_hide(duration: float = -1.0) -> Tween:
	if _card == null:
		return null
	return _card.play_body_hide(duration)


func bind_unit(unit: UnitInstance) -> void:
	_unit = unit
	_home_position = position
	if _unit != null and _unit.is_alive():
		scale = Vector2.ONE
	_ensure_card()
	_card.bind_unit_instance(unit)


func refresh_display() -> void:
	if _unit == null or _card == null:
		return
	if not is_node_ready():
		return
	_card.bind_unit_instance(_unit)


func set_hovered(hovered: bool) -> void:
	if _hovered == hovered:
		return
	_hovered = hovered
	_apply_visual_modulate()


func set_acting(acting: bool) -> void:
	if _acting == acting:
		return
	_acting = acting
	_apply_visual_modulate()


func set_head_idle(active: bool) -> void:
	if _card != null:
		_card.set_head_idle(active)


func _apply_visual_modulate() -> void:
	if _acting:
		modulate = COLOR_ACTING
	elif _hovered:
		modulate = COLOR_HOVER
	else:
		modulate = Color.WHITE


func play_move_to(world_pos: Vector2, duration: float) -> Tween:
	_kill_motion_tween()
	_home_position = world_pos
	_move_start = position
	_move_end = world_pos
	_move_hop_height = float(_cell_size) * CombatAnimationConfig.MOVE_HOP_HEIGHT
	_motion_tween = create_tween()
	_motion_tween.tween_method(_apply_move_hop, 0.0, 1.0, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return _motion_tween


func play_slide_charge_to(world_pos: Vector2, duration: float) -> Tween:
	_kill_motion_tween()
	_home_position = world_pos
	var start := position
	var end := world_pos
	var delta := end - start
	var dist := delta.length()
	if dist < 0.5:
		return play_move_to(world_pos, duration)

	var dir := delta / dist
	var stretch := _charge_stretch_scale(dir)
	var windup_dist := minf(
		dist * CombatAnimationConfig.SLIDE_WINDUP_RATIO,
		float(_cell_size) * 0.3,
	)
	var overshoot_dist := minf(
		dist * CombatAnimationConfig.SLIDE_OVERSHOOT_RATIO,
		float(_cell_size) * 0.24,
	)
	var windup_pos := start - dir * windup_dist
	var overshoot_pos := end + dir * overshoot_dist

	var windup_t := duration * CombatAnimationConfig.SLIDE_WINDUP_FRAC
	var charge_t := duration * CombatAnimationConfig.SLIDE_CHARGE_FRAC
	var settle_t := maxf(duration - windup_t - charge_t, 0.04)

	scale = Vector2.ONE
	_kill_motion_tween()
	_motion_tween = create_tween()
	_motion_tween.tween_property(self, "position", windup_pos, windup_t)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "scale", Vector2(0.92, 0.92), windup_t)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_motion_tween.tween_property(self, "position", overshoot_pos, charge_t)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_motion_tween.parallel().tween_property(self, "scale", stretch, charge_t * 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_motion_tween.tween_property(self, "position", end, settle_t)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "scale", Vector2.ONE, settle_t)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_callback(func() -> void:
		if _card != null:
			_card.squash_impact(1.15)
	)
	return _motion_tween


func _charge_stretch_scale(dir: Vector2) -> Vector2:
	if absf(dir.x) >= absf(dir.y):
		return Vector2(CombatAnimationConfig.SLIDE_STRETCH, CombatAnimationConfig.SLIDE_SQUASH)
	return Vector2(CombatAnimationConfig.SLIDE_SQUASH, CombatAnimationConfig.SLIDE_STRETCH)


func play_clash_impact(impact_scale: float = 1.2) -> void:
	if _card != null:
		_card.squash_impact(impact_scale)


func play_clash_out(
	clash_world: Vector2,
	duration: float,
	travel_ratio: float,
	impact_scale: float = 1.2,
) -> Tween:
	_kill_motion_tween()
	position = _home_position
	var clash_pos := _home_position.lerp(clash_world, travel_ratio)
	_motion_tween = create_tween()
	_motion_tween.tween_property(self, "position", clash_pos, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion_tween.tween_callback(func() -> void:
		play_clash_impact(impact_scale)
	)
	return _motion_tween


func play_clash_back(duration: float) -> Tween:
	_kill_motion_tween()
	_motion_tween = create_tween()
	_motion_tween.tween_property(self, "position", _home_position, duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return _motion_tween


func play_clash_attack(
	clash_world: Vector2,
	out_duration: float,
	back_duration: float,
	travel_ratio: float = CombatAnimationConfig.CLASH_TRAVEL_RATIO,
) -> Tween:
	_kill_motion_tween()
	var clash_pos := _home_position.lerp(clash_world, travel_ratio)
	_motion_tween = create_tween()
	_motion_tween.tween_property(self, "position", clash_pos, out_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion_tween.tween_callback(func() -> void:
		if _card != null:
			_card.squash_impact(1.2)
	)
	_motion_tween.tween_property(self, "position", _home_position, back_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return _motion_tween


func play_attack_lunge(target_pos: Vector2, duration: float) -> Tween:
	var clash := target_pos if target_pos != Vector2.ZERO else _home_position + Vector2.RIGHT
	var out_dur := duration * 0.45
	var back_dur := duration * 0.55
	return play_clash_attack(clash, out_dur, back_dur)


func play_hit_impact(
	pace_scale: float = 1.0,
	knockback_dir: Vector2 = Vector2.ZERO,
	damage_amount: int = 0,
	is_crit: bool = false,
) -> Tween:
	_kill_fx_tween()
	var impact_scale := _impact_pace_scale(pace_scale)
	if is_crit:
		impact_scale *= 1.12
	var flash_dur := maxf(
		CombatAnimationConfig.DUR_HIT_FLASH * impact_scale,
		CombatAnimationConfig.MIN_IMPACT_DURATION,
	)
	if is_crit:
		flash_dur *= 1.1
	var original := modulate
	var peak_flash := Color(2.0, 2.0, 2.0, 1.0)
	var mid_flash := Color(1.35, 0.65, 0.65, 1.0)
	if is_crit:
		peak_flash = CombatAnimationConfig.CRIT_HIT_TINT * 1.5
		mid_flash = CombatAnimationConfig.CRIT_HIT_TINT
	_fx_tween = create_tween()
	_fx_tween.tween_callback(func() -> void:
		if _card != null:
			_card.squash_impact(impact_scale, damage_amount)
	)
	if knockback_dir.length_squared() > 0.01:
		var knockback_mult := CombatAnimationConfig.KNOCKBACK_PX
		if is_crit:
			knockback_mult *= CombatAnimationConfig.CRIT_KNOCKBACK_MULT
		var push := knockback_dir.normalized() * knockback_mult
		var base_pos := position
		var knocked := base_pos + push
		var push_t := flash_dur * 0.35
		_fx_tween.set_parallel(true)
		_fx_tween.tween_property(self, "modulate", peak_flash, push_t)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_fx_tween.tween_property(self, "position", knocked, push_t)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_fx_tween.set_parallel(false)
		_fx_tween.tween_property(self, "position", _home_position, flash_dur * 0.65)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_fx_tween.tween_property(self, "modulate", peak_flash, flash_dur * 0.25)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_fx_tween.tween_property(self, "modulate", mid_flash, flash_dur * 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fx_tween.tween_property(self, "modulate", original, flash_dur * 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return _fx_tween


func play_hit_flash(pace_scale: float = 1.0) -> Tween:
	return play_hit_impact(pace_scale)


func pop_damage_number(amount: int, duration: float = -1.0, is_crit: bool = false) -> Tween:
	if _card == null:
		return null
	if duration < 0.0:
		duration = CombatAnimationConfig.DUR_DAMAGE_POPUP
	return _card.pop_damage_number(amount, duration, is_crit)


func play_buff_pop(pace_scale: float = 1.0) -> Tween:
	if _card == null:
		return null
	return _card.play_buff_pulse(pace_scale)


func play_heal_pulse(pace_scale: float = 1.0) -> Tween:
	if _card == null:
		return null
	return _card.play_heal_pulse(pace_scale)


func play_skill_damage_flash(
	pace_scale: float = 1.0,
	knockback_dir: Vector2 = Vector2.ZERO,
	damage_amount: int = 0,
) -> Tween:
	_kill_fx_tween()
	var impact_scale := _impact_pace_scale(pace_scale)
	var flash_dur := maxf(
		CombatAnimationConfig.DUR_HIT_FLASH * impact_scale * 1.15,
		CombatAnimationConfig.MIN_IMPACT_DURATION,
	)
	var original := modulate
	_fx_tween = create_tween()
	_fx_tween.tween_callback(func() -> void:
		if _card != null:
			_card.squash_impact(impact_scale, damage_amount)
	)
	if knockback_dir.length_squared() > 0.01:
		var push := knockback_dir.normalized() * CombatAnimationConfig.KNOCKBACK_PX * 1.15
		var base_pos := position
		var knocked := base_pos + push
		var push_t := flash_dur * 0.4
		_fx_tween.set_parallel(true)
		_fx_tween.tween_property(self, "modulate", Color(1.5, 0.55, 0.5, 1.0), push_t)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_fx_tween.tween_property(self, "position", knocked, push_t)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_fx_tween.set_parallel(false)
		_fx_tween.tween_property(self, "position", _home_position, flash_dur * 0.6)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_fx_tween.tween_property(self, "modulate", Color(1.5, 0.55, 0.5, 1.0), flash_dur * 0.45)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_fx_tween.tween_property(self, "modulate", original, flash_dur * 0.55)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return _fx_tween


func play_spawn_pop(duration: float = -1.0) -> Tween:
	_kill_motion_tween()
	if duration < 0.0:
		duration = CombatAnimationConfig.DUR_SPAWN
	modulate.a = 0.0
	scale = Vector2(0.2, 0.2)
	_home_position = position
	_motion_tween = create_tween()
	_motion_tween.set_parallel(true)
	_motion_tween.tween_property(self, "modulate:a", 1.0, duration)
	_motion_tween.tween_property(self, "scale", Vector2.ONE, duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return _motion_tween


func play_teleport_move(
	from_world: Vector2,
	to_world: Vector2,
	duration: float,
	on_arrive: Callable = Callable(),
) -> Tween:
	_kill_motion_tween()
	_kill_fx_tween()

	update_home_position(from_world)
	scale = Vector2.ONE
	modulate = Color.WHITE

	var depart_t := duration * CombatAnimationConfig.DUR_TELEPORT_DEPART_FRAC
	var arrive_t := maxf(duration - depart_t, 0.04)
	var tint := CombatAnimationConfig.TELEPORT_TINT
	var arrive_scale := CombatAnimationConfig.TELEPORT_ARRIVE_SCALE_START
	var tint_fade := Color(tint.r, tint.g, tint.b, 0.0)

	_motion_tween = create_tween()

	_motion_tween.set_parallel(true)
	_motion_tween.tween_property(self, "modulate", tint_fade, depart_t)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion_tween.tween_property(self, "scale", CombatAnimationConfig.TELEPORT_DEPART_SQUASH, depart_t)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion_tween.set_parallel(false)

	_motion_tween.tween_callback(func() -> void:
		update_home_position(to_world)
		scale = Vector2(arrive_scale, arrive_scale)
		modulate = tint_fade
		if on_arrive.is_valid():
			on_arrive.call()
	)

	_motion_tween.set_parallel(true)
	_motion_tween.tween_property(self, "modulate", Color.WHITE, arrive_t)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "scale", Vector2.ONE, arrive_t)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.set_parallel(false)

	_motion_tween.tween_callback(func() -> void:
		_apply_visual_modulate()
	)
	return _motion_tween


func play_death_fade(fade_duration: float = -1.0, flash_duration: float = -1.0) -> Tween:
	stop_active_tweens(false)
	if fade_duration < 0.0:
		fade_duration = CombatAnimationConfig.DUR_DEATH
	if flash_duration < 0.0:
		flash_duration = CombatAnimationConfig.DUR_DEATH_FLASH
	modulate = Color.WHITE
	scale = Vector2.ONE
	position = _home_position
	var drop_y := _home_position.y + float(_cell_size) * 0.08
	var squash := CombatAnimationConfig.DEATH_SQUASH
	var end_scale := squash * 0.74
	_motion_tween = create_tween()
	_motion_tween.tween_property(self, "scale", squash, flash_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_motion_tween.tween_property(self, "scale", end_scale, fade_duration)
	_motion_tween.parallel().tween_property(self, "modulate:a", 0.0, fade_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion_tween.parallel().tween_property(self, "position:y", drop_y, fade_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return _motion_tween


func tween_hp_visual(pace_scale: float = 1.0) -> Tween:
	if _card == null:
		return null
	return _card.tween_hp_visual(pace_scale)


func restore_opacity_modulate() -> void:
	_apply_visual_modulate()


func stop_active_tweens(reset_visual: bool = true) -> void:
	_kill_motion_tween()
	_kill_fx_tween()
	restore_opacity_modulate()
	if _card != null:
		_card.stop_active_tweens()


func update_home_position(world_pos: Vector2) -> void:
	_home_position = world_pos
	position = world_pos


func set_tween_paused(paused: bool) -> void:
	for tween in [_motion_tween, _fx_tween]:
		if tween != null and tween.is_valid():
			if paused:
				tween.pause()
			else:
				tween.play()
	if _card != null:
		_card.set_card_tween_paused(paused)


func _apply_move_hop(t: float) -> void:
	var flat := _move_start.lerp(_move_end, t)
	var hop := sin(t * PI) * _move_hop_height
	position = flat - Vector2(0.0, hop)


func _ensure_card() -> void:
	if _card != null:
		return
	_card = CARD_SCENE.instantiate() as UnitCardDisplay
	_card.name = "UnitCardDisplay"
	_card.theme = PROJECT_THEME
	_card.set_board_paper_mode(true)
	add_child(_card)


func _kill_motion_tween() -> void:
	if _motion_tween != null and _motion_tween.is_running():
		_motion_tween.kill()
	_motion_tween = null


func _kill_fx_tween() -> void:
	if _fx_tween != null and _fx_tween.is_running():
		_fx_tween.kill()
	_fx_tween = null


func _impact_pace_scale(pace_scale: float) -> float:
	return maxf(pace_scale, CombatAnimationConfig.MIN_IMPACT_DURATION / CombatAnimationConfig.DUR_HIT_FLASH)
