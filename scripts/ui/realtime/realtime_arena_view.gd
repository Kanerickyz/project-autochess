class_name RealtimeArenaView
extends Control
## 实时战场绘制：林间空地背景、半场色调、中线、投放高亮/虚影、角色贴图、
## 底部攻/血色块标（参考小动物自走棋）、血条、部署弧、投射物与溅射圈。
## 只读 RealtimeCombatSim 状态，不参与逻辑。剪影可大于碰撞圆（脚小身大）。

signal board_pressed(tile_pos: Vector2)
signal card_dropped(entry_id: int, tile_pos: Vector2)
## 招募：候选人拖放到上半场；replace_entry_id≥0 为替换；seat_index≥0 为指定空座。
signal recruit_drop(candidate_index: int, replace_entry_id: int, seat_index: int)
signal recruit_candidate_pressed(candidate_index: int)
signal recruit_team_pressed(entry_id: int)
## 招募：上区队伍成员拖到出售落点松手。
signal recruit_sell(entry_id: int)
## 招募：下区候选人拖到锁定落点松手（切换锁定）。
signal recruit_candidate_lock(candidate_index: int)
## 招募：上区成员拖到空座或另一成员座位换座。
signal recruit_team_seat_drop(entry_id: int, target_seat: int)
## 招募道具行：点击道具槽。
signal recruit_item_pressed(item_slot: int)
## 招募道具行：药水拖到上区队伍成员。
signal recruit_item_drop(item_slot: int, entry_id: int)

const DRAG_KEY := "rt_entry_id"
const RECRUIT_CANDIDATE_KEY := "rt_recruit_candidate"
const RECRUIT_ITEM_KEY := "rt_recruit_item_slot"
const NO_CELL := Vector2i(-1, -1)
const ARENA_BACKGROUND := preload("res://assets/sprites/paper_cutout/env/arena_background.jpg")
## 背景图左右树林各占原图宽度的比例；棋盘只压进树林内缘这部分，避免座位被树盖住。
const BACKGROUND_TREE_BAND := 0.15
const BOARD_TREE_OVERLAP := 0.4
const PLAYER_TINT := Color(0.25, 0.45, 0.95, 0.06)
const ENEMY_TINT := Color(0.95, 0.25, 0.22, 0.06)
const MIDLINE := Color(1.0, 0.98, 0.9, 0.55)
const DEPLOY_HIGHLIGHT := Color(0.45, 0.75, 1.0, 0.18)
const PLAYER_COLOR := Color(0.22, 0.47, 0.92)
const ENEMY_COLOR := Color(0.88, 0.24, 0.22)
const CONTACT_SHADOW := Color(0.22, 0.20, 0.10, 0.28)
## 贴图高度相对剪影半高；贴图含米白纸边，比色块剪影略大。
const SPRITE_HEIGHT_MUL := 2.5
## 单格角色贴图最大宽度（格）；超宽武器/骑乘按比例缩小以保持格内可读。
const SPRITE_MAX_WIDTH_CELLS := 1.35
## 多格足迹（如 Boss 2×2）允许更宽。
const SPRITE_MAX_WIDTH_CELLS_FOOTPRINT := 2.2
const ATTACK_FLASH_SECONDS := 0.12
const HIT_FLASH_SECONDS := 0.10
const FX_SECONDS := 0.35
const ELLIPSE_SEGMENTS := 28
## 技能因果飘字（COMBAT_FEEDBACK）：基础寿命；加速时缩短但不短于下限。
const FEEDBACK_SECONDS := 0.85
const FEEDBACK_MIN_SECONDS := 0.35
const FEEDBACK_MERGE_WINDOW := 0.28
const FEEDBACK_MAX_PER_UNIT := 3
const FEEDBACK_FLOAT_TILES := 0.55
const CALLOUT_SECONDS := 0.45
## 单位下方攻/血标（左攻右血；深色/红色色块 + 白描边白字）。
const STAT_ATTACK_TEX := preload("res://assets/sprites/paper_cutout/ui/stat_attack.png")
const STAT_HP_TEX := preload("res://assets/sprites/paper_cutout/ui/stat_hp.png")
const STAT_FONT := preload("res://resources/ui/stat_badge_font.tres")
const STAT_TEXT := Color(0.10, 0.08, 0.07, 1.0)
## 标签高度只随格子尺寸变化，所有单位同一尺寸。
const STAT_BADGE_HEIGHT_MUL := 0.5
const STAT_BADGE_MIN_HEIGHT := 14.0
const STAT_BADGE_MAX_HEIGHT := 28.0
## 贴图左侧是图标，数字居中于右侧空白区（按贴图宽度比例）。
const STAT_NUMBER_CENTER_X := 0.66
const STAT_NUMBER_MAX_WIDTH := 0.42
## 受击闪白：modulate 拉高到接近纯白，墨线仍保留轮廓。
const SPRITE_FLASH_MUL := 5.0
## 镜头震动时背景外扩，避免露边。
const SHAKE_BLEED_PX := 8.0
## 长按查看单位信息（SAP 式）：按住超过阈值弹卡，松手收起且不触发点按。
const LONG_PRESS_MS := 380
const LONG_PRESS_SLOP_PX := 10.0

var board_size: Vector2i = Vector2i(5, 8)
## 相对旧 9×16 基准放大剪影，使紧凑棋盘上角色仍饱满可读。
const REFERENCE_BOARD_WIDTH := 9.0
const REFERENCE_BOARD_HEIGHT := 16.0
var sim: RealtimeCombatSim
## Array[Dictionary]：{position, radius, visual_half_width?, visual_half_height?, label, attack?, hp?}
var enemy_previews: Array = []
## 已选中手牌时为 true：高亮我方半场并显示悬停虚影
var placement_active: bool = false
var ghost_radius: float = 0.7
var ghost_visual_half_width: float = 0.0
var ghost_visual_half_height: float = 0.0
var ghost_label: String = ""
var ghost_unit_id: String = ""
## 准备阶段友方角色座位；战斗中仍可画占位框
var prepare_slots: PrepareSlotBoard
## 敌方角色座位几何；空座淡示意，已占由 enemy_previews 画单位
var enemy_slots: PrepareSlotBoard
## 战斗加速倍率：缩短反馈 / 时停表现寿命；是否暂停模拟由控制器时停队列决定。
var presentation_time_scale: float = 1.0
## 胜后半场退出/招募进入：上半场 / 下半场像素位移（由控制器 Tween）。
## 草地与外框不随位移；仅半场色调与单位/座位内容滑动。
var enemy_half_slide_y: float = 0.0
var ally_half_slide_y: float = 0.0
## 招募模式：上半场画队伍、下半场画候选人（不走战斗 sim）。
var recruit_active: bool = false
## 角色库模式：整盘铺单位剪影，长按弹技能卡（不走战斗 / 招募）。
var catalog_active: bool = false
## 上半场队伍座位（几何同敌方 4×5）；occupants 为 DeckEntry。
var recruit_team_slots: PrepareSlotBoard
## Array[Dictionary]：{index, unit, cell, cost?, affordable?}
var recruit_candidates: Array = []
## Array[Dictionary]：{index, item, cell, cost?, affordable?, label?}
var recruit_items: Array = []
## Array[Dictionary]：{unit: UnitData, cell: Vector2i}
var catalog_units: Array = []
## 角色库预览星级：1=一星，2=一次三合一。
var catalog_preview_level: int = 1
var recruit_selected_candidate: int = -1
var recruit_selected_replace_id: int = -1
var recruit_needs_replace: bool = false
## 待用药水槽；≥0 时点上区队伍成员结算。
var recruit_pending_item_slot: int = -1
## 下区出售落点格；与候选人/道具槽分离，避免混手势。
var recruit_sell_cell: Vector2i = NO_CELL
## 下区锁定落点格：候选人拖入切换锁定（与出售对称）。
var recruit_lock_cell: Vector2i = NO_CELL
## 拖到出售落点时预览退金（由控制器写入）。
var recruit_sell_preview_gold: int = 0


var _hover_cell: Vector2i = NO_CELL
var _drag_active: bool = false
var _drag_radius: float = 0.7
var _drag_visual_half_width: float = 0.0
var _drag_visual_half_height: float = 0.0
var _drag_label: String = ""
var _drag_unit_id: String = ""
var _art: UnitArtCatalog = UnitArtCatalog.load_default()
var _fx: Array = []
var _fx_clock: float = 0.0
## Array[Dictionary]：技能结果数字 / 短提示
var _feedback: Array = []
var _recruit_drag_index: int = -1
var _recruit_press_index: int = -1
var _recruit_item_drag_index: int = -1
var _recruit_item_press_index: int = -1
var _recruit_team_drag_id: int = -1
var _recruit_team_press_id: int = -1
var _motion := RealtimeUnitMotion.new()
var _frame_shake := Vector2.ZERO
var _info_card := RealtimeUnitInfoCard.new()
var _press_active := false
var _press_pos := Vector2.ZERO
var _press_ms: int = -1
var _press_info: Dictionary = {}
var _press_tap: Callable
var _info_shown := false
## 当前信息卡对应的单位（用于角色库把该剪影画到最上层）。
var _shown_info: Dictionary = {}
## 长按焦点单位：小丑牌式抬起 / 滑动弹跳（纯绘制）。
var _inspect_focus_key := ""
var _inspect_focus_at: float = -1.0
var _inspect_kick_dir: float = 0.0
var _inspect_finger := Vector2.ZERO
## 技能触发自动弹出的信息卡：到期自动收起（长按中不抢收）。
var _auto_info_until_clock: float = -1.0
const SKILL_INFO_SECONDS := 1.35

## 座位铺满半场时不描格线；仅极淡底色，避免棋盘像表格。
const SLOT_EMPTY := Color(0.95, 0.88, 0.45, 0.08)
const SLOT_OCCUPIED := Color(0.35, 0.65, 1.0, 0.18)
const SLOT_BORDER := Color(1.0, 0.95, 0.55, 0.0)
const ENEMY_SLOT_EMPTY := Color(0.95, 0.40, 0.36, 0.06)
const ENEMY_SLOT_OCCUPIED := Color(0.90, 0.30, 0.28, 0.14)
const ENEMY_SLOT_BORDER := Color(0.95, 0.60, 0.55, 0.0)
const RECRUIT_TEAM_EMPTY := Color(0.45, 0.70, 0.95, 0.22)
const RECRUIT_TEAM_FILL := Color(0.30, 0.55, 0.95, 0.42)
const RECRUIT_TEAM_BORDER := Color(0.75, 0.90, 1.0, 0.95)
const RECRUIT_CAND_EMPTY := Color(0.95, 0.78, 0.35, 0.28)
const RECRUIT_CAND_FILL := Color(0.95, 0.70, 0.25, 0.48)
const RECRUIT_CAND_BORDER := Color(1.0, 0.92, 0.45, 0.95)
const RECRUIT_ITEM_EMPTY := Color(0.55, 0.85, 0.70, 0.28)
const RECRUIT_ITEM_FILL := Color(0.35, 0.78, 0.60, 0.48)
const RECRUIT_ITEM_BORDER := Color(0.70, 0.95, 0.85, 0.95)
const RECRUIT_SELECT := Color(1.0, 0.95, 0.35, 0.55)
const RECRUIT_SELL_EMPTY := Color(0.55, 0.35, 0.55, 0.28)
const RECRUIT_SELL_HOT := Color(0.85, 0.35, 0.75, 0.45)
const RECRUIT_SELL_BORDER := Color(0.95, 0.70, 0.95, 0.95)
const RECRUIT_LOCK_EMPTY := Color(0.55, 0.50, 0.25, 0.28)
const RECRUIT_LOCK_HOT := Color(0.95, 0.80, 0.30, 0.45)
const RECRUIT_LOCK_BORDER := Color(1.0, 0.88, 0.40, 0.95)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)
	_motion.name = "UnitMotion"
	add_child(_motion)
	_info_card.name = "UnitInfoCard"
	add_child(_info_card)


