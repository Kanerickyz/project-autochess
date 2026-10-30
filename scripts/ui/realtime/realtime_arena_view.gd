class_name RealtimeArenaView
extends Control
## 实时战场绘制：林间空地背景、半场色调、中线、投放高亮/虚影、角色贴图、
## 底部攻/血色块标（参考小动物自走棋）、血条、部署弧、投射物与溅射圈。
## 只读 RealtimeCombatSim 状态，不参与逻辑。剪影可大于碰撞圆（脚小身大）。

signal board_pressed(tile_pos: Vector2)
signal card_dropped(entry_id: int, tile_pos: Vector2)
## 招募：候选人拖放到上半场；replace_entry_id≥0 为替换（仅点选路径会发）；seat_index≥0 为指定空座。
signal recruit_drop(candidate_index: int, replace_entry_id: int, seat_index: int)
## 招募：候选人拖到非法落点（如已占座）；reason 如 occupied_seat。
signal recruit_drop_rejected(reason: StringName)
signal recruit_candidate_pressed(candidate_index: int)
signal recruit_team_pressed(entry_id: int)
## 招募：上区队伍成员拖到出售落点松手。
signal recruit_sell(entry_id: int)
## 招募：下区候选人拖到锁定落点松手（切换锁定）。
signal recruit_candidate_lock(candidate_index: int)
## 招募：上区成员拖到空座或另一成员座位换座。
signal recruit_team_seat_drop(entry_id: int, target_seat: int)
## 招募：点上区空座（备战选中后上阵用）。
signal recruit_empty_seat_pressed(seat_index: int)
## 招募道具行：点击道具槽。
signal recruit_item_pressed(item_slot: int)
## 招募道具行：药水拖到上区队伍成员。
signal recruit_item_drop(item_slot: int, entry_id: int)
## 附魔：队伍成员拖到时机格 A / 效果格 B。
signal enchant_forge_drop(entry_id: int, slot: StringName)
## 附魔：下半场队伍换座（与招募上区同规则）。
signal enchant_team_seat_drop(entry_id: int, target_seat: int)
## 地图商店：货架拖到上半场角色；kind = consumable | equipment。
signal map_shop_offer_drop(kind: StringName, slot_index: int, entry_id: int)
## 地图商店：上区队伍换座。
signal map_shop_team_seat_drop(entry_id: int, target_seat: int)
## 准备阶段：拖已入座角色到空座或另一座位换座（写回由控制器处理）。
signal prepare_team_seat_drop(entry_id: int, target_seat: int)
## 准备：拖已入座角色松手落在备战格。
signal prepare_team_bench_drop(entry_id: int, bench_slot: int)
## 招募：拖上区/备战成员松手落在备战格（或未落座时由控制器兼容）。
signal recruit_team_bench_drop(entry_id: int, bench_slot: int)
## 点备战已占格（选中 / 药水等）。
signal bench_pressed(entry_id: int)
## 点备战空格（接收已选入座角色下阵）。
signal bench_empty_pressed(slot_index: int)

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
## 招募道具图集 3×2、每格 256、间距与偏移都是 0。墨线大约落在 y=31..225。
## 1 = 跟角色同一绘制框。格内留白会让道具比紧裁角色略小一圈。
const RECRUIT_PROP_SPRITE_SCALE := 1.0
const RECRUIT_PROP_CONTENT_BOTTOM := 225.0 / 256.0
const RECRUIT_TEX_HP := preload("res://resources/recruit_shop/icons/hp_potion_icon.tres")
const RECRUIT_TEX_ATK := preload("res://resources/recruit_shop/icons/atk_potion_icon.tres")
const RECRUIT_TEX_LOCK := preload("res://resources/recruit_shop/icons/lock_icon.tres")
const RECRUIT_TEX_SELL := preload("res://resources/recruit_shop/icons/sell_icon.tres")
const RECRUIT_TEX_BANNER := preload("res://resources/recruit_shop/icons/banner_icon.tres")
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
const STAT_GOLD_TEX := preload("res://assets/sprites/paper_cutout/ui/stat_gold.png")
## 技能产金反馈：金币纸片（显示边长 = 典型角色纸片高度的 1/4）。
const FX_GOLD_COIN_TEX := preload("res://assets/sprites/paper_cutout/ui/fx_gold_coin.png")
const GOLD_COIN_PAPER_SCALE := 0.25
const GOLD_COIN_MAX_BURST := 5
## 掉落落地：抛出 → 落地弹动 → 随机左右滑移 → 久留 → 淡出（不旋转）。
const GOLD_COIN_THROW_SEC := 0.18
const GOLD_COIN_FALL_SEC := 0.32
const GOLD_COIN_BOUNCE_SEC := 0.22
const GOLD_COIN_SLIDE_SEC := 0.28
const GOLD_COIN_LINGER_SEC := 2.2
const GOLD_COIN_FADE_SEC := 0.65
## 落地后左右滑移距离（相对格子边长）。
const GOLD_COIN_SLIDE_TILE_MIN := 0.18
const GOLD_COIN_SLIDE_TILE_MAX := 0.42
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
## 附魔试验场左右滑条：伸进棋盘内缘（勿盖住边列中心）+ 伸出到树带留白，方便两边跟手滚。
const ENCHANT_SCROLL_SIDE_INNER_TILES := 0.35
const ENCHANT_SCROLL_SIDE_OUTER_TILES := 1.25
## 拖角色：小丑牌式抬起 / 速度倾斜 / 落座（采样见 RealtimeUnitMotion.sample_drag_hold）。
const DRAG_PICKUP_SEC := RealtimeUnitMotion.DRAG_PICKUP_SEC
const DRAG_SETTLE_SEC := 0.2
const DRAG_FOLLOW_RATE := 18.0
const DRAG_SCALE := RealtimeUnitMotion.DRAG_SCALE
const DRAG_VELOCITY_SMOOTH := 14.0
const DRAG_SOURCE_ALPHA := 0.32
## 招募候选人货架卡壳（旧纸包装）：统一尺寸；shader 噪声逐步溶解（非整卡透明度）。
const RECRUIT_CARD_DISSOLVE_SEC := 0.42
const RECRUIT_CARD_RESTORE_SEC := 0.32
const RECRUIT_CARD_W_CELLS := 0.90
const RECRUIT_CARD_H_CELLS := 1.30
const RECRUIT_CARD_SLOT_CAP := 5
const RECRUIT_CARD_SHADER: Shader = preload("res://assets/ui/recruit/recruit_card_dissolve.gdshader")
const RECRUIT_CARD_FILL := Color(0.93, 0.86, 0.68, 0.94)
const RECRUIT_CARD_FILL_INNER := Color(0.97, 0.92, 0.78, 0.55)
const RECRUIT_CARD_STROKE := Color(0.38, 0.24, 0.12, 0.96)
const RECRUIT_CARD_BURN := Color(1.0, 0.52, 0.14, 1.0)
## 三合一合成演出：残影飞入 → 合成体弹跳闪白 + 星标。
const MERGE_FLY_SEC := 0.28
const MERGE_POP_SEC := 0.42

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
## 备战区：准备/战斗在棋盘底边下方；招募时在 midline 中缝（队伍与招募半场之间）。
var bench_slots: PrepareSlotBoard
## 准备/战斗/招募显示备战行；附魔/商店/目录关闭。
var bench_visible: bool = false
## 准备/招募可拖；战斗只读（长按信息仍可）。
var bench_interactive: bool = false
## 备战 entry_id → true：队伍内同角色同星已满 2，再买即三合一。
var bench_triple_merge_hint_entry_ids: Dictionary = {}
## 备战行与棋盘底边的空隙（逻辑格；仅棋盘外备战）。
const BENCH_GAP_TILES := 0.25
const BENCH_ROW_TILES := 1.0
## 战斗加速倍率：缩短反馈 / 时停表现寿命；是否暂停模拟由控制器时停队列决定。
var presentation_time_scale: float = 1.0
## 胜后半场退出/招募进入：上半场 / 下半场像素位移（由控制器 Tween）。
## 草地与外框不随位移；仅半场色调与单位/座位内容滑动。
var enemy_half_slide_y: float = 0.0
var ally_half_slide_y: float = 0.0
## 开战后备战行向下移出屏（准备/战斗棋盘外一行；与半场 slide 独立）。
var bench_slide_y: float = 0.0
## 招募模式：上半场画队伍、下半场画候选人（不走战斗 sim）。
var recruit_active: bool = false
## 地图商店：上半场队伍、下半场消耗品+装备货架（与招募分区一致）。
var map_shop_active: bool = false
## Array[Dictionary]：{index, kind, item, cell, cost?, affordable?, label?, summary?}
var map_shop_offers: Array = []
## 附魔：上炉下队；上半场熔炉三格，下半场队伍座位。
var enchant_active: bool = false
var enchant_forge_previews: Array = []
## 友方队伍区纵向滚动（行）；试验场单位过多时启用。
var enchant_team_scroll_rows: float = 0.0
var enchant_team_scroll_enabled: bool = false
var enchant_team_max_scroll_rows: float = 0.0
## 角色库模式：整盘铺单位剪影，长按弹技能卡（不走战斗 / 招募）。
var catalog_active: bool = false
## true：不画竞技场背景/半场色调，只铺角色格（远征统计卡牌条）。
var catalog_plain_backdrop: bool = false
## >0 时覆盖 get_unit_visual_scale（远征统计等窄条目录用，避免缩略棋盘放大剪影）。
var catalog_visual_scale_override: float = -1.0
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
## 非单位拖影贴图（地图商店货架物品纸片）；有值时优先于 unit_id 查表。
var _drag_texture: Texture2D = null
## 拖影 Pose：跟手时由 sample_drag_hold 驱动；落座用 Tween 弹性回正。
var _drag_pose: RealtimeUnitMotion.Pose = RealtimeUnitMotion.Pose.new()
var _drag_tween: Tween
var _drag_pointer := Vector2.ZERO
var _drag_draw_pos := Vector2.ZERO
var _drag_visual_alive: bool = false
var _drag_settling: bool = false
var _drag_started_at: float = -1.0
var _drag_last_pointer := Vector2.ZERO
var _drag_velocity_tiles := Vector2.ZERO
var _art: UnitArtCatalog = UnitArtCatalog.load_default()
var _fx: Array = []
var _fx_clock: float = 0.0
## Array[Dictionary]：技能结果数字 / 短提示
var _feedback: Array = []
var _recruit_drag_index: int = -1
var _recruit_press_index: int = -1
## 候选人拖出：源格、是否已离格溶解、溶解进度（0完整→1消失）、失败回席后再现。
var _recruit_drag_source_cell: Vector2i = NO_CELL
var _recruit_left_source: bool = false
var _recruit_shell_progress: float = 0.0
var _recruit_shell_tween: Tween
var _recruit_restore_index: int = -1
var _recruit_card_shells: Array[ColorRect] = []
var _recruit_card_mats: Array[ShaderMaterial] = []
## 跟手溶解卡：离格后卡壳跟着角色碎掉，播完只剩纸片。
var _recruit_follow_shell: ColorRect
var _recruit_follow_mat: ShaderMaterial
var _recruit_item_drag_index: int = -1
var _recruit_item_press_index: int = -1
var _recruit_team_drag_id: int = -1
var _enchant_team_drag_id: int = -1
var _enchant_team_press_id: int = -1
var _enchant_team_pan_active: bool = false
var _enchant_team_pan_last_y: float = 0.0
var _enchant_forge_press: bool = false
var _recruit_team_press_id: int = -1
var _recruit_empty_seat_press: int = -1
var _party_speech_bubble: PartySpeechBubble
## 产金反馈金币层（TextureRect + Tween；clear_fx 时清空）。
var _gold_coin_layer: Control
## 地图商店货架拖拽：map_shop_offers 数组下标。
var _map_shop_offer_drag_index: int = -1
var _map_shop_offer_press_index: int = -1
var _map_shop_team_drag_id: int = -1
var _map_shop_team_press_id: int = -1
## 准备阶段座位拖换：按住已入座角色拖到目标座。
var _prepare_team_drag_id: int = -1
var _prepare_team_press_id: int = -1
## 备战格按下（可与准备/招募拖共用 drag id）。
var _bench_press_id: int = -1
var _bench_empty_press: int = -1
var _motion := RealtimeUnitMotion.new()
var _frame_shake := Vector2.ZERO
var _info_card := RealtimeUnitInfoCard.new()
## 主卡下方的附属信息卡（装备等）；顺序与 info.attachments 一致。
var _info_attachment_cards: Array[RealtimeUnitInfoCard] = []
const INFO_ATTACHMENT_GAP_PX := 8.0
var _press_active := false
var _press_pos := Vector2.ZERO
var _press_ms: int = -1
var _press_info: Dictionary = {}
var _press_tap: Callable
## 三合一演出态（招募上区）；由 play_triple_merge_animation 驱动。
var _merge_active: bool = false
var _merge_tween: Tween
var _merge_survivor_seat: int = -1
var _merge_unit_id: String = ""
var _merge_level: int = 1
## Array[Dictionary]：{from: Vector2i, to: Vector2i, t: float}
var _merge_ghosts: Array = []
var _merge_survivor_scale: float = 1.0
var _merge_survivor_flash: float = 0.0
var _merge_ring: float = 0.0
var _merge_label_alpha: float = 0.0
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
## 战斗技能播报期间禁止 SKILL_INFO 定时收卡（见 RealtimeBattleController）。
var _combat_skill_info_pin: int = 0
## 观战技能播报卡（触发者脚下向下）；与长按 _info_shown 分离，但仍复用焦点抬起/压暗。
var _combat_broadcast_info := false
const SKILL_INFO_SECONDS := 1.35

## 战场与商店不再铺半透明格和线框。角色库仍用卡牌底板；出售/锁定只在拖到格子上时加高亮。
const RECRUIT_CAND_EMPTY := Color(0.95, 0.78, 0.35, 0.28)
const RECRUIT_CAND_BORDER := Color(1.0, 0.92, 0.45, 0.95)
const RECRUIT_SELL_HOT := Color(0.85, 0.35, 0.75, 0.45)
const RECRUIT_LOCK_HOT := Color(0.95, 0.80, 0.30, 0.45)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)
	_motion.name = "UnitMotion"
	add_child(_motion)
	_info_card.name = "UnitInfoCard"
	add_child(_info_card)
	_ensure_recruit_card_shells()


func _process(delta: float) -> void:
	_fx_clock += delta
	if _drag_visual_alive and not _drag_settling:
		_update_drag_hold_pose(delta)
	if sim != null and sim.has_started():
		_motion.speed_scale = presentation_time_scale
		_motion.sync_units(sim.get_units(), sim.get_current_actor())
	if _press_ms >= 0 and not _info_shown and Time.get_ticks_msec() - _press_ms >= LONG_PRESS_MS:
		_show_info_card(_press_info)
	if _combat_skill_info_pin <= 0 and _auto_info_until_clock >= 0.0 and _fx_clock >= _auto_info_until_clock:
		if not _press_active:
			_hide_all_info_cards()
			_info_shown = false
			_combat_broadcast_info = false
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
		_reset_recruit_card_dissolve()
		_recruit_item_drag_index = -1
		_recruit_item_press_index = -1
		_recruit_team_drag_id = -1
		_recruit_team_press_id = -1
		_recruit_empty_seat_press = -1
		_map_shop_offer_drag_index = -1
		_map_shop_offer_press_index = -1
		_map_shop_team_drag_id = -1
		_map_shop_team_press_id = -1
		_prepare_team_drag_id = -1
		_prepare_team_press_id = -1
		_bench_press_id = -1
		_bench_empty_press = -1
		_finish_drag_visual(_hover_cell)
		_hover_cell = NO_CELL
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover_cell = NO_CELL


# --- 公开接口 ---


func _bench_layout_tiles() -> float:
	if not bench_visible:
		return 0.0
	## 招募备战在棋盘内中缝，不另占棋盘外高度。
	if recruit_active:
		return 0.0
	return BENCH_GAP_TILES + BENCH_ROW_TILES


func get_cell_px() -> float:
	if board_size.x <= 0 or board_size.y <= 0:
		return 1.0
	var content_rows := float(board_size.y) + _bench_layout_tiles()
	## 纯角色目录：铺满控件，不留背景树带边距（与角色库体量一致）。
	if catalog_active and catalog_plain_backdrop:
		return maxf(1.0, minf(size.x / float(board_size.x), size.y / content_rows))
	var bg := _get_background_rect()
	var gutter := maxf(0.0, bg.position.x + bg.size.x * BACKGROUND_TREE_BAND * (1.0 - BOARD_TREE_OVERLAP))
	var avail_x := maxf(1.0, size.x - gutter * 2.0)
	return maxf(1.0, minf(avail_x / board_size.x, size.y / content_rows))


## 列/行变少时放大角色表现（碰撞仍以逻辑格为准）；再收 20% 避免邻格剪影互盖。
func get_unit_visual_scale() -> float:
	if catalog_active and catalog_visual_scale_override > 0.0:
		return catalog_visual_scale_override
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
	var bench_h := _bench_layout_tiles() * px
	var total := Vector2(board_px.x, board_px.y + bench_h)
	var origin := (size - total) * 0.5
	## 棋盘在内容区顶部；准备/战斗备战行画在 board 底边下方。
	return Rect2(origin, board_px)


## 备战格中心本地坐标。招募：逻辑格中心（midline）；准备/战斗：棋盘外虚拟行。
func bench_slot_center_local(slot_index: int) -> Vector2:
	if bench_slots == null or slot_index < 0 or slot_index >= bench_slots.cells.size():
		return Vector2.ZERO
	var cell := bench_slots.cells[slot_index]
	var px := get_cell_px()
	## 棋盘内备战（招募中缝）：与座位同口径的格心。
	if cell.y < board_size.y:
		return tile_to_local(Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5)) + Vector2(0.0, bench_slide_y)
	var gap := BENCH_GAP_TILES * px if bench_visible else 0.0
	return (
		get_board_rect().position
		+ Vector2(float(cell.x) + 0.5, float(board_size.y)) * px
		+ Vector2(0.0, gap + px * 0.5)
		+ Vector2(0.0, bench_slide_y)
	)


func local_to_tile(local_pos: Vector2) -> Vector2:
	var rect := get_board_rect()
	return (local_pos - rect.position) / get_cell_px()


func tile_to_local(tile_pos: Vector2) -> Vector2:
	return get_board_rect().position + tile_pos * get_cell_px()


