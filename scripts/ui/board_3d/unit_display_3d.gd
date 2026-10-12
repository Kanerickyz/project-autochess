class_name UnitDisplay3D
extends Node3D

const DISPLAY_SCENE := preload("res://scenes/units/unit_board_display.tscn")
const CARD_WIDTH_RATIO := 0.98
const CARD_HEIGHT_RATIO := 1.12
## 视口边距，避免头像描边/角标贴边被 SubViewport 裁切
const VIEWPORT_PAD_PX := 6
const VIEWPORT_PAD_BOTTOM_PX := 62
## Under top-down camera: lean card so it still reads like isometric (not flat/edge-on).
const SPRITE_LEAN_DEG := -56.0

var _unit: UnitInstance
var _tile_size: float = 1.0
var _pixel_cell_size: int = 64
var _home_position: Vector3 = Vector3.ZERO
var _motion_tween: Tween
var _fx_tween: Tween
var _death_sprite_tween: Tween
var _move_start: Vector3 = Vector3.ZERO
var _move_end: Vector3 = Vector3.ZERO
var _move_hop_height: float = 0.0
var _dragging: bool = false
var _preview_mode: bool = false
var _viewport: SubViewport
var _display: UnitBoardDisplay
var _sprite: Sprite3D
var _vfx_layer: Node2D
var _project_screen: Callable


func configure(tile_size: float, pixel_cell_size: int = 64) -> void:
	_tile_size = tile_size
	_pixel_cell_size = maxi(1, pixel_cell_size)
	_ensure_viewport_display()
	_ensure_sprite()
	if _display != null:
		_display.configure(
			_pixel_cell_size,
			CARD_WIDTH_RATIO,
			CARD_HEIGHT_RATIO,
			UnitCardDisplay.BOARD_PORTRAIT_FILL,
			UnitCardDisplay.BOARD_CHARACTER_CY_RATIO,
		)
	_update_sprite_layout()


func set_vfx_context(layer: Node2D, project_screen: Callable) -> void:
	_vfx_layer = layer
	_project_screen = project_screen


func bind_unit(unit: UnitInstance) -> void:
	_unit = unit
	_home_position = position
	if _unit != null and _unit.is_alive():
		scale = Vector3.ONE
	_ensure_viewport_display()
	_ensure_sprite()
	if _display != null:
		_display.bind_unit(unit)
	_update_sprite_layout()
	_restore_opacity_modulate()


func refresh_display() -> void:
	if _display != null:
		_display.refresh_display()


func set_character_phase(phase: UnitCardDisplay.CharacterPhase) -> void:
	if _display != null:
		_display.set_character_phase(phase)


func play_body_reveal(duration: float = -1.0) -> Tween:
	if _display == null:
		return null
	return _display.play_body_reveal(duration)


func play_body_hide(duration: float = -1.0) -> Tween:
	if _display == null:
		return null
	return _display.play_body_hide(duration)


func set_acting(acting: bool) -> void:
	if _display != null:
		_display.set_acting(acting)


func set_hovered(hovered: bool) -> void:
	if _display != null:
		_display.set_hovered(hovered)


func set_head_idle(active: bool) -> void:
	if _display != null:
		_display.set_head_idle(active)


func set_dragging(dragging: bool) -> void:
	var changed := _dragging != dragging
	_dragging = dragging
	if changed or not dragging:
		_apply_overlay_modulate()


func restore_opacity_modulate() -> void:
	_restore_opacity_modulate()


func set_preview_mode(active: bool) -> void:
	_preview_mode = active
	_apply_overlay_modulate()


func update_home_position(world_pos: Vector2) -> void:
	_home_position = Vector3(world_pos.x, _home_position.y, world_pos.y)
	position = _home_position


func update_home_position_3d(world_pos: Vector3) -> void:
	_home_position = world_pos
	position = world_pos


func sync_home_y(y: float) -> void:
	_home_position.y = y
	position.y = y