func _process(delta: float) -> void:
	_fx_clock += delta
	if sim != null and sim.has_started():
		_motion.speed_scale = presentation_time_scale
		_motion.sync_units(sim.get_units(), sim.get_current_actor())
	if _press_ms >= 0 and not _info_shown and Time.get_ticks_msec() - _press_ms >= LONG_PRESS_MS:
		_show_info_card(_press_info)
	if _auto_info_until_clock >= 0.0 and _fx_clock >= _auto_info_until_clock:
		if not _press_active:
			_info_card.hide_info()
			_info_shown = false
			_shown_info = {}
			_clear_inspect_focus()
		_auto_info_until_clock = -1.0
	if not _fx.is_empty():
		var alive: Array = []
		for fx in _fx:
			var life := CALLOUT_SECONDS if fx.get("kind", "") == "callout" else FX_SECONDS
			if _fx_clock - float(fx["t0"]) < life:
				alive.append(fx)
		_fx = alive
	if not _feedback.is_empty():
		var keep: Array = []
		for fb in _feedback:
			if _fx_clock - float(fb["t0"]) < float(fb["duration"]):
				keep.append(fb)
		_feedback = keep
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_cancel_press()
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_cancel_press()
	if what == NOTIFICATION_DRAG_END:
		_drag_active = false
		_recruit_drag_index = -1
		_recruit_press_index = -1
		_recruit_item_drag_index = -1
		_recruit_item_press_index = -1
		_recruit_team_drag_id = -1
		_recruit_team_press_id = -1
		_hover_cell = NO_CELL
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover_cell = NO_CELL


# --- 公开接口 ---


func get_cell_px() -> float:
	if board_size.x <= 0 or board_size.y <= 0:
		return 1.0
	var bg := _get_background_rect()
	var gutter := maxf(0.0, bg.position.x + bg.size.x * BACKGROUND_TREE_BAND * (1.0 - BOARD_TREE_OVERLAP))
	var avail_x := maxf(1.0, size.x - gutter * 2.0)
	return maxf(1.0, minf(avail_x / board_size.x, size.y / board_size.y))


## 列/行变少时放大角色表现（碰撞仍以逻辑格为准）；再收 20% 避免邻格剪影互盖。
func get_unit_visual_scale() -> float:
	var sx := REFERENCE_BOARD_WIDTH / float(maxi(1, board_size.x))
	var sy := REFERENCE_BOARD_HEIGHT / float(maxi(1, board_size.y))
	return clampf(minf(sx, sy), 1.0, 1.75) * 0.8


## 背景按「铺满」缩放并居中裁切，保持原图比例。
func _get_background_rect() -> Rect2:
	var tex_size := ARENA_BACKGROUND.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return Rect2(Vector2.ZERO, size)
	var scale := maxf(size.x / tex_size.x, size.y / tex_size.y)
	var drawn := tex_size * scale
	return Rect2((size - drawn) * 0.5, drawn)


func get_board_rect() -> Rect2:
	var px := get_cell_px()
	var board_px := Vector2(board_size) * px
	return Rect2((size - board_px) * 0.5, board_px)


func local_to_tile(local_pos: Vector2) -> Vector2:
	var rect := get_board_rect()
	return (local_pos - rect.position) / get_cell_px()


func tile_to_local(tile_pos: Vector2) -> Vector2:
	return get_board_rect().position + tile_pos * get_cell_px()


func tile_to_cell(tile_pos: Vector2) -> Vector2i:
	var cell := Vector2i(floori(tile_pos.x), floori(tile_pos.y))
	if cell.x < 0 or cell.y < 0 or cell.x >= board_size.x or cell.y >= board_size.y:
		return NO_CELL
	return cell


func add_splash_fx(center: Vector2, radius: float) -> void:
	_fx.append({"kind": "splash", "center": center, "radius": radius, "t0": _fx_clock})


func add_death_fx(center: Vector2, radius: float, is_player: bool) -> void:
	_fx.append({"kind": "death", "center": center, "radius": radius, "t0": _fx_clock, "player": is_player})


## 技能播报占位：高亮圈 + 可选短标（锁阵与时停队列共用）。
func add_skill_callout(center: Vector2, text: String = "", is_player: bool = true) -> void:
	_fx.append({
		"kind": "callout",
		"center": center,
		"radius": 0.85,
		"t0": _fx_clock,
		"player": is_player,
		"text": text,
	})


## 技能因果反馈：kind=damage/heal/stat/label；同单位短窗可合并。
func add_feedback_popup(
	kind: StringName,
	text: String,
	center: Vector2,
	is_player: bool,
	unit_id: int = -1,
	amount: int = 0,
	merge_key: String = "",
	tip: String = "",
) -> void:
	if text.is_empty() and tip.is_empty():
		return
	var key := merge_key
	if key.is_empty():
		key = "%d|%s" % [unit_id, String(kind)]
	var duration := _feedback_duration_for_scale(presentation_time_scale)
	## 短合并窗：同 merge_key 且仍存活 → 合计数字或刷新短标。
	if unit_id >= 0:
		for fb in _feedback:
			if String(fb.get("merge_key", "")) != key:
				continue
			if _fx_clock - float(fb["t0"]) > FEEDBACK_MERGE_WINDOW:
				continue
			if kind == RealtimeEffectFeedback.KIND_DAMAGE or kind == RealtimeEffectFeedback.KIND_HEAL \
					or kind == RealtimeEffectFeedback.KIND_STAT:
				var merged_amount := int(fb["amount"]) + amount
				fb["amount"] = merged_amount
				fb["text"] = _format_merged_feedback_text(kind, merged_amount, text)
			else:
				fb["text"] = text if not text.is_empty() else String(fb["text"])
			if not tip.is_empty():
				fb["tip"] = tip
			fb["t0"] = _fx_clock
			fb["duration"] = duration
			fb["center"] = center
			return
	_feedback.append({
		"kind": kind,
		"text": text,
		"tip": tip,
		"center": center,
		"player": is_player,
		"unit_id": unit_id,
		"amount": amount,
		"merge_key": key,
		"t0": _fx_clock,
		"duration": duration,
	})
	_trim_feedback_for_unit(unit_id)


func get_feedback_count() -> int:
	return _feedback.size()


func get_feedback_entries() -> Array:
	return _feedback.duplicate()


func clear_fx() -> void:
	_fx.clear()
	_feedback.clear()
	_motion.clear()
	_cancel_press()


## 死亡残影：闪白后侧倒、缩小淡出（纯表现，单位已从模拟移除）。
func play_unit_death(rt: RtUnit) -> void:
	if rt == null:
		return
	var half := _resolve_visual_half(rt.get_visual_half_height(), rt.get_radius(), 1.6)
	_motion.play_death(rt, _rt_unit_id(rt), half)


func _feedback_duration_for_scale(scale: float) -> float:
	var s := maxf(0.25, scale)
	return clampf(FEEDBACK_SECONDS / s, FEEDBACK_MIN_SECONDS, FEEDBACK_SECONDS)


func _format_merged_feedback_text(kind: StringName, amount: int, fallback: String) -> String:
	match kind:
		RealtimeEffectFeedback.KIND_DAMAGE:
			return "-%d" % amount
		RealtimeEffectFeedback.KIND_HEAL:
			return "+%d" % amount if amount > 0 else "%d" % amount
		RealtimeEffectFeedback.KIND_STAT:
			## 保留原后缀（攻/生命/暴）；跳过符号与数字。
			var suffix := ""
			for i in fallback.length():
				var ch := fallback.substr(i, 1)
				if ch == "+" or ch == "-":
					continue
				if ch >= "0" and ch <= "9":
					continue
				suffix = fallback.substr(i)
				break
			var sign := "+" if amount > 0 else ""
			return "%s%d%s" % [sign, amount, suffix]
		_:
			return fallback


func _trim_feedback_for_unit(unit_id: int) -> void:
	if unit_id < 0:
		return
	var indices: Array[int] = []
	for i in _feedback.size():
		if int(_feedback[i].get("unit_id", -1)) == unit_id:
			indices.append(i)
	while indices.size() > FEEDBACK_MAX_PER_UNIT:
		var drop_i: int = indices[0]
		_feedback.remove_at(drop_i)
		indices.remove_at(0)
		for j in indices.size():
			if indices[j] > drop_i:
				indices[j] -= 1


# --- 输入 ---


func _gui_input(event: InputEvent) -> void:
	if recruit_active:
		_gui_input_recruit(event)
		return
	## catalog_active 走与战斗相同的长按信息卡路径。
	if event is InputEventMouseMotion:
		var motion_pos := (event as InputEventMouseMotion).position
		_hover_cell = tile_to_cell(local_to_tile(motion_pos))
		_track_press_motion(motion_pos)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			var info := inspect_at(mb.position)
			if not info.is_empty():
				## 按在单位上：点按动作推迟到松手，按住则改为看信息。
				_begin_press(mb.position, info, board_pressed.emit.bind(local_to_tile(mb.position)))
			else:
				board_pressed.emit(local_to_tile(mb.position))
			accept_event()
		elif _end_press():
			accept_event()