func find_bench_slot_at_local(local_pos: Vector2) -> int:
	if not bench_visible or bench_slots == null:
		return -1
	var px := get_cell_px()
	var best := -1
	var best_d := INF
	for i in bench_slots.cells.size():
		var center := bench_slot_center_local(i)
		var hit := Rect2(center.x - px * 0.5, center.y - px * 0.5, px, px)
		if not hit.has_point(local_pos):
			continue
		var d := local_pos.distance_squared_to(center)
		if d < best_d:
			best_d = d
			best = i
	return best


func find_bench_slot_at_cell(cell: Vector2i) -> int:
	if not bench_visible or bench_slots == null or cell == NO_CELL:
		return -1
	return bench_slots.find_slot_at_cell(cell)


func find_bench_entry_at_local(local_pos: Vector2) -> int:
	var slot_i := find_bench_slot_at_local(local_pos)
	if slot_i < 0 or bench_slots == null:
		return -1
	var entry := bench_slots.get_entry(slot_i)
	if entry == null:
		return -1
	return entry.entry_id


func is_pointer_over_bench(local_pos: Vector2 = Vector2.INF) -> bool:
	var pos := local_pos
	if pos == Vector2.INF:
		pos = get_local_mouse_position()
	return find_bench_slot_at_local(pos) >= 0


## 招募上区队伍成员纸片中心（本地坐标，含半场 slide）；找不到返回零向量且 ok=false。
func get_recruit_team_unit_tip(unit_id: String) -> Dictionary:
	var result := {"ok": false, "tip": Vector2.ZERO}
	if not recruit_active or recruit_team_slots == null or unit_id.is_empty():
		return result
	var enemy_off := Vector2(0.0, enemy_half_slide_y)
	for i in recruit_team_slots.cells.size():
		var entry := recruit_team_slots.get_entry(i)
		if entry == null or entry.unit == null:
			continue
		if String(entry.unit.id) != unit_id:
			continue
		var tile := Vector2(recruit_team_slots.cells[i]) + Vector2(0.5, 0.5)
		var center := tile_to_local(tile) + enemy_off
		## 尖角对准纸片上沿略上方。
		var tip := center + Vector2(0.0, -get_cell_px() * 0.55)
		result["ok"] = true
		result["tip"] = tip
		return result
	return result


func show_party_bark(unit_id: String, text: String) -> void:
	if text.is_empty():
		return
	var tip_info := get_recruit_team_unit_tip(unit_id)
	if not bool(tip_info.get("ok", false)):
		return
	var bubble := _ensure_party_speech_bubble()
	bubble.present_at(tip_info["tip"] as Vector2, text)


func clear_party_bark() -> void:
	if _party_speech_bubble != null:
		_party_speech_bubble.dismiss()


func is_merge_animating() -> bool:
	return _merge_active


