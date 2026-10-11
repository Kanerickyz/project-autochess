class_name UnitCardDisplay
extends Control

enum CharacterPhase { PREPARE, COMBAT }

const PLACEHOLDER_HEAD := preload("res://assets/sprites/0_head.png")
const PLACEHOLDER_BODY := preload("res://assets/sprites/0_body.png")
const PAPER_TEX_SIZE := 256.0
## 0_head 不透明区域 fallback（动态读取失败时使用）
const PAPER_HEAD_CONTENT_MAX := 94.0
const PAPER_HEAD_VISUAL_CENTER_Y := 119.0
const PAPER_BODY_BOTTOM_Y := 217.0
const PAPER_BOARD_BOTTOM_PAD := 6.0
const PAPER_BOARD_TOP_PAD := 4.0
const BOARD_PORTRAIT_FILL := 0.28
const BOARD_CHARACTER_CY_RATIO := 0.44
const PAPER_BODY_Z_INDEX := 1
const PAPER_HEAD_Z_INDEX := 2

const COLOR_PLAYER := Color(0.35, 0.75, 0.95, 1.0)
const COLOR_ENEMY := Color(0.95, 0.4, 0.35, 1.0)
const COLOR_RAGE := Color(0.95, 0.55, 0.2, 1.0)
const COLOR_SPAWN := Color(0.65, 0.45, 0.95, 1.0)
const COLOR_SPIDER := Color(0.45, 0.25, 0.7, 1.0)
const COLOR_PIG := Color(0.95, 0.65, 0.75, 1.0)
const COLOR_T2 := Color(0.3, 0.65, 0.85, 1.0)
const COLOR_LEVEL := Color(1.0, 0.92, 0.2, 1.0)
const COLOR_ATTACK := Color(0.55, 0.58, 0.62, 1.0)
const COLOR_CRIT := Color(1.0, 0.82, 0.25, 1.0)
const COLOR_DAMAGE_POPUP := Color(1.0, 0.25, 0.2, 1.0)
const COLOR_HEALTH := Color(0.92, 0.18, 0.22, 1.0)
const COLOR_OUTLINE_WHITE := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_OUTLINE_BLACK := Color(0.05, 0.06, 0.08, 1.0)

const TIER_LABEL_COLORS: Array[Color] = [
	Color(0.75, 0.82, 0.7, 1.0),
	Color(0.55, 0.78, 0.82, 1.0),
	Color(0.45, 0.62, 0.95, 1.0),
	Color(0.72, 0.52, 0.95, 1.0),
	Color(0.95, 0.72, 0.35, 1.0),
	Color(0.98, 0.45, 0.55, 1.0),
]

const CARD_SCENE := preload("res://scenes/ui/unit_card_display.tscn")
const UNIT_ICON_BASE := "res://assets/sprites/units"
const DESIGN_HEIGHT := 110.0
const SIZE_DEFAULT := Vector2(110.0, 138.0)
const SIZE_SHOP := Vector2(125.0, 148.0)
const DAMAGE_POPUP_FONT_BASE := 44.0
const DAMAGE_POPUP_FONT_MIN := 28
const DAMAGE_POPUP_WIDTH_BASE := 112.0
const DAMAGE_POPUP_HEIGHT_BASE := 58.0
const DAMAGE_POPUP_FLOAT_BASE := 44.0
const DAMAGE_POPUP_SCALE_START := 1.45
const DAMAGE_POPUP_SCALE_END := 0.72

static var _icon_cache: Dictionary = {}
static var _paper_opaque_cache: Dictionary = {}

@onready var _level_badge: Control = %LevelBadge
@onready var _lvl_label: Label = %LvlLabel
@onready var _level_number: Label = %LevelNumber
@onready var _exp_bar: HBoxContainer = %ExpBar
@onready var _character_root: Node2D = %CharacterRoot
@onready var _outline_white: Polygon2D = %OutlineWhite
@onready var _outline_black: Polygon2D = %OutlineBlack
@onready var _body: Polygon2D = %Body
@onready var _portrait: Sprite2D = %Portrait
@onready var _paper_body_anchor: Node2D = %PaperBodyAnchor
@onready var _body_sprite: Sprite2D = %BodySprite
@onready var _stat_bar: Control = %StatBar
@onready var _attack_root: Node2D = %AttackRoot
@onready var _attack_icon: Polygon2D = %AttackIcon
@onready var _attack_label: Label = %AttackLabel
@onready var _crit_root: Node2D = %CritRoot
@onready var _crit_icon: Polygon2D = %CritIcon
@onready var _crit_label: Label = %CritLabel
@onready var _health_root: Node2D = %HealthRoot
@onready var _health_icon: Polygon2D = %HealthIcon
@onready var _health_label: Label = %HealthLabel
@onready var _state_overlay: ColorRect = %StateOverlay
@onready var _team_badge: Label = %TeamBadge
@onready var _tier_badge: Label = %TierBadge
@onready var _damage_popup: Label = %DamagePopup