func _gui_input_recruit(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_hover_cell = tile_to_cell(local_to_tile(motion.position))
		_track_press_motion(motion.position)
		if _recruit_press_index >= 0 and _recruit_drag_index < 0 and not _info_shown:
			## 离开按下点超过容差即进入拖拽（触屏抖动不误触发）。
			if motion.position.distance_to(_press_pos) > LONG_PRESS_SLOP_PX:
				_cancel_press()
				_begin_recruit_drag(_recruit_press_index)
		elif _recruit_item_press_index >= 0 and _recruit_item_drag_index < 0 and not _info_shown:
			if motion.position.distance_to(_press_pos) > LONG_PRESS_SLOP_PX:
				_cancel_press()
				_begin_recruit_item_drag(_recruit_item_press_index)
		elif _recruit_team_press_id >= 0 and _recruit_team_drag_id < 0 and not _info_shown:
			if motion.position.distance_to(_press_pos) > LONG_PRESS_SLOP_PX:
				_cancel_press()
				_begin_recruit_team_drag(_recruit_team_press_id)
		accept_event()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var tile := local_to_tile(mb.position)
		var cell := tile_to_cell(tile)
		if mb.pressed:
			var cand := _find_recruit_candidate_at(cell)
			if cand >= 0:
				_recruit_press_index = cand
				_recruit_item_press_index = -1
				_recruit_team_press_id = -1
				_begin_press(mb.position, inspect_at(mb.position), Callable())
				accept_event()
				return
			var item_i := _find_recruit_item_at(cell)
			if item_i >= 0:
				_recruit_item_press_index = item_i
				_recruit_press_index = -1
				_recruit_team_press_id = -1
				_begin_press(mb.position, {}, Callable())
				accept_event()
				return
			var entry_id := _find_recruit_team_entry_at(cell)
			if entry_id >= 0:
				_recruit_team_press_id = entry_id
				_recruit_press_index = -1
				_recruit_item_press_index = -1
				_begin_press(mb.position, inspect_at(mb.position), recruit_team_pressed.emit.bind(entry_id))
				accept_event()
			return
		## 松开
		if _info_shown:
			_recruit_press_index = -1
			_recruit_item_press_index = -1
			_recruit_team_press_id = -1
			_end_press()
			accept_event()
			return
		if _end_press():
			accept_event()
		if _recruit_team_drag_id >= 0:
			_finish_recruit_team_drag(cell)
			accept_event()
			return
		if _recruit_drag_index >= 0:
			_finish_recruit_drag(cell)
			accept_event()
			return
		if _recruit_item_drag_index >= 0:
			_finish_recruit_item_drag(cell)
			accept_event()
			return
		if _recruit_press_index >= 0:
			var pressed := _recruit_press_index
			_recruit_press_index = -1
			recruit_candidate_pressed.emit(pressed)
			accept_event()
		elif _recruit_item_press_index >= 0:
			var item_pressed := _recruit_item_press_index
			_recruit_item_press_index = -1
			recruit_item_pressed.emit(item_pressed)
			accept_event()
		_recruit_team_press_id = -1


func _begin_press(pos: Vector2, info: Dictionary, tap: Callable) -> void:
	_cancel_press()
	_press_active = true
	_press_pos = pos
	_press_info = info
	_press_tap = tap
	_press_ms = Time.get_ticks_msec() if not info.is_empty() else -1
	_info_shown = false


func _track_press_motion(pos: Vector2) -> void:
	if not _press_active:
		return
	## 信息卡已弹出：保持按住时滑到其他单位即切换介绍，并跟手微倾。
	if _info_shown:
		_inspect_finger = pos
		_update_info_card_under_finger(pos)
		_info_card.follow_finger(pos)
		return
	if _press_ms >= 0 and pos.distance_to(_press_pos) > LONG_PRESS_SLOP_PX:
		_press_ms = -1


func _update_info_card_under_finger(pos: Vector2) -> void:
	var info := inspect_at(pos)
	if info.is_empty():
		return
	var prev_key := String(_press_info.get("inspect_key", ""))
	var next_key := String(info.get("inspect_key", ""))
	if next_key.is_empty():
		next_key = "%s|%s" % [String(info.get("name", "")), str(info.get("center", Vector2.ZERO))]
	if prev_key.is_empty():
		prev_key = "%s|%s" % [String(_press_info.get("name", "")), str(_press_info.get("center", Vector2.ZERO))]
	if next_key == prev_key:
		return
	var prev_center: Vector2 = _press_info.get("center", pos) as Vector2
	var next_center: Vector2 = info.get("center", pos) as Vector2
	var slide_dir := signf(next_center.x - prev_center.x)
	if is_zero_approx(slide_dir):
		slide_dir = signf(pos.x - _press_pos.x)
	_press_info = info
	_show_info_card(info, slide_dir)


## 松手：信息卡已弹出则只收起；否则执行推迟的点按。返回是否有待处理的按下。
func _end_press() -> bool:
	if not _press_active:
		return false
	var shown := _info_shown
	var tap := _press_tap
	_cancel_press()
	if not shown and tap.is_valid():
		tap.call()
	return true


func _cancel_press() -> void:
	_press_active = false
	_press_ms = -1
	_press_info = {}
	_press_tap = Callable()
	_info_shown = false
	_shown_info = {}
	_clear_inspect_focus()
	_info_card.hide_info()


func is_info_card_visible() -> bool:
	return _info_card.visible


## 测试与无障碍入口：直接弹出指定位置单位的信息卡。
func show_unit_info_at(local_pos: Vector2) -> bool:
	var info := inspect_at(local_pos)
	if info.is_empty():
		return false
	_show_info_card(info)
	return true


func hide_unit_info() -> void:
	_cancel_press()


## 准备手牌等外部锚点：用与场上同一套信息卡展示 DeckEntry。
func show_deck_entry_info(entry: DeckEntry, local_anchor: Vector2) -> bool:
	if entry == null:
		return false
	_show_info_card(_info_from_entry(entry, local_anchor))
	return true


func _show_info_card(info: Dictionary, slide_dir: float = 0.0) -> void:
	if info.is_empty():
		return
	_info_shown = true
	_shown_info = info
	_begin_inspect_focus(info, slide_dir)
	var center: Vector2 = info["center"]
	var px := get_cell_px()
	var head := center + Vector2(0.0, px * (0.38 - 1.7))
	var foot := center + Vector2(0.0, px * 0.38) + Vector2(0.0, get_stat_badge_size(px).y * 1.1)
	_info_card.show_info(info, head, foot, Rect2(Vector2.ZERO, size), slide_dir)
	queue_redraw()


func _begin_inspect_focus(info: Dictionary, slide_dir: float) -> void:
	var key := String(info.get("inspect_key", ""))
	if key.is_empty():
		key = "%s|%s" % [String(info.get("name", "")), str(info.get("center", Vector2.ZERO))]
	var switched := key != _inspect_focus_key
	_inspect_focus_key = key
	if switched or _inspect_focus_at < 0.0:
		_inspect_focus_at = _fx_clock
		_inspect_kick_dir = slide_dir
	_inspect_finger = info.get("center", _inspect_finger) as Vector2


func _clear_inspect_focus() -> void:
	_inspect_focus_key = ""
	_inspect_focus_at = -1.0
	_inspect_kick_dir = 0.0
	_inspect_finger = Vector2.ZERO


## 长按焦点视觉：焦点单位抬起倾斜，其余略压暗缩小。
func _sample_inspect_visual(sprite_center: Vector2) -> Dictionary:
	if not _info_shown or _shown_info.is_empty():
		return {}
	var focus_c: Vector2 = _shown_info.get("center", Vector2.INF) as Vector2
	var hit_r := get_cell_px() * 0.55
	var focused := sprite_center.distance_squared_to(focus_c) <= hit_r * hit_r
	var elapsed := 0.0 if _inspect_focus_at < 0.0 else maxf(0.0, _fx_clock - _inspect_focus_at)
	var finger_tiles := Vector2.ZERO
	if focused and get_cell_px() > 0.0:
		finger_tiles = (_inspect_finger - focus_c) / get_cell_px()
	return RealtimeUnitMotion.sample_inspect_focus(
		elapsed,
		_inspect_kick_dir if focused else 0.0,
		finger_tiles,
		focused,
	)


func _inspect_focus_hit_r2() -> float:
	var r := get_cell_px() * 0.55
	return r * r


## 长按时把焦点座位画到最后，抬起不被邻格挡住。
func _bring_inspect_slot_to_front(
	indices: Array[int],
	slots: PrepareSlotBoard,
	half_off: Vector2,
) -> void:
	if not _info_shown or slots == null or indices.is_empty():
		return
	var focus_c: Vector2 = _shown_info.get("center", Vector2.INF) as Vector2
	var hit_r2 := _inspect_focus_hit_r2()
	var focus_at := -1
	for idx in indices.size():
		var slot_i: int = indices[idx]
		if slot_i < 0 or slot_i >= slots.cells.size():
			continue
		var cell: Vector2i = slots.cells[slot_i]
		var center := tile_to_local(Vector2(cell) + Vector2(0.5, 0.5)) + half_off
		if center.distance_squared_to(focus_c) <= hit_r2:
			focus_at = idx
			break
	if focus_at < 0:
		return
	var moved: int = indices[focus_at]
	indices.remove_at(focus_at)
	indices.append(moved)


func _bring_inspect_rt_to_front(ordered: Array) -> void:
	if not _info_shown or ordered.is_empty():
		return
	var focus_c: Vector2 = _shown_info.get("center", Vector2.INF) as Vector2
	var hit_r2 := _inspect_focus_hit_r2()
	var focus_at := -1
	for idx in ordered.size():
		var rt := ordered[idx] as RtUnit
		if rt == null:
			continue
		var off := Vector2(0.0, ally_half_slide_y if rt.is_player() else enemy_half_slide_y)
		var center := tile_to_local(rt.position) + off
		if center.distance_squared_to(focus_c) <= hit_r2:
			focus_at = idx
			break
	if focus_at < 0:
		return
	var moved: Variant = ordered[focus_at]
	ordered.remove_at(focus_at)
	ordered.append(moved)


## 技能触发时先弹出与长按相同的单位信息卡（含技能介绍）。
func show_skill_trigger_info(unit: UnitInstance, is_player: bool, attack: int, hp: int, tile_pos: Vector2) -> void:
	if unit == null:
		return
	var off := Vector2(0.0, ally_half_slide_y if is_player else enemy_half_slide_y)
	var center := tile_to_local(tile_pos) + off
	_show_info_card(_info_from_instance(unit, is_player, attack, hp, center))
	var life := SKILL_INFO_SECONDS / maxf(0.25, presentation_time_scale)
	_auto_info_until_clock = _fx_clock + life


## 命中测试：返回该位置单位的信息字典（含 center 本地坐标）；未命中返回空字典。
func inspect_at(local_pos: Vector2) -> Dictionary:
	var px := get_cell_px()
	var best: Dictionary = {}
	var best_d := INF
	for info: Dictionary in _collect_inspectables():
		var center: Vector2 = info["center"]
		var feet_y := center.y + px * 0.38
		var hit := Rect2(center.x - px * 0.55, feet_y - px * 1.6, px * 1.1, px * 1.6 + get_stat_badge_size(px).y * 1.2)
		if not hit.has_point(local_pos):
			continue
		var d := local_pos.distance_squared_to(center)
		if d < best_d:
			best_d = d
			best = info
	return best


func _collect_inspectables() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ally_off := Vector2(0.0, ally_half_slide_y)
	var enemy_off := Vector2(0.0, enemy_half_slide_y)
	if catalog_active:
		for i in catalog_units.size():
			var entry: Variant = catalog_units[i]
			if not (entry is Dictionary):
				continue
			var unit: UnitData = (entry as Dictionary).get("unit") as UnitData
			var cell: Vector2i = (entry as Dictionary).get("cell", NO_CELL)
			if unit == null or cell == NO_CELL:
				continue
			var tile := Vector2(cell) + Vector2(0.5, 0.5)
			out.append(_info_from_unit_data(
				unit, tile_to_local(tile), "catalog:%d" % i, catalog_preview_level
			))
		return out
	if recruit_active:
		if recruit_team_slots != null:
			for i in recruit_team_slots.cells.size():
				var entry := recruit_team_slots.get_entry(i)
				if entry != null:
					var tile := Vector2(recruit_team_slots.cells[i]) + Vector2(0.5, 0.5)
					out.append(_info_from_entry(entry, tile_to_local(tile) + enemy_off))
		for cand in recruit_candidates:
			if not (cand is Dictionary):
				continue
			var unit: UnitData = cand.get("unit") as UnitData
			var cell: Vector2i = cand.get("cell", NO_CELL)
			if unit != null and cell != NO_CELL:
				var tile := Vector2(cell) + Vector2(0.5, 0.5)
				var cand_i := int(cand.get("index", -1))
				out.append(_info_from_unit_data(
					unit, tile_to_local(tile) + ally_off, "cand:%d" % cand_i
				))
		return out
	if sim != null and sim.has_started():
		for item in sim.get_units():
			var rt := item as RtUnit
			if rt == null or rt.unit == null:
				continue
			var off := ally_off if rt.is_player() else enemy_off
			out.append(_info_from_instance(
				rt.unit, rt.is_player(), rt.get_effective_attack(), rt.get_current_hp(), tile_to_local(rt.position) + off
			))
		return out
	if prepare_slots != null:
		for i in prepare_slots.cells.size():
			var entry := prepare_slots.get_entry(i)
			if entry != null:
				var tile := Vector2(prepare_slots.cells[i]) + Vector2(0.5, 0.5)
				out.append(_info_from_entry(entry, tile_to_local(tile) + ally_off))
	for preview in enemy_previews:
		if not (preview is Dictionary):
			continue
		var unit := preview.get("unit") as UnitInstance
		if unit == null:
			continue
		out.append(_info_from_instance(
			unit, false, int(preview.get("attack", 0)), int(preview.get("hp", 0)),
			tile_to_local(preview["position"]) + enemy_off,
		))
	return out


func _info_from_entry(entry: DeckEntry, center: Vector2) -> Dictionary:
	var stats := entry.unit.stats if entry.unit != null else null
	return {
		"inspect_key": "entry:%d" % entry.entry_id,
		"center": center,
		"name": entry.get_display_name(),
		"side_player": true,
		"tier": entry.unit.tier if entry.unit != null else 0,
		"attack": maxi(1, stats.attack + entry.bonus_attack) if stats != null else 0,
		"hp": maxi(1, stats.max_hp + entry.bonus_max_hp) if stats != null else 0,
		"skills": UnitInfoText.get_skills_block_from_entry(entry, true),
		"texture": _art.get_texture(entry.get_unit_id(), true) if _art != null else null,
	}


func _info_from_unit_data(
	data: UnitData,
	center: Vector2,
	inspect_key: String = "",
	preview_level: int = 1,
) -> Dictionary:
	var key := inspect_key
	if key.is_empty():
		key = "unit:%s@%s" % [data.id, str(center)]
	var level := clampi(preview_level, 1, 3)
	var stat_mult := UnitInfoText.catalog_preview_stat_mult(level)
	var atk := data.stats.attack if data.stats != null else 0
	var hp := data.stats.max_hp if data.stats != null else 0
	var star_tag := "" if level <= 1 else " · %d★" % level
	return {
		"inspect_key": key,
		"center": center,
		"name": UnitInfoText.get_display_name_from_unit_data(data) + star_tag,
		"side_player": true,
		"tier": data.tier,
		"attack": atk * stat_mult,
		"hp": hp * stat_mult,
		"skills": UnitInfoText.get_skills_block_from_unit_data(data, level, true),
		"texture": _art.get_texture(data.id, true) if _art != null else null,
	}


func _info_from_instance(unit: UnitInstance, is_player: bool, attack: int, hp: int, center: Vector2) -> Dictionary:
	var unit_id := unit.unit_data.id if unit.unit_data != null else ""
	return {
		"inspect_key": "inst:%d" % unit.get_instance_id(),
		"center": center,
		"name": UnitInfoText.get_display_name(unit),
		"side_player": is_player,
		"tier": unit.unit_data.tier if unit.unit_data != null else 0,
		"attack": attack,
		"hp": hp,
		"skills": UnitInfoText.get_skills_block(unit, true),
		"texture": _art.get_texture(unit_id, is_player) if _art != null else null,
	}


func _candidate_needs_replace(index: int) -> bool:
	if index < 0 or index >= recruit_candidates.size():
		return recruit_needs_replace
	var info: Dictionary = recruit_candidates[index]
	if info.has("needs_replace"):
		return bool(info.get("needs_replace", false))
	return recruit_needs_replace


func _begin_recruit_drag(index: int) -> void:
	if index < 0 or index >= recruit_candidates.size():
		return
	var info: Dictionary = recruit_candidates[index]
	if info.get("unit") == null:
		return
	_recruit_drag_index = index
	_recruit_press_index = -1
	_recruit_item_drag_index = -1
	_recruit_item_press_index = -1
	_recruit_team_drag_id = -1
	_recruit_team_press_id = -1
	recruit_selected_candidate = index
	recruit_needs_replace = _candidate_needs_replace(index)
	_drag_active = true
	var unit: UnitData = info.get("unit") as UnitData
	var stats: UnitStats = unit.stats if unit != null else null
	_drag_radius = stats.body_radius if stats != null else 0.7
	_drag_visual_half_width = stats.get_visual_half_width() if stats != null else 0.0
	_drag_visual_half_height = stats.get_visual_half_height() if stats != null else 0.0
	_drag_label = unit.display_name if unit != null else String(info.get("label", ""))
	_drag_unit_id = unit.id if unit != null else ""
	queue_redraw()


func _begin_recruit_item_drag(index: int) -> void:
	if index < 0 or index >= recruit_items.size():
		return
	var info: Dictionary = recruit_items[index]
	var item: PrepareItemData = info.get("item") as PrepareItemData
	if item == null or not item.needs_target():
		## 旗帜不拖，走点击购买。
		return
	_recruit_item_drag_index = index
	_recruit_item_press_index = -1
	_recruit_drag_index = -1
	_recruit_press_index = -1
	_recruit_team_drag_id = -1
	_recruit_team_press_id = -1
	recruit_pending_item_slot = index
	_drag_active = true
	_drag_radius = 0.55
	_drag_visual_half_width = 0.0
	_drag_visual_half_height = 0.0
	_drag_label = String(info.get("label", item.get_display_name()))
	_drag_unit_id = ""
	queue_redraw()


func _finish_recruit_item_drag(cell: Vector2i) -> void:
	var index := _recruit_item_drag_index
	_recruit_item_drag_index = -1
	_recruit_item_press_index = -1
	_drag_active = false
	if index < 0:
		queue_redraw()
		return
	var mid := BoardHalf.midline_row(board_size.y)
	if cell == NO_CELL or cell.y >= mid:
		queue_redraw()
		return
	var entry_id := _find_recruit_team_entry_at(cell)
	if entry_id < 0:
		queue_redraw()
		return
	recruit_item_drop.emit(index, entry_id)
	queue_redraw()


func _finish_recruit_drag(cell: Vector2i) -> void:
	var index := _recruit_drag_index
	_recruit_drag_index = -1
	_recruit_press_index = -1
	_drag_active = false
	if index < 0:
		return
	## 候选人拖到出售落点无效（与队伍拖卖分离）。
	if _is_recruit_sell_cell(cell):
		queue_redraw()
		return
	## 拖到锁定落点：切换锁定，不购买。
	if _is_recruit_lock_cell(cell):
		recruit_candidate_lock.emit(index)
		queue_redraw()
		return
	var mid := BoardHalf.midline_row(board_size.y)
	if cell == NO_CELL or cell.y >= mid:
		queue_redraw()
		return
	var replace_id := _find_recruit_team_entry_at(cell)
	var seat_i := _find_recruit_team_seat_at(cell)
	if _candidate_needs_replace(index):
		if replace_id < 0:
			queue_redraw()
			return
		recruit_drop.emit(index, replace_id, -1)
	else:
		## 空席：指定空座优先；拖到非座位格则首空座（seat=-1）。
		## 满员可三合一时走此分支，直接买入。
		if replace_id >= 0:
			seat_i = -1
		elif seat_i < 0 and recruit_team_slots != null:
			seat_i = recruit_team_slots.find_nearest_empty_slot(cell)
		recruit_drop.emit(index, -1, seat_i)
	queue_redraw()


func _begin_recruit_team_drag(entry_id: int) -> void:
	if entry_id < 0 or recruit_team_slots == null:
		return
	var entry: DeckEntry = null
	for i in recruit_team_slots.slot_count:
		var e := recruit_team_slots.get_entry(i)
		if e != null and e.entry_id == entry_id:
			entry = e
			break
	if entry == null:
		return
	_recruit_team_drag_id = entry_id
	_recruit_team_press_id = -1
	_recruit_drag_index = -1
	_recruit_press_index = -1
	_drag_active = true
	var stats := entry.unit.stats if entry.unit != null else null
	_drag_radius = stats.body_radius if stats != null else 0.7
	_drag_visual_half_width = stats.get_visual_half_width() if stats != null else 0.0
	_drag_visual_half_height = stats.get_visual_half_height() if stats != null else 0.0
	_drag_label = entry.get_display_name()
	_drag_unit_id = entry.get_unit_id()
	recruit_sell_preview_gold = DeckUpgradeService.get_sell_price(entry)
	queue_redraw()


func _finish_recruit_team_drag(cell: Vector2i) -> void:
	var entry_id := _recruit_team_drag_id
	_recruit_team_drag_id = -1
	_recruit_team_press_id = -1
	_drag_active = false
	recruit_sell_preview_gold = 0
	if entry_id < 0:
		queue_redraw()
		return
	if _is_recruit_sell_cell(cell):
		recruit_sell.emit(entry_id)
		queue_redraw()
		return
	## 拖到上区空座或另一座位：换座（写回由控制器处理）；勿与出售冲突。
	var seat_i := _find_recruit_team_seat_at(cell)
	if seat_i < 0 and recruit_team_slots != null:
		seat_i = recruit_team_slots.find_nearest_empty_slot(cell)
		if seat_i >= 0:
			var sc := recruit_team_slots.get_cell(seat_i)
			if absi(sc.x - cell.x) + absi(sc.y - cell.y) > 4:
				seat_i = -1
	if seat_i >= 0:
		recruit_team_seat_drop.emit(entry_id, seat_i)
	queue_redraw()


func _is_recruit_sell_cell(cell: Vector2i) -> bool:
	return recruit_sell_cell != NO_CELL and cell == recruit_sell_cell


func _is_recruit_lock_cell(cell: Vector2i) -> bool:
	return recruit_lock_cell != NO_CELL and cell == recruit_lock_cell


func _find_recruit_candidate_at(cell: Vector2i) -> int:
	if cell == NO_CELL:
		return -1
	for info in recruit_candidates:
		if not (info is Dictionary):
			continue
		var c: Vector2i = info.get("cell", NO_CELL)
		if c == cell:
			return int(info.get("index", -1))
	return -1


func _find_recruit_item_at(cell: Vector2i) -> int:
	if cell == NO_CELL:
		return -1
	for info in recruit_items:
		if not (info is Dictionary):
			continue
		var c: Vector2i = info.get("cell", NO_CELL)
		if c == cell:
			return int(info.get("index", -1))
	return -1


func _find_recruit_team_entry_at(cell: Vector2i) -> int:
	if recruit_team_slots == null or cell == NO_CELL:
		return -1
	var slot_i := recruit_team_slots.find_slot_at_cell(cell)
	if slot_i < 0:
		return -1
	var entry := recruit_team_slots.get_entry(slot_i)
	if entry == null:
		return -1
	return entry.entry_id


func _find_recruit_team_seat_at(cell: Vector2i) -> int:
	if recruit_team_slots == null or cell == NO_CELL:
		return -1
	return recruit_team_slots.find_slot_at_cell(cell)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var dict := data as Dictionary
	if dict.has(RECRUIT_CANDIDATE_KEY) and recruit_active:
		_drag_active = true
		_recruit_drag_index = int(dict[RECRUIT_CANDIDATE_KEY])
		_drag_radius = float(dict.get("radius", 0.7))
		_drag_visual_half_width = float(dict.get("visual_half_width", 0.0))
		_drag_visual_half_height = float(dict.get("visual_half_height", 0.0))
		_drag_label = String(dict.get("label", ""))
		_drag_unit_id = String(dict.get("unit_id", ""))
		_hover_cell = tile_to_cell(local_to_tile(at_position))
		return true
	if not dict.has(DRAG_KEY):
		return false
	_drag_active = true
	_drag_radius = float(dict.get("radius", 0.7))
	_drag_visual_half_width = float(dict.get("visual_half_width", 0.0))
	_drag_visual_half_height = float(dict.get("visual_half_height", 0.0))
	_drag_label = String(dict.get("label", ""))
	_drag_unit_id = String(dict.get("unit_id", ""))
	_hover_cell = tile_to_cell(local_to_tile(at_position))
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	_drag_active = false
	var dict := data as Dictionary
	if dict.has(RECRUIT_CANDIDATE_KEY) and recruit_active:
		var index := int(dict[RECRUIT_CANDIDATE_KEY])
		_recruit_drag_index = -1
		var cell := tile_to_cell(local_to_tile(at_position))
		var mid := BoardHalf.midline_row(board_size.y)
		if cell == NO_CELL or cell.y >= mid:
			return
		var replace_id := _find_recruit_team_entry_at(cell)
		var seat_i := _find_recruit_team_seat_at(cell)
		if _candidate_needs_replace(index):
			if replace_id < 0:
				return
			recruit_drop.emit(index, replace_id, -1)
		else:
			if replace_id >= 0:
				seat_i = -1
			elif seat_i < 0 and recruit_team_slots != null:
				seat_i = recruit_team_slots.find_nearest_empty_slot(cell)
			recruit_drop.emit(index, -1, seat_i)
		return
	card_dropped.emit(int(dict[DRAG_KEY]), local_to_tile(at_position))


# --- 绘制 ---


func reset_half_slide() -> void:
	enemy_half_slide_y = 0.0
	ally_half_slide_y = 0.0
	queue_redraw()


func clear_recruit_mode() -> void:
	_cancel_press()
	recruit_active = false
	recruit_team_slots = null
	recruit_candidates.clear()
	recruit_items.clear()
	recruit_selected_candidate = -1
	recruit_selected_replace_id = -1
	recruit_needs_replace = false
	recruit_pending_item_slot = -1
	recruit_sell_cell = NO_CELL
	recruit_lock_cell = NO_CELL
	recruit_sell_preview_gold = 0
	_recruit_drag_index = -1
	_recruit_press_index = -1
	_recruit_item_drag_index = -1
	_recruit_item_press_index = -1
	_recruit_team_drag_id = -1
	_recruit_team_press_id = -1
	queue_redraw()


## 角色库：把单位按列铺满棋盘，沿用战斗剪影 / 攻血标 / 长按技能卡。
## preview_level：1=一星，2=三合一预览（攻血×3、技能按星级缩放）。
func set_catalog_units(units: Array[UnitData], columns: int = 5, preview_level: int = 1) -> void:
	_cancel_press()
	clear_recruit_mode()
	sim = null
	prepare_slots = null
	enemy_slots = null
	enemy_previews.clear()
	catalog_active = true
	catalog_preview_level = clampi(preview_level, 1, 3)
	catalog_units.clear()
	var cols := maxi(1, columns)
	var rows := maxi(4, int(ceili(float(maxi(1, units.size())) / float(cols))))
	board_size = Vector2i(cols, rows)
	for i in units.size():
		var unit := units[i]
		if unit == null:
			continue
		catalog_units.append({
			"unit": unit,
			"cell": Vector2i(i % cols, int(i / cols)),
		})
	queue_redraw()


func clear_catalog_mode() -> void:
	_cancel_press()
	catalog_active = false
	catalog_preview_level = 1
	catalog_units.clear()
	board_size = Vector2i(5, 8)
	queue_redraw()


func set_half_slide_offscreen(travel: float) -> void:
	enemy_half_slide_y = -absf(travel)
	ally_half_slide_y = absf(travel)
	queue_redraw()


func _draw() -> void:
	var rect := get_board_rect()
	var px := get_cell_px()
	var mid := BoardHalf.midline_row(board_size.y)
	var enemy_off := Vector2(0.0, enemy_half_slide_y)
	var ally_off := Vector2(0.0, ally_half_slide_y)
	_frame_shake = _motion.get_shake_offset()
	draw_set_transform(_frame_shake)
	## 背景不随半场 slide，保证胜→招募同屏背景不断。
	draw_texture_rect(ARENA_BACKGROUND, _get_background_rect().grow(SHAKE_BLEED_PX), false)
	## 半场色调与单位/座位随内容滑动。
	draw_rect(Rect2(rect.position + enemy_off, Vector2(rect.size.x, mid * px)), ENEMY_TINT)
	draw_rect(
		Rect2(rect.position + Vector2(0, mid * px) + ally_off, Vector2(rect.size.x, (board_size.y - mid) * px)),
		PLAYER_TINT,
	)

	var showing_placement := (placement_active or _drag_active) and not recruit_active and not catalog_active
	if showing_placement:
		draw_rect(
			Rect2(rect.position + Vector2(0, mid * px) + ally_off, Vector2(rect.size.x, (board_size.y - mid) * px)),
			DEPLOY_HIGHLIGHT,
		)
	var mid_y := rect.position.y + mid * px
	## 中线仅作半场暗示，避免画成明显格网线。
	if not catalog_active:
		draw_line(Vector2(rect.position.x, mid_y), Vector2(rect.end.x, mid_y), Color(MIDLINE, MIDLINE.a * 0.45), 1.0)

	if catalog_active:
		_draw_catalog_units(px)
	elif recruit_active:
		_draw_recruit_zone_labels(px, mid, enemy_off, ally_off)
		_draw_recruit_team(px, enemy_off)
		_draw_recruit_candidates(px, ally_off)
		_draw_recruit_items(px, ally_off)
		_draw_recruit_sell_slot(px, ally_off)
		_draw_recruit_lock_slot(px, ally_off)
		if _recruit_drag_index >= 0 and _hover_cell != NO_CELL:
			_draw_recruit_drop_hint(px, mid)
		elif _recruit_item_drag_index >= 0 and _hover_cell != NO_CELL:
			_draw_recruit_item_drop_hint(px, mid)
		elif _recruit_team_drag_id >= 0 and _hover_cell != NO_CELL:
			if _is_recruit_sell_cell(_hover_cell):
				_draw_recruit_team_sell_hint(px)
			else:
				_draw_recruit_team_seat_hint(px)
	else:
		_draw_enemy_slots(px)
		_draw_prepare_slots(px)

		## 敌方预览按 y 轴排序：靠下压上，避免剪影互盖错层。
		var previews := enemy_previews.duplicate()
		previews.sort_custom(func(a: Variant, b: Variant) -> bool:
			var ay := float((a as Dictionary).get("position", Vector2.ZERO).y)
			var by := float((b as Dictionary).get("position", Vector2.ZERO).y)
			if ay == by:
				return float((a as Dictionary).get("position", Vector2.ZERO).x) < float((b as Dictionary).get("position", Vector2.ZERO).x)
			return ay < by
		)
		for preview in previews:
			if not (preview is Dictionary):
				continue
			var body_r := float(preview["radius"])
			var vwx := float(preview.get("visual_half_width", 0.0))
			var vhy := float(preview.get("visual_half_height", 0.0))
			var fp_span := maxf(
				float(preview.get("footprint_w", 1)),
				float(preview.get("footprint_h", 1)),
			)
			_draw_body(
				preview["position"], body_r, vwx, vhy, ENEMY_COLOR, 0.85, String(preview["label"]), px, false, enemy_off,
				false, String(preview.get("unit_id", "")), null, Vector2.ZERO, fp_span,
			)
			_draw_stat_badges(
				tile_to_local(preview["position"]) + enemy_off,
				int(preview.get("attack", 0)),
				int(preview.get("hp", 0)),
				0.9,
				px,
			)

		if sim != null:
			_draw_units(px)
			_draw_projectiles(px)
	_draw_fx(px)
	_draw_feedback(px)
	if showing_placement and _hover_cell != NO_CELL:
		_draw_ghost(px, mid)


func _draw_recruit_zone_labels(px: float, mid: int, enemy_off: Vector2, ally_off: Vector2) -> void:
	var rect := get_board_rect()
	var font := get_theme_default_font()
	var font_size := clampi(int(px * 0.55), 11, 18)
	var top_pos := rect.position + enemy_off + Vector2(px * 0.25, px * 0.7)
	var bot_pos := rect.position + ally_off + Vector2(px * 0.25, float(mid) * px + px * 0.7)
	draw_string(font, top_pos, "队伍", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.92, 0.96, 1.0, 0.9))
	draw_string(font, bot_pos, "招募商店", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.95, 0.75, 0.9))


