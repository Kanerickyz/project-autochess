class_name CombatEntryStrip
extends RefCounted
## 战场扫读用词条带：主技能简标 + 战斗状态角标（COMBAT_FEEDBACK §5.3.1）。

const CHIP_SKILL := &"skill"
const CHIP_BUFF_PREFIX := &"buff:"


static func skill_short_label(unit: UnitInstance) -> String:
	if unit == null:
		return ""
	var ability: AbilityData = null
	if unit.unit_data != null:
		ability = unit.unit_data.ability
	if ability == null:
		return ""
	var name := ability.display_name.strip_edges()
	if name.is_empty():
		name = ability.id
	if name.is_empty():
		return ""
	return name.substr(0, mini(2, name.length()))


static func collect_status_chips(unit: UnitInstance) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if unit == null:
		return out
	for status_id in CombatStatusStack.DISPLAY_ORDER:
		var stacks := unit.combat_statuses.get_stacks(status_id)
		if stacks <= 0:
			continue
		out.append(
			{
				"chip_key": status_id,
				"label": CombatStatusStack.get_display_name(status_id),
				"stacks": stacks,
			}
		)
	return out


static func chip_key_for_buff(buff: BuffCardData) -> StringName:
	if buff == null or buff.id.is_empty():
		return StringName("%sunknown" % CHIP_BUFF_PREFIX)
	return StringName("%s%s" % [CHIP_BUFF_PREFIX, buff.id])


static func chip_key_for_action(action: EffectAction) -> StringName:
	if action == null:
		return CHIP_SKILL
	match action.action_type:
		EffectAction.Type.APPLY_COMBAT_STATUS, EffectAction.Type.REMOVE_COMBAT_STATUS:
			return action.stat_name
		_:
			return CHIP_SKILL


static func chip_color(chip_key: StringName) -> Color:
	match chip_key:
		CombatStatusStack.ID_WEAK:
			return Color(0.62, 0.48, 0.92, 1.0)
		CombatStatusStack.ID_BERSERK:
			return Color(0.92, 0.35, 0.28, 1.0)
		CombatStatusStack.ID_POISON:
			return Color(0.38, 0.78, 0.42, 1.0)
		_:
			if String(chip_key).begins_with(String(CHIP_BUFF_PREFIX)):
				return Color(0.95, 0.78, 0.32, 1.0)
			return Color(0.35, 0.42, 0.55, 1.0)


static func draw_strip(
	canvas: CanvasItem,
	center: Vector2,
	unit: UnitInstance,
	px: float,
	alpha: float,
	chip_shake_offsets: Dictionary,
) -> void:
	if unit == null or canvas == null:
		return
	var chips: Array[Dictionary] = []
	var skill := skill_short_label(unit)
	if not skill.is_empty():
		chips.append({"chip_key": CHIP_SKILL, "label": skill, "stacks": 0})
	for row in collect_status_chips(unit):
		chips.append(row)
	if chips.is_empty():
		return
	var font: Font = canvas.get_theme_default_font()
	var chip_h := clampf(px * 0.22, 10.0, 18.0)
	var pad_x := chip_h * 0.28
	var gap := chip_h * 0.12
	var widths: PackedFloat32Array = PackedFloat32Array()
	for chip in chips:
		var label := String(chip.get("label", ""))
		var stacks := int(chip.get("stacks", 0))
		var text := label if stacks <= 0 else "%s%d" % [label, stacks]
		var fs := clampi(int(chip_h * 0.72), 7, 14)
		var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append(tw + pad_x * 2.0)
	var total_w := 0.0
	for w in widths:
		total_w += w
	total_w += gap * float(maxi(0, chips.size() - 1))
	var x := center.x - total_w * 0.5
	var y := center.y + px * 0.08
	for i in chips.size():
		var chip: Dictionary = chips[i]
		var chip_key: StringName = chip.get("chip_key", CHIP_SKILL)
		var shake := chip_shake_offsets.get(chip_key, Vector2.ZERO) as Vector2
		var w := widths[i]
		var rect := Rect2(Vector2(x, y) + shake, Vector2(w, chip_h))
		var fill := chip_color(chip_key)
		fill.a *= alpha
		canvas.draw_rect(rect, fill, true)
		canvas.draw_rect(rect, Color(0, 0, 0, 0.35 * alpha), false, 1.0)
		var label := String(chip.get("label", ""))
		var stacks := int(chip.get("stacks", 0))
		var text := label if stacks <= 0 else "%s%d" % [label, stacks]
		var fs := clampi(int(chip_h * 0.72), 7, 14)
		var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var baseline := Vector2(
			rect.position.x + (rect.size.x - tw) * 0.5,
			rect.position.y + chip_h * 0.5 + font.get_ascent(fs) * 0.5 - font.get_descent(fs) * 0.25,
		)
		canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, alpha))
		x += w + gap