func play_move_to(world_pos: Vector2, duration: float) -> Tween:
	_kill_motion_tween()
	var end := Vector3(world_pos.x, _home_position.y, world_pos.y)
	_home_position = end
	_move_start = position
	_move_end = end
	_move_hop_height = _tile_size * CombatAnimationConfig.MOVE_HOP_HEIGHT
	_motion_tween = create_tween()
	_motion_tween.tween_method(_apply_move_hop, 0.0, 1.0, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return _motion_tween


func play_slide_charge_to(world_pos: Vector2, duration: float) -> Tween:
	_kill_motion_tween()
	var end := Vector3(world_pos.x, _home_position.y, world_pos.y)
	_home_position = end
	var start := position
	var delta := end - start
	var dist := Vector2(delta.x, delta.z).length()
	if dist < 0.05:
		return play_move_to(world_pos, duration)

	var dir := Vector3(delta.x, 0.0, delta.z).normalized()
	var stretch := _charge_stretch_scale(dir)
	var windup_dist := minf(dist * CombatAnimationConfig.SLIDE_WINDUP_RATIO, _tile_size * 0.3)
	var overshoot_dist := minf(dist * CombatAnimationConfig.SLIDE_OVERSHOOT_RATIO, _tile_size * 0.24)
	var windup_pos := start - dir * windup_dist
	var overshoot_pos := end + dir * overshoot_dist

	var windup_t := duration * CombatAnimationConfig.SLIDE_WINDUP_FRAC
	var charge_t := duration * CombatAnimationConfig.SLIDE_CHARGE_FRAC
	var settle_t := maxf(duration - windup_t - charge_t, 0.04)

	scale = Vector3.ONE
	_motion_tween = create_tween()
	_motion_tween.tween_property(self, "position", windup_pos, windup_t)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "scale", Vector3(0.92, 0.92, 0.92), windup_t)
	_motion_tween.tween_property(self, "position", overshoot_pos, charge_t)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_motion_tween.parallel().tween_property(self, "scale", stretch, charge_t * 0.4)
	_motion_tween.tween_property(self, "position", end, settle_t)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "scale", Vector3.ONE, settle_t)
	return _motion_tween