func _draw_recruit_sell_slot(px: float, off: Vector2) -> void:
	if recruit_sell_cell == NO_CELL:
		return
	var rect := get_board_rect()
	var cell_rect := Rect2(rect.position + Vector2(recruit_sell_cell) * px + off, Vector2(px, px))
	var hot := _recruit_team_drag_id >= 0 and _hover_cell == recruit_sell_cell
	draw_rect(cell_rect, RECRUIT_SELL_HOT if hot else RECRUIT_SELL_EMPTY)
	draw_rect(cell_rect, RECRUIT_SELL_BORDER, false, 2.0)
	var font := get_theme_default_font()
	var font_size := clampi(int(px * 0.4), 10, 16)
	var label := "出售"
	if hot and recruit_sell_preview_gold > 0:
		label = "+%d金" % recruit_sell_preview_gold
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := cell_rect.position + Vector2(
		(cell_rect.size.x - text_size.x) * 0.5,
		(cell_rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5,
	)
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.92, 1.0, 0.95))


func _draw_recruit_lock_slot(px: float, off: Vector2) -> void:
	if recruit_lock_cell == NO_CELL:
		return
	var rect := get_board_rect()
	var cell_rect := Rect2(rect.position + Vector2(recruit_lock_cell) * px + off, Vector2(px, px))
	var hot := _recruit_drag_index >= 0 and _hover_cell == recruit_lock_cell
	draw_rect(cell_rect, RECRUIT_LOCK_HOT if hot else RECRUIT_LOCK_EMPTY)
	draw_rect(cell_rect, RECRUIT_LOCK_BORDER, false, 2.0)
	var font := get_theme_default_font()
	var font_size := clampi(int(px * 0.4), 10, 16)
	var label := "锁定"
	if hot and _recruit_drag_index >= 0 and _recruit_drag_index < recruit_candidates.size():
		var info: Dictionary = recruit_candidates[_recruit_drag_index]
		if bool(info.get("locked", false)):
			label = "解锁"
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := cell_rect.position + Vector2(
		(cell_rect.size.x - text_size.x) * 0.5,
		(cell_rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5,
	)
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.95, 0.75, 0.95))