## 三合一反馈：原料残影飞向合成座 → 合成体弹跳闪白并弹出星标。
## survivor_seat / source_seats 为 PrepareSlotBoard 下标；座位几何取自 recruit_team_slots。
func play_triple_merge_animation(
	survivor_seat: int,
	source_seats: Array,
	unit_id: String,
	new_level: int,
) -> void:
	clear_merge_fx()
	if recruit_team_slots == null or recruit_team_slots.cells.is_empty():
		return
	if survivor_seat < 0 or survivor_seat >= recruit_team_slots.cells.size():
		return
	_merge_active = true
	_merge_survivor_seat = survivor_seat
	_merge_unit_id = unit_id
	_merge_level = clampi(new_level, 1, 3)
	_merge_survivor_scale = 0.28
	_merge_survivor_flash = 0.0
	_merge_ring = 0.0
	_merge_label_alpha = 0.0
	_merge_ghosts.clear()
	var dest: Vector2i = recruit_team_slots.cells[survivor_seat]
	for seat_v in source_seats:
		var seat := int(seat_v)
		if seat < 0 or seat == survivor_seat:
			continue
		if seat >= recruit_team_slots.cells.size():
			continue
		_merge_ghosts.append({
			"from": recruit_team_slots.cells[seat],
			"to": dest,
			"t": 0.0,
		})
	_merge_tween = create_tween()
	_merge_tween.set_parallel(true)
	for i in _merge_ghosts.size():
		var idx := i
		_merge_tween.tween_method(
			func(v: float) -> void:
				if idx >= 0 and idx < _merge_ghosts.size():
					_merge_ghosts[idx]["t"] = v
				queue_redraw(),
			0.0,
			1.0,
			MERGE_FLY_SEC,
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_merge_tween.set_parallel(false)
	_merge_tween.tween_property(self, "_merge_survivor_scale", 1.32, MERGE_POP_SEC * 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_merge_tween.parallel().tween_property(self, "_merge_survivor_flash", 1.0, MERGE_POP_SEC * 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_merge_tween.parallel().tween_property(self, "_merge_ring", 1.0, MERGE_POP_SEC * 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_merge_tween.parallel().tween_property(self, "_merge_label_alpha", 1.0, MERGE_POP_SEC * 0.25)
	_merge_tween.tween_property(self, "_merge_survivor_scale", 1.0, MERGE_POP_SEC * 0.55) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_merge_tween.parallel().tween_property(self, "_merge_survivor_flash", 0.0, MERGE_POP_SEC * 0.4)
	_merge_tween.parallel().tween_property(self, "_merge_label_alpha", 0.0, MERGE_POP_SEC * 0.45) \
		.set_delay(MERGE_POP_SEC * 0.2)
	_merge_tween.parallel().tween_property(self, "_merge_ring", 0.0, MERGE_POP_SEC * 0.35) \
		.set_delay(MERGE_POP_SEC * 0.2)
	await _merge_tween.finished
	clear_merge_fx()


func clear_merge_fx() -> void:
	if _merge_tween != null and _merge_tween.is_valid():
		_merge_tween.kill()
	_merge_tween = null
	_merge_active = false
	_merge_survivor_seat = -1
	_merge_unit_id = ""
	_merge_level = 1
	_merge_ghosts.clear()
	_merge_survivor_scale = 1.0
	_merge_survivor_flash = 0.0
	_merge_ring = 0.0
	_merge_label_alpha = 0.0
	queue_redraw()


func _ensure_party_speech_bubble() -> PartySpeechBubble:
	if _party_speech_bubble != null and is_instance_valid(_party_speech_bubble):
		return _party_speech_bubble
	_party_speech_bubble = PartySpeechBubble.new()
	_party_speech_bubble.name = "PartySpeechBubble"
	add_child(_party_speech_bubble)
	return _party_speech_bubble


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


## 技能因果反馈：kind=damage/heal/stat/label/gold；同单位短窗可合并。
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
			if (
				kind == RealtimeEffectFeedback.KIND_DAMAGE
				or kind == RealtimeEffectFeedback.KIND_HEAL
				or kind == RealtimeEffectFeedback.KIND_STAT
				or kind == RealtimeEffectFeedback.KIND_GOLD
			):
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


## 产金技能：在单位旁弹出金币纸片（边长 = 典型角色纸片高度 × 1/4）。
## Tween：抛出 → 落地压扁 → 弹起回正 → 随机左右滑移 → 久留淡出；全程不旋转。
func spawn_gold_coin_burst(center_tile: Vector2, amount: int) -> void:
	if FX_GOLD_COIN_TEX == null or amount <= 0:
		return
	var layer := _ensure_gold_coin_layer()
	var count := clampi(amount, 1, GOLD_COIN_MAX_BURST)
	var px := get_cell_px()
	var coin_px := _typical_paper_height_px(px) * GOLD_COIN_PAPER_SCALE
	var origin := tile_to_local(center_tile)
	var speed := maxf(0.25, presentation_time_scale)
	for i in count:
		var coin := TextureRect.new()
		coin.texture = FX_GOLD_COIN_TEX
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.size = Vector2(coin_px, coin_px)
		coin.pivot_offset = coin.size * 0.5
		## 从角色胸口附近抛出，落在脚下附近地面。
		var throw_offset := Vector2(
			randf_range(-0.18, 0.18) * px + float(i - count / 2.0) * px * 0.06,
			-randf_range(0.35, 0.55) * px,
		)
		var start_pos := origin - coin.pivot_offset + throw_offset
		var land_pos := origin - coin.pivot_offset + Vector2(
			randf_range(-0.55, 0.55) * px + float(i - count / 2.0) * px * 0.14,
			randf_range(0.28, 0.55) * px,
		)
		var apex_pos := Vector2(
			lerpf(start_pos.x, land_pos.x, 0.35),
			minf(start_pos.y, land_pos.y) - randf_range(0.22, 0.42) * px,
		)
		var bounce_height := randf_range(0.10, 0.18) * px
		var bounce_apex := land_pos + Vector2(0.0, -bounce_height)
		var slide_dir := -1.0 if randf() < 0.5 else 1.0
		var slide_dist := randf_range(GOLD_COIN_SLIDE_TILE_MIN, GOLD_COIN_SLIDE_TILE_MAX) * px
		var settle_pos := land_pos + Vector2(slide_dir * slide_dist, 0.0)
		coin.position = start_pos
		coin.scale = Vector2(0.55, 0.55)
		coin.rotation = 0.0
		coin.modulate = Color(1, 1, 1, 1)
		layer.add_child(coin)
		var tw := create_tween()
		tw.set_speed_scale(speed)
		## 抛起：放大 + 上弧（不转）。
		tw.set_parallel(true)
		tw.tween_property(coin, "position", apex_pos, GOLD_COIN_THROW_SEC) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(coin, "scale", Vector2(1.08, 1.08), GOLD_COIN_THROW_SEC) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.set_parallel(false)
		## 落地：加速下落 + 压扁。
		tw.set_parallel(true)
		tw.tween_property(coin, "position", land_pos, GOLD_COIN_FALL_SEC) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(coin, "scale", Vector2(1.18, 0.72), GOLD_COIN_FALL_SEC) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.set_parallel(false)
		## 弹动：弹起回正 → 再落回地面（Tween 弹感）。
		tw.set_parallel(true)
		tw.tween_property(coin, "position", bounce_apex, GOLD_COIN_BOUNCE_SEC * 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(coin, "scale", Vector2(0.92, 1.12), GOLD_COIN_BOUNCE_SEC * 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.set_parallel(false)
		tw.set_parallel(true)
		tw.tween_property(coin, "position", land_pos, GOLD_COIN_BOUNCE_SEC * 0.55) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(coin, "scale", Vector2.ONE, GOLD_COIN_BOUNCE_SEC * 0.55) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.set_parallel(false)
		## 落地弹动后随机左右滑移。
		tw.tween_property(coin, "position", settle_pos, GOLD_COIN_SLIDE_SEC) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		## 久留后淡出。
		tw.tween_interval(GOLD_COIN_LINGER_SEC)
		tw.tween_property(coin, "modulate:a", 0.0, GOLD_COIN_FADE_SEC) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(coin.queue_free)


func get_gold_coin_fx_count() -> int:
	if _gold_coin_layer == null or not is_instance_valid(_gold_coin_layer):
		return 0
	return _gold_coin_layer.get_child_count()


func _ensure_gold_coin_layer() -> Control:
	if _gold_coin_layer != null and is_instance_valid(_gold_coin_layer):
		return _gold_coin_layer
	_gold_coin_layer = Control.new()
	_gold_coin_layer.name = "GoldCoinFxLayer"
	_gold_coin_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gold_coin_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_gold_coin_layer)
	return _gold_coin_layer


## 典型单格角色纸片绘制高度（与 `_draw_unit_sprite` 同口径），供金币缩放对齐。
func _typical_paper_height_px(px: float) -> float:
	var half := _resolve_visual_half(0.0, 0.7, 1.6) * px
	return clampf(half * SPRITE_HEIGHT_MUL, px * 1.05, px * 1.9)


func get_feedback_count() -> int:
	return _feedback.size()


func get_feedback_entries() -> Array:
	return _feedback.duplicate()


func clear_fx() -> void:
	_fx.clear()
	_feedback.clear()
	_motion.clear()
	clear_merge_fx()
	_clear_gold_coin_fx()
	_cancel_press()


func _clear_gold_coin_fx() -> void:
	if _gold_coin_layer == null or not is_instance_valid(_gold_coin_layer):
		_gold_coin_layer = null
		return
	for child in _gold_coin_layer.get_children():
		child.queue_free()


## 出击 / 回位 action tween 是否仍在播（供控制器门控下一动；不含 idle/flash/残影）。
func has_active_combat_action_tween() -> bool:
	return _motion != null and _motion.has_active_action_tween()


## 「下一动」解卡：打断出击/回位 tween 并归零姿态，避免演出门闩永久挡住模拟。
func finish_combat_action_tweens() -> void:
	if _motion != null:
		_motion.force_home_all()


## 控制器在出手瞬间调用：立刻识别 last_attack 并开 strike tween（不等到本帧 _process）。
func sync_combat_motion_now() -> void:
	if _motion == null or sim == null or not sim.has_started():
		return
	_motion.speed_scale = presentation_time_scale
	_motion.sync_units(sim.get_units(), sim.get_current_actor())


## 死亡：侧倒淡出。淡出结束由运动层移除，不再绘制。
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
		RealtimeEffectFeedback.KIND_GOLD:
			return "+%d金" % amount
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
	if enchant_active:
		_gui_input_enchant(event)
		return
	if map_shop_active:
		_gui_input_map_shop(event)
		return
	if recruit_active:
		_gui_input_recruit(event)
		return
	## catalog_active 走与战斗相同的长按信息卡路径；准备阶段额外支持拖座位/备战。
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_hover_cell = tile_to_cell(local_to_tile(motion.position))
		_track_press_motion(motion.position)
		if _prepare_team_drag_id >= 0:
			_set_drag_pointer(motion.position)
			accept_event()
		elif (
			_can_drag_prepare_or_bench()
			and (_prepare_team_press_id >= 0 or _bench_press_id >= 0)
			and _prepare_team_drag_id < 0
			and not _info_shown
		):
			if motion.position.distance_to(_press_pos) > LONG_PRESS_SLOP_PX:
				var drag_id := _prepare_team_press_id if _prepare_team_press_id >= 0 else _bench_press_id
				_cancel_press()
				_begin_prepare_team_drag(drag_id, motion.position)
				accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			var info := inspect_at(mb.position)
			_prepare_team_press_id = -1
			_bench_press_id = -1
			_bench_empty_press = -1
			var bench_entry := find_bench_entry_at_local(mb.position) if bench_visible else -1
			var bench_slot := find_bench_slot_at_local(mb.position) if bench_visible else -1
			if bench_entry >= 0:
				## 战斗只读：仍可长按信息；准备/招募可拖与点选。
				_bench_press_id = bench_entry if bench_interactive else -1
				var bench_tap := (
					bench_pressed.emit.bind(bench_entry) if bench_interactive else Callable()
				)
				_begin_press(mb.position, info, bench_tap)
			elif (
				bench_interactive
				and bench_slot >= 0
				and bench_slots != null
				and bench_slots.is_empty(bench_slot)
			):
				_bench_empty_press = bench_slot
				accept_event()
				return
			elif not info.is_empty():
				## 按在单位上：点按动作推迟到松手，按住则改为看信息；移超 slop 则拖换座。
				if _can_prepare_seat_drag():
					var press_cell := tile_to_cell(local_to_tile(mb.position))
					var press_entry := _find_prepare_team_entry_at(press_cell)
					if press_entry >= 0:
						_prepare_team_press_id = press_entry
				_begin_press(mb.position, info, board_pressed.emit.bind(local_to_tile(mb.position)))
			else:
				board_pressed.emit(local_to_tile(mb.position))
			accept_event()
		else:
			var release_cell := tile_to_cell(local_to_tile(mb.position))
			if _prepare_team_drag_id >= 0:
				_finish_prepare_team_drag(release_cell, mb.position)
				accept_event()
				return
			if _bench_empty_press >= 0:
				var empty_i := _bench_empty_press
				_bench_empty_press = -1
				if empty_i == find_bench_slot_at_local(mb.position):
					bench_empty_pressed.emit(empty_i)
				accept_event()
				return
			_prepare_team_press_id = -1
			_bench_press_id = -1
			if _end_press():
				accept_event()


func _gui_input_recruit(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_hover_cell = tile_to_cell(local_to_tile(motion.position))
		_track_press_motion(motion.position)
		if _recruit_drag_index >= 0 or _recruit_item_drag_index >= 0 or _recruit_team_drag_id >= 0:
			_set_drag_pointer(motion.position)
			if _recruit_drag_index >= 0:
				_update_recruit_drag_leave(motion.position)
		elif _recruit_press_index >= 0 and _recruit_drag_index < 0 and not _info_shown:
			## 离开按下点超过容差即进入拖拽（触屏抖动不误触发）。
			if motion.position.distance_to(_press_pos) > LONG_PRESS_SLOP_PX:
				_cancel_press()
				_begin_recruit_drag(_recruit_press_index, motion.position)
		elif _recruit_item_press_index >= 0 and _recruit_item_drag_index < 0 and not _info_shown:
			if motion.position.distance_to(_press_pos) > LONG_PRESS_SLOP_PX:
				_cancel_press()
				_begin_recruit_item_drag(_recruit_item_press_index, motion.position)
		elif (
			(_recruit_team_press_id >= 0 or (_bench_press_id >= 0 and bench_interactive))
			and _recruit_team_drag_id < 0
			and not _info_shown
		):
			if motion.position.distance_to(_press_pos) > LONG_PRESS_SLOP_PX:
				var drag_id := _recruit_team_press_id if _recruit_team_press_id >= 0 else _bench_press_id
				_cancel_press()
				_begin_recruit_team_drag(drag_id, motion.position)
		accept_event()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var tile := local_to_tile(mb.position)
		## 招募候选/出售/锁定可用棋盘外虚拟格；勿用 tile_to_cell 钳死。
		var cell := Vector2i(floori(tile.x), floori(tile.y))
		var board_cell := tile_to_cell(tile)
		if mb.pressed:
			_bench_press_id = -1
			_bench_empty_press = -1
			var bench_entry := find_bench_entry_at_local(mb.position) if bench_visible else -1
			var bench_slot := find_bench_slot_at_local(mb.position) if bench_visible else -1
			if bench_entry >= 0:
				_bench_press_id = bench_entry if bench_interactive else -1
				_recruit_team_press_id = -1
				_recruit_press_index = -1
				_recruit_item_press_index = -1
				_recruit_empty_seat_press = -1
				var bench_tap := (
					bench_pressed.emit.bind(bench_entry) if bench_interactive else Callable()
				)
				_begin_press(mb.position, inspect_at(mb.position), bench_tap)
				accept_event()
				return
			if (
				bench_interactive
				and bench_slot >= 0
				and bench_slots != null
				and bench_slots.is_empty(bench_slot)
			):
				_bench_empty_press = bench_slot
				_recruit_team_press_id = -1
				_recruit_press_index = -1
				_recruit_item_press_index = -1
				accept_event()
				return
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
				_begin_press(mb.position, inspect_at(mb.position), Callable())
				accept_event()
				return
			## 锁定 / 卖出：长按看介绍；短按无操作（拖入才生效）。
			if _is_recruit_lock_cell(cell) or _is_recruit_sell_cell(cell):
				_recruit_item_press_index = -1
				_recruit_press_index = -1
				_recruit_team_press_id = -1
				_begin_press(mb.position, inspect_at(mb.position), Callable())
				accept_event()
				return
			var entry_id := _find_recruit_team_entry_at(board_cell)
			if entry_id >= 0:
				_recruit_team_press_id = entry_id
				_recruit_press_index = -1
				_recruit_item_press_index = -1
				_recruit_empty_seat_press = -1
				_begin_press(mb.position, inspect_at(mb.position), recruit_team_pressed.emit.bind(entry_id))
				accept_event()
				return
			var empty_press := _find_recruit_team_seat_at(board_cell)
			if empty_press >= 0:
				_recruit_empty_seat_press = empty_press
				_recruit_team_press_id = -1
				_recruit_press_index = -1
				_recruit_item_press_index = -1
				accept_event()
			return
		## 松开
		if _info_shown:
			_recruit_press_index = -1
			_recruit_item_press_index = -1
			_recruit_team_press_id = -1
			_recruit_empty_seat_press = -1
			_bench_press_id = -1
			_bench_empty_press = -1
			_end_press()
			accept_event()
			return
		if _end_press():
			accept_event()
		if _recruit_team_drag_id >= 0:
			_finish_recruit_team_drag(cell, mb.position)
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
		if _bench_empty_press >= 0:
			var empty_bench := _bench_empty_press
			_bench_empty_press = -1
			if empty_bench == find_bench_slot_at_local(mb.position):
				bench_empty_pressed.emit(empty_bench)
			accept_event()
			return
		if _recruit_press_index >= 0:
			var pressed := _recruit_press_index
			_recruit_press_index = -1
			_recruit_empty_seat_press = -1
			recruit_candidate_pressed.emit(pressed)
			accept_event()
		elif _recruit_item_press_index >= 0:
			var item_pressed := _recruit_item_press_index
			_recruit_item_press_index = -1
			_recruit_empty_seat_press = -1
			recruit_item_pressed.emit(item_pressed)
			accept_event()
		elif _recruit_empty_seat_press >= 0:
			var empty_seat := _recruit_empty_seat_press
			_recruit_empty_seat_press = -1
			if empty_seat == _find_recruit_team_seat_at(board_cell) and _find_recruit_team_entry_at(board_cell) < 0:
				recruit_empty_seat_pressed.emit(empty_seat)
			accept_event()
		_recruit_team_press_id = -1
		_recruit_empty_seat_press = -1
		_bench_press_id = -1


func _gui_input_map_shop(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_hover_cell = tile_to_cell(local_to_tile(motion.position))
		_track_press_motion(motion.position)
		if _map_shop_offer_drag_index >= 0 or _map_shop_team_drag_id >= 0:
			_set_drag_pointer(motion.position)
		elif _map_shop_offer_press_index >= 0 and _map_shop_offer_drag_index < 0 and not _info_shown:
			if motion.position.distance_to(_press_pos) > LONG_PRESS_SLOP_PX:
				_cancel_press()
				_begin_map_shop_offer_drag(_map_shop_offer_press_index, motion.position)
		elif _map_shop_team_press_id >= 0 and _map_shop_team_drag_id < 0 and not _info_shown:
			if motion.position.distance_to(_press_pos) > LONG_PRESS_SLOP_PX:
				_cancel_press()
				_begin_map_shop_team_drag(_map_shop_team_press_id, motion.position)
		accept_event()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var cell := tile_to_cell(local_to_tile(mb.position))
		if mb.pressed:
			var offer_i := _find_map_shop_offer_at(cell)
			if offer_i >= 0:
				_map_shop_offer_press_index = offer_i
				_map_shop_team_press_id = -1
				_begin_press(mb.position, inspect_at(mb.position), Callable())
				accept_event()
				return
			var entry_id := _find_recruit_team_entry_at(cell)
			if entry_id >= 0:
				_map_shop_team_press_id = entry_id
				_map_shop_offer_press_index = -1
				_begin_press(mb.position, inspect_at(mb.position), Callable())
				accept_event()
			return
		if _info_shown:
			_map_shop_offer_press_index = -1
			_map_shop_team_press_id = -1
			_end_press()
			accept_event()
			return
		if _end_press():
			accept_event()
		if _map_shop_team_drag_id >= 0:
			_finish_map_shop_team_drag(cell)
			accept_event()
			return
		if _map_shop_offer_drag_index >= 0:
			_finish_map_shop_offer_drag(cell)
			accept_event()
			return
		_map_shop_offer_press_index = -1
		_map_shop_team_press_id = -1


func _gui_input_enchant(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_hover_cell = tile_to_cell(local_to_tile(motion.position))
		if _enchant_team_pan_active and enchant_team_scroll_enabled:
			var px := get_cell_px()
			if px > 0.0:
				var delta_rows := (motion.position.y - _enchant_team_pan_last_y) / px
				_enchant_team_pan_last_y = motion.position.y
				enchant_team_scroll_rows = clampf(
					enchant_team_scroll_rows - delta_rows,
					0.0,
					enchant_team_max_scroll_rows,
				)
				queue_redraw()
			accept_event()
			return
		if _enchant_team_drag_id >= 0:
			_set_drag_pointer(motion.position)
		## 点在队员上：越出 slop 一律开拖（含竖直上炉）；滚列表只走空白区跟手 / 滚轮。
		if not _try_begin_enchant_team_drag_on_motion(motion.position):
			_track_press_motion(motion.position)
		accept_event()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and enchant_team_scroll_enabled:
			enchant_team_scroll_rows = maxf(0.0, enchant_team_scroll_rows - 0.5)
			queue_redraw()
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and enchant_team_scroll_enabled:
			enchant_team_scroll_rows = minf(
				enchant_team_max_scroll_rows,
				enchant_team_scroll_rows + 0.5,
			)
			queue_redraw()
			accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var cell := tile_to_cell(local_to_tile(mb.position))
		if mb.pressed:
			var forge_info := _inspect_enchant_forge_at(mb.position)
			if not forge_info.is_empty():
				_enchant_forge_press = true
				_begin_press(mb.position, forge_info, Callable())
				accept_event()
				return
			## 左右边条优先滚列表（可盖住边列角色外缘）；中间点队员仍开拖。
			if enchant_team_scroll_enabled and _is_enchant_side_scroll_zone(mb.position):
				_enchant_team_press_id = -1
				_enchant_team_pan_active = true
				_enchant_team_pan_last_y = mb.position.y
				accept_event()
				return
			var entry_id := _find_enchant_team_entry_at(cell)
			if entry_id >= 0:
				_enchant_team_press_id = entry_id
				_begin_press(mb.position, inspect_at(mb.position), Callable())
				accept_event()
				return
			if enchant_team_scroll_enabled and _is_enchant_team_scroll_cell(cell):
				_enchant_team_pan_active = true
				_enchant_team_pan_last_y = mb.position.y
				accept_event()
			return
		if _info_shown:
			_enchant_team_press_id = -1
			_enchant_forge_press = false
			_end_press()
			accept_event()
			return
		if _end_press():
			accept_event()
		if _enchant_team_drag_id >= 0:
			_finish_enchant_team_drag(cell)
			accept_event()
			return
		if _enchant_team_pan_active:
			_enchant_team_pan_active = false
			accept_event()
			return
		_enchant_team_press_id = -1
		_enchant_forge_press = false


func _enchant_forge_draw_offset() -> Vector2:
	return Vector2(0.0, enemy_half_slide_y)


func _inspect_enchant_forge_at(local_pos: Vector2) -> Dictionary:
	if not enchant_active:
		return {}
	var px := get_cell_px()
	var rect := get_board_rect()
	var off := _enchant_forge_draw_offset()
	var best: Dictionary = {}
	var best_d := INF
	for fi in enchant_forge_previews.size():
		var item: Variant = enchant_forge_previews[fi]
		if not (item is Dictionary):
			continue
		var forge_entry: DeckEntry = (item as Dictionary).get("entry", null)
		var forge_cell: Vector2i = (item as Dictionary).get("cell", NO_CELL)
		if forge_entry == null or forge_cell == NO_CELL:
			continue
		var cell_rect := Rect2(rect.position + Vector2(forge_cell) * px + off, Vector2(px, px))
		if not cell_rect.has_point(local_pos):
			continue
		var center := cell_rect.position + cell_rect.size * 0.5
		var d := local_pos.distance_squared_to(center)
		if d < best_d:
			best_d = d
			best = _info_from_entry(forge_entry, center, "enchant_forge:%d" % fi)
	return best


func _enchant_hit_cell(hover: Vector2i) -> Vector2i:
	if hover == NO_CELL:
		return NO_CELL
	if not enchant_active:
		return hover
	return Vector2i(hover.x, hover.y + int(floor(enchant_team_scroll_rows)))


func _is_enchant_team_scroll_cell(cell: Vector2i) -> bool:
	if cell == NO_CELL:
		return false
	var mid := BoardHalf.midline_row(board_size.y)
	return cell.y >= mid


## 队伍半场左右边条：含棋盘外留白 + 边列外缘；边列中心仍留给拖队员。
func _is_enchant_side_scroll_zone(local_pos: Vector2) -> bool:
	if not enchant_team_scroll_enabled:
		return false
	var tile := local_to_tile(local_pos)
	var mid := float(BoardHalf.midline_row(board_size.y))
	if tile.y < mid or tile.y >= float(board_size.y):
		return false
	var rect := get_board_rect()
	var px := get_cell_px()
	if rect.size.x <= 1.0 or px <= 1.0:
		return false
	var inner := px * ENCHANT_SCROLL_SIDE_INNER_TILES
	var outer := px * ENCHANT_SCROLL_SIDE_OUTER_TILES
	if local_pos.x >= rect.position.x - outer and local_pos.x <= rect.position.x + inner:
		return true
	if (
		local_pos.x >= rect.position.x + rect.size.x - inner
		and local_pos.x <= rect.position.x + rect.size.x + outer
	):
		return true
	return false


func _find_enchant_team_entry_at(hover: Vector2i) -> int:
	if prepare_slots == null or hover == NO_CELL:
		return -1
	var cell := _enchant_hit_cell(hover)
	for i in prepare_slots.slot_count:
		var entry: DeckEntry = prepare_slots.get_entry(i)
		if entry == null:
			continue
		if prepare_slots.get_cell(i) == cell:
			return entry.entry_id
	return -1


func _find_enchant_team_seat_at(hover: Vector2i) -> int:
	if prepare_slots == null or hover == NO_CELL:
		return -1
	var mid := BoardHalf.midline_row(board_size.y)
	if hover.y < mid:
		return -1
	return prepare_slots.find_slot_at_cell(_enchant_hit_cell(hover))


func _begin_enchant_team_drag(entry_id: int, from_local: Vector2 = Vector2.ZERO) -> void:
	if entry_id < 0 or prepare_slots == null:
		return
	var entry: DeckEntry = null
	for i in prepare_slots.slot_count:
		var e := prepare_slots.get_entry(i)
		if e != null and e.entry_id == entry_id:
			entry = e
			break
	if entry == null:
		return
	_enchant_team_drag_id = entry_id
	_enchant_team_press_id = -1
	_drag_active = true
	var stats := entry.unit.stats if entry.unit != null else null
	_drag_radius = stats.body_radius if stats != null else 0.7
	_drag_visual_half_width = stats.get_visual_half_width() if stats != null else 0.0
	_drag_visual_half_height = stats.get_visual_half_height() if stats != null else 0.0
	_drag_label = entry.get_display_name()
	_drag_unit_id = entry.get_unit_id()
	_drag_texture = null
	var origin := from_local if from_local != Vector2.ZERO else _press_pos
	_start_drag_visual(origin)
	queue_redraw()


func _finish_enchant_team_drag(hover: Vector2i) -> void:
	var entry_id := _enchant_team_drag_id
	_enchant_team_drag_id = -1
	_enchant_team_press_id = -1
	_enchant_team_pan_active = false
	_enchant_team_pan_last_y = 0.0
	_drag_active = false
	_finish_drag_visual(hover)
	if entry_id < 0:
		queue_redraw()
		return
	var mid := BoardHalf.midline_row(board_size.y)
	if hover != NO_CELL and hover.y < mid:
		var slot := EnchantLayout.forge_slot_name_at(hover, board_size)
		if not slot.is_empty():
			enchant_forge_drop.emit(entry_id, slot)
		queue_redraw()
		return
	var seat_i := _find_enchant_team_seat_at(hover)
	if seat_i < 0 and prepare_slots != null and hover != NO_CELL:
		var logical := _enchant_hit_cell(hover)
		seat_i = prepare_slots.find_nearest_empty_slot(logical)
		if seat_i >= 0:
			var sc := prepare_slots.get_cell(seat_i)
			if absi(sc.x - logical.x) + absi(sc.y - logical.y) > 4:
				seat_i = -1
	if seat_i >= 0:
		enchant_team_seat_drop.emit(entry_id, seat_i)
	queue_redraw()


func _kill_drag_tween() -> void:
	if _drag_tween != null and _drag_tween.is_valid():
		_drag_tween.kill()
	_drag_tween = null


func _start_drag_visual(from_local: Vector2) -> void:
	_kill_drag_tween()
	_drag_visual_alive = true
	_drag_settling = false
	var origin := from_local
	if origin == Vector2.ZERO:
		origin = get_local_mouse_position()
	_drag_pointer = origin
	_drag_draw_pos = origin
	_drag_last_pointer = origin
	_drag_velocity_tiles = Vector2.ZERO
	_drag_started_at = _fx_clock
	_drag_pose.offset = Vector2(0.0, 0.02)
	_drag_pose.scale = Vector2.ONE * 0.92
	_drag_pose.alpha = 0.85
	_drag_pose.rotation = 0.0
	_drag_pose.flash = 0.0
	_drag_pose.shadow_mul = 1.0
	_apply_drag_sample(0.0, Vector2.ZERO)


func _set_drag_pointer(local_pos: Vector2) -> void:
	if not _drag_visual_alive or _drag_settling:
		return
	_drag_pointer = local_pos


func _update_drag_hold_pose(delta: float) -> void:
	var follow_t := 1.0 - exp(-DRAG_FOLLOW_RATE * delta)
	_drag_draw_pos = _drag_draw_pos.lerp(_drag_pointer, follow_t)
	var px := maxf(1.0, get_cell_px())
	var instant := (_drag_pointer - _drag_last_pointer) / px / maxf(delta, 0.0001)
	_drag_last_pointer = _drag_pointer
	var vel_t := 1.0 - exp(-DRAG_VELOCITY_SMOOTH * delta)
	_drag_velocity_tiles = _drag_velocity_tiles.lerp(instant, vel_t)
	var elapsed := 0.0 if _drag_started_at < 0.0 else maxf(0.0, _fx_clock - _drag_started_at)
	_apply_drag_sample(elapsed, _drag_velocity_tiles)


func _apply_drag_sample(elapsed: float, velocity_tiles: Vector2) -> void:
	var sample: Dictionary = RealtimeUnitMotion.sample_drag_hold(elapsed, velocity_tiles)
	_drag_pose.offset = sample.get("offset", Vector2.ZERO) as Vector2
	_drag_pose.rotation = float(sample.get("rotation", 0.0))
	_drag_pose.scale = sample.get("scale", Vector2.ONE) as Vector2
	_drag_pose.alpha = float(sample.get("alpha", 1.0))
	_drag_pose.shadow_mul = float(sample.get("shadow_mul", 1.0))


func _finish_drag_visual(hover: Vector2i = NO_CELL) -> void:
	if not _drag_visual_alive:
		return
	if _drag_settling:
		return
	_drag_settling = true
	var target := _drag_draw_pos
	if hover != NO_CELL:
		target = tile_to_local(Vector2(hover) + Vector2(0.5, 0.5))
	_kill_drag_tween()
	## 落座：BACK 弹性回正（同信息卡切换的小丑牌收势）。
	_drag_tween = create_tween()
	_drag_tween.set_parallel(true)
	_drag_tween.tween_property(self, "_drag_draw_pos", target, DRAG_SETTLE_SEC) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_drag_tween.tween_property(_drag_pose, "scale", Vector2.ONE, DRAG_SETTLE_SEC) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_drag_tween.tween_property(_drag_pose, "offset", Vector2.ZERO, DRAG_SETTLE_SEC) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_drag_tween.tween_property(_drag_pose, "rotation", 0.0, DRAG_SETTLE_SEC) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_drag_tween.tween_property(_drag_pose, "shadow_mul", 1.0, DRAG_SETTLE_SEC) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_drag_tween.tween_property(_drag_pose, "alpha", 0.55, DRAG_SETTLE_SEC * 0.85) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_drag_tween.chain().tween_callback(_clear_drag_visual)


func _clear_drag_visual() -> void:
	_kill_drag_tween()
	_drag_visual_alive = false
	_drag_settling = false
	_drag_started_at = -1.0
	_drag_velocity_tiles = Vector2.ZERO
	_drag_texture = null
	_drag_pose.offset = Vector2.ZERO
	_drag_pose.scale = Vector2.ONE
	_drag_pose.alpha = 1.0
	_drag_pose.rotation = 0.0
	_drag_pose.flash = 0.0
	_drag_pose.shadow_mul = 1.0
	## 失败回席：纸片落地后再淡入卡壳（可被下次拖拽打断）。
	if _recruit_restore_index >= 0:
		_start_recruit_shell_restore(_recruit_restore_index)
	queue_redraw()


func _kill_recruit_shell_tween() -> void:
	if _recruit_shell_tween != null and _recruit_shell_tween.is_valid():
		_recruit_shell_tween.kill()
	_recruit_shell_tween = null


func _reset_recruit_card_dissolve() -> void:
	_kill_recruit_shell_tween()
	_recruit_drag_source_cell = NO_CELL
	_recruit_left_source = false
	_recruit_shell_progress = 0.0
	_recruit_restore_index = -1
	_hide_recruit_card_shells()


## 测试/调试：候选人拖已离源格（卡溶解、源槽空、跟手仅纸片）。
func is_recruit_drag_detached() -> bool:
	return _recruit_drag_index >= 0 and _recruit_left_source


## 测试/调试：源槽当前不画纸片角色（离格溶解中或失败回席飞行中）。
func is_recruit_drag_source_body_hidden() -> bool:
	if _recruit_drag_index >= 0 and _recruit_left_source:
		return true
	if _recruit_restore_index >= 0 and _drag_settling:
		return true
	return false


## 测试/调试：当前溶解进度（0 完整 → 1 消失）。
func get_recruit_shell_dissolve_progress() -> float:
	return _recruit_shell_progress


func _recruit_candidate_cell(index: int) -> Vector2i:
	if index < 0 or index >= recruit_candidates.size():
		return NO_CELL
	var info: Variant = recruit_candidates[index]
	if not (info is Dictionary):
		return NO_CELL
	return (info as Dictionary).get("cell", NO_CELL) as Vector2i


func _update_recruit_drag_leave(local_pos: Vector2 = Vector2.INF) -> void:
	if _recruit_drag_index < 0 or _recruit_left_source:
		return
	if _recruit_drag_source_cell == NO_CELL:
		return
	## 与点选候选人一致：用未钳死的虚拟格，避免半场外候选被 tile_to_cell 夹到他格而误溶。
	var pos := local_pos if local_pos != Vector2.INF else get_local_mouse_position()
	var tile := local_to_tile(pos)
	var cell := Vector2i(floori(tile.x), floori(tile.y))
	if cell == _recruit_drag_source_cell:
		return
	_recruit_left_source = true
	_start_recruit_shell_dissolve()


func _start_recruit_shell_dissolve() -> void:
	_kill_recruit_shell_tween()
	_recruit_restore_index = -1
	_recruit_shell_progress = 0.0
	_recruit_shell_tween = create_tween()
	_recruit_shell_tween.tween_property(self, "_recruit_shell_progress", 1.0, RECRUIT_CARD_DISSOLVE_SEC) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _start_recruit_shell_restore(index: int) -> void:
	_kill_recruit_shell_tween()
	_recruit_restore_index = index
	_recruit_left_source = false
	_recruit_drag_source_cell = NO_CELL
	_recruit_shell_progress = 1.0
	_recruit_shell_tween = create_tween()
	_recruit_shell_tween.tween_property(self, "_recruit_shell_progress", 0.0, RECRUIT_CARD_RESTORE_SEC) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_recruit_shell_tween.tween_callback(func() -> void:
		if _recruit_restore_index == index:
			_recruit_restore_index = -1
			_recruit_shell_progress = 0.0
		queue_redraw()
	)


func _make_recruit_card_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = RECRUIT_CARD_SHADER
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("fill_color", RECRUIT_CARD_FILL)
	mat.set_shader_parameter("fill_inner", RECRUIT_CARD_FILL_INNER)
	mat.set_shader_parameter("stroke_color", RECRUIT_CARD_STROKE)
	mat.set_shader_parameter("burn_color", RECRUIT_CARD_BURN)
	mat.set_shader_parameter("burn_width", 0.16)
	mat.set_shader_parameter("noise_scale", 9.5)
	return mat


func _ensure_recruit_card_shells() -> void:
	if _recruit_card_shells.is_empty():
		for i in RECRUIT_CARD_SLOT_CAP:
			var shell := ColorRect.new()
			shell.name = "RecruitCardShell_%d" % i
			shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shell.show_behind_parent = true
			shell.visible = false
			shell.color = Color(1, 1, 1, 1)
			var mat := _make_recruit_card_material()
			shell.material = mat
			add_child(shell)
			move_child(shell, 0)
			_recruit_card_shells.append(shell)
			_recruit_card_mats.append(mat)
	if _recruit_follow_shell == null:
		_recruit_follow_shell = ColorRect.new()
		_recruit_follow_shell.name = "RecruitCardFollowShell"
		_recruit_follow_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_recruit_follow_shell.show_behind_parent = true
		_recruit_follow_shell.visible = false
		_recruit_follow_shell.color = Color(1, 1, 1, 1)
		_recruit_follow_mat = _make_recruit_card_material()
		_recruit_follow_shell.material = _recruit_follow_mat
		add_child(_recruit_follow_shell)
		move_child(_recruit_follow_shell, 0)


func _hide_recruit_card_shells() -> void:
	for shell in _recruit_card_shells:
		if shell != null:
			shell.visible = false
	if _recruit_follow_shell != null:
		_recruit_follow_shell.visible = false


func _recruit_candidate_shell_size(px: float) -> Vector2:
	## 全槽统一尺寸（不随兵种剪影半宽/半高变化）。
	return Vector2(px * RECRUIT_CARD_W_CELLS, px * RECRUIT_CARD_H_CELLS)


func _recruit_candidate_shell_rect(center_local: Vector2, px: float) -> Rect2:
	var sz := _recruit_candidate_shell_size(px)
	return Rect2(center_local - sz * 0.5, sz)


func _sync_recruit_card_shells(px: float, off: Vector2) -> void:
	_ensure_recruit_card_shells()
	if not recruit_active:
		_hide_recruit_card_shells()
		return
	var active_slots: Dictionary = {}
	var follow_active := false
	for info in recruit_candidates:
		if not (info is Dictionary):
			continue
		var cell: Vector2i = info.get("cell", NO_CELL)
		if cell == NO_CELL:
			continue
		var unit: UnitData = info.get("unit") as UnitData
		if unit == null:
			continue
		var index := int(info.get("index", -1))
		if index < 0 or index >= _recruit_card_shells.size():
			continue
		var dragging := index == _recruit_drag_index
		var restoring := index == _recruit_restore_index
		## 离格后源槽立刻空：溶解改在跟手卡壳上播。
		if dragging and _recruit_left_source:
			continue
		if restoring and _drag_settling:
			continue
		var progress := 0.0
		if restoring:
			progress = _recruit_shell_progress
		var center_local := tile_to_local(Vector2(cell) + Vector2(0.5, 0.5)) + off
		var rect := _recruit_candidate_shell_rect(center_local, px)
		var shell := _recruit_card_shells[index]
		var mat := _recruit_card_mats[index]
		shell.visible = progress < 0.999
		shell.position = rect.position
		shell.size = rect.size
		if mat != null:
			mat.set_shader_parameter("progress", progress)
		active_slots[index] = true
	## 跟手溶解：卡跟着角色，噪声阈值逐步碎掉后只剩纸片。
	if (
		_recruit_drag_index >= 0
		and _recruit_left_source
		and _drag_visual_alive
		and _recruit_shell_progress < 0.999
		and _recruit_follow_shell != null
	):
		var follow_rect := _recruit_candidate_shell_rect(_drag_draw_pos, px)
		_recruit_follow_shell.visible = true
		_recruit_follow_shell.position = follow_rect.position
		_recruit_follow_shell.size = follow_rect.size
		if _recruit_follow_mat != null:
			_recruit_follow_mat.set_shader_parameter("progress", _recruit_shell_progress)
		follow_active = true
	if _recruit_follow_shell != null and not follow_active:
		_recruit_follow_shell.visible = false
	for i in _recruit_card_shells.size():
		if not active_slots.has(i):
			_recruit_card_shells[i].visible = false


func _draw_enchant_team_seat_hint(px: float) -> void:
	var hover := _hover_cell
	if hover == NO_CELL:
		return
	var seat_i := _find_enchant_team_seat_at(hover)
	if seat_i < 0 and prepare_slots != null:
		var logical := _enchant_hit_cell(hover)
		seat_i = prepare_slots.find_nearest_empty_slot(logical)
		if seat_i >= 0:
			var sc := prepare_slots.get_cell(seat_i)
			if absi(sc.x - logical.x) + absi(sc.y - logical.y) > 4:
				seat_i = -1
	var ok := seat_i >= 0
	var cell := hover
	if ok:
		cell = prepare_slots.get_cell(seat_i)
	var rect := get_board_rect()
	var scroll_y := 0.0
	if enchant_team_scroll_enabled:
		scroll_y = enchant_team_scroll_rows * px
	var off := Vector2(0.0, ally_half_slide_y - scroll_y)
	var cell_rect := Rect2(rect.position + Vector2(cell) * px + off, Vector2(px, px))
	draw_rect(cell_rect, Color(0.45, 0.85, 1.0, 0.4) if ok else Color(1.0, 0.25, 0.2, 0.25))
	## 跟手拖影由 _draw_drag_follower 绘制，落点只高亮格。
	if _drag_visual_alive:
		return
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
		off,
		true,
		_drag_unit_id,
	)


func _draw_enchant_forge_drop_hint(px: float, off: Vector2) -> void:
	var hover := _hover_cell
	if hover == NO_CELL:
		return
	var slot := EnchantLayout.forge_slot_name_at(hover, board_size)
	var ok := not slot.is_empty()
	var cells := EnchantLayout.forge_slot_cells(board_size)
	var target := NO_CELL
	if slot == &"a" and cells.size() > 0:
		target = cells[0]
	elif slot == &"b" and cells.size() > 1:
		target = cells[1]
	if target == NO_CELL:
		return
	var cell_rect := Rect2(get_board_rect().position + Vector2(target) * px + off, Vector2(px, px))
	draw_rect(cell_rect, Color(0.45, 0.85, 1.0, 0.45) if ok else Color(1.0, 0.25, 0.2, 0.25))


func _begin_press(pos: Vector2, info: Dictionary, tap: Callable) -> void:
	_cancel_press()
	_press_active = true
	_press_pos = pos
	_press_info = info
	_press_tap = tap
	_press_ms = Time.get_ticks_msec() if not info.is_empty() else -1
	_info_shown = false


func _try_begin_enchant_team_drag_on_motion(pos: Vector2) -> bool:
	if _enchant_forge_press or _enchant_team_press_id < 0 or _enchant_team_drag_id >= 0 or _info_shown:
		return false
	if _enchant_team_pan_active:
		return false
	if pos.distance_to(_press_pos) <= LONG_PRESS_SLOP_PX:
		return false
	_cancel_press()
	_begin_enchant_team_drag(_enchant_team_press_id, pos)
	return true


func _track_press_motion(pos: Vector2) -> void:
	if not _press_active:
		return
	## 信息卡已弹出：保持按住时滑到其他单位即切换介绍，并跟手微倾。
	if _info_shown:
		_inspect_finger = pos
		_update_info_card_under_finger(pos)
		if _info_card.top_level:
			_info_card.follow_finger(get_global_transform() * pos)
		else:
			_info_card.follow_finger(pos)
		_sync_info_attachment_positions()
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
	_enchant_forge_press = false
	_clear_inspect_focus()
	_hide_all_info_cards()


func is_info_card_visible() -> bool:
	return _info_card.visible


func _hide_all_info_cards() -> void:
	_info_card.hide_info()
	_info_card.top_level = false
	_combat_broadcast_info = false
	_hide_info_attachments()


func _hide_info_attachments() -> void:
	for card in _info_attachment_cards:
		if card != null:
			card.hide_info()
			card.top_level = false


func _ensure_info_attachment_card(index: int) -> RealtimeUnitInfoCard:
	while _info_attachment_cards.size() <= index:
		var card := RealtimeUnitInfoCard.new()
		card.name = "UnitInfoAttachment_%d" % _info_attachment_cards.size()
		add_child(card)
		_info_attachment_cards.append(card)
	return _info_attachment_cards[index]


func _sync_info_attachment_positions() -> void:
	if not _info_card.visible:
		return
	var follow := _info_card.get_follow_offset()
	for card in _info_attachment_cards:
		if card == null or not card.visible:
			continue
		card.apply_follow_offset(follow)


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
	var attachments: Array = info.get("attachments", [])
	_hide_info_attachments()
	## 统计/目录在 Scroll 内会被裁切：信息卡提到顶层并用视口坐标，避免被遮罩挡住技能文。
	if catalog_active:
		_info_card.top_level = true
		var xf := get_global_transform()
		var head_g := xf * head
		var foot_g := xf * foot
		var vp := get_viewport().get_visible_rect()
		_info_card.show_info(info, head_g, foot_g, vp, slide_dir)
		_show_info_attachments(attachments, vp, slide_dir, true)
	else:
		_info_card.top_level = false
		var bounds := Rect2(Vector2.ZERO, size)
		_info_card.show_info(info, head, foot, bounds, slide_dir)
		_show_info_attachments(attachments, bounds, slide_dir, false)
	queue_redraw()


## 战斗内技能播报：详卡贴在棋盘区底边、触发者列内；可叠状态/装备附属卡栈。
func _show_combat_broadcast_info_card(info: Dictionary, slide_dir: float = 0.0) -> void:
	if info.is_empty():
		return
	_combat_broadcast_info = true
	_shown_info = info
	_begin_inspect_focus(info, slide_dir)
	var attachments: Array = info.get("attachments", [])
	_hide_info_attachments()
	_info_card.top_level = false
	var center: Vector2 = info.get("center", Vector2.ZERO)
	var px := get_cell_px()
	var foot := center + Vector2(0.0, px * 0.38) + Vector2(0.0, get_stat_badge_size(px).y * 1.1)
	var bounds := get_board_rect()
	_info_card.show_info_combat_below_unit(info, foot, bounds, slide_dir)
	_show_info_attachments(attachments, bounds, slide_dir, false)
	queue_redraw()


func _show_info_attachments(
	attachments: Array, bounds: Rect2, slide_dir: float, top_level: bool
) -> void:
	if attachments.is_empty():
		return
	var leader_rest := _info_card.get_rest_position()
	var leader_size := _info_card.size
	for i in attachments.size():
		var att: Dictionary = attachments[i] as Dictionary
		if att.is_empty():
			continue
		var card := _ensure_info_attachment_card(i)
		card.top_level = top_level
		card.show_stack_attachment(
			att, leader_rest, leader_size, INFO_ATTACHMENT_GAP_PX, bounds, slide_dir, i
		)
		leader_rest = card.get_rest_position()
		leader_size = card.size


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


func _info_focus_visual_active() -> bool:
	return (_info_shown or _combat_broadcast_info) and not _shown_info.is_empty()


## 长按焦点视觉：焦点单位抬起倾斜，其余略压暗缩小。
func _sample_inspect_visual(sprite_center: Vector2) -> Dictionary:
	if not _info_focus_visual_active():
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
	if not _info_focus_visual_active() or slots == null or indices.is_empty():
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
	if not _info_focus_visual_active() or ordered.is_empty():
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


func pin_combat_skill_info() -> void:
	_combat_skill_info_pin = 1


func unpin_combat_skill_info() -> void:
	_combat_skill_info_pin = 0


func bump_combat_skill_info_visibility(extra_seconds: float) -> void:
	if extra_seconds <= 0.0:
		return
	var until := _fx_clock + extra_seconds
	if until > _auto_info_until_clock:
		_auto_info_until_clock = until


## 技能触发时先弹出与长按相同的单位信息卡（含技能介绍）。
## skills_override 非空时只展示本条触发（RichText / BBCode）。
func show_skill_trigger_info(
	unit: UnitInstance,
	is_player: bool,
	attack: int,
	hp: int,
	tile_pos: Vector2,
	skills_override: String = "",
	attachments: Array = [],
) -> void:
	if unit == null:
		return
	var off := Vector2(0.0, ally_half_slide_y if is_player else enemy_half_slide_y)
	var center := tile_to_local(tile_pos) + off
	var info := _info_from_instance(unit, is_player, attack, hp, center)
	info["attachments"] = attachments
	if not skills_override.is_empty():
		info["skills"] = skills_override
	_show_combat_broadcast_info_card(info)
	play_combat_skill_info_reel_intro()
	var life := SKILL_INFO_SECONDS / maxf(0.25, presentation_time_scale)
	bump_combat_skill_info_visibility(life)


## 展示步 ①：整张**战斗技能介绍卡**（主卡）。
func play_combat_skill_info_reel_intro() -> void:
	_schedule_settlement_reel_shake(_info_card)


func _schedule_settlement_reel_shake(card: RealtimeUnitInfoCard) -> void:
	if card == null or not card.visible:
		return
	var delay := RealtimeUnitInfoCard.POP_IN_SEC / maxf(0.25, presentation_time_scale)
	get_tree().create_timer(delay).timeout.connect(
		func() -> void:
			if card != null and card.visible:
				card.play_settlement_reel_shake(
					presentation_time_scale, _settlement_reel_amplitude_for_card(card)
				),
		CONNECT_ONE_SHOT,
	)


func _settlement_reel_amplitude_for_card(card: RealtimeUnitInfoCard) -> float:
	if card == _info_card:
		return 1.0
	return RealtimeUnitInfoCard.REEL_ATTACHMENT_AMP_MULT


func play_combat_skill_info_reel_resolve(payload: CombatEventPayload) -> void:
	var card := _pick_reel_info_card(payload)
	if card != null:
		card.play_settlement_reel_shake(
			presentation_time_scale, _settlement_reel_amplitude_for_card(card)
		)


func _pick_reel_info_card(payload: CombatEventPayload) -> RealtimeUnitInfoCard:
	var entries: Array = payload.effect_entries
	if entries.is_empty() and payload.effect_action != null:
		entries = [{"action": payload.effect_action, "target": payload.target}]
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var action: EffectAction = entry.get("action")
		if action == null:
			continue
		if (
			action.action_type == EffectAction.Type.APPLY_COMBAT_STATUS
			or action.action_type == EffectAction.Type.REMOVE_COMBAT_STATUS
		):
			var att := _find_status_attachment_card(action.stat_name)
			if att != null:
				return att
	if _info_card.visible:
		return _info_card
	return null


func _find_status_attachment_card(status_id: StringName) -> RealtimeUnitInfoCard:
	var attachments: Array = _shown_info.get("attachments", [])
	for i in attachments.size():
		var att: Variant = attachments[i]
		if not (att is Dictionary):
			continue
		var dict: Dictionary = att
		if dict.get("attachment_kind") != UnitInfoText.INFO_ATTACHMENT_KIND_STATUS:
			continue
		if dict.get("status_id", &"") == status_id and i < _info_attachment_cards.size():
			var card := _info_attachment_cards[i]
			if card.visible:
				return card
	return null


## 展示步 ①②：整张**装备附属介绍卡**（与主技能卡分卡时）。
func play_combat_equipment_info_reel_shake(equipment_id: StringName) -> void:
	var card := _find_equipment_attachment_card(equipment_id)
	if card != null:
		card.play_settlement_reel_shake(
			presentation_time_scale, _settlement_reel_amplitude_for_card(card)
		)


func _find_equipment_attachment_card(equipment_id: StringName) -> RealtimeUnitInfoCard:
	var attachments: Array = _shown_info.get("attachments", [])
	for i in attachments.size():
		var att: Variant = attachments[i]
		if not (att is Dictionary):
			continue
		var dict: Dictionary = att
		if dict.get("attachment_kind") != UnitInfoText.INFO_ATTACHMENT_KIND_EQUIPMENT:
			continue
		if dict.get("equipment_id", &"") == equipment_id and i < _info_attachment_cards.size():
			var c := _info_attachment_cards[i]
			if c.visible:
				return c
	return null


## 命中测试：返回该位置单位的信息字典（含 center 本地坐标）；未命中返回空字典。
func inspect_at(local_pos: Vector2) -> Dictionary:
	if enchant_active:
		var forge_info := _inspect_enchant_forge_at(local_pos)
		if not forge_info.is_empty():
			return forge_info
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
	if map_shop_active:
		if recruit_team_slots != null:
			for i in recruit_team_slots.cells.size():
				var team_entry := recruit_team_slots.get_entry(i)
				if team_entry != null:
					var team_tile := Vector2(recruit_team_slots.cells[i]) + Vector2(0.5, 0.5)
					out.append(_info_from_entry(team_entry, tile_to_local(team_tile) + enemy_off))
		for oi in map_shop_offers.size():
			var offer_info := _info_from_map_shop_offer_index(oi, ally_off)
			if not offer_info.is_empty():
				out.append(offer_info)
		return out
	if catalog_active:
		for i in catalog_units.size():
			var entry: Variant = catalog_units[i]
			if not (entry is Dictionary):
				continue
			var info_dict := entry as Dictionary
			var cell: Vector2i = info_dict.get("cell", NO_CELL)
			if cell == NO_CELL:
				continue
			var tile := Vector2(cell) + Vector2(0.5, 0.5)
			var deck_entry: DeckEntry = info_dict.get("deck_entry") as DeckEntry
			if deck_entry != null and deck_entry.unit != null:
				out.append(_info_from_entry(deck_entry, tile_to_local(tile), "catalog:%d" % i))
				continue
			var unit: UnitData = info_dict.get("unit") as UnitData
			if unit == null:
				continue
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
				out.append(
					_info_from_unit_data(
						unit,
						tile_to_local(tile) + ally_off,
						"cand:%d" % cand_i,
						1,
						int(cand.get("cost", 0)),
						bool(cand.get("affordable", true)),
					)
				)
		for oi in recruit_items.size():
			var item_info := _info_from_recruit_item_index(oi, ally_off)
			if not item_info.is_empty():
				out.append(item_info)
		var lock_info := _info_from_recruit_action_cell(
			recruit_lock_cell,
			ally_off,
			"recruit_lock",
			"锁定",
			"操作",
			RECRUIT_TEX_LOCK,
			"把候选人拖到此处切换锁定。\n已锁定角色刷新时保留，完成/跳过后下一场招募仍在同槽；新 Run 与开局招募清空。\n空槽不可锁；长按只看介绍。",
		)
		if not lock_info.is_empty():
			out.append(lock_info)
		var sell_info := _info_from_recruit_action_cell(
			recruit_sell_cell,
			ally_off,
			"recruit_sell",
			"卖出",
			"操作",
			RECRUIT_TEX_SELL,
			"把上区或备战成员拖到此处出售，获得正常退金并腾位。\n长按只看介绍，不会卖出；拖超过阈值后松手才成交，可拖回取消。",
		)
		if not sell_info.is_empty():
			out.append(sell_info)
		_append_bench_inspectables(out)
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
		_append_bench_inspectables(out)
		return out
	if prepare_slots != null:
		var team_off := _prepare_slots_inspect_offset(ally_off)
		for i in prepare_slots.cells.size():
			var entry := prepare_slots.get_entry(i)
			if entry != null:
				var tile := Vector2(prepare_slots.cells[i]) + Vector2(0.5, 0.5)
				out.append(_info_from_entry(entry, tile_to_local(tile) + team_off))
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
	_append_bench_inspectables(out)
	return out


func _append_bench_inspectables(out: Array[Dictionary]) -> void:
	if not bench_visible or bench_slots == null:
		return
	for i in bench_slots.cells.size():
		var entry := bench_slots.get_entry(i)
		if entry == null:
			continue
		out.append(_info_from_entry(
			entry,
			bench_slot_center_local(i),
			"bench:%d" % entry.entry_id,
		))


func _prepare_slots_inspect_offset(ally_off: Vector2) -> Vector2:
	var scroll_y := 0.0
	if enchant_active and enchant_team_scroll_enabled:
		scroll_y = enchant_team_scroll_rows * get_cell_px()
	return ally_off + Vector2(0.0, -scroll_y)


func _info_from_entry(entry: DeckEntry, center: Vector2, inspect_key: String = "") -> Dictionary:
	var key := inspect_key
	if key.is_empty():
		key = "entry:%d" % entry.entry_id
	var unit_cost := entry.unit.cost if entry.unit != null else 0
	return {
		"inspect_key": key,
		"center": center,
		"name": entry.get_display_name(),
		"side_player": true,
		"tier": entry.unit.tier if entry.unit != null else 0,
		"attack": maxi(1, DeckUpgradeService.get_display_attack(entry)),
		"hp": maxi(1, DeckUpgradeService.get_display_max_hp(entry)),
		"armor": entry.get_armor_block(),
		"skills": UnitInfoText.get_skills_block_from_entry(entry, true),
		"attachments": UnitInfoText.collect_info_attachments_from_entry(entry, true),
		"texture": _art.get_texture(entry.get_unit_id(), true) if _art != null else null,
		## 与攻/血同列展示角色花费（招募价另传 recruit_cost 时覆盖）。
		"recruit_cost": maxi(0, unit_cost),
		"recruit_cost_affordable": true,
	}


func _info_from_unit_data(
	data: UnitData,
	center: Vector2,
	inspect_key: String = "",
	preview_level: int = 1,
	recruit_cost: int = -1,
	recruit_cost_affordable: bool = true,
) -> Dictionary:
	var key := inspect_key
	if key.is_empty():
		key = "unit:%s@%s" % [data.id, str(center)]
	var level := clampi(preview_level, 1, 3)
	var stat_mult := UnitInfoText.catalog_preview_stat_mult(level)
	var atk := data.stats.attack if data.stats != null else 0
	var hp := data.stats.max_hp if data.stats != null else 0
	var star_tag := "" if level <= 1 else " · %d★" % level
	var info := {
		"inspect_key": key,
		"center": center,
		"name": UnitInfoText.get_display_name_from_unit_data(data) + star_tag,
		"side_player": true,
		"tier": data.tier,
		"attack": atk * stat_mult,
		"hp": hp * stat_mult,
		"skills": UnitInfoText.get_skills_block_from_unit_data(data, level, true),
		"texture": _art.get_texture(data.id, true) if _art != null else null,
		## 默认展示角色花费；招募候选可覆盖为当场价。
		"recruit_cost": maxi(0, data.cost),
		"recruit_cost_affordable": true,
	}
	if recruit_cost >= 0:
		info["recruit_cost"] = recruit_cost
		info["recruit_cost_affordable"] = recruit_cost_affordable
	return info


func _info_from_instance(unit: UnitInstance, is_player: bool, attack: int, hp: int, center: Vector2) -> Dictionary:
	var unit_id := unit.unit_data.id if unit.unit_data != null else ""
	var unit_cost := unit.unit_data.cost if unit.unit_data != null else 0
	return {
		"inspect_key": "inst:%d" % unit.get_instance_id(),
		"center": center,
		"name": UnitInfoText.get_display_name(unit),
		"side_player": is_player,
		"tier": unit.unit_data.tier if unit.unit_data != null else 0,
		"attack": attack,
		"hp": hp,
		"armor": unit.get_armor_block(),
		"skills": UnitInfoText.get_skills_block(unit, true),
		"attachments": UnitInfoText.collect_info_attachments_from_unit(unit, true),
		"texture": _art.get_texture(unit_id, is_player) if _art != null else null,
		"recruit_cost": maxi(0, unit_cost),
		"recruit_cost_affordable": true,
	}


## 招募半场道具：与地图商店同用 RealtimeUnitInfoCard（is_item）。
func _info_from_recruit_item_index(index: int, half_off: Vector2) -> Dictionary:
	if index < 0 or index >= recruit_items.size():
		return {}
	var dict: Variant = recruit_items[index]
	if not (dict is Dictionary):
		return {}
	var offer := dict as Dictionary
	var item: PrepareItemData = offer.get("item") as PrepareItemData
	if item == null:
		return {}
	var cell: Vector2i = offer.get("cell", NO_CELL)
	if cell == NO_CELL:
		return {}
	var center := tile_to_local(Vector2(cell) + Vector2(0.5, 0.5)) + half_off
	var bonus := maxi(1, item.bonus_value)
	var kind_label := "道具"
	var skills := ""
	match item.item_type:
		PrepareItemData.ItemType.HP_POTION:
			kind_label = "消耗品"
			skills = (
				"永久 +%s%d 生命上限。\n拖到上区队伍角色使用，或点选后再点目标；即时扣金，整局保留。"
				% [UnitInfoText.STAT_ICON_HP, bonus]
			)
		PrepareItemData.ItemType.ATK_POTION:
			kind_label = "消耗品"
			skills = (
				"永久 +%s%d 攻击。\n拖到上区队伍角色使用，或点选后再点目标；即时扣金，整局保留。"
				% [UnitInfoText.STAT_ICON_ATK, bonus]
			)
		PrepareItemData.ItemType.BANNER:
			kind_label = "道具"
			skills = "上场席位上限 +1（最高 10）；不扩备战格数。\n点击购买，即时扣金；已满 10 席时本行不出旗帜。价格随本局成功购买次数升高。"
		_:
			skills = "招募道具。"
	return {
		"inspect_key": "recruit_item:%d" % index,
		"center": center,
		"name": item.get_display_name(),
		"side_player": true,
		"tier": 0,
		"is_item": true,
		"kind_label": kind_label,
		"cost": int(offer.get("cost", item.cost)),
		"attack": 0,
		"hp": 0,
		"skills": skills,
		"texture": _recruit_prop_texture(item.id),
	}


## 招募锁定 / 卖出落点：同信息卡，无价格。
func _info_from_recruit_action_cell(
	cell: Vector2i,
	half_off: Vector2,
	inspect_key: String,
	display_name: String,
	kind_label: String,
	texture: Texture2D,
	skills: String,
) -> Dictionary:
	if cell == NO_CELL:
		return {}
	var center := tile_to_local(Vector2(cell) + Vector2(0.5, 0.5)) + half_off
	return {
		"inspect_key": inspect_key,
		"center": center,
		"name": display_name,
		"side_player": true,
		"tier": 0,
		"is_item": true,
		"kind_label": kind_label,
		"cost": 0,
		"attack": 0,
		"hp": 0,
		"skills": skills,
		"texture": texture,
	}


## 地图商店货架物品：与角色同用 RealtimeUnitInfoCard，攻血标隐藏、侧栏写种类与价格。
func _info_from_map_shop_offer_index(index: int, half_off: Vector2) -> Dictionary:
	if index < 0 or index >= map_shop_offers.size():
		return {}
	var dict: Variant = map_shop_offers[index]
	if not (dict is Dictionary):
		return {}
	var offer := dict as Dictionary
	if offer.get("item") == null:
		return {}
	var cell: Vector2i = offer.get("cell", NO_CELL)
	if cell == NO_CELL:
		return {}
	var center := tile_to_local(Vector2(cell) + Vector2(0.5, 0.5)) + half_off
	var kind: StringName = offer.get("kind", &"consumable")
	var kind_label := "装备" if kind == &"equipment" else "消耗品"
	var skills := ""
	var armor := 0
	if kind == &"equipment":
		var eq := offer.get("item") as EquipmentData
		if eq != null:
			armor = eq.get_armor_block()
			skills = (
				"护甲：有护甲时不扣血（伤害大于护甲时护甲归零、溢出也不扣血）。\n挂在一名队伍成员上，跨节点保留；离开战斗节点后回满；每角色最多一件。"
				% armor
			)
	else:
		var cons := offer.get("item") as MapShopConsumableData
		if cons != null:
			skills = (
				"%s\n永久改变目标角色属性；拖到上半场角色使用，该槽清空。"
				% cons.get_effect_summary()
			)
		else:
			skills = String(offer.get("summary", ""))
	if skills.is_empty():
		skills = String(offer.get("summary", "商店物品"))
	return {
		"inspect_key": "map_shop_offer:%d" % index,
		"center": center,
		"name": String(offer.get("label", "物品")),
		"side_player": true,
		"tier": 0,
		"is_item": true,
		"kind_label": kind_label,
		"cost": int(offer.get("cost", 0)),
		"attack": 0,
		"hp": 0,
		"armor": armor,
		"skills": skills,
		"texture": offer.get("icon") as Texture2D,
	}


func _candidate_needs_replace(index: int) -> bool:
	if index < 0 or index >= recruit_candidates.size():
		return recruit_needs_replace
	var info: Dictionary = recruit_candidates[index]
	if info.has("needs_replace"):
		return bool(info.get("needs_replace", false))
	return recruit_needs_replace


func _begin_recruit_drag(index: int, from_local: Vector2 = Vector2.ZERO) -> void:
	if index < 0 or index >= recruit_candidates.size():
		return
	var info: Dictionary = recruit_candidates[index]
	if info.get("unit") == null:
		return
	## 买不起仍允许预览拖；扣费由 session 在松手结算时拒绝。
	_kill_recruit_shell_tween()
	_recruit_drag_index = index
	_recruit_press_index = -1
	_recruit_item_drag_index = -1
	_recruit_item_press_index = -1
	_recruit_team_drag_id = -1
	_recruit_team_press_id = -1
	_recruit_restore_index = -1
	_recruit_drag_source_cell = info.get("cell", NO_CELL) as Vector2i
	_recruit_left_source = false
	_recruit_shell_progress = 0.0
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
	_drag_texture = null
	var origin := from_local if from_local != Vector2.ZERO else _press_pos
	_start_drag_visual(origin)
	_update_recruit_drag_leave(origin)
	queue_redraw()


func _begin_recruit_item_drag(index: int, from_local: Vector2 = Vector2.ZERO) -> void:
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
	_drag_radius = 0.7
	_drag_visual_half_width = 0.0
	_drag_visual_half_height = 0.0
	_drag_label = String(info.get("label", item.get_display_name()))
	_drag_unit_id = ""
	_drag_texture = _recruit_prop_texture(item.id)
	var origin := from_local if from_local != Vector2.ZERO else _press_pos
	_start_drag_visual(origin)
	queue_redraw()


func _finish_recruit_item_drag(cell: Vector2i) -> void:
	var index := _recruit_item_drag_index
	_recruit_item_drag_index = -1
	_recruit_item_press_index = -1
	_drag_active = false
	_finish_drag_visual(cell)
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
	var source := _recruit_drag_source_cell
	var left_source := _recruit_left_source
	_recruit_drag_index = -1
	_recruit_press_index = -1
	_drag_active = false
	if index < 0:
		_reset_recruit_card_dissolve()
		_finish_drag_visual(cell)
		return
	var info: Dictionary = {}
	if index >= 0 and index < recruit_candidates.size():
		info = recruit_candidates[index]
	var affordable := bool(info.get("affordable", true))
	## 候选人拖到出售落点无效（与队伍拖卖分离）。
	if _is_recruit_sell_cell(cell):
		_bounce_recruit_card_drag(index, source, left_source)
		queue_redraw()
		return
	## 拖到锁定落点：切换锁定，不购买；纸片回席、卡再现。
	if _is_recruit_lock_cell(cell):
		recruit_candidate_lock.emit(index)
		_bounce_recruit_card_drag(index, source, left_source)
		queue_redraw()
		return
	var mid := BoardHalf.midline_row(board_size.y)
	if cell == NO_CELL or cell.y >= mid:
		_bounce_recruit_card_drag(index, source, left_source)
		queue_redraw()
		return
	var replace_id := _find_recruit_team_entry_at(cell)
	var seat_i := _find_recruit_team_seat_at(cell)
	## 候选人不可拖到已上场友方（避免误替换致旧人消失）；替换仅点选路径。
	if replace_id >= 0:
		recruit_drop_rejected.emit("occupied_seat")
		_bounce_recruit_card_drag(index, source, left_source)
		queue_redraw()
		return
	## 空席：指定空座；拖到非座位格则找最近空座；仍无则 seat=-1（点买优先上场）。
	if seat_i < 0 and recruit_team_slots != null:
		seat_i = recruit_team_slots.find_nearest_empty_slot(cell)
		if seat_i >= 0:
			var sc := recruit_team_slots.get_cell(seat_i)
			if absi(sc.x - cell.x) + absi(sc.y - cell.y) > 4:
				seat_i = -1
	## 买不起：预览拖后必回弹+卡再现（仍发 drop 让控制器提示，session 不扣费）。
	if not affordable:
		recruit_drop.emit(index, -1, seat_i)
		_bounce_recruit_card_drag(index, source, left_source)
		queue_redraw()
		return
	## 成功落座路径：跟手落向目标；货架槽由 sync 清空，卡不再现。
	_reset_recruit_card_dissolve()
	_finish_drag_visual(cell)
	recruit_drop.emit(index, -1, seat_i)
	queue_redraw()


func _bounce_recruit_card_drag(index: int, source: Vector2i, left_source: bool) -> void:
	if not left_source:
		## 未离源格：尚未拆卡，直接收起跟手，源位仍是卡+人。
		_reset_recruit_card_dissolve()
		_clear_drag_visual()
		return
	_recruit_restore_index = index
	_recruit_left_source = true
	_recruit_shell_progress = 1.0
	_kill_recruit_shell_tween()
	var settle_cell := source if source != NO_CELL else _recruit_candidate_cell(index)
	_finish_drag_visual(settle_cell)


func _begin_recruit_team_drag(entry_id: int, from_local: Vector2 = Vector2.ZERO) -> void:
	if entry_id < 0:
		return
	var entry := _find_deck_entry_on_board_or_bench(entry_id)
	if entry == null:
		return
	_recruit_team_drag_id = entry_id
	_recruit_team_press_id = -1
	_bench_press_id = -1
	_recruit_drag_index = -1
	_recruit_press_index = -1
	_drag_active = true
	var stats := entry.unit.stats if entry.unit != null else null
	_drag_radius = stats.body_radius if stats != null else 0.7
	_drag_visual_half_width = stats.get_visual_half_width() if stats != null else 0.0
	_drag_visual_half_height = stats.get_visual_half_height() if stats != null else 0.0
	_drag_label = entry.get_display_name()
	_drag_unit_id = entry.get_unit_id()
	_drag_texture = null
	recruit_sell_preview_gold = DeckUpgradeService.get_sell_price(entry)
	var origin := from_local if from_local != Vector2.ZERO else _press_pos
	_start_drag_visual(origin)
	queue_redraw()


func _finish_recruit_team_drag(cell: Vector2i, release_local: Vector2 = Vector2.ZERO) -> void:
	var entry_id := _recruit_team_drag_id
	_recruit_team_drag_id = -1
	_recruit_team_press_id = -1
	_bench_press_id = -1
	_drag_active = false
	recruit_sell_preview_gold = 0
	_finish_drag_visual(cell)
	if entry_id < 0:
		queue_redraw()
		return
	if _is_recruit_sell_cell(cell):
		recruit_sell.emit(entry_id)
		queue_redraw()
		return
	var release_pos := release_local if release_local != Vector2.ZERO else get_local_mouse_position()
	## 精确命中座位（换座 / 备战上阵）；中缝备战须优先于「最近空座」吸附，
	## 否则松手在 midline 备战会被上区后排空座抢走。
	var seat_i := _find_recruit_team_seat_at(cell)
	if seat_i >= 0:
		recruit_team_seat_drop.emit(entry_id, seat_i)
	elif is_pointer_over_bench(release_pos):
		var bench_i := find_bench_slot_at_local(release_pos)
		recruit_team_bench_drop.emit(entry_id, bench_i)
	elif recruit_team_slots != null:
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
		if info.get("item") == null:
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


## 准备阶段可拖已入座角色换座（开战 / 目录 / 其它半场模式除外）。
func _can_prepare_seat_drag() -> bool:
	return (
		prepare_slots != null
		and not catalog_active
		and not recruit_active
		and not map_shop_active
		and not enchant_active
		and (sim == null or not sim.has_started())
	)


func _can_drag_prepare_or_bench() -> bool:
	if catalog_active or map_shop_active or enchant_active:
		return false
	if recruit_active:
		return bench_interactive
	return _can_prepare_seat_drag() or (bench_visible and bench_interactive)


func _find_deck_entry_on_board_or_bench(entry_id: int) -> DeckEntry:
	if entry_id < 0:
		return null
	if prepare_slots != null:
		for i in prepare_slots.slot_count:
			var e := prepare_slots.get_entry(i)
			if e != null and e.entry_id == entry_id:
				return e
	if recruit_team_slots != null:
		for i in recruit_team_slots.slot_count:
			var re := recruit_team_slots.get_entry(i)
			if re != null and re.entry_id == entry_id:
				return re
	if bench_slots != null:
		for i in bench_slots.slot_count:
			var be := bench_slots.get_entry(i)
			if be != null and be.entry_id == entry_id:
				return be
	return null


func _find_prepare_team_entry_at(cell: Vector2i) -> int:
	if prepare_slots == null or cell == NO_CELL:
		return -1
	var slot_i := prepare_slots.find_slot_at_cell(cell)
	if slot_i < 0:
		return -1
	var entry := prepare_slots.get_entry(slot_i)
	if entry == null:
		return -1
	return entry.entry_id


func _find_prepare_team_seat_at(cell: Vector2i) -> int:
	if prepare_slots == null or cell == NO_CELL:
		return -1
	return prepare_slots.find_slot_at_cell(cell)


func _begin_prepare_team_drag(entry_id: int, from_local: Vector2 = Vector2.ZERO) -> void:
	if entry_id < 0 or not _can_drag_prepare_or_bench():
		return
	var entry := _find_deck_entry_on_board_or_bench(entry_id)
	if entry == null:
		return
	_prepare_team_drag_id = entry_id
	_prepare_team_press_id = -1
	_bench_press_id = -1
	_drag_active = true
	var stats := entry.unit.stats if entry.unit != null else null
	_drag_radius = stats.body_radius if stats != null else 0.7
	_drag_visual_half_width = stats.get_visual_half_width() if stats != null else 0.0
	_drag_visual_half_height = stats.get_visual_half_height() if stats != null else 0.0
	_drag_label = entry.get_display_name()
	_drag_unit_id = entry.get_unit_id()
	_drag_texture = null
	var origin := from_local if from_local != Vector2.ZERO else _press_pos
	_start_drag_visual(origin)
	queue_redraw()


func _finish_prepare_team_drag(cell: Vector2i, release_local: Vector2 = Vector2.ZERO) -> void:
	var entry_id := _prepare_team_drag_id
	_prepare_team_drag_id = -1
	_prepare_team_press_id = -1
	_bench_press_id = -1
	_drag_active = false
	_finish_drag_visual(cell)
	if entry_id < 0:
		queue_redraw()
		return
	var release_pos := release_local if release_local != Vector2.ZERO else get_local_mouse_position()
	## 精确座位优先；备战命中次之；最近空座吸附垫底（与招募同序）。
	var seat_i := _find_prepare_team_seat_at(cell)
	if seat_i >= 0:
		prepare_team_seat_drop.emit(entry_id, seat_i)
	elif is_pointer_over_bench(release_pos):
		var bench_i := find_bench_slot_at_local(release_pos)
		prepare_team_bench_drop.emit(entry_id, bench_i)
	elif prepare_slots != null:
		seat_i = prepare_slots.find_nearest_empty_slot(cell)
		if seat_i >= 0:
			var sc := prepare_slots.get_cell(seat_i)
			if absi(sc.x - cell.x) + absi(sc.y - cell.y) > 4:
				seat_i = -1
		if seat_i >= 0:
			prepare_team_seat_drop.emit(entry_id, seat_i)
	queue_redraw()


## 兼容旧 Dock 接管路径；备战已迁入 Arena 后一般不再需要。
func take_active_prepare_team_drag() -> int:
	var entry_id := _prepare_team_drag_id
	if entry_id < 0:
		return -1
	_prepare_team_drag_id = -1
	_prepare_team_press_id = -1
	_bench_press_id = -1
	_drag_active = false
	_finish_drag_visual(NO_CELL)
	queue_redraw()
	return entry_id


## 兼容旧 Dock 接管路径；备战已迁入 Arena 后一般不再需要。
func take_active_recruit_team_drag() -> int:
	var entry_id := _recruit_team_drag_id
	if entry_id < 0:
		return -1
	_recruit_team_drag_id = -1
	_recruit_team_press_id = -1
	_bench_press_id = -1
	_drag_active = false
	recruit_sell_preview_gold = 0
	_finish_drag_visual(NO_CELL)
	queue_redraw()
	return entry_id


func _draw_prepare_team_seat_hint(px: float) -> void:
	var cell := _hover_cell
	if cell == NO_CELL:
		return
	var seat_i := _find_prepare_team_seat_at(cell)
	var ok := seat_i >= 0
	var cell_rect := Rect2(get_board_rect().position + Vector2(cell) * px, Vector2(px, px))
	draw_rect(cell_rect, Color(0.45, 0.85, 1.0, 0.4) if ok else Color(1.0, 0.25, 0.2, 0.25))
	if _drag_visual_alive:
		return
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


func _find_map_shop_offer_at(cell: Vector2i) -> int:
	if cell == NO_CELL:
		return -1
	for i in map_shop_offers.size():
		var info: Variant = map_shop_offers[i]
		if not (info is Dictionary):
			continue
		var c: Vector2i = (info as Dictionary).get("cell", NO_CELL)
		if c == cell and (info as Dictionary).get("item") != null:
			return i
	return -1


func _begin_map_shop_offer_drag(index: int, from_local: Vector2 = Vector2.ZERO) -> void:
	if index < 0 or index >= map_shop_offers.size():
		return
	var info: Dictionary = map_shop_offers[index]
	if info.get("item") == null:
		return
	_map_shop_offer_drag_index = index
	_map_shop_offer_press_index = -1
	_map_shop_team_drag_id = -1
	_map_shop_team_press_id = -1
	_drag_active = true
	_drag_radius = 0.55
	_drag_visual_half_width = 0.0
	_drag_visual_half_height = 0.0
	_drag_label = String(info.get("label", ""))
	_drag_unit_id = ""
	_drag_texture = info.get("icon") as Texture2D
	var origin := from_local if from_local != Vector2.ZERO else _press_pos
	_start_drag_visual(origin)
	queue_redraw()


func _finish_map_shop_offer_drag(cell: Vector2i) -> void:
	var index := _map_shop_offer_drag_index
	_map_shop_offer_drag_index = -1
	_map_shop_offer_press_index = -1
	_drag_active = false
	_finish_drag_visual(cell)
	if index < 0 or index >= map_shop_offers.size():
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
	var info: Dictionary = map_shop_offers[index]
	var kind: StringName = info.get("kind", &"consumable")
	var slot_index := int(info.get("index", -1))
	map_shop_offer_drop.emit(kind, slot_index, entry_id)
	queue_redraw()


func _begin_map_shop_team_drag(entry_id: int, from_local: Vector2 = Vector2.ZERO) -> void:
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
	_map_shop_team_drag_id = entry_id
	_map_shop_team_press_id = -1
	_map_shop_offer_drag_index = -1
	_map_shop_offer_press_index = -1
	_drag_active = true
	var stats := entry.unit.stats if entry.unit != null else null
	_drag_radius = stats.body_radius if stats != null else 0.7
	_drag_visual_half_width = stats.get_visual_half_width() if stats != null else 0.0
	_drag_visual_half_height = stats.get_visual_half_height() if stats != null else 0.0
	_drag_label = entry.get_display_name()
	_drag_unit_id = entry.get_unit_id()
	_drag_texture = null
	var origin := from_local if from_local != Vector2.ZERO else _press_pos
	_start_drag_visual(origin)
	queue_redraw()


func _finish_map_shop_team_drag(cell: Vector2i) -> void:
	var entry_id := _map_shop_team_drag_id
	_map_shop_team_drag_id = -1
	_map_shop_team_press_id = -1
	_drag_active = false
	_finish_drag_visual(cell)
	if entry_id < 0:
		queue_redraw()
		return
	var seat_i := _find_recruit_team_seat_at(cell)
	if seat_i < 0 and recruit_team_slots != null:
		seat_i = recruit_team_slots.find_nearest_empty_slot(cell)
		if seat_i >= 0:
			var sc := recruit_team_slots.get_cell(seat_i)
			if absi(sc.x - cell.x) + absi(sc.y - cell.y) > 4:
				seat_i = -1
	if seat_i >= 0:
		map_shop_team_seat_drop.emit(entry_id, seat_i)
	queue_redraw()


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
		_drag_texture = null
		_hover_cell = tile_to_cell(local_to_tile(at_position))
		_ensure_external_drag_visual(at_position)
		return true
	if not dict.has(DRAG_KEY):
		return false
	_drag_active = true
	_drag_radius = float(dict.get("radius", 0.7))
	_drag_visual_half_width = float(dict.get("visual_half_width", 0.0))
	_drag_visual_half_height = float(dict.get("visual_half_height", 0.0))
	_drag_label = String(dict.get("label", ""))
	_drag_unit_id = String(dict.get("unit_id", ""))
	_drag_texture = null
	_hover_cell = tile_to_cell(local_to_tile(at_position))
	_ensure_external_drag_visual(at_position)
	return true


func _ensure_external_drag_visual(at_position: Vector2) -> void:
	## 手牌原生拖入：预览由 RealtimeHandCard.DragGhost（Tween）负责；
	## 棋盘只更新落点高亮，避免与系统拖影叠画。
	_drag_pointer = at_position


func _drop_data(at_position: Vector2, data: Variant) -> void:
	_drag_active = false
	var cell := tile_to_cell(local_to_tile(at_position))
	_finish_drag_visual(cell)
	var dict := data as Dictionary
	if dict.has(RECRUIT_CANDIDATE_KEY) and recruit_active:
		var index := int(dict[RECRUIT_CANDIDATE_KEY])
		_recruit_drag_index = -1
		var mid := BoardHalf.midline_row(board_size.y)
		if cell == NO_CELL or cell.y >= mid:
			return
		var replace_id := _find_recruit_team_entry_at(cell)
		var seat_i := _find_recruit_team_seat_at(cell)
		## 与 _finish_recruit_drag 一致：已占座拒绝，不静默替换。
		if replace_id >= 0:
			recruit_drop_rejected.emit("occupied_seat")
			return
		if seat_i < 0 and recruit_team_slots != null:
			seat_i = recruit_team_slots.find_nearest_empty_slot(cell)
			if seat_i >= 0:
				var sc := recruit_team_slots.get_cell(seat_i)
				if absi(sc.x - cell.x) + absi(sc.y - cell.y) > 4:
					seat_i = -1
		recruit_drop.emit(index, -1, seat_i)
		return
	card_dropped.emit(int(dict[DRAG_KEY]), local_to_tile(at_position))


# --- 绘制 ---


func reset_half_slide() -> void:
	enemy_half_slide_y = 0.0
	ally_half_slide_y = 0.0
	bench_slide_y = 0.0
	queue_redraw()


func clear_enchant_mode() -> void:
	_cancel_press()
	enchant_active = false
	enchant_forge_previews.clear()
	enchant_team_scroll_rows = 0.0
	enchant_team_scroll_enabled = false
	enchant_team_max_scroll_rows = 0.0
	_enchant_team_drag_id = -1
	_enchant_team_press_id = -1
	_enchant_team_pan_active = false
	_enchant_team_pan_last_y = 0.0
	_enchant_forge_press = false
	_clear_drag_visual()
	queue_redraw()


func clear_map_shop_mode() -> void:
	_cancel_press()
	map_shop_active = false
	map_shop_offers.clear()
	recruit_team_slots = null
	_map_shop_offer_drag_index = -1
	_map_shop_offer_press_index = -1
	_map_shop_team_drag_id = -1
	_map_shop_team_press_id = -1
	_clear_drag_visual()
	queue_redraw()


func clear_recruit_mode() -> void:
	_cancel_press()
	recruit_active = false
	## 地图商店复用 recruit_team_slots 画上半场；清招募时勿误清商店。
	if not map_shop_active:
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
	_reset_recruit_card_dissolve()
	_recruit_item_drag_index = -1
	_recruit_item_press_index = -1
	_recruit_team_drag_id = -1
	_recruit_team_press_id = -1
	_recruit_empty_seat_press = -1
	clear_party_bark()
	_clear_drag_visual()
	queue_redraw()


## 角色库：把单位按列铺满棋盘，沿用战斗剪影 / 攻血标 / 长按技能卡。
## preview_level：1=一星，2=三合一预览（攻血×3、技能按星级缩放）。
## 远征统计等：一行展示队伍成员（攻血与招募队伍区一致）。
func set_catalog_deck_entries(
	entries: Array[DeckEntry],
	columns: int = 5,
	plain_backdrop: bool = false,
) -> void:
	_cancel_press()
	clear_recruit_mode()
	sim = null
	prepare_slots = null
	enemy_slots = null
	enemy_previews.clear()
	catalog_active = true
	catalog_plain_backdrop = plain_backdrop
	catalog_preview_level = 1
	catalog_units.clear()
	var cols := maxi(1, columns)
	var placed := 0
	for entry in entries:
		if entry == null or entry.unit == null:
			continue
		catalog_units.append({
			"deck_entry": entry,
			"cell": Vector2i(placed % cols, int(placed / cols)),
		})
		placed += 1
	var rows := maxi(1, int(ceili(float(maxi(1, placed)) / float(cols))))
	board_size = Vector2i(cols, rows)
	queue_redraw()


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
	catalog_plain_backdrop = false
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
	## 背景不随半场 slide，保证胜→招募同屏背景不断；纯目录模式不画场景底。
	if not (catalog_active and catalog_plain_backdrop):
		draw_texture_rect(ARENA_BACKGROUND, _get_background_rect().grow(SHAKE_BLEED_PX), false)
	## 半场色调与单位/座位随内容滑动；角色库用统一淡色；纯目录只留透明底给卡牌格。
	if catalog_active and catalog_plain_backdrop:
		pass
	elif catalog_active:
		draw_rect(Rect2(rect.position, rect.size), PLAYER_TINT)
	else:
		draw_rect(Rect2(rect.position + enemy_off, Vector2(rect.size.x, mid * px)), ENEMY_TINT)
		draw_rect(
			Rect2(rect.position + Vector2(0, mid * px) + ally_off, Vector2(rect.size.x, (board_size.y - mid) * px)),
			PLAYER_TINT,
		)

	var showing_placement := (
		(placement_active or _drag_active)
		and not recruit_active
		and not map_shop_active
		and not catalog_active
	)
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
	elif enchant_active:
		_draw_enchant_zone_labels(px, mid, enemy_off, ally_off)
		_draw_enchant_forge(px, enemy_off)
		_draw_prepare_slots(px)
		if _enchant_team_drag_id >= 0 and _hover_cell != NO_CELL:
			if _hover_cell.y < mid:
				_draw_enchant_forge_drop_hint(px, enemy_off)
			else:
				_draw_enchant_team_seat_hint(px)
	elif map_shop_active:
		_draw_map_shop_zone_labels(px, mid, enemy_off, ally_off)
		_draw_recruit_team(px, enemy_off)
		_draw_map_shop_offers(px, ally_off)
		if _map_shop_offer_drag_index >= 0 and _hover_cell != NO_CELL:
			_draw_map_shop_offer_drop_hint(px, mid)
		elif _map_shop_team_drag_id >= 0 and _hover_cell != NO_CELL:
			_draw_map_shop_team_seat_hint(px)
	elif recruit_active:
		_draw_recruit_zone_labels(px, mid, enemy_off, ally_off)
		_draw_recruit_team(px, enemy_off)
		## 备战在中缝、候选在下半场：先画备战再画候选，避免纸片盖住招募席。
		_draw_bench_row(px)
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
		_draw_prepare_slots(px)
		if _prepare_team_drag_id >= 0 and _hover_cell != NO_CELL:
			_draw_prepare_team_seat_hint(px)

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
	## 备战行：准备/战斗在友方半场下方；招募已在候选之前绘制。
	if not recruit_active:
		_draw_bench_row(px)
	_draw_fx(px)
	_draw_feedback(px)
	if showing_placement and _hover_cell != NO_CELL:
		_draw_ghost(px, mid)
	if _drag_visual_alive:
		_draw_drag_follower(px)


func _draw_enchant_zone_labels(px: float, mid: int, enemy_off: Vector2, ally_off: Vector2) -> void:
	var rect := get_board_rect()
	var font := get_theme_default_font()
	var font_size := clampi(int(px * 0.55), 11, 18)
	var top_pos := rect.position + enemy_off + Vector2(px * 0.25, px * 0.7)
	var bot_pos := rect.position + ally_off + Vector2(px * 0.25, float(mid) * px + px * 0.7)
	draw_string(font, top_pos, "附魔台", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.75, 0.90, 1.0, 0.9))
	draw_string(font, bot_pos, "队伍", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.92, 0.96, 1.0, 0.9))


func _draw_enchant_forge(px: float, off: Vector2) -> void:
	var rect := get_board_rect()
	var font := get_theme_default_font()
	var font_size := clampi(int(px * 0.38), 9, 14)
	var ordered := enchant_forge_previews.duplicate()
	if _info_shown:
		var focus_key := String(_shown_info.get("inspect_key", ""))
		if focus_key.begins_with("enchant_forge:"):
			var focus_idx := int(focus_key.get_slice(":", 1))
			if focus_idx >= 0 and focus_idx < ordered.size():
				var focus_item: Variant = ordered[focus_idx]
				ordered.remove_at(focus_idx)
				ordered.append(focus_item)
	for item in ordered:
		if item is not Dictionary:
			continue
		var cell: Vector2i = item.get("cell", NO_CELL)
		if cell == NO_CELL:
			continue
		var cell_rect := Rect2(rect.position + Vector2(cell) * px + off, Vector2(px, px))
		var label: String = item.get("label", "")
		var entry: DeckEntry = item.get("entry", null)
		if entry != null and entry.unit != null:
			var center_tile := Vector2(cell) + Vector2(0.5, 0.5)
			_draw_body(
				center_tile,
				0.65,
				0.0,
				0.0,
				Color(0.55, 0.75, 0.95),
				0.85,
				entry.get_display_name(),
				px,
				true,
				off,
				true,
				entry.get_unit_id(),
			)
			_draw_stat_badges(
				tile_to_local(center_tile) + off,
				DeckUpgradeService.get_display_attack(entry),
				DeckUpgradeService.get_display_max_hp(entry),
				0.95,
				px,
				entry.get_armor_block(),
			)
		if not label.is_empty():
			var pos := cell_rect.position + Vector2(px * 0.05, px * 0.12)
			draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.85))


func _draw_recruit_zone_labels(px: float, mid: int, enemy_off: Vector2, ally_off: Vector2) -> void:
	var rect := get_board_rect()
	var font := get_theme_default_font()
	var font_size := clampi(int(px * 0.55), 11, 18)
	var top_pos := rect.position + enemy_off + Vector2(px * 0.25, px * 0.7)
	var bot_pos := rect.position + ally_off + Vector2(px * 0.25, float(mid) * px + px * 0.7)
	draw_string(font, top_pos, "队伍", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.92, 0.96, 1.0, 0.9))
	draw_string(font, bot_pos, "招募商店", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.95, 0.75, 0.9))


func _draw_map_shop_zone_labels(px: float, mid: int, enemy_off: Vector2, ally_off: Vector2) -> void:
	var rect := get_board_rect()
	var font := get_theme_default_font()
	var font_size := clampi(int(px * 0.55), 11, 18)
	var top_pos := rect.position + enemy_off + Vector2(px * 0.25, px * 0.7)
	var bot_pos := rect.position + ally_off + Vector2(px * 0.25, float(mid) * px + px * 0.7)
	draw_string(font, top_pos, "队伍", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.92, 0.96, 1.0, 0.9))
	draw_string(font, bot_pos, "商店货架", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.95, 0.75, 0.9))