var _card_tween: Tween
var _popup_tween: Tween
var _body_reveal_tween: Tween
var _idle_tween: Tween
var _head_idle_requested: bool = false
var _body_reveal_running: bool = false
var _body_hide_running: bool = false
var _board_paper_mode: bool = false
var _character_phase: CharacterPhase = CharacterPhase.PREPARE
var _paper_scale: float = 1.0
var _paper_head_center_adjust: float = 0.0

const COLOR_PORTRAIT_ENEMY := Color(1.0, 0.78, 0.78, 1.0)
const COLOR_OUTLINE_PLAYER := Color(0.85, 0.95, 1.0, 1.0)
const COLOR_OUTLINE_ENEMY := Color(1.0, 0.55, 0.48, 1.0)
const COLOR_OUTLINE_INNER_ENEMY := Color(0.28, 0.08, 0.06, 1.0)
const COLOR_BUFF := Color(1.25, 1.15, 0.55, 1.0)
const COLOR_HEAL := Color(0.35, 0.9, 0.55, 1.0)

var _unit: UnitInstance
var _unit_data: UnitData
var _override_attack: int = -1
var _override_hp: int = -1
var _override_max_hp: int = -1
var _override_crit_percent: int = -1
var _card_size: Vector2 = SIZE_DEFAULT
var _show_current_hp: bool = false
var _team: UnitInstance.Team = UnitInstance.Team.PLAYER
var _body_half: float = 19.0
var _portrait_fill_ratio: float = 0.22
var _character_cy_ratio: float = 0.46
var _exp_current: int = 0
var _exp_needed: int = 2
var _exp_is_max: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_level(1)
	if _card_size != Vector2.ZERO:
		configure(_card_size)


func configure(card_size: Vector2) -> void:
	_card_size = card_size
	custom_minimum_size = card_size
	size = card_size
	if not is_node_ready():
		return
	_apply_layout()
	_apply_exp_bar()
	_apply_icon_shapes()
	refresh_stats()


func set_board_paper_mode(enabled: bool) -> void:
	_board_paper_mode = enabled
	if enabled:
		_portrait_fill_ratio = BOARD_PORTRAIT_FILL
		_character_cy_ratio = BOARD_CHARACTER_CY_RATIO
	if not is_node_ready():
		return
	_apply_layout()
	_apply_portrait()


func set_character_phase(phase: CharacterPhase) -> void:
	_character_phase = phase
	if phase == CharacterPhase.PREPARE:
		set_head_idle(false)
	if not _board_paper_mode or not is_node_ready():
		return
	if _body_reveal_running or _body_hide_running:
		return
	_kill_body_reveal_tween()
	match phase:
		CharacterPhase.PREPARE:
			_set_paper_body_visible(false)
			_set_paper_body_scale_y(0.0)
		CharacterPhase.COMBAT:
			_set_paper_body_visible(true)
			_set_paper_body_scale_y(1.0)