func _draw_recruit_team_sell_hint(px: float) -> void:
	var cell := _hover_cell
	if cell == NO_CELL:
		return
	var cell_rect := Rect2(get_board_rect().position + Vector2(cell) * px, Vector2(px, px))
	var ok := _is_recruit_sell_cell(cell)
	draw_rect(cell_rect, Color(0.85, 0.45, 0.9, 0.4) if ok else Color(1.0, 0.25, 0.2, 0.25))
	_draw_body(
		Vector2(cell) + Vector2(0.5, 0.5),
		_drag_radius,
		_drag_visual_half_width,
		_drag_visual_half_height,
		PLAYER_COLOR,
		0.45,
		_drag_label,
		px,
		true,
		Vector2.ZERO,
		true,
		_drag_unit_id,
	)


func _draw_recruit_team_seat_hint(px: float) -> void:
	var cell := _hover_cell
	if cell == NO_CELL:
		return
	var seat_i := _find_recruit_team_seat_at(cell)
	var ok := seat_i >= 0
	var cell_rect := Rect2(get_board_rect().position + Vector2(cell) * px, Vector2(px, px))
	draw_rect(cell_rect, Color(0.45, 0.85, 1.0, 0.4) if ok else Color(1.0, 0.25, 0.2, 0.25))
	_draw_body(
		Vector2(cell) + Vector2(0.5, 0.5),
		_drag_radius,
		_drag_visual_half_width,
		_drag_visual_half_height,
		PLAYER_COLOR,
		0.45,
		_drag_label,
		px,
		true,
		Vector2.ZERO,
		true,
		_drag_unit_id,
	)