func _draw_map_shop_offers(px: float, off: Vector2) -> void:
	var indices: Array[int] = []
	for i in map_shop_offers.size():
		indices.append(i)
	## 长按详情时把焦点货架纸片画到最后，抬起不被邻格挡住。
	if _info_shown:
		var focus_key := String(_shown_info.get("inspect_key", ""))
		if focus_key.begins_with("map_shop_offer:"):
			var focus_idx := int(focus_key.get_slice(":", 1))
			var at := indices.find(focus_idx)
			if at >= 0:
				indices.remove_at(at)
				indices.append(focus_idx)
	for i in indices:
		var info: Variant = map_shop_offers[i]
		if not (info is Dictionary):
			continue
		var dict := info as Dictionary
		var cell: Vector2i = dict.get("cell", NO_CELL)
		if cell == NO_CELL:
			continue
		var item: Variant = dict.get("item")
		if item == null:
			continue
		var alpha := 0.4 if i == _map_shop_offer_drag_index else 1.0
		var icon: Texture2D = dict.get("icon") as Texture2D
		var label := String(dict.get("label", ""))
		var center_tile := Vector2(cell) + Vector2(0.5, 0.5)
		## 与角色同路径：纸片剪影 + 接触阴影；详请走长按信息卡。
		_draw_body(
			center_tile,
			0.55,
			0.0,
			0.0,
			PLAYER_COLOR,
			alpha,
			label,
			px,
			true,
			off,
			true,
			"",
			null,
			Vector2.ZERO,
			1.0,
			_idle_seed_for("map_shop:%d" % i, i),
			icon,
		)
		var cost := int(dict.get("cost", 0))
		var affordable := bool(dict.get("affordable", true))
		_draw_recruit_cost_tag(tile_to_local(center_tile) + off, cost, affordable, px)