func play_clash_out(
	clash_world: Vector2,
	duration: float,
	travel_ratio: float,
	impact_scale: float = 1.2,
) -> Tween:
	_kill_motion_tween()
	position = _home_position
	var clash := Vector3(clash_world.x, _home_position.y, clash_world.y)
	var clash_pos := _home_position.lerp(clash, travel_ratio)
	_motion_tween = create_tween()
	_motion_tween.tween_property(self, "position", clash_pos, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion_tween.tween_callback(func() -> void:
		if _display != null:
			_display.play_clash_impact(impact_scale)
	)
	return _motion_tween


func play_clash_back(duration: float) -> Tween:
	_kill_motion_tween()
	_motion_tween = create_tween()
	_motion_tween.tween_property(self, "position", _home_position, duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return _motion_tween


func play_hit_impact(
	pace_scale: float = 1.0,
	knockback_dir: Vector2 = Vector2.ZERO,
	damage_amount: int = 0,
	is_crit: bool = false,
) -> Tween:
	_kill_fx_tween()
	var display_tween: Tween = null
	if _display != null:
		display_tween = _display.play_hit_impact(
			pace_scale,
			Vector2.ZERO,
			damage_amount,
			is_crit,
		)

	if knockback_dir.length_squared() <= 0.01:
		return display_tween

	var impact_scale := maxf(
		pace_scale,
		CombatAnimationConfig.MIN_IMPACT_DURATION / CombatAnimationConfig.DUR_HIT_FLASH,
	)
	if is_crit:
		impact_scale *= 1.12
	var flash_dur := maxf(
		CombatAnimationConfig.DUR_HIT_FLASH * impact_scale,
		CombatAnimationConfig.MIN_IMPACT_DURATION,
	)
	var push := Vector3(
		knockback_dir.normalized().x,
		0.0,
		knockback_dir.normalized().y,
	) * CombatAnimationConfig.KNOCKBACK_PX * (
		CombatAnimationConfig.CRIT_KNOCKBACK_MULT if is_crit else 1.0
	)
	var knocked := _home_position + push
	var push_t := flash_dur * 0.35
	_fx_tween = create_tween()
	_fx_tween.tween_property(self, "position", knocked, push_t)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_fx_tween.tween_property(self, "position", _home_position, flash_dur * 0.65)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return display_tween


func play_skill_damage_flash(
	pace_scale: float = 1.0,
	knockback_dir: Vector2 = Vector2.ZERO,
	damage_amount: int = 0,
) -> Tween:
	return play_hit_impact(pace_scale, knockback_dir, damage_amount, false)


func pop_damage_number(amount: int, duration: float = -1.0, is_crit: bool = false) -> Tween:
	if duration < 0.0:
		duration = CombatAnimationConfig.DUR_DAMAGE_POPUP
	if _vfx_layer != null and _project_screen.is_valid():
		return _spawn_screen_damage_popup(amount, duration, is_crit)
	if _display != null:
		return _display.pop_damage_number(amount, duration, is_crit)
	return null


func _spawn_screen_damage_popup(amount: int, duration: float, is_crit: bool) -> Tween:
	var label := Label.new()
	label.text = UnitCardDisplay.format_damage_popup_text(amount)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var font_mult := CombatAnimationConfig.damage_pop_font_mult(amount)
	var font_size := int(UnitCardDisplay.DAMAGE_POPUP_FONT_BASE * font_mult)
	var start_scale_val := UnitCardDisplay.DAMAGE_POPUP_SCALE_START\
		* CombatAnimationConfig.damage_pop_overshoot(amount)
	if is_crit:
		font_size = int(font_size * CombatAnimationConfig.CRIT_POPUP_FONT_MULT)
		start_scale_val *= CombatAnimationConfig.CRIT_POPUP_OVERSHOOT_MULT
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", maxi(6, int(font_size * 0.24)))
	if is_crit:
		label.add_theme_color_override("font_color", CombatAnimationConfig.COLOR_CRIT_POPUP)
		label.modulate = Color.WHITE
	else:
		label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2, 1.0))
		label.modulate = Color.WHITE
	var popup_w := UnitCardDisplay.DAMAGE_POPUP_WIDTH_BASE * font_mult
	var popup_h := UnitCardDisplay.DAMAGE_POPUP_HEIGHT_BASE * font_mult
	var anchor := get_billboard_top_global()
	var screen_pos: Vector2 = _project_screen.call(anchor)
	label.size = Vector2(popup_w, popup_h)
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(start_scale_val, start_scale_val)
	label.position = screen_pos - label.pivot_offset
	_vfx_layer.add_child(label)
	var end_scale_val := UnitCardDisplay.DAMAGE_POPUP_SCALE_END
	var end_pos_y := label.position.y - UnitCardDisplay.DAMAGE_POPUP_FLOAT_BASE
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", end_pos_y, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(end_scale_val, end_scale_val), duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "modulate:a", 0.0, duration * 0.85)\
		.set_delay(duration * 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
	return tween


func play_buff_pop(pace_scale: float = 1.0) -> Tween:
	if _display == null:
		return null
	return _display.play_buff_pop(pace_scale)


func play_heal_pulse(pace_scale: float = 1.0) -> Tween:
	if _display == null:
		return null
	return _display.play_heal_pulse(pace_scale)