func _draw_recruit_team(px: float, off: Vector2) -> void:
	if recruit_team_slots == null or recruit_team_slots.cells.is_empty():
		return
	var rect := get_board_rect()
	var occupied_indices: Array[int] = []
	for i in recruit_team_slots.cells.size():
		var cell: Vector2i = recruit_team_slots.cells[i]
		var entry: DeckEntry = recruit_team_slots.get_entry(i)
		var cell_rect := Rect2(rect.position + Vector2(cell) * px + off, Vector2(px, px))
		draw_rect(cell_rect, RECRUIT_TEAM_FILL if entry != null else RECRUIT_TEAM_EMPTY)
		var border := RECRUIT_TEAM_BORDER
		if entry != null and entry.entry_id == recruit_selected_replace_id:
			draw_rect(cell_rect, RECRUIT_SELECT)
			border = Color(1.0, 0.95, 0.4, 1.0)
		draw_rect(cell_rect, border, false, 2.0)
		if entry != null:
			occupied_indices.append(i)
	occupied_indices.sort_custom(func(a: int, b: int) -> bool:
		var ca := recruit_team_slots.cells[a]
		var cb := recruit_team_slots.cells[b]
		if ca.y != cb.y:
			return ca.y < cb.y
		return ca.x < cb.x
	)
	_bring_inspect_slot_to_front(occupied_indices, recruit_team_slots, off)
	for i in occupied_indices:
		var cell: Vector2i = recruit_team_slots.cells[i]
		var entry: DeckEntry = recruit_team_slots.get_entry(i)
		if entry == null:
			continue
		var center_tile := Vector2(cell) + Vector2(0.5, 0.5)
		var stats := entry.unit.stats if entry.unit != null else null
		var radius := stats.body_radius if stats != null else 0.7
		var vwx := stats.get_visual_half_width() if stats != null else 0.0
		var vhy := stats.get_visual_half_height() if stats != null else 0.0
		_draw_body(
			center_tile, radius, vwx, vhy, PLAYER_COLOR, 0.9, entry.get_display_name(), px, true, off,
			true, entry.get_unit_id(), null, Vector2.ZERO, 1.0, _idle_seed_for(entry.get_unit_id(), i),
		)
		var atk := 0
		var hp := 0
		if stats != null:
			atk = maxi(1, stats.attack + entry.bonus_attack)
			hp = maxi(1, stats.max_hp + entry.bonus_max_hp)
		_draw_stat_badges(tile_to_local(center_tile) + off, atk, hp, 0.95, px)


func _draw_catalog_units(px: float) -> void:
	var rect := get_board_rect()
	var ordered := catalog_units.duplicate()
	ordered.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ac: Vector2i = (a as Dictionary).get("cell", NO_CELL)
		var bc: Vector2i = (b as Dictionary).get("cell", NO_CELL)
		if ac.y == bc.y:
			return ac.x < bc.x
		return ac.y < bc.y
	)
	## 长按查看技能时，把该角色（含攻血标）画到最后，避免被邻格剪影/数值挡住（不改列表排序）。
	if _info_shown:
		var focus_key := String(_shown_info.get("inspect_key", ""))
		if focus_key.begins_with("catalog:"):
			var focus_idx := int(focus_key.get_slice(":", 1))
			if focus_idx >= 0 and focus_idx < catalog_units.size():
				var focus_entry: Variant = catalog_units[focus_idx]
				var at := ordered.find(focus_entry)
				if at >= 0:
					ordered.remove_at(at)
					ordered.append(focus_entry)
	## 身体与攻血标同序绘制：后画的整组在上；勿先画完全员身体再叠标，否则邻格数值会盖住置顶剪影。
	for info in ordered:
		if not (info is Dictionary):
			continue
		var cell: Vector2i = info.get("cell", NO_CELL)
		var unit: UnitData = info.get("unit") as UnitData
		if cell == NO_CELL or unit == null:
			continue
		var cell_rect := Rect2(rect.position + Vector2(cell) * px, Vector2(px, px))
		draw_rect(cell_rect, RECRUIT_CAND_EMPTY)
		draw_rect(cell_rect, Color(RECRUIT_CAND_BORDER, 0.35), false, 1.0)
		var center_tile := Vector2(cell) + Vector2(0.5, 0.5)
		var stats := unit.stats
		var radius := stats.body_radius if stats != null else 0.7
		var vwx := stats.get_visual_half_width() if stats != null else 0.0
		var vhy := stats.get_visual_half_height() if stats != null else 0.0
		_draw_body(
			center_tile, radius, vwx, vhy, PLAYER_COLOR, 0.95, unit.display_name, px, true, Vector2.ZERO,
			true, unit.id, null, Vector2.ZERO, 1.0, _idle_seed_for(unit.id, cell.x + cell.y * 8),
		)
		var preview_mult := UnitInfoText.catalog_preview_stat_mult(catalog_preview_level)
		_draw_stat_badges(
			tile_to_local(center_tile),
			(stats.attack if stats != null else 0) * preview_mult,
			(stats.max_hp if stats != null else 0) * preview_mult,
			0.95,
			px,
		)


func _draw_recruit_candidates(px: float, off: Vector2) -> void:
	var rect := get_board_rect()
	var ordered := recruit_candidates.duplicate()
	if _info_shown and not ordered.is_empty():
		var focus_c: Vector2 = _shown_info.get("center", Vector2.INF) as Vector2
		var hit_r2 := _inspect_focus_hit_r2()
		var focus_at := -1
		for idx in ordered.size():
			var cand: Variant = ordered[idx]
			if not (cand is Dictionary):
				continue
			var cell_i: Vector2i = (cand as Dictionary).get("cell", NO_CELL)
			if cell_i == NO_CELL:
				continue
			var c := tile_to_local(Vector2(cell_i) + Vector2(0.5, 0.5)) + off
			if c.distance_squared_to(focus_c) <= hit_r2:
				focus_at = idx
				break
		if focus_at >= 0:
			var moved: Variant = ordered[focus_at]
			ordered.remove_at(focus_at)
			ordered.append(moved)
	for info in ordered:
		if not (info is Dictionary):
			continue
		var cell: Vector2i = info.get("cell", NO_CELL)
		if cell == NO_CELL:
			continue
		var index := int(info.get("index", -1))
		var unit: UnitData = info.get("unit") as UnitData
		var cell_rect := Rect2(rect.position + Vector2(cell) * px + off, Vector2(px, px))
		draw_rect(cell_rect, RECRUIT_CAND_FILL if unit != null else RECRUIT_CAND_EMPTY)
		var locked := bool(info.get("locked", false))
		var border := RECRUIT_CAND_BORDER
		if locked:
			border = Color(0.95, 0.75, 0.25, 1.0)
		if index == recruit_selected_candidate or index == _recruit_drag_index:
			draw_rect(cell_rect, RECRUIT_SELECT)
			border = Color(1.0, 0.95, 0.4, 1.0)
		draw_rect(cell_rect, border, false, 2.0 if not locked else 3.0)
		if unit == null:
			continue
		## 拖拽中的候选人在原位半透明，并在悬停格画幽灵。
		var alpha := 0.35 if index == _recruit_drag_index else 0.95
		var center_tile := Vector2(cell) + Vector2(0.5, 0.5)
		var stats := unit.stats
		var radius := stats.body_radius if stats != null else 0.7
		var vwx := stats.get_visual_half_width() if stats != null else 0.0
		var vhy := stats.get_visual_half_height() if stats != null else 0.0
		_draw_body(
			center_tile, radius, vwx, vhy, PLAYER_COLOR.lightened(0.15), alpha, unit.display_name, px, true, off,
			true, unit.id, null, Vector2.ZERO, 1.0, _idle_seed_for(unit.id, index),
		)
		var atk := stats.attack if stats != null else 0
		var hp := stats.max_hp if stats != null else 0
		_draw_stat_badges(tile_to_local(center_tile) + off, atk, hp, alpha, px)
		var cost := int(info.get("cost", 0))
		var affordable := bool(info.get("affordable", true))
		_draw_recruit_cost_tag(tile_to_local(center_tile) + off, cost, affordable, px)
		if locked:
			_draw_recruit_lock_tag(tile_to_local(center_tile) + off, px)


func _draw_recruit_cost_tag(center: Vector2, cost: int, affordable: bool, px: float) -> void:
	var font := get_theme_default_font()
	var text := "%d金" % cost
	var font_size := clampi(int(px * 0.35), 9, 14)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := center + Vector2(-text_size.x * 0.5, -px * 0.85)
	var color := Color(1.0, 0.9, 0.35, 0.95) if affordable else Color(1.0, 0.35, 0.3, 0.95)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_recruit_lock_tag(center: Vector2, px: float) -> void:
	var font := get_theme_default_font()
	var text := "锁"
	var font_size := clampi(int(px * 0.32), 9, 13)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := center + Vector2(px * 0.22 - text_size.x * 0.5, -px * 0.55)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.85, 0.3, 0.98))


func _draw_recruit_items(px: float, off: Vector2) -> void:
	var rect := get_board_rect()
	var font := get_theme_default_font()
	for info in recruit_items:
		if not (info is Dictionary):
			continue
		var cell: Vector2i = info.get("cell", NO_CELL)
		if cell == NO_CELL:
			continue
		var index := int(info.get("index", -1))
		var item: PrepareItemData = info.get("item") as PrepareItemData
		var cell_rect := Rect2(rect.position + Vector2(cell) * px + off, Vector2(px, px))
		draw_rect(cell_rect, RECRUIT_ITEM_FILL if item != null else RECRUIT_ITEM_EMPTY)
		var border := RECRUIT_ITEM_BORDER
		if index == recruit_pending_item_slot or index == _recruit_item_drag_index:
			draw_rect(cell_rect, RECRUIT_SELECT)
			border = Color(1.0, 0.95, 0.4, 1.0)
		draw_rect(cell_rect, border, false, 2.0)
		if item == null:
			continue
		var label := String(info.get("label", item.get_display_name()))
		var font_size := clampi(int(px * 0.28), 8, 12)
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var text_pos := cell_rect.position + Vector2(
			(cell_rect.size.x - text_size.x) * 0.5,
			cell_rect.size.y * 0.42,
		)
		var alpha := 0.4 if index == _recruit_item_drag_index else 1.0
		draw_string(
			font,
			text_pos,
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color(0.95, 1.0, 0.95, alpha),
		)
		var cost := int(info.get("cost", 0))
		var affordable := bool(info.get("affordable", true))
		_draw_recruit_cost_tag(tile_to_local(Vector2(cell) + Vector2(0.5, 0.5)) + off, cost, affordable, px)


func _draw_recruit_item_drop_hint(px: float, mid: int) -> void:
	var cell := _hover_cell
	if cell == NO_CELL:
		return
	var cell_rect := Rect2(get_board_rect().position + Vector2(cell) * px, Vector2(px, px))
	if cell.y >= mid:
		draw_rect(cell_rect, Color(1.0, 0.25, 0.2, 0.3))
		return
	var ok := _find_recruit_team_entry_at(cell) >= 0
	draw_rect(cell_rect, Color(0.35, 0.95, 0.65, 0.4) if ok else Color(1.0, 0.25, 0.2, 0.3))
	var font := get_theme_default_font()
	var font_size := clampi(int(px * 0.32), 9, 14)
	var label := _drag_label if not _drag_label.is_empty() else "药水"
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := cell_rect.position + Vector2(
		(cell_rect.size.x - text_size.x) * 0.5,
		(cell_rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5,
	)
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.9))


func _draw_recruit_drop_hint(px: float, mid: int) -> void:
	var cell := _hover_cell
	if cell == NO_CELL:
		return
	var cell_rect := Rect2(get_board_rect().position + Vector2(cell) * px, Vector2(px, px))
	## 锁区在下半场：拖候选人落锁为合法高亮。
	if _is_recruit_lock_cell(cell):
		draw_rect(cell_rect, Color(0.95, 0.85, 0.35, 0.4))
		_draw_body(
			Vector2(cell) + Vector2(0.5, 0.5),
			_drag_radius,
			_drag_visual_half_width,
			_drag_visual_half_height,
			PLAYER_COLOR,
			0.45,
			_drag_label,
			px,
			true,
			Vector2.ZERO,
			true,
			_drag_unit_id,
		)
		return
	if cell.y >= mid:
		draw_rect(cell_rect, Color(1.0, 0.25, 0.2, 0.3))
		return
	var ok := true
	if recruit_needs_replace:
		ok = _find_recruit_team_entry_at(cell) >= 0
	draw_rect(cell_rect, Color(0.35, 0.95, 0.45, 0.35) if ok else Color(1.0, 0.25, 0.2, 0.3))
	var info: Dictionary = {}
	if _recruit_drag_index >= 0 and _recruit_drag_index < recruit_candidates.size():
		info = recruit_candidates[_recruit_drag_index]
	var unit: UnitData = info.get("unit") as UnitData if not info.is_empty() else null
	var stats := unit.stats if unit != null else null
	var radius := stats.body_radius if stats != null else _drag_radius
	var vwx := stats.get_visual_half_width() if stats != null else _drag_visual_half_width
	var vhy := stats.get_visual_half_height() if stats != null else _drag_visual_half_height
	var label := unit.display_name if unit != null else _drag_label
	var uid := unit.id if unit != null else _drag_unit_id
	_draw_body(
		Vector2(cell) + Vector2(0.5, 0.5), radius, vwx, vhy, PLAYER_COLOR, 0.45, label, px, true, Vector2.ZERO,
		true, uid,
	)