func _draw_map_shop_offer_drop_hint(px: float, mid: int) -> void:
	var cell := _hover_cell
	if cell == NO_CELL:
		return
	var cell_rect := Rect2(get_board_rect().position + Vector2(cell) * px, Vector2(px, px))
	if cell.y >= mid:
		draw_rect(cell_rect, Color(1.0, 0.25, 0.2, 0.3))
		return
	var ok := _find_recruit_team_entry_at(cell) >= 0
	draw_rect(cell_rect, Color(0.35, 0.95, 0.65, 0.4) if ok else Color(1.0, 0.25, 0.2, 0.3))
	if _drag_visual_alive:
		return
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
		null,
		Vector2.ZERO,
		1.0,
		-1,
		_drag_texture,
	)


func _draw_map_shop_team_seat_hint(px: float) -> void:
	var cell := _hover_cell
	if cell == NO_CELL:
		return
	var seat_i := _find_recruit_team_seat_at(cell)
	var cell_rect := Rect2(get_board_rect().position + Vector2(cell) * px, Vector2(px, px))
	var ok := seat_i >= 0
	draw_rect(cell_rect, Color(0.35, 0.85, 1.0, 0.4) if ok else Color(1.0, 0.25, 0.2, 0.3))


func _draw_recruit_sell_slot(px: float, off: Vector2) -> void:
	if recruit_sell_cell == NO_CELL:
		return
	var rect := get_board_rect()
	var cell_rect := Rect2(rect.position + Vector2(recruit_sell_cell) * px + off, Vector2(px, px))
	var hot := _recruit_team_drag_id >= 0 and _hover_cell == recruit_sell_cell
	if hot:
		draw_rect(cell_rect, RECRUIT_SELL_HOT)
	var center_tile := Vector2(recruit_sell_cell) + Vector2(0.5, 0.5)
	_draw_recruit_prop(center_tile, RECRUIT_TEX_SELL, 1.0, px, off, _idle_seed_for("recruit_sell", 0))
	if hot and recruit_sell_preview_gold > 0:
		var font := get_theme_default_font()
		var font_size := clampi(int(px * 0.36), 10, 16)
		var label := "+%d金" % recruit_sell_preview_gold
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var pos := cell_rect.position + Vector2(
			(cell_rect.size.x - text_size.x) * 0.5,
			cell_rect.size.y - px * 0.06,
		)
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.92, 0.45, 0.98))