func play_spawn_pop(duration: float = -1.0) -> Tween:
	_kill_motion_tween()
	if duration < 0.0:
		duration = CombatAnimationConfig.DUR_SPAWN
	scale = Vector3(0.2, 0.2, 0.2)
	if _sprite != null:
		_sprite.modulate.a = 0.0
	_motion_tween = create_tween()
	_motion_tween.set_parallel(true)
	if _sprite != null:
		_motion_tween.tween_property(_sprite, "modulate:a", 1.0, duration)
	_motion_tween.tween_property(self, "scale", Vector3.ONE, duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.finished.connect(func() -> void: _restore_opacity_modulate(), CONNECT_ONE_SHOT)
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
	scale = Vector3.ONE
	var depart_t := duration * CombatAnimationConfig.DUR_TELEPORT_DEPART_FRAC
	var arrive_t := maxf(duration - depart_t, 0.04)
	var tint := CombatAnimationConfig.TELEPORT_TINT
	var tint_fade := Color(tint.r, tint.g, tint.b, 0.0)
	_motion_tween = create_tween()
	if _sprite != null:
		_motion_tween.tween_property(_sprite, "modulate", tint_fade, depart_t)
	_motion_tween.tween_callback(func() -> void:
		update_home_position(to_world)
		if on_arrive.is_valid():
			on_arrive.call()
	)
	if _sprite != null:
		_motion_tween.tween_property(_sprite, "modulate", Color.WHITE, arrive_t)
	_motion_tween.parallel().tween_property(self, "scale", Vector3.ONE, arrive_t)
	_motion_tween.finished.connect(func() -> void: _restore_opacity_modulate(), CONNECT_ONE_SHOT)
	return _motion_tween


func prepare_death_visual() -> void:
	_kill_motion_tween()
	_kill_fx_tween()
	_death_sprite_tween = null
	position = _home_position
	scale = Vector3.ONE
	set_acting(false)
	set_head_idle(false)
	if _sprite != null:
		_sprite.modulate = Color.WHITE
	if _display != null:
		_display.set_acting(false)
		_display.stop_active_tweens(false)


func play_death_fade(fade_duration: float = -1.0, flash_duration: float = -1.0) -> Tween:
	prepare_death_visual()
	if fade_duration < 0.0:
		fade_duration = CombatAnimationConfig.DUR_DEATH
	if flash_duration < 0.0:
		flash_duration = CombatAnimationConfig.DUR_DEATH_FLASH
	var display_tween: Tween = null
	if _display != null:
		display_tween = _display.play_death_fade(fade_duration, flash_duration)
	if _sprite != null:
		_death_sprite_tween = create_tween()
		_death_sprite_tween.tween_property(_sprite, "modulate:a", 0.0, fade_duration)\
			.set_delay(flash_duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return display_tween if display_tween != null else _death_sprite_tween


func get_death_sprite_tween() -> Tween:
	return _death_sprite_tween


func tween_hp_visual(pace_scale: float = 1.0) -> Tween:
	if _display == null:
		return null
	return _display.tween_hp_visual(pace_scale)


func stop_active_tweens(reset_visual: bool = true) -> void:
	_kill_motion_tween()
	_kill_fx_tween()
	_restore_opacity_modulate()
	if _display != null:
		_display.stop_active_tweens(reset_visual)


func set_tween_paused(paused: bool) -> void:
	for tween in [_motion_tween, _fx_tween]:
		if tween != null and tween.is_valid():
			if paused:
				tween.pause()
			else:
				tween.play()
	if _display != null:
		_display.set_tween_paused(paused)


func get_bound_unit() -> UnitInstance:
	return _unit


func get_billboard_top_global() -> Vector3:
	var world_h := _get_card_world_height()
	return global_position + Vector3(0.0, _get_sprite_center_y() + world_h * 0.5, 0.0)


func get_billboard_center_global() -> Vector3:
	return global_position + Vector3(0.0, _get_sprite_center_y(), 0.0)


func get_screen_anchor() -> Vector2:
	var center := get_billboard_center_global()
	return Vector2(center.x, center.z)


func _apply_move_hop(t: float) -> void:
	var flat := _move_start.lerp(_move_end, t)
	var hop := sin(t * PI) * _move_hop_height
	position = flat + Vector3(0.0, hop, 0.0)


func _charge_stretch_scale(dir: Vector3) -> Vector3:
	if absf(dir.x) >= absf(dir.z):
		return Vector3(CombatAnimationConfig.SLIDE_STRETCH, CombatAnimationConfig.SLIDE_SQUASH, CombatAnimationConfig.SLIDE_SQUASH)
	return Vector3(CombatAnimationConfig.SLIDE_SQUASH, CombatAnimationConfig.SLIDE_SQUASH, CombatAnimationConfig.SLIDE_STRETCH)


func _ensure_viewport_display() -> void:
	if _viewport != null and _display != null:
		return
	_viewport = SubViewport.new()
	_viewport.name = "UnitCardViewport"
	_viewport.transparent_bg = true
	_viewport.handle_input_locally = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_display = DISPLAY_SCENE.instantiate() as UnitBoardDisplay
	_viewport.add_child(_display)


func _ensure_sprite() -> void:
	if _sprite != null:
		return
	_sprite = Sprite3D.new()
	_sprite.name = "CardSprite3D"
	# Fixed lean (not camera billboard): keep isometric character read under top-down cam.
	_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_sprite.centered = true
	_sprite.shaded = false
	_sprite.double_sided = true
	add_child(_sprite)


func _update_sprite_layout() -> void:
	if _viewport == null or _sprite == null:
		return
	var card_w := int(round(float(_pixel_cell_size) * CARD_WIDTH_RATIO))
	var card_h := int(round(float(_pixel_cell_size) * CARD_HEIGHT_RATIO))
	var pad := VIEWPORT_PAD_PX
	var vp_w := card_w + pad * 2
	var vp_h := card_h + pad + VIEWPORT_PAD_BOTTOM_PX
	_viewport.size = Vector2i(maxi(1, vp_w), maxi(1, vp_h))
	if _display != null:
		# 卡面中心对齐视口中心，避免非对称 padding 在俯视时把头部顶偏
		_display.position = Vector2(float(vp_w) * 0.5, float(vp_h) * 0.5)
	_sprite.texture = _viewport.get_texture()
	var world_w := _tile_size * CARD_WIDTH_RATIO
	var world_h := _tile_size * CARD_HEIGHT_RATIO
	if card_w > 0:
		_sprite.pixel_size = world_w / float(card_w)
	_sprite.rotation_degrees = Vector3(SPRITE_LEAN_DEG, 0.0, 0.0)
	# Feet on board (y≈0); z=0 centers the leaned footprint on the cell (avoids -Z spill).
	var half_h := world_h * 0.5
	var lean_abs := absf(deg_to_rad(SPRITE_LEAN_DEG))
	_sprite.position = Vector3(0.0, half_h * cos(lean_abs), 0.0)
	_sprite.offset = Vector2.ZERO


func _get_card_world_height() -> float:
	return _tile_size * CARD_HEIGHT_RATIO


func _get_sprite_center_y() -> float:
	if _sprite != null:
		return _sprite.position.y
	var half_h := _get_card_world_height() * 0.5
	return half_h * cos(absf(deg_to_rad(SPRITE_LEAN_DEG)))


func _restore_opacity_modulate() -> void:
	_apply_overlay_modulate()
	if _display != null:
		_display.restore_opacity_modulate()


func _apply_overlay_modulate() -> void:
	if _sprite == null:
		return
	if _dragging:
		_sprite.modulate = Color(1.0, 1.0, 1.0, 0.35)
	elif _preview_mode:
		_sprite.modulate = Color(1.0, 1.0, 1.0, 0.55)
	else:
		_sprite.modulate = Color.WHITE


func _kill_motion_tween() -> void:
	if _motion_tween != null and _motion_tween.is_running():
		_motion_tween.kill()
	_motion_tween = null


func _kill_fx_tween() -> void:
	if _fx_tween != null and _fx_tween.is_running():
		_fx_tween.kill()
	_fx_tween = null