func _draw_enemy_slots(px: float) -> void:
	if enemy_slots == null or enemy_slots.cells.is_empty():
		return
	var occupied := _enemy_preview_seat_set()
	var rect := get_board_rect()
	var off := Vector2(0.0, enemy_half_slide_y)
	for i in enemy_slots.cells.size():
		var cell: Vector2i = enemy_slots.cells[i]
		var cell_rect := Rect2(rect.position + Vector2(cell) * px + off, Vector2(px, px))
		var filled := occupied.has(i)
		## 不描边；空座几乎不可见，避免铺满半场时像格子纸。
		if filled:
			draw_rect(cell_rect, ENEMY_SLOT_OCCUPIED)
		elif ENEMY_SLOT_EMPTY.a > 0.0:
			draw_rect(cell_rect, ENEMY_SLOT_EMPTY)


func _enemy_preview_seat_set() -> Dictionary:
	var occupied: Dictionary = {}
	for preview in enemy_previews:
		if preview is Dictionary and (preview as Dictionary).has("seat_index"):
			var seat_i := int(preview["seat_index"])
			if seat_i >= 0:
				occupied[seat_i] = true
	return occupied


func _draw_prepare_slots(px: float) -> void:
	if prepare_slots == null or prepare_slots.cells.is_empty():
		return
	var rect := get_board_rect()
	var off := Vector2(0.0, ally_half_slide_y)
	## 先画底色，再按 y 排序画角色（靠下压上）。
	var occupied_indices: Array[int] = []
	for i in prepare_slots.cells.size():
		var cell: Vector2i = prepare_slots.cells[i]
		var entry: DeckEntry = prepare_slots.get_entry(i)
		var cell_rect := Rect2(rect.position + Vector2(cell) * px + off, Vector2(px, px))
		## 不描边；空座极淡，占座仅轻晕，避免显性格线。
		if entry != null:
			draw_rect(cell_rect, SLOT_OCCUPIED)
			occupied_indices.append(i)
		elif SLOT_EMPTY.a > 0.0:
			draw_rect(cell_rect, SLOT_EMPTY)
	if sim != null and sim.has_started():
		return
	occupied_indices.sort_custom(func(a: int, b: int) -> bool:
		var ca := prepare_slots.cells[a]
		var cb := prepare_slots.cells[b]
		if ca.y != cb.y:
			return ca.y < cb.y
		return ca.x < cb.x
	)
	_bring_inspect_slot_to_front(occupied_indices, prepare_slots, off)
	for i in occupied_indices:
		var cell: Vector2i = prepare_slots.cells[i]
		var entry: DeckEntry = prepare_slots.get_entry(i)
		if entry == null:
			continue
		var center_tile := Vector2(cell) + Vector2(0.5, 0.5)
		var stats := entry.unit.stats if entry.unit != null else null
		var radius := stats.body_radius if stats != null else 0.7
		var vwx := stats.get_visual_half_width() if stats != null else 0.0
		var vhy := stats.get_visual_half_height() if stats != null else 0.0
		_draw_body(
			center_tile, radius, vwx, vhy, PLAYER_COLOR, 0.9, entry.get_display_name(), px, true, off,
			true, entry.get_unit_id(), null, Vector2.ZERO, 1.0, _idle_seed_for(entry.get_unit_id(), i),
		)
		var atk := 0
		var hp := 0
		if stats != null:
			atk = maxi(1, stats.attack + entry.bonus_attack)
			hp = maxi(1, stats.max_hp + entry.bonus_max_hp)
		_draw_stat_badges(tile_to_local(center_tile) + off, atk, hp, 0.95, px)


func _draw_units(px: float) -> void:
	var now := sim.elapsed_seconds
	var started := sim.has_started()
	## COMBAT_FEEDBACK：当前行动者高亮；其余略降对比，不做出手条。
	var actor: RtUnit = sim.get_current_actor() if started else null
	## 先画全部单位再画全部攻血标，避免相邻贴图盖住标签。
	var badges: Array[Dictionary] = []
	## 按 y 轴排序绘制：靠下（更大 y）后画压上，避免剪影叠层错乱。
	var ordered := sim.get_units().duplicate()
	ordered.sort_custom(func(a: RtUnit, b: RtUnit) -> bool:
		if a.position.y == b.position.y:
			return a.position.x < b.position.x
		return a.position.y < b.position.y
	)
	_bring_inspect_rt_to_front(ordered)
	for item in ordered:
		var rt := item as RtUnit
		var base := PLAYER_COLOR if rt.is_player() else ENEMY_COLOR
		var alpha := 1.0
		var is_actor := actor != null and rt == actor
		if started and actor != null and not is_actor:
			alpha = 0.72
		if started and rt.is_deploying():
			alpha = mini(alpha, 0.55)
		if now - rt.last_attack_time < ATTACK_FLASH_SECONDS:
			base = base.lightened(0.45)
		if now - rt.last_hit_time < HIT_FLASH_SECONDS:
			base = base.lerp(Color.WHITE, 0.5)
		if is_actor:
			base = base.lightened(0.28)
		var vwx := rt.get_visual_half_width()
		var vhy := rt.get_visual_half_height()
		## 当前行动者略放大剪影，便于观战指认。
		var scale := 1.12 if is_actor else 1.0
		var off := Vector2(0.0, ally_half_slide_y if rt.is_player() else enemy_half_slide_y)
		var fp := rt.get_footprint_size()
		var fp_span := maxf(float(fp.x), float(fp.y))
		_draw_body(
			rt.position, rt.get_radius(), vwx * scale, vhy * scale, base, alpha, rt.get_display_name(), px, true, off,
			rt.is_player(), _rt_unit_id(rt), _motion.get_pose(rt), _motion.walk_pose(rt), fp_span,
		)
		var center := tile_to_local(rt.position) + off
		var silhouette_r_px := maxf(vwx, vhy) * scale * px
		if is_actor:
			draw_arc(center, silhouette_r_px + 5.0, 0.0, TAU, 28, Color(1.0, 0.92, 0.35, 0.95), 2.5)
		if started and rt.is_deploying():
			var ratio := rt.get_deploy_ratio()
			draw_arc(center, silhouette_r_px + 3.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 24, Color(1, 1, 1, 0.9), 2.0)
		badges.append({
			"center": center, "attack": rt.get_effective_attack(), "hp": rt.get_current_hp(), "alpha": alpha,
		})
	_draw_corpses(px)
	for badge in badges:
		_draw_stat_badges(badge["center"], badge["attack"], badge["hp"], badge["alpha"], px)


func _draw_corpses(px: float) -> void:
	for corpse in _motion.get_corpses():
		var tex: Texture2D = _art.get_texture(corpse.unit_id, corpse.is_player) if _art != null else null
		if tex == null:
			continue
		var off := Vector2(0.0, ally_half_slide_y if corpse.is_player else enemy_half_slide_y)
		var center := tile_to_local(corpse.position) + off
		var base := PLAYER_COLOR if corpse.is_player else ENEMY_COLOR
		_draw_unit_sprite(center, corpse.half_height * px, px, tex, base, 1.0, corpse.is_player, corpse.pose)


func _draw_body(
	tile_pos: Vector2,
	body_radius: float,
	visual_half_width: float,
	visual_half_height: float,
	color: Color,
	alpha: float,
	label: String,
	px: float,
	show_foot: bool,
	pixel_offset: Vector2 = Vector2.ZERO,
	is_player: bool = true,
	unit_id: String = "",
	pose: RealtimeUnitMotion.Pose = null,
	walk: Vector2 = Vector2.ZERO,
	footprint_span: float = 1.0,
	idle_seed: int = -1,
) -> void:
	var center := tile_to_local(tile_pos) + pixel_offset
	var rx := maxf(3.0, _resolve_visual_half(visual_half_width, body_radius, 1.3) * px)
	var ry := maxf(3.0, _resolve_visual_half(visual_half_height, body_radius, 1.6) * px)
	## 多格足迹：剪影略放大，使角色在 2×2 内更饱满可读。
	if footprint_span >= 1.5:
		rx *= 1.35
		ry *= 1.35
	var tex: Texture2D = _art.get_texture(unit_id, is_player) if _art != null else null
	if tex != null:
		_draw_unit_sprite(center, ry, px, tex, color, alpha, is_player, pose, walk, footprint_span, idle_seed)
		return
	## 美术目录缺失时的兜底；正常路径每个兵种都有贴图。
	var fill := Color(color, alpha)
	_draw_ellipse_filled(center, rx, ry, fill)
	_draw_ellipse_outline(center, rx, ry, Color(0, 0, 0, 0.45 * alpha), 1.5)
	if show_foot:
		var foot_r := maxf(2.0, body_radius * px)
		draw_arc(center, foot_r, 0.0, TAU, 20, Color(0, 0, 0, 0.35 * alpha), 1.25)
	if label.is_empty():
		return
	var font := get_theme_default_font()
	## 剪影上标最多两字，便于认出「盾兵 / 链枷」等 Content 兵种名。
	var max_chars := 2 if minf(rx, ry) >= 10.0 else 1
	var font_size := clampi(int(minf(rx, ry) * (0.85 if max_chars > 1 else 1.1)), 8, 22)
	var glyph := label.substr(0, mini(max_chars, label.length()))
	var text_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.5 - font.get_descent(font_size) * 0.25)
	draw_string(font, baseline, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, alpha))