func _draw_recruit_lock_slot(px: float, off: Vector2) -> void:
	if recruit_lock_cell == NO_CELL:
		return
	var rect := get_board_rect()
	var cell_rect := Rect2(rect.position + Vector2(recruit_lock_cell) * px + off, Vector2(px, px))
	var hot := _recruit_drag_index >= 0 and _hover_cell == recruit_lock_cell
	if hot:
		draw_rect(cell_rect, RECRUIT_LOCK_HOT)
	var center_tile := Vector2(recruit_lock_cell) + Vector2(0.5, 0.5)
	_draw_recruit_prop(center_tile, RECRUIT_TEX_LOCK, 1.0, px, off, _idle_seed_for("recruit_lock", 1))
	if not hot:
		return
	var label := "锁定"
	if _recruit_drag_index >= 0 and _recruit_drag_index < recruit_candidates.size():
		var info: Dictionary = recruit_candidates[_recruit_drag_index]
		if bool(info.get("locked", false)):
			label = "解锁"
	var font := get_theme_default_font()
	var font_size := clampi(int(px * 0.36), 10, 16)
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := cell_rect.position + Vector2(
		(cell_rect.size.x - text_size.x) * 0.5,
		cell_rect.size.y - px * 0.06,
	)
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.95, 0.75, 0.98))