func play_body_reveal(duration: float = -1.0) -> Tween:
	if not _board_paper_mode or _body_sprite == null:
		return null
	if duration < 0.0:
		duration = CombatAnimationConfig.DUR_BODY_REVEAL
	_stop_head_idle()
	_kill_body_reveal_tween()
	_character_phase = CharacterPhase.COMBAT
	_body_reveal_running = true
	_set_paper_body_visible(true)
	_set_paper_body_scale_y(0.0)
	_body_reveal_tween = create_tween()
	_body_reveal_tween.tween_method(_set_paper_body_scale_y, 0.0, 1.0, duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_body_reveal_tween.finished.connect(func() -> void:
		_body_reveal_running = false
	, CONNECT_ONE_SHOT)
	return _body_reveal_tween


func play_body_hide(duration: float = -1.0) -> Tween:
	if not _board_paper_mode or _body_sprite == null:
		return null
	if duration < 0.0:
		duration = CombatAnimationConfig.DUR_BODY_REVEAL
	set_head_idle(false)
	_kill_body_reveal_tween()
	var from_reveal := 1.0
	if _paper_scale > 0.0:
		from_reveal = _body_sprite.scale.y / _paper_scale
	_body_hide_running = true
	_set_paper_body_visible(true)
	_body_reveal_tween = create_tween()
	_body_reveal_tween.tween_method(_set_paper_body_scale_y, from_reveal, 0.0, duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_body_reveal_tween.finished.connect(func() -> void:
		_body_hide_running = false
		_character_phase = CharacterPhase.PREPARE
		_set_paper_body_visible(false)
	, CONNECT_ONE_SHOT)
	return _body_reveal_tween


func set_portrait_fill_ratio(ratio: float, character_cy_ratio: float = -1.0) -> void:
	_portrait_fill_ratio = ratio
	if character_cy_ratio >= 0.0:
		_character_cy_ratio = character_cy_ratio
	if not is_node_ready():
		return
	_apply_layout()
	_apply_portrait()


func bind_unit_instance(unit: UnitInstance) -> void:
	_unit = unit
	_unit_data = unit.unit_data if unit != null else null
	_override_crit_percent = -1
	_show_current_hp = true
	if unit != null:
		_team = unit.team
		set_level(unit.level)
		set_experience(0, 0, true)
	refresh_stats()
	_apply_body_color()
	_apply_portrait()
	_apply_team_visuals()


func bind_unit_data(
	data: UnitData,
	atk: int = -1,
	hp: int = -1,
	max_hp: int = -1,
	crit_percent: int = -1,
) -> void:
	_unit = null
	_unit_data = data
	_override_attack = atk
	_override_hp = hp
	_override_max_hp = max_hp
	_override_crit_percent = crit_percent
	_show_current_hp = false
	_team = data.team_default if data != null else UnitInstance.Team.PLAYER
	refresh_stats()
	_apply_body_color()
	_apply_portrait()
	_apply_team_visuals()


func set_level(level: int = 1) -> void:
	if _level_number != null:
		_level_number.text = str(maxi(1, level))


func set_experience(current_xp: int, xp_needed: int, is_max: bool) -> void:
	_exp_current = maxi(0, current_xp)
	_exp_needed = maxi(0, xp_needed)
	_exp_is_max = is_max
	if is_node_ready():
		_apply_exp_bar()


func bind_deck_entry(entry: DeckEntry, level_config: LevelConfig) -> void:
	if entry == null or entry.unit == null:
		return
	bind_unit_data(
		entry.unit,
		DeckUpgradeService.get_display_attack(entry),
		DeckUpgradeService.get_display_max_hp(entry),
		DeckUpgradeService.get_display_max_hp(entry),
		DeckUpgradeService.get_display_crit_rate(entry),
	)
	set_level(entry.level)
	set_experience(
		entry.experience,
		DeckUpgradeService.get_xp_to_next_level(entry, level_config),
		DeckUpgradeService.is_max_level(entry, level_config),
	)


func set_state(selected: bool, deployed: bool) -> void:
	if _state_overlay == null:
		return
	if deployed:
		_state_overlay.visible = true
		_state_overlay.color = Color(0.05, 0.06, 0.08, 0.45)
		modulate = Color(0.55, 0.55, 0.55, 1.0)
	elif selected:
		_state_overlay.visible = true
		_state_overlay.color = Color(1.0, 0.95, 0.55, 0.18)
		modulate = Color(1.15, 1.15, 1.05, 1.0)
	else:
		_state_overlay.visible = false
		modulate = Color.WHITE


func get_body_node() -> Node2D:
	return _body


static func format_damage_popup_text(amount: int) -> String:
	return "-%d!" % amount


func pop_damage_number(amount: int, duration: float = -1.0, is_crit: bool = false) -> Tween:
	if _damage_popup == null:
		return null
	_kill_popup_tween()
	var card_scale := _card_size.y / DESIGN_HEIGHT
	if duration < 0.0:
		duration = CombatAnimationConfig.DUR_DAMAGE_POPUP
	var font_mult := CombatAnimationConfig.damage_pop_font_mult(amount)
	var start_scale_val := DAMAGE_POPUP_SCALE_START * CombatAnimationConfig.damage_pop_overshoot(amount)
	if is_crit:
		font_mult *= CombatAnimationConfig.CRIT_POPUP_FONT_MULT
		start_scale_val *= CombatAnimationConfig.CRIT_POPUP_OVERSHOOT_MULT
	var font_size := maxi(DAMAGE_POPUP_FONT_MIN, int(DAMAGE_POPUP_FONT_BASE * card_scale * font_mult))
	var popup_size := Vector2(
		DAMAGE_POPUP_WIDTH_BASE * card_scale * font_mult,
		DAMAGE_POPUP_HEIGHT_BASE * card_scale * font_mult,
	)
	_damage_popup.text = format_damage_popup_text(amount)
	_damage_popup.add_theme_font_size_override("font_size", font_size)
	_damage_popup.add_theme_constant_override(
		"outline_size",
		maxi(6, int(font_size * 0.24)),
	)
	_damage_popup.visible = true
	if is_crit:
		_damage_popup.add_theme_color_override(
			"font_color",
			CombatAnimationConfig.COLOR_CRIT_POPUP,
		)
		_damage_popup.modulate = Color.WHITE
	else:
		_damage_popup.add_theme_color_override("font_color", COLOR_DAMAGE_POPUP)
		_damage_popup.modulate = Color.WHITE
	_damage_popup.rotation = 0.0
	var center_x := _card_size.x * 0.5
	var center_y := 4.0 * card_scale + popup_size.y * 0.5
	var end_center_y := center_y - DAMAGE_POPUP_FLOAT_BASE * card_scale
	var drift := CombatAnimationConfig.DAMAGE_POP_DRIFT_PX * card_scale
	if amount >= 3:
		drift *= 1.2
	var end_center_x := center_x + (drift if amount % 2 == 0 else -drift)
	_damage_popup.size = popup_size
	_damage_popup.pivot_offset = popup_size * 0.5
	_damage_popup.position = Vector2(center_x, center_y) - _damage_popup.pivot_offset
	_damage_popup.scale = Vector2(start_scale_val, start_scale_val)
	var end_pos := Vector2(end_center_x, end_center_y) - _damage_popup.pivot_offset
	var end_scale_val := DAMAGE_POPUP_SCALE_END

	_popup_tween = create_tween()
	_popup_tween.set_parallel(true)
	_popup_tween.tween_property(_damage_popup, "position", end_pos, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_popup_tween.tween_property(_damage_popup, "scale", Vector2(end_scale_val, end_scale_val), duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_popup_tween.tween_property(_damage_popup, "modulate:a", 0.0, duration * 0.85)\
		.set_delay(duration * 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_popup_tween.set_parallel(false)
	_popup_tween.tween_callback(func() -> void:
		if _damage_popup != null:
			_damage_popup.visible = false
			_damage_popup.modulate = Color.WHITE
			_damage_popup.add_theme_color_override("font_color", COLOR_DAMAGE_POPUP)
			_damage_popup.scale = Vector2.ONE
			_damage_popup.rotation = 0.0
	)
	return _popup_tween


func squash_impact(pace_scale: float = 1.0, damage_amount: int = 0) -> Tween:
	var root := _get_animation_root()
	if root == null:
		return null
	_kill_card_tween()
	var base := _resolve_animation_scale()
	var stretch := 1.15
	var squash := 0.85
	if damage_amount >= 4:
		stretch = 1.22
		squash = 0.78
	_card_tween = create_tween()
	_card_tween.tween_property(
		root,
		"scale",
		Vector2(base.x * stretch, base.y * squash),
		0.05 * pace_scale,
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_card_tween.tween_property(root, "scale", base, 0.07 * pace_scale)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return _card_tween


func play_buff_pulse(pace_scale: float = 1.0) -> Tween:
	var root := _get_animation_root()
	if root == null:
		return null
	_kill_card_tween()
	var base := _resolve_animation_scale()
	var original := modulate
	_card_tween = create_tween()
	_card_tween.set_parallel(true)
	_card_tween.tween_property(self, "modulate", COLOR_BUFF, 0.08 * pace_scale)
	_card_tween.tween_property(root, "scale", base * 1.18, 0.08 * pace_scale)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_card_tween.set_parallel(false)
	_card_tween.tween_property(self, "modulate", original, 0.1 * pace_scale)
	_card_tween.tween_property(root, "scale", base, 0.1 * pace_scale)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return _card_tween


func play_heal_pulse(pace_scale: float = 1.0) -> Tween:
	var root := _get_animation_root()
	if root == null:
		return null
	_kill_card_tween()
	var base := _resolve_animation_scale()
	var original := modulate
	_card_tween = create_tween()
	_card_tween.set_parallel(true)
	_card_tween.tween_property(self, "modulate", COLOR_HEAL.lightened(0.35), 0.08 * pace_scale)
	_card_tween.tween_property(root, "scale", base * 1.12, 0.08 * pace_scale)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_card_tween.set_parallel(false)
	_card_tween.tween_property(self, "modulate", original, 0.1 * pace_scale)
	_card_tween.tween_property(root, "scale", base, 0.1 * pace_scale)
	return _card_tween


func set_head_idle(active: bool) -> void:
	if _head_idle_requested == active:
		return
	_head_idle_requested = active
	if active:
		_start_head_idle()
	else:
		_stop_head_idle()


func stop_active_tweens() -> void:
	_kill_card_tween()
	_kill_popup_tween()
	_kill_body_reveal_tween()
	_kill_idle_tween()
	if _portrait != null:
		_portrait.position = Vector2.ZERO


func set_card_tween_paused(paused: bool) -> void:
	for tween in [_card_tween, _popup_tween, _body_reveal_tween, _idle_tween]:
		if tween != null and tween.is_valid():
			if paused:
				tween.pause()
			else:
				tween.play()


func tween_hp_visual(_pace_scale: float = 1.0) -> Tween:
	_reset_animation_scale()
	return null


func refresh_stats() -> void:
	if not is_node_ready():
		return
	var attack := _resolve_attack()
	var health := _resolve_health_display()
	var crit := _resolve_crit_percent()
	if _attack_label != null:
		_attack_label.text = str(attack)
	if _crit_label != null:
		_crit_label.text = "%d%%" % crit
	if _health_label != null:
		_health_label.text = health
	_apply_hp_visual(true)


func apply_hp_visual(instant: bool) -> void:
	if instant:
		_apply_hp_visual(true)
	else:
		tween_hp_visual()


static func color_for_unit(unit_data: UnitData, team: UnitInstance.Team) -> Color:
	if unit_data != null and not unit_data.id.is_empty():
		match unit_data.id:
			"peacock":
				return COLOR_RAGE
			"cricket", "zombie_cricket":
				return COLOR_SPAWN
			"spider", "spider_hatchling":
				return COLOR_SPIDER
			"pig":
				return COLOR_PIG
			"hedgehog", "crab":
				return COLOR_T2
	return COLOR_PLAYER if team == UnitInstance.Team.PLAYER else COLOR_ENEMY


func _resolve_attack() -> int:
	if _unit != null:
		return _unit.get_effective_attack()
	if _override_attack >= 0:
		return _override_attack
	if _unit_data != null and _unit_data.stats != null:
		return _unit_data.stats.attack
	return 0


func _resolve_crit_percent() -> int:
	if _unit != null:
		return int(round(_unit.get_effective_crit_rate() * 100.0))
	if _override_crit_percent >= 0:
		return _override_crit_percent
	if _unit_data != null and _unit_data.stats != null:
		return _unit_data.stats.crit_rate_percent
	return 5


func _resolve_health_display() -> String:
	if _unit != null:
		return str(_unit.current_hp)
	if _override_hp >= 0:
		return str(_override_hp)
	if _override_max_hp >= 0:
		return str(_override_max_hp)
	if _unit_data != null and _unit_data.stats != null:
		return str(_unit_data.stats.max_hp)
	return "0"


func _resolve_hp_ratio() -> float:
	if _unit != null:
		return float(_unit.current_hp) / float(maxi(1, _unit.get_effective_max_hp()))
	if _override_max_hp > 0 and _override_hp >= 0:
		return float(_override_hp) / float(_override_max_hp)
	if _unit_data != null and _unit_data.stats != null:
		return 1.0
	return 1.0


func _apply_body_color() -> void:
	if _body == null:
		return
	_body.color = color_for_unit(_unit_data, _team)


func _apply_hp_visual(_instant: bool) -> void:
	_reset_animation_scale()


func _apply_layout() -> void:
	var w := _card_size.x
	var h := _card_size.y
	var scale := h / DESIGN_HEIGHT
	var outline_outer := 4.0 * scale
	var outline_inner := 2.0 * scale

	if _level_badge != null:
		_level_badge.position = Vector2(2.0 * scale, 2.0 * scale)
		_level_badge.size = Vector2(w * 0.46, h * 0.22)

	if _lvl_label != null:
		_lvl_label.add_theme_font_size_override("font_size", maxi(8, int(9.0 * scale)))
		_level_number.add_theme_font_size_override("font_size", maxi(10, int(12.0 * scale)))

	var body_half := minf(w, h) * _portrait_fill_ratio
	_body_half = body_half
	var cx := w * 0.5
	var cy := h * _character_cy_ratio
	if _character_root != null:
		_character_root.position = Vector2(cx, cy)
		_apply_square_polygon(_outline_white, body_half + outline_outer + outline_inner)
		_apply_square_polygon(_outline_black, body_half + outline_inner)
		_apply_square_polygon(_body, body_half)

	if _team_badge != null:
		var badge_size := maxi(14, int(16.0 * scale))
		_team_badge.add_theme_font_size_override("font_size", badge_size)
		_team_badge.position = Vector2(w - badge_size * 1.35, 2.0 * scale)
		_team_badge.size = Vector2(badge_size * 1.2, badge_size * 1.1)

	_apply_tier_badge_layout(w, scale)

	var stat_h := h * 0.18
	var stat_y := h - stat_h - 2.0 * scale
	if _stat_bar != null:
		_stat_bar.position = Vector2(w * 0.075, stat_y)
		_stat_bar.size = Vector2(w * 0.85, stat_h)

	var stat_w := _stat_bar.size.x
	var atk_w := stat_w * 0.33
	var crit_w := stat_w * 0.34
	var hp_w := stat_w * 0.33
	var badge_h := stat_h
	var font_size := maxi(9, int(11.0 * scale))
	_layout_stat_badge(_attack_root, _attack_label, Vector2(0.0, 0.0), atk_w, badge_h, font_size)
	_layout_stat_badge(
		_crit_root,
		_crit_label,
		Vector2(atk_w, 0.0),
		crit_w,
		badge_h,
		font_size,
		0.62,
	)
	_layout_stat_badge(
		_health_root,
		_health_label,
		Vector2(atk_w + crit_w, 0.0),
		hp_w,
		badge_h,
		font_size,
	)

	if _state_overlay != null:
		_state_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_state_overlay.offset_left = 0.0
		_state_overlay.offset_top = 0.0
		_state_overlay.offset_right = 0.0
		_state_overlay.offset_bottom = 0.0

	if _damage_popup != null:
		_damage_popup.visible = false

	_apply_portrait()
	_apply_team_visuals()
	_apply_tier_badge()


func _resolve_tier() -> int:
	if _unit_data == null:
		return -1
	return clampi(_unit_data.tier, 1, 6)


func _apply_tier_badge_layout(card_width: float, layout_scale: float) -> void:
	if _tier_badge == null:
		return
	var font_size := maxi(10, int(12.0 * layout_scale))
	_tier_badge.add_theme_font_size_override("font_size", font_size)
	var badge_h := font_size * 1.2
	var badge_w := font_size * 2.4
	var x_offset := 2.0 * layout_scale
	if _team == UnitInstance.Team.ENEMY:
		x_offset += badge_w * 0.85
	_tier_badge.position = Vector2(card_width - badge_w - x_offset, 2.0 * layout_scale)
	_tier_badge.size = Vector2(badge_w, badge_h)


func _apply_tier_badge() -> void:
	if _tier_badge == null:
		return
	var tier := _resolve_tier()
	if tier < 1:
		_tier_badge.visible = false
		return
	_tier_badge.visible = true
	_tier_badge.text = "T%d" % tier
	_tier_badge.add_theme_color_override(
		"font_color",
		TIER_LABEL_COLORS[tier - 1],
	)
	if is_node_ready():
		var layout_scale := _card_size.y / DESIGN_HEIGHT
		_apply_tier_badge_layout(_card_size.x, layout_scale)


func _apply_portrait() -> void:
	if not is_node_ready():
		return
	if _board_paper_mode:
		_apply_paper_character()
		return

	var icon := _resolve_unit_icon()
	var has_icon := icon != null
	if _body != null:
		_body.visible = not has_icon
	if _portrait == null:
		_apply_team_visuals()
		return

	if has_icon:
		_portrait.texture = icon
		_portrait.visible = true
		_fit_portrait_to_body(_body_half * 2.0)
	else:
		_portrait.texture = null
		_portrait.visible = false
	_apply_team_visuals()


func _resolve_unit_icon() -> Texture2D:
	if _unit_data == null:
		return null
	if _unit_data.icon != null:
		return _unit_data.icon
	if _unit_data.id.is_empty():
		return null
	if _icon_cache.has(_unit_data.id):
		return _icon_cache[_unit_data.id] as Texture2D
	var path := "%s/%s.png" % [UNIT_ICON_BASE, _unit_data.id]
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex != null:
		_icon_cache[_unit_data.id] = tex
	return tex


func _resolve_paper_textures() -> Array:
	var head := PLACEHOLDER_HEAD
	var body := PLACEHOLDER_BODY
	if _unit_data == null:
		return [head, body]
	if _unit_data.portrait_head != null:
		head = _unit_data.portrait_head
	if _unit_data.portrait_body != null:
		body = _unit_data.portrait_body
	return [head, body]


static func _opaque_content_rect(tex: Texture2D) -> Rect2i:
	if tex == null:
		return Rect2i(0, 0, int(PAPER_TEX_SIZE), int(PAPER_TEX_SIZE))
	var key: String = tex.resource_path
	if key.is_empty():
		key = str(tex.get_instance_id())
	if _paper_opaque_cache.has(key):
		return _paper_opaque_cache[key]
	var img := tex.get_image()
	if img == null or img.is_empty():
		var fallback := Rect2i(
			0,
			0,
			int(PAPER_HEAD_CONTENT_MAX),
			int(PAPER_HEAD_CONTENT_MAX),
		)
		_paper_opaque_cache[key] = fallback
		return fallback
	var used := img.get_used_rect()
	_paper_opaque_cache[key] = used
	return used


func _compute_paper_layout(head_tex: Texture2D, body_tex: Texture2D) -> Dictionary:
	var head_rect := _opaque_content_rect(head_tex)
	var body_rect := _opaque_content_rect(body_tex)
	var tex_center_y := float(head_tex.get_height()) * 0.5
	var head_center_y := float(head_rect.position.y) + float(head_rect.size.y) * 0.5
	if head_rect.size == Vector2i.ZERO:
		head_center_y = PAPER_HEAD_VISUAL_CENTER_Y

	var neck_y := head_center_y
	var feet_y := PAPER_BODY_BOTTOM_Y
	if body_rect.size != Vector2i.ZERO:
		neck_y = float(body_rect.position.y)
		feet_y = float(body_rect.position.y + body_rect.size.y)

	# 有身体贴图时按身体宽度统一缩放，避免皇冠/浮饰撑大头部包围盒导致角色偏小
	var head_span_for_scale := maxf(
		maxf(float(head_rect.size.x), float(head_rect.size.y)),
		PAPER_HEAD_CONTENT_MAX,
	)
	if body_rect.size != Vector2i.ZERO:
		head_span_for_scale = maxf(float(body_rect.size.x), PAPER_HEAD_CONTENT_MAX)

	var feet_span := maxf(1.0, feet_y - head_center_y)
	var head_top_span := maxf(1.0, head_center_y - float(head_rect.position.y))
	if body_rect.size != Vector2i.ZERO:
		feet_span = maxf(1.0, feet_y - neck_y)
		head_top_span = maxf(1.0, neck_y - head_center_y)

	var head_diameter := _body_half * 2.0
	var scale := head_diameter / head_span_for_scale

	if _board_paper_mode:
		var layout_scale := _card_size.y / DESIGN_HEIGHT
		var bottom_pad := PAPER_BOARD_BOTTOM_PAD * layout_scale
		var top_pad := PAPER_BOARD_TOP_PAD * layout_scale
		var head_anchor_y := _card_size.y * _character_cy_ratio
		var max_feet_y := _card_size.y - bottom_pad
		scale = minf(scale, (max_feet_y - head_anchor_y) / feet_span)
		scale = minf(scale, (head_anchor_y - top_pad) / head_top_span)

	return {
		"scale": maxf(scale, 0.01),
		"head_center_adjust": (tex_center_y - head_center_y) * scale,
	}


func _apply_paper_character() -> void:
	if _outline_white != null:
		_outline_white.visible = false
	if _outline_black != null:
		_outline_black.visible = false
	if _body != null:
		_body.visible = false
	var paper_textures := _resolve_paper_textures()
	var layout := _compute_paper_layout(paper_textures[0], paper_textures[1])
	_paper_scale = layout["scale"]
	_paper_head_center_adjust = layout["head_center_adjust"]
	if _portrait != null:
		_portrait.visible = true
		_portrait.texture = paper_textures[0]
		_portrait.centered = true
		_portrait.position = Vector2.ZERO
		_portrait.region_enabled = false
		_portrait.scale = Vector2(_paper_scale, _paper_scale)
		_portrait.z_index = PAPER_HEAD_Z_INDEX
	if _paper_body_anchor != null:
		_paper_body_anchor.position = Vector2.ZERO
		_paper_body_anchor.z_index = PAPER_BODY_Z_INDEX
	if _body_sprite != null:
		_body_sprite.texture = paper_textures[1]
		_body_sprite.centered = true
		_body_sprite.position = Vector2.ZERO
		_body_sprite.region_enabled = false
	_apply_paper_character_root_position()
	if _body_reveal_running or _body_hide_running:
		_apply_team_visuals()
		return
	match _character_phase:
		CharacterPhase.PREPARE:
			_set_paper_body_visible(false)
			_set_paper_body_scale_y(0.0)
		CharacterPhase.COMBAT:
			_set_paper_body_visible(true)
			_set_paper_body_scale_y(1.0)
	_apply_team_visuals()


func _apply_paper_character_root_position() -> void:
	if _character_root == null:
		return
	var cx := _card_size.x * 0.5
	var base_cy := _card_size.y * _character_cy_ratio
	_character_root.position = Vector2(cx, base_cy + _paper_head_center_adjust)


func _set_paper_body_visible(visible: bool) -> void:
	if _paper_body_anchor != null:
		_paper_body_anchor.visible = visible
	if _body_sprite != null:
		_body_sprite.visible = visible


func _set_paper_body_scale_y(scale_y: float) -> void:
	if _body_sprite == null:
		return
	var sy := maxf(scale_y, 0.0)
	_body_sprite.scale = Vector2(_paper_scale, _paper_scale * sy)


func _apply_team_visuals() -> void:
	if not is_node_ready():
		return
	var is_enemy := _team == UnitInstance.Team.ENEMY

	if _board_paper_mode:
		if _portrait != null and _portrait.visible:
			_portrait.modulate = COLOR_PORTRAIT_ENEMY if is_enemy else Color.WHITE
			_portrait.flip_h = is_enemy
		if _body_sprite != null:
			_body_sprite.modulate = COLOR_PORTRAIT_ENEMY if is_enemy else Color.WHITE
			_body_sprite.flip_h = is_enemy
		if _team_badge != null:
			_team_badge.visible = is_enemy
		_apply_tier_badge()
		return

	if _outline_white != null:
		_outline_white.visible = true
		_outline_white.color = COLOR_OUTLINE_ENEMY if is_enemy else COLOR_OUTLINE_PLAYER
	if _outline_black != null:
		_outline_black.visible = true
		_outline_black.color = COLOR_OUTLINE_INNER_ENEMY if is_enemy else COLOR_OUTLINE_BLACK
	if _portrait != null and _portrait.visible:
		_portrait.modulate = COLOR_PORTRAIT_ENEMY if is_enemy else Color.WHITE
		_portrait.flip_h = is_enemy
	if _team_badge != null:
		_team_badge.visible = is_enemy
	_apply_tier_badge()


func _fit_portrait_to_body(body_diameter: float) -> void:
	if _portrait == null or _portrait.texture == null:
		return
	var tex_size := _portrait.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var scale_factor := body_diameter / maxf(tex_size.x, tex_size.y)
	_portrait.scale = Vector2(scale_factor, scale_factor)
	_portrait.position = Vector2.ZERO


func _layout_stat_badge(
	root: Node2D,
	label: Label,
	pos: Vector2,
	badge_w: float,
	badge_h: float,
	font_size: int,
	label_width_ratio: float = 0.55,
) -> void:
	if root == null:
		return
	root.position = pos + Vector2(badge_w * 0.5, badge_h * 0.5)
	if label != null:
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_constant_override("outline_size", maxi(3, int(font_size * 0.35)))
		label.position = Vector2(-badge_w * 0.18, -badge_h * 0.22)
		label.size = Vector2(badge_w * label_width_ratio, badge_h * 0.55)


func _apply_square_polygon(poly: Polygon2D, half: float) -> void:
	if poly == null:
		return
	poly.polygon = PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half),
	])


func _apply_exp_bar() -> void:
	if _exp_bar == null:
		return
	for child in _exp_bar.get_children():
		child.queue_free()
	if _exp_is_max or _exp_needed <= 0:
		_exp_bar.visible = false
		return
	_exp_bar.visible = true
	var scale := _card_size.y / DESIGN_HEIGHT
	for i in _exp_needed:
		var segment := ColorRect.new()
		segment.custom_minimum_size = Vector2(14.0 * scale, 5.0 * scale)
		if i < _exp_current:
			segment.color = Color(0.95, 0.75, 0.2, 1.0)
		else:
			segment.color = Color(0.42, 0.28, 0.18, 1.0)
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_exp_bar.add_child(segment)


func _apply_icon_shapes() -> void:
	var scale := _card_size.y / DESIGN_HEIGHT
	if _attack_icon != null:
		var s := 7.0 * scale
		_attack_icon.polygon = PackedVector2Array([
			Vector2(-s * 0.8, s * 0.2),
			Vector2(-s * 0.2, -s * 0.9),
			Vector2(s * 0.5, -s * 0.3),
			Vector2(s * 0.9, s * 0.4),
			Vector2(s * 0.1, s * 0.9),
		])
		_attack_icon.color = COLOR_ATTACK
	if _health_icon != null:
		var hs := 6.5 * scale
		_health_icon.polygon = PackedVector2Array([
			Vector2(0.0, hs * 0.95),
			Vector2(-hs * 0.95, -hs * 0.15),
			Vector2(-hs * 0.45, -hs * 0.85),
			Vector2(0.0, -hs * 0.45),
			Vector2(hs * 0.45, -hs * 0.85),
			Vector2(hs * 0.95, -hs * 0.15),
		])
		_health_icon.color = COLOR_HEALTH
	if _crit_icon != null:
		var cs := 6.0 * scale
		_crit_icon.polygon = PackedVector2Array([
			Vector2(0.0, -cs),
			Vector2(cs * 0.28, -cs * 0.28),
			Vector2(cs, 0.0),
			Vector2(cs * 0.28, cs * 0.28),
			Vector2(0.0, cs),
			Vector2(-cs * 0.28, cs * 0.28),
			Vector2(-cs, 0.0),
			Vector2(-cs * 0.28, -cs * 0.28),
		])
		_crit_icon.color = COLOR_CRIT


func _get_animation_root() -> Node2D:
	return _character_root


func _resolve_animation_scale() -> Vector2:
	return Vector2.ONE


func _reset_animation_scale() -> void:
	var root := _get_animation_root()
	if root != null:
		root.scale = Vector2.ONE
	if _body != null:
		_body.scale = Vector2.ONE
	if _board_paper_mode:
		match _character_phase:
			CharacterPhase.PREPARE:
				_set_paper_body_scale_y(0.0)
			CharacterPhase.COMBAT:
				_set_paper_body_scale_y(1.0)


func _kill_card_tween() -> void:
	if _card_tween != null and _card_tween.is_running():
		_card_tween.kill()
	_card_tween = null
	_reset_animation_scale()


func _kill_popup_tween() -> void:
	if _popup_tween != null and _popup_tween.is_running():
		_popup_tween.kill()
	_popup_tween = null


func _kill_body_reveal_tween() -> void:
	if _body_reveal_tween != null and _body_reveal_tween.is_running():
		_body_reveal_tween.kill()
	_body_reveal_tween = null
	_body_reveal_running = false
	_body_hide_running = false


func _start_head_idle() -> void:
	if not _head_idle_requested:
		return
	if not _board_paper_mode or not is_node_ready():
		return
	if _portrait == null or not _portrait.visible:
		return
	if _body_reveal_running or _body_hide_running:
		return
	_kill_idle_tween()
	_portrait.position = Vector2.ZERO
	var start_angle := randf() * TAU
	if _unit != null:
		start_angle += float(_unit.instance_id % 17) * 0.37
	var phase_delay := 0.0
	if _unit != null:
		phase_delay = float(_unit.instance_id % 17) * CombatAnimationConfig.IDLE_HEAD_BOB_PHASE_STEP
	if phase_delay > 0.0:
		_idle_tween = create_tween()
		_idle_tween.tween_interval(phase_delay)
		_idle_tween.tween_callback(func() -> void:
			_begin_head_idle_orbit(start_angle)
		)
	else:
		_begin_head_idle_orbit(start_angle)


func _begin_head_idle_orbit(start_angle: float) -> void:
	if not _head_idle_requested or _portrait == null:
		return
	var radius_y := CombatAnimationConfig.IDLE_HEAD_BOB_PX * _paper_scale
	var radius_x := CombatAnimationConfig.IDLE_HEAD_BOB_X_PX * _paper_scale
	var cycle := CombatAnimationConfig.IDLE_HEAD_BOB_CYCLE
	_apply_head_idle_orbit_position(start_angle, radius_x, radius_y)
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_method(
		func(progress: float) -> void:
			var angle := _orbit_progress_to_angle(progress) + start_angle
			_apply_head_idle_orbit_position(angle, radius_x, radius_y),
		0.0,
		1.0,
		cycle,
	).set_trans(Tween.TRANS_LINEAR)


func _orbit_progress_to_angle(progress: float) -> float:
	var fall_frac := clampf(
		CombatAnimationConfig.IDLE_HEAD_BOB_FALL_TIME_FRAC,
		0.15,
		0.85,
	)
	if progress <= fall_frac:
		var t := progress / fall_frac
		var eased := pow(t, CombatAnimationConfig.IDLE_HEAD_BOB_FALL_ACCEL)
		return eased * PI
	var t := (progress - fall_frac) / (1.0 - fall_frac)
	var eased := 1.0 - pow(1.0 - t, CombatAnimationConfig.IDLE_HEAD_BOB_RISE_DECEL)
	return PI + eased * PI


func _apply_head_idle_orbit_position(angle: float, radius_x: float, radius_y: float) -> void:
	if _portrait == null:
		return
	_portrait.position = Vector2(
		cos(angle) * radius_x,
		sin(angle) * radius_y,
	)


func _stop_head_idle() -> void:
	_head_idle_requested = false
	_kill_idle_tween()
	if _portrait != null:
		_portrait.position = Vector2.ZERO


func _kill_idle_tween() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null