## 贴图脚底：单格落在格心略下方；多格足迹则把整张贴图垂向居中于足迹中心。
## pose / walk 为纯表现动画：以脚底为轴旋转缩放，偏移以格为单位。
## idle_seed>=0 且无 pose 时：准备/招募时钟呼吸待机。
func _draw_unit_sprite(
	center: Vector2,
	half_height_px: float,
	px: float,
	tex: Texture2D,
	tint: Color,
	alpha: float,
	is_player: bool,
	pose: RealtimeUnitMotion.Pose = null,
	walk: Vector2 = Vector2.ZERO,
	footprint_span: float = 1.0,
	idle_seed: int = -1,
) -> void:
	var h_cap := px * 1.9
	if footprint_span >= 1.5:
		h_cap = px * minf(2.6, footprint_span * 1.15)
	var h := clampf(half_height_px * SPRITE_HEIGHT_MUL, px * 1.05, h_cap)
	var tex_size := tex.get_size()
	var w := h * tex_size.x / maxf(1.0, tex_size.y)
	## 贴纸 sheet 剪影偏方/偏宽：限制占格宽度，超限时等比缩小，避免压住邻格。
	var max_w := px * (
		SPRITE_MAX_WIDTH_CELLS_FOOTPRINT if footprint_span >= 1.5 else SPRITE_MAX_WIDTH_CELLS
	)
	if w > max_w and w > 0.0:
		var shrink := max_w / w
		w = max_w
		h *= shrink
	## 2×2：贴图中心对齐足迹几何中心；1×1：脚底略低于格心。
	var feet := (
		center + Vector2(0.0, h * 0.5)
		if footprint_span >= 1.5
		else center + Vector2(0.0, px * 0.38)
	)
	var offset := Vector2(0.0, walk.y * px)
	var rot := walk.x
	var scl := Vector2.ONE
	var flash := 0.0
	var a := alpha
	if pose != null:
		offset += (pose.offset + pose.idle_offset) * px
		rot += pose.rotation
		scl = pose.scale * pose.idle_scale
		flash = pose.flash
		a *= pose.alpha
	elif idle_seed >= 0:
		var idle: Dictionary = RealtimeUnitMotion.sample_idle(_fx_clock, idle_seed)
		offset += (idle.get("offset", Vector2.ZERO) as Vector2) * px
		scl = idle.get("scale", Vector2.ONE) as Vector2
	## 长按信息卡焦点：小丑牌式抬起 / 倾斜；非焦点略压暗。
	var inspect_v := _sample_inspect_visual(center)
	var shadow_mul := 1.0
	if not inspect_v.is_empty():
		offset += (inspect_v.get("offset", Vector2.ZERO) as Vector2) * px
		rot += float(inspect_v.get("rotation", 0.0))
		scl *= inspect_v.get("scale", Vector2.ONE) as Vector2
		a *= float(inspect_v.get("alpha", 1.0))
		shadow_mul = float(inspect_v.get("shadow_mul", 1.0))
	var shadow := Color(CONTACT_SHADOW, CONTACT_SHADOW.a * a * clampf(shadow_mul, 0.4, 2.2))
	var shadow_pos := feet + Vector2(
		offset.x + px * 0.06,
		px * 0.02 + maxf(0.0, offset.y) + px * 0.04 * maxf(0.0, shadow_mul - 1.0),
	)
	var shadow_rx := w * 0.30 * scl.x * (0.85 + 0.2 * shadow_mul)
	_draw_ellipse_filled(shadow_pos, shadow_rx, maxf(2.0, px * 0.12 * shadow_mul), shadow)
	var base := PLAYER_COLOR if is_player else ENEMY_COLOR
	var lift := 1.0 + clampf(tint.get_luminance() - base.get_luminance(), 0.0, 0.5)
	var modulate_color := Color(lift, lift, lift, a).lerp(
		Color(SPRITE_FLASH_MUL, SPRITE_FLASH_MUL, SPRITE_FLASH_MUL, a), clampf(flash, 0.0, 1.0)
	)
	draw_set_transform(_frame_shake + feet + offset, rot, scl)
	draw_texture_rect(tex, Rect2(-w * 0.5, -h, w, h), false, modulate_color)
	draw_set_transform(_frame_shake)


func _rt_unit_id(rt: RtUnit) -> String:
	if rt == null or rt.unit == null or rt.unit.unit_data == null:
		return ""
	return rt.unit.unit_data.id


## 准备/招募待机相位种子：同兵种不同席位错开呼吸。
func _idle_seed_for(unit_id: String, slot: int) -> int:
	return absi(unit_id.hash() + slot * 31)


func _resolve_visual_half(explicit: float, body_radius: float, fallback_mul: float) -> float:
	var scale := get_unit_visual_scale()
	if explicit > 0.0:
		return explicit * scale
	return maxf(0.05, body_radius * fallback_mul * scale)


func _draw_ellipse_filled(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in ELLIPSE_SEGMENTS:
		var a := TAU * float(i) / float(ELLIPSE_SEGMENTS)
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(points, color)


func _draw_ellipse_outline(center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in ELLIPSE_SEGMENTS + 1:
		var a := TAU * float(i) / float(ELLIPSE_SEGMENTS)
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(points, color, width, true)


## 攻血标尺寸：只随格子尺寸变化，与兵种剪影、数值位数无关。
func get_stat_badge_size(px: float) -> Vector2:
	var h := clampf(px * STAT_BADGE_HEIGHT_MUL, STAT_BADGE_MIN_HEIGHT, STAT_BADGE_MAX_HEIGHT)
	var tex_size := STAT_ATTACK_TEX.get_size()
	return Vector2(h * tex_size.x / maxf(1.0, tex_size.y), h)


## 脚下居中一对纸片标签：左攻击（剑）、右生命（心）。
func _draw_stat_badges(center: Vector2, attack: int, hp: int, alpha: float, px: float) -> void:
	var badge := get_stat_badge_size(px)
	var gap := badge.y * 0.06
	var top := center.y + px * 0.38 + badge.y * 0.05
	var half_pair := badge.x + gap * 0.5
	var cx := clampf(center.x, half_pair, maxf(half_pair, size.x - half_pair))
	var atk_rect := Rect2(Vector2(cx - half_pair, top), badge)
	var hp_rect := Rect2(Vector2(cx + gap * 0.5, top), badge)
	_draw_stat_badge(atk_rect, STAT_ATTACK_TEX, attack, alpha)
	_draw_stat_badge(hp_rect, STAT_HP_TEX, hp, alpha)


func _draw_stat_badge(rect: Rect2, tex: Texture2D, value: int, alpha: float) -> void:
	draw_texture_rect(tex, rect, false, Color(1, 1, 1, alpha))
	var text := str(maxi(0, value))
	var font_size := maxi(8, int(rect.size.y * 0.62))
	var max_w := rect.size.x * STAT_NUMBER_MAX_WIDTH
	var text_w := STAT_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if text_w > max_w:
		font_size = maxi(6, int(font_size * max_w / text_w))
		text_w = STAT_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var ascent := STAT_FONT.get_ascent(font_size)
	var descent := STAT_FONT.get_descent(font_size)
	var baseline := Vector2(
		rect.position.x + rect.size.x * STAT_NUMBER_CENTER_X - text_w * 0.5,
		rect.position.y + rect.size.y * 0.5 + (ascent - descent) * 0.5,
	)
	draw_string(
		STAT_FONT, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(STAT_TEXT, STAT_TEXT.a * alpha),
	)


func _draw_projectiles(px: float) -> void:
	for item in sim.get_projectiles():
		var proj := item as RtProjectile
		var color := Color(0.85, 0.95, 1.0) if proj.is_player_owned() else Color(1.0, 0.85, 0.6)
		draw_circle(tile_to_local(proj.position), maxf(2.5, 0.12 * px), color)


func _draw_fx(px: float) -> void:
	for fx in _fx:
		var kind := String(fx.get("kind", ""))
		var life := CALLOUT_SECONDS if kind == "callout" else FX_SECONDS
		var t := clampf((_fx_clock - float(fx["t0"])) / life, 0.0, 1.0)
		var center := tile_to_local(fx["center"])
		var r_px := float(fx["radius"]) * px
		if kind == "splash":
			draw_circle(center, r_px, Color(1.0, 0.9, 0.5, 0.35 * (1.0 - t)))
			draw_arc(center, r_px, 0.0, TAU, 32, Color(1.0, 0.85, 0.4, 0.8 * (1.0 - t)), 2.0)
		elif kind == "callout":
			var callout_c := PLAYER_COLOR if bool(fx.get("player", true)) else ENEMY_COLOR
			draw_arc(center, r_px * (1.0 + t * 0.35), 0.0, TAU, 28, Color(callout_c, 0.9 * (1.0 - t)), 2.5)
			draw_circle(center, r_px * 0.35, Color(callout_c, 0.22 * (1.0 - t)))
			var callout_text := String(fx.get("text", ""))
			if not callout_text.is_empty():
				var font := get_theme_default_font()
				_draw_feedback_string(
					font,
					center + Vector2(0.0, -r_px - 6.0),
					callout_text,
					12,
					Color(0.95, 0.98, 1.0, 0.95 * (1.0 - t)),
				)
		else:
			var color := PLAYER_COLOR if bool(fx["player"]) else ENEMY_COLOR
			draw_arc(center, r_px * (1.0 + t), 0.0, TAU, 24, Color(color, 0.8 * (1.0 - t)), 2.0)


func _draw_feedback(px: float) -> void:
	if _feedback.is_empty():
		return
	var font := get_theme_default_font()
	for fb in _feedback:
		var life := float(fb["duration"])
		if life <= 0.0:
			continue
		var t := clampf((_fx_clock - float(fb["t0"])) / life, 0.0, 1.0)
		var is_player := bool(fb["player"])
		## 友方优先可读：字号更大、更不透明；敌方保下限。
		var base_size := 16 if is_player else 13
		var alpha := (1.0 - t * 0.85) * (1.0 if is_player else 0.78)
		var float_y := -FEEDBACK_FLOAT_TILES * px * t
		var center := tile_to_local(fb["center"]) + Vector2(0.0, float_y - px * 0.35)
		var kind: StringName = fb["kind"]
		var color := _feedback_color(kind, is_player)
		color.a = alpha
		var main_text := String(fb["text"])
		var tip := String(fb.get("tip", ""))
		if not main_text.is_empty():
			var font_size := base_size + (2 if kind == RealtimeEffectFeedback.KIND_STAT else 0)
			_draw_feedback_string(font, center, main_text, font_size, color)
			center.y -= float(font_size) + 2.0
		if not tip.is_empty():
			var tip_color := Color(0.92, 0.95, 1.0, alpha * 0.9)
			_draw_feedback_string(font, center, tip, maxi(10, base_size - 3), tip_color)


func _feedback_color(kind: StringName, is_player: bool) -> Color:
	match kind:
		RealtimeEffectFeedback.KIND_DAMAGE:
			return Color(1.0, 0.42, 0.32) if is_player else Color(1.0, 0.55, 0.40)
		RealtimeEffectFeedback.KIND_HEAL:
			return Color(0.40, 0.95, 0.55)
		RealtimeEffectFeedback.KIND_STAT:
			return Color(1.0, 0.88, 0.35)
		_:
			return Color(0.88, 0.94, 1.0)


func _draw_feedback_string(
	font: Font,
	center: Vector2,
	text: String,
	font_size: int,
	color: Color,
) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center + Vector2(
		-text_size.x * 0.5,
		font.get_ascent(font_size) * 0.5 - font.get_descent(font_size) * 0.25,
	)
	## 描边：形/字双通道，不完全靠颜色。
	var outline := Color(0.05, 0.05, 0.08, color.a * 0.85)
	for ox in [-1.0, 0.0, 1.0]:
		for oy in [-1.0, 0.0, 1.0]:
			if ox == 0.0 and oy == 0.0:
				continue
			draw_string(
				font, baseline + Vector2(ox, oy), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline,
			)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_ghost(px: float, mid: int) -> void:
	var cell := _hover_cell
	var center_tile := Vector2(cell) + Vector2(0.5, 0.5)
	var radius := _drag_radius if _drag_active else ghost_radius
	var vwx := _drag_visual_half_width if _drag_active else ghost_visual_half_width
	var vhy := _drag_visual_half_height if _drag_active else ghost_visual_half_height
	var label := _drag_label if _drag_active else ghost_label
	var cell_rect := Rect2(get_board_rect().position + Vector2(cell) * px, Vector2(px, px))
	if cell.y < mid:
		draw_rect(cell_rect, Color(1.0, 0.2, 0.2, 0.35))
		var center := tile_to_local(center_tile)
		var d := px * 0.3
		draw_line(center - Vector2(d, d), center + Vector2(d, d), Color(1, 1, 1, 0.9), 2.0)
		draw_line(center + Vector2(-d, d), center + Vector2(d, -d), Color(1, 1, 1, 0.9), 2.0)
		return
	draw_rect(cell_rect, Color(1, 1, 1, 0.25))
	var uid := _drag_unit_id if _drag_active else ghost_unit_id
	_draw_body(center_tile, radius, vwx, vhy, PLAYER_COLOR, 0.45, label, px, true, Vector2.ZERO, true, uid)