func _draw_recruit_team_sell_hint(px: float) -> void:
	var cell := _hover_cell
	if cell == NO_CELL:
		return
	var cell_rect := Rect2(get_board_rect().position + Vector2(cell) * px, Vector2(px, px))
	var ok := _is_recruit_sell_cell(cell)
	draw_rect(cell_rect, Color(0.85, 0.45, 0.9, 0.4) if ok else Color(1.0, 0.25, 0.2, 0.25))
	if _drag_visual_alive:
		return
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
	if _drag_visual_alive:
		return
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
	var occupied_indices: Array[int] = []
	for i in recruit_team_slots.cells.size():
		var entry: DeckEntry = recruit_team_slots.get_entry(i)
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
		var dragging := (
			entry.entry_id == _recruit_team_drag_id or entry.entry_id == _map_shop_team_drag_id
		)
		var alpha := DRAG_SOURCE_ALPHA if dragging else 0.9
		var merge_pose: RealtimeUnitMotion.Pose = null
		var idle_seed := _idle_seed_for(entry.get_unit_id(), i)
		if _merge_active and i == _merge_survivor_seat:
			merge_pose = RealtimeUnitMotion.Pose.new()
			merge_pose.scale = Vector2.ONE * _merge_survivor_scale
			merge_pose.flash = _merge_survivor_flash
			merge_pose.shadow_mul = 1.0 + 0.55 * _merge_survivor_flash
			idle_seed = -1
		_draw_body(
			center_tile, radius, vwx, vhy, PLAYER_COLOR, alpha, entry.get_display_name(), px, true, off,
			true, entry.get_unit_id(), merge_pose, Vector2.ZERO, 1.0, idle_seed,
		)
		var atk := 0
		var hp := 0
		if stats != null:
			atk = maxi(1, stats.attack + entry.bonus_attack)
			hp = maxi(1, stats.max_hp + entry.bonus_max_hp)
		_draw_stat_badges(
			tile_to_local(center_tile) + off, atk, hp, alpha, px, entry.get_armor_block()
		)
	if _merge_active:
		_draw_merge_fx(px, off)


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
		var deck_entry: DeckEntry = info.get("deck_entry") as DeckEntry
		var unit: UnitData = info.get("unit") as UnitData
		if deck_entry != null:
			unit = deck_entry.unit
		if cell == NO_CELL or unit == null:
			continue
		var cell_rect := Rect2(rect.position + Vector2(cell) * px, Vector2(px, px))
		## 纯目录：卡牌底板略厚，贴近角色库可读性。
		if catalog_plain_backdrop:
			draw_rect(cell_rect.grow(-2.0), Color(0.14, 0.17, 0.22, 0.95))
			draw_rect(cell_rect.grow(-2.0), Color(0.55, 0.48, 0.32, 0.75), false, 2.0)
		else:
			draw_rect(cell_rect, RECRUIT_CAND_EMPTY)
			draw_rect(cell_rect, Color(RECRUIT_CAND_BORDER, 0.35), false, 1.0)
		var center_tile := Vector2(cell) + Vector2(0.5, 0.5)
		var stats := unit.stats
		var radius := stats.body_radius if stats != null else 0.7
		var vwx := stats.get_visual_half_width() if stats != null else 0.0
		var vhy := stats.get_visual_half_height() if stats != null else 0.0
		var label := (
			deck_entry.get_display_name() if deck_entry != null else unit.display_name
		)
		var unit_id := deck_entry.get_unit_id() if deck_entry != null else unit.id
		_draw_body(
			center_tile, radius, vwx, vhy, PLAYER_COLOR, 0.95, label, px, true, Vector2.ZERO,
			true, unit_id, null, Vector2.ZERO, 1.0, _idle_seed_for(unit_id, cell.x + cell.y * 8),
		)
		var atk := 0
		var hp := 0
		var armor := 0
		if deck_entry != null and stats != null:
			atk = maxi(1, stats.attack + deck_entry.bonus_attack)
			hp = maxi(1, stats.max_hp + deck_entry.bonus_max_hp)
			armor = deck_entry.get_armor_block()
		else:
			var preview_mult := UnitInfoText.catalog_preview_stat_mult(catalog_preview_level)
			atk = (stats.attack if stats != null else 0) * preview_mult
			hp = (stats.max_hp if stats != null else 0) * preview_mult
		_draw_stat_badges(tile_to_local(center_tile), atk, hp, 0.95, px, armor)


func _draw_merge_fx(px: float, off: Vector2) -> void:
	if not _merge_active:
		return
	## 残影飞向合成座。
	for ghost in _merge_ghosts:
		var t := clampf(float(ghost.get("t", 0.0)), 0.0, 1.0)
		var from_c: Vector2i = ghost.get("from", NO_CELL)
		var to_c: Vector2i = ghost.get("to", NO_CELL)
		if from_c == NO_CELL or to_c == NO_CELL:
			continue
		var from_tile := Vector2(from_c) + Vector2(0.5, 0.5)
		var to_tile := Vector2(to_c) + Vector2(0.5, 0.5)
		var tile := from_tile.lerp(to_tile, t)
		var ghost_alpha := (1.0 - t) * 0.72
		if ghost_alpha <= 0.02:
			continue
		_draw_body(
			tile, 0.7, 0.0, 0.0, PLAYER_COLOR, ghost_alpha, "", px, true, off,
			true, _merge_unit_id, null, Vector2.ZERO, 1.0, -1,
		)
	if _merge_survivor_seat < 0 or _merge_survivor_seat >= recruit_team_slots.cells.size():
		return
	var dest_cell: Vector2i = recruit_team_slots.cells[_merge_survivor_seat]
	var dest_center := tile_to_local(Vector2(dest_cell) + Vector2(0.5, 0.5)) + off
	## 冲击环。
	if _merge_ring > 0.02:
		var ring_r := px * (0.35 + _merge_ring * 0.95)
		var ring_a := (1.0 - _merge_ring) * 0.85
		draw_arc(
			dest_center, ring_r, 0.0, TAU, 36,
			Color(1.0, 0.92, 0.45, ring_a), maxf(2.0, px * 0.08), true
		)
		draw_arc(
			dest_center, ring_r * 0.72, 0.0, TAU, 28,
			Color(1.0, 0.98, 0.8, ring_a * 0.55), maxf(1.5, px * 0.05), true
		)
	## 星级标。
	if _merge_label_alpha > 0.02 and _merge_level >= 2:
		var font := get_theme_default_font()
		var label := "%d★" % _merge_level
		var font_size := clampi(int(px * 0.55), 16, 36)
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var lift := px * (0.55 + 0.2 * _merge_ring)
		var pos := dest_center + Vector2(-text_size.x * 0.5, -lift)
		draw_string(
			font, pos + Vector2(1.5, 1.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			Color(0.1, 0.08, 0.05, _merge_label_alpha * 0.55)
		)
		draw_string(
			font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			Color(1.0, 0.92, 0.35, _merge_label_alpha)
		)


func _draw_recruit_candidates(px: float, off: Vector2) -> void:
	## 统一卡壳（ColorRect + dissolve shader）画在父节点背后；此处只同步并画居中角色。
	_sync_recruit_card_shells(px, off)
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
	var shell_sz := _recruit_candidate_shell_size(px)
	var badge := get_stat_badge_size(px)
	for info in ordered:
		if not (info is Dictionary):
			continue
		var cell: Vector2i = info.get("cell", NO_CELL)
		if cell == NO_CELL:
			continue
		var index := int(info.get("index", -1))
		var unit: UnitData = info.get("unit") as UnitData
		var locked := bool(info.get("locked", false))
		if unit == null:
			continue
		var dragging := index == _recruit_drag_index
		var restoring := index == _recruit_restore_index
		var center_tile := Vector2(cell) + Vector2(0.5, 0.5)
		var center_local := tile_to_local(center_tile) + off
		var stats := unit.stats
		var radius := stats.body_radius if stats != null else 0.7
		var vwx := stats.get_visual_half_width() if stats != null else 0.0
		var vhy := stats.get_visual_half_height() if stats != null else 0.0
		## 静置 / 源格内拖：卡+人；离格后源槽空；回席 settle 完再 shader 复卡。
		var hide_body := (dragging and _recruit_left_source) or (restoring and _drag_settling)
		if hide_body:
			continue
		var alpha := 0.95
		if restoring:
			alpha = clampf(1.0 - _recruit_shell_progress, 0.35, 0.95)
		_draw_body(
			center_tile, radius, vwx, vhy, PLAYER_COLOR.lightened(0.15), alpha, unit.display_name, px, true, off,
			true, unit.id, null, Vector2.ZERO, 1.0, _idle_seed_for(unit.id, index), null, true,
		)
		var atk := stats.attack if stats != null else 0
		var hp := stats.max_hp if stats != null else 0
		var cost := int(info.get("cost", 0))
		var affordable := bool(info.get("affordable", true))
		## 价签/攻血挂在统一卡壳下缘外侧（_draw_stat_badges 会再加 px*0.38）。
		var badge_anchor := Vector2(
			center_local.x,
			center_local.y + shell_sz.y * 0.5 - px * 0.38 + badge.y * 0.08,
		)
		_draw_stat_badges(
			badge_anchor, atk, hp, alpha, px, 0, cost, affordable
		)
		if locked:
			_draw_recruit_lock_tag(center_local + Vector2(0.0, -shell_sz.y * 0.42), px)


func _draw_recruit_cost_tag(center: Vector2, cost: int, affordable: bool, px: float) -> void:
	_draw_recruit_gold_badge(center, cost, affordable, 1.0, px)


func _draw_recruit_gold_badge(
	center: Vector2, cost: int, affordable: bool, alpha: float, px: float
) -> void:
	if STAT_GOLD_TEX == null:
		return
	var badge := get_stat_badge_size(px)
	var top := center.y + px * 0.38 + badge.y * 0.05
	var half_span := badge.x * 0.5
	var cx := clampf(center.x, half_span, maxf(half_span, size.x - half_span))
	var rect := Rect2(Vector2(cx - half_span, top), badge)
	var text_color := STAT_TEXT if affordable else Color(0.85, 0.22, 0.18, 1.0)
	_draw_stat_badge(rect, STAT_GOLD_TEX, cost, alpha, text_color)


func _draw_recruit_lock_tag(center: Vector2, px: float) -> void:
	var font := get_theme_default_font()
	var text := "锁"
	var font_size := clampi(int(px * 0.32), 9, 13)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := center + Vector2(px * 0.22 - text_size.x * 0.5, -px * 0.55)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.85, 0.3, 0.98))


func _draw_recruit_items(px: float, off: Vector2) -> void:
	for info in recruit_items:
		if not (info is Dictionary):
			continue
		var cell: Vector2i = info.get("cell", NO_CELL)
		if cell == NO_CELL:
			continue
		var index := int(info.get("index", -1))
		var item: PrepareItemData = info.get("item") as PrepareItemData
		if item == null:
			continue
		var alpha := 0.4 if index == _recruit_item_drag_index else 1.0
		var center_tile := Vector2(cell) + Vector2(0.5, 0.5)
		_draw_recruit_prop(
			center_tile,
			_recruit_prop_texture(item.id),
			alpha,
			px,
			off,
			_idle_seed_for(item.id, index),
		)
		var cost := int(info.get("cost", 0))
		var affordable := bool(info.get("affordable", true))
		_draw_recruit_cost_tag(tile_to_local(center_tile) + off, cost, affordable, px)


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
		if _drag_visual_alive:
			return
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
	## 已上场友方格：非法（候选人不可直接盖上去）；仅空座 / 空地上半场可绿。
	var ok := _find_recruit_team_entry_at(cell) < 0
	draw_rect(cell_rect, Color(0.35, 0.95, 0.45, 0.35) if ok else Color(1.0, 0.25, 0.2, 0.3))
	if _drag_visual_alive:
		return
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


func _draw_prepare_slots(px: float) -> void:
	if prepare_slots == null or prepare_slots.cells.is_empty():
		return
	## 开战后代打单位由模拟绘制；准备阶段只画占座角色，不再铺底色和线框。
	if sim != null and sim.has_started():
		return
	var scroll_y := 0.0
	if enchant_active and enchant_team_scroll_enabled:
		scroll_y = enchant_team_scroll_rows * px
	var off := Vector2(0.0, ally_half_slide_y - scroll_y)
	var occupied_indices: Array[int] = []
	for i in prepare_slots.cells.size():
		var entry: DeckEntry = prepare_slots.get_entry(i)
		if entry != null:
			occupied_indices.append(i)
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
		var dragging := (
			entry.entry_id == _enchant_team_drag_id or entry.entry_id == _prepare_team_drag_id
		)
		var alpha := DRAG_SOURCE_ALPHA if dragging else 0.9
		_draw_body(
			center_tile, radius, vwx, vhy, PLAYER_COLOR, alpha, entry.get_display_name(), px, true, off,
			true, entry.get_unit_id(), null, Vector2.ZERO, 1.0, _idle_seed_for(entry.get_unit_id(), i),
		)
		var atk := 0
		var hp := 0
		if stats != null:
			atk = maxi(1, stats.attack + entry.bonus_attack)
			hp = maxi(1, stats.max_hp + entry.bonus_max_hp)
		_draw_stat_badges(
			tile_to_local(center_tile) + off, atk, hp, alpha, px, entry.get_armor_block()
		)


func _draw_bench_row(px: float) -> void:
	if not bench_visible or bench_slots == null or bench_slots.cells.is_empty():
		return
	if catalog_active or map_shop_active or enchant_active:
		return
	var font := get_theme_default_font()
	var font_size := clampi(int(px * 0.32), 9, 13)
	var occupied_indices: Array[int] = []
	for i in bench_slots.cells.size():
		if bench_slots.get_entry(i) != null:
			occupied_indices.append(i)
	occupied_indices.sort_custom(func(a: int, b: int) -> bool:
		var ca := bench_slots.cells[a]
		var cb := bench_slots.cells[b]
		if ca.y != cb.y:
			return ca.y < cb.y
		return ca.x < cb.x
	)
	_bring_inspect_slot_to_front(occupied_indices, bench_slots, Vector2(0.0, bench_slide_y))
	## 空格淡底；已占按 y/x 排序后绘制（与准备席同口径）。
	for i in bench_slots.cells.size():
		if bench_slots.get_entry(i) != null:
			continue
		var center := bench_slot_center_local(i)
		var cell_rect := Rect2(center - Vector2(px, px) * 0.5, Vector2(px, px))
		draw_rect(cell_rect, Color(PLAYER_COLOR, 0.10))
		draw_rect(cell_rect, Color(0.85, 0.90, 1.0, 0.22), false, 1.0)
	for i in occupied_indices:
		var center := bench_slot_center_local(i)
		var entry: DeckEntry = bench_slots.get_entry(i)
		if entry == null:
			continue
		if bench_triple_merge_hint_entry_ids.get(entry.entry_id, false):
			_draw_bench_triple_merge_hint(center, px)
		var dragging := (
			entry.entry_id == _prepare_team_drag_id or entry.entry_id == _recruit_team_drag_id
		)
		var alpha := DRAG_SOURCE_ALPHA if dragging else (0.78 if not bench_interactive else 0.9)
		var stats := entry.unit.stats if entry.unit != null else null
		var radius := stats.body_radius if stats != null else 0.7
		var vwx := stats.get_visual_half_width() if stats != null else 0.0
		var vhy := stats.get_visual_half_height() if stats != null else 0.0
		## 用本地中心换算成虚拟 tile，复用 _draw_body / 徽章口径。
		var center_tile := local_to_tile(center)
		_draw_body(
			center_tile,
			radius,
			vwx,
			vhy,
			PLAYER_COLOR,
			alpha,
			entry.get_display_name(),
			px,
			true,
			Vector2.ZERO,
			true,
			entry.get_unit_id(),
			null,
			Vector2.ZERO,
			1.0,
			_idle_seed_for(entry.get_unit_id(), 100 + i),
		)
		var atk := DeckUpgradeService.get_display_attack(entry)
		var hp := DeckUpgradeService.get_display_max_hp(entry)
		_draw_stat_badges(center, atk, hp, alpha, px, entry.get_armor_block())
	## 小标签：备战
	var label_pos := bench_slot_center_local(0) + Vector2(-px * 0.45, -px * 0.62)
	draw_string(font, label_pos, "备战", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.92, 0.96, 1.0, 0.75))


func _draw_bench_triple_merge_hint(center: Vector2, px: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.5 + 0.5 * sin(t * 5.2)
	var ring_r := px * (0.38 + 0.08 * pulse)
	var outer := Color(1.0, 0.82, 0.22, 0.22 + 0.28 * pulse)
	var inner := Color(1.0, 0.94, 0.45, 0.35 + 0.4 * pulse)
	draw_arc(center, ring_r, 0.0, TAU, 32, outer, 3.0)
	draw_arc(center, ring_r * 0.86, 0.0, TAU, 24, inner, 1.75)


func _draw_units(px: float) -> void:
	var now := sim.elapsed_seconds
	var started := sim.has_started()
	## COMBAT_FEEDBACK：当前行动者高亮；其余略降对比，不做出手条。
	var actor: RtUnit = sim.get_current_actor() if started else null
	## 按 y 轴排序绘制：靠下（更大 y）后画压上。攻血标与纸片同序同体绘制，
	## 避免后排数值浮在全局顶层挡住前排剪影（准备/招募路径同口径）。
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
		## 已死单位走残影；defer 致死待 finalize 前仍绘活体，避免先消失再侧倒。
		if not rt.is_alive():
			if sim == null or not sim.is_death_presentation_pending(rt):
				continue
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
		_draw_stat_badges(
			center,
			rt.get_effective_attack(),
			rt.get_current_hp(),
			alpha,
			px,
			rt.unit.get_armor_block() if rt.unit != null else 0,
		)
	_draw_corpses(px)


func _draw_corpses(px: float) -> void:
	for corpse in _motion.get_corpses():
		if corpse.done or corpse.pose.alpha <= 0.02:
			continue
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
	walk: Variant = null,
	footprint_span: float = 1.0,
	idle_seed: int = -1,
	override_tex: Texture2D = null,
	center_sprite: bool = false,
) -> void:
	var center := tile_to_local(tile_pos) + pixel_offset
	var rx := maxf(3.0, _resolve_visual_half(visual_half_width, body_radius, 1.3) * px)
	var ry := maxf(3.0, _resolve_visual_half(visual_half_height, body_radius, 1.6) * px)
	## 多格足迹：剪影略放大，使角色在 2×2 内更饱满可读。
	if footprint_span >= 1.5:
		rx *= 1.35
		ry *= 1.35
	var tex: Texture2D = override_tex
	if tex == null and _art != null:
		tex = _art.get_texture(unit_id, is_player)
	if tex != null:
		_draw_unit_sprite(
			center, ry, px, tex, color, alpha, is_player, pose, walk, footprint_span, idle_seed, center_sprite
		)
		return
	## 美术目录缺失时的兜底；正常路径每个兵种都有贴图。
	var fill := Color(color, alpha)
	_draw_ellipse_filled(center, rx, ry, fill)
	_draw_ellipse_outline(center, rx, ry, Color(0, 0, 0, 0.45 * alpha), 1.5)
	if show_foot and not center_sprite:
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


func _recruit_prop_texture(item_id: String) -> Texture2D:
	match item_id:
		"hp_potion":
			return RECRUIT_TEX_HP
		"atk_potion":
			return RECRUIT_TEX_ATK
		"banner":
			return RECRUIT_TEX_BANNER
		_:
			return null


func _is_recruit_prop_tex(tex: Texture2D) -> bool:
	return (
		tex == RECRUIT_TEX_HP
		or tex == RECRUIT_TEX_ATK
		or tex == RECRUIT_TEX_LOCK
		or tex == RECRUIT_TEX_SELL
		or tex == RECRUIT_TEX_BANNER
	)


func _draw_recruit_prop(
	center_tile: Vector2,
	tex: Texture2D,
	alpha: float,
	px: float,
	off: Vector2,
	idle_seed: int,
) -> void:
	if tex == null:
		return
	## 半径跟普通角色一样；道具不再额外放大。
	_draw_body(
		center_tile,
		0.7,
		0.0,
		0.0,
		PLAYER_COLOR,
		alpha,
		"",
		px,
		true,
		off,
		true,
		"",
		null,
		Vector2.ZERO,
		1.0,
		idle_seed,
		tex,
	)


## 贴图脚底：单格落在格心略下方；多格足迹则把整张贴图垂向居中于足迹中心。
## pose / walk 为纯表现动画：以脚底为轴旋转缩放，偏移以格为单位。
## walk：Dictionary{offset,rotation,scale,shadow_mul}（小丑牌步进）；兼容旧 Vector2(tilt, hop)。
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
	walk: Variant = null,
	footprint_span: float = 1.0,
	idle_seed: int = -1,
	center_sprite: bool = false,
) -> void:
	var h_cap := px * 1.9
	if footprint_span >= 1.5:
		h_cap = px * minf(2.6, footprint_span * 1.15)
	## 货架卡内居中：略收高度，保证剪影落在统一卡壳内。
	if center_sprite:
		h_cap = minf(h_cap, px * RECRUIT_CARD_H_CELLS * 0.78)
	var h := clampf(half_height_px * SPRITE_HEIGHT_MUL, px * 1.05, h_cap)
	if center_sprite:
		h = minf(h, px * RECRUIT_CARD_H_CELLS * 0.72)
	var tex_size := tex.get_size()
	var w := h * tex_size.x / maxf(1.0, tex_size.y)
	## 贴纸 sheet 剪影偏方/偏宽：限制占格宽度，超限时等比缩小，避免压住邻格。
	var max_w := px * (
		SPRITE_MAX_WIDTH_CELLS_FOOTPRINT if footprint_span >= 1.5 else SPRITE_MAX_WIDTH_CELLS
	)
	if center_sprite:
		max_w = minf(max_w, px * RECRUIT_CARD_W_CELLS * 0.78)
	if w > max_w and w > 0.0:
		var shrink := max_w / w
		w = max_w
		h *= shrink
	## 道具用角色同一绘制框，不再按留白额外放大。
	var content_bottom := 1.0
	if _is_recruit_prop_tex(tex):
		w *= RECRUIT_PROP_SPRITE_SCALE
		h *= RECRUIT_PROP_SPRITE_SCALE
		content_bottom = RECRUIT_PROP_CONTENT_BOTTOM
	## 货架卡：贴图几何中心对齐卡心；2×2 同理；1×1 战场仍脚底略低于格心。
	var feet := (
		center + Vector2(0.0, h * 0.5)
		if center_sprite or footprint_span >= 1.5
		else center + Vector2(0.0, px * 0.38)
	)
	var offset := Vector2.ZERO
	var rot := 0.0
	var scl := Vector2.ONE
	var flash := 0.0
	var a := alpha
	var shadow_mul := 1.0
	if walk is Dictionary:
		var wd: Dictionary = walk
		offset += (wd.get("offset", Vector2.ZERO) as Vector2) * px
		rot += float(wd.get("rotation", 0.0))
		scl *= wd.get("scale", Vector2.ONE) as Vector2
		shadow_mul = maxf(shadow_mul, float(wd.get("shadow_mul", 1.0)))
	elif walk is Vector2:
		var wv: Vector2 = walk
		offset += Vector2(0.0, wv.y * px)
		rot += wv.x
	if pose != null:
		offset += (pose.offset + pose.idle_offset) * px
		rot += pose.rotation
		scl = pose.scale * pose.idle_scale * scl
		flash = pose.flash
		a *= pose.alpha
		shadow_mul = maxf(shadow_mul, pose.shadow_mul)
	elif idle_seed >= 0:
		var idle: Dictionary = RealtimeUnitMotion.sample_idle(_fx_clock, idle_seed)
		offset += (idle.get("offset", Vector2.ZERO) as Vector2) * px
		scl *= idle.get("scale", Vector2.ONE) as Vector2
	## 长按信息卡焦点：小丑牌式抬起 / 倾斜；非焦点略压暗。
	var inspect_v := _sample_inspect_visual(center)
	if not inspect_v.is_empty():
		offset += (inspect_v.get("offset", Vector2.ZERO) as Vector2) * px
		rot += float(inspect_v.get("rotation", 0.0))
		scl *= inspect_v.get("scale", Vector2.ONE) as Vector2
		a *= float(inspect_v.get("alpha", 1.0))
		shadow_mul = maxf(shadow_mul, float(inspect_v.get("shadow_mul", 1.0)))
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
	## 道具墨线底边对齐角色脚底；角色图 content_bottom=1，不挪。
	var foot_shift := h * (1.0 - content_bottom)
	draw_texture_rect(tex, Rect2(-w * 0.5, -h + foot_shift, w, h), false, modulate_color)
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


## 脚下纸片标签：攻 + 血；有装备护甲时再画护甲标（无图则跳过护甲标）。
func _draw_stat_badges(
	center: Vector2,
	attack: int,
	hp: int,
	alpha: float,
	px: float,
	armor: int = 0,
	gold_cost: int = -1,
	gold_affordable: bool = true,
) -> void:
	var badge := get_stat_badge_size(px)
	var gap := badge.y * 0.06
	var top := center.y + px * 0.38 + badge.y * 0.05
	var armor_tex := UiStatIcons.armor_texture()
	var show_armor := armor > 0 and armor_tex != null
	var show_gold := gold_cost >= 0 and STAT_GOLD_TEX != null
	var count := 2 + (1 if show_armor else 0) + (1 if show_gold else 0)
	var total_w := badge.x * float(count) + gap * float(count - 1)
	var half_span := total_w * 0.5
	var cx := clampf(center.x, half_span, maxf(half_span, size.x - half_span))
	var x0 := cx - half_span
	var slot := 0
	var atk_rect := Rect2(Vector2(x0 + (badge.x + gap) * float(slot), top), badge)
	slot += 1
	_draw_stat_badge(atk_rect, STAT_ATTACK_TEX, attack, alpha)
	var hp_rect := Rect2(Vector2(x0 + (badge.x + gap) * float(slot), top), badge)
	slot += 1
	_draw_stat_badge(hp_rect, STAT_HP_TEX, hp, alpha)
	if show_armor:
		var armor_rect := Rect2(Vector2(x0 + (badge.x + gap) * float(slot), top), badge)
		slot += 1
		_draw_stat_badge(armor_rect, armor_tex, armor, alpha)
	if show_gold:
		var gold_rect := Rect2(Vector2(x0 + (badge.x + gap) * float(slot), top), badge)
		var gold_text := STAT_TEXT if gold_affordable else Color(0.85, 0.22, 0.18, 1.0)
		_draw_stat_badge(gold_rect, STAT_GOLD_TEX, gold_cost, alpha, gold_text)


func _draw_stat_badge(
	rect: Rect2, tex: Texture2D, value: int, alpha: float, text_color: Color = STAT_TEXT
) -> void:
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
		STAT_FONT,
		baseline,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color(text_color, text_color.a * alpha),
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
		RealtimeEffectFeedback.KIND_GOLD:
			return Color(1.0, 0.84, 0.28) if is_player else Color(1.0, 0.78, 0.35)
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


func _draw_drag_follower(px: float) -> void:
	if not _drag_visual_alive:
		return
	## 候选人拖仍在源格内：跟手不画，避免与源位卡+人双影。
	if _recruit_drag_index >= 0 and not _recruit_left_source:
		return
	var tile := local_to_tile(_drag_draw_pos)
	var snapped := tile_to_local(tile)
	var pixel_off := _drag_draw_pos - snapped
	_draw_body(
		tile,
		_drag_radius,
		_drag_visual_half_width,
		_drag_visual_half_height,
		PLAYER_COLOR,
		1.0,
		_drag_label,
		px,
		true,
		pixel_off,
		true,
		_drag_unit_id,
		_drag_pose,
		null,
		1.0,
		-1,
		_drag_texture,
	)


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
	## 跟手拖影 / 手牌 DragGhost 负责剪影；此处只留格心虚影给「点选未拖」投放。
	if _drag_visual_alive or _drag_active:
		return
	var uid := _drag_unit_id if _drag_active else ghost_unit_id
	_draw_body(center_tile, radius, vwx, vhy, PLAYER_COLOR, 0.45, label, px, true, Vector2.ZERO, true, uid)
