class_name BoardCell3D
extends Node3D

const TILE_HEIGHT_RATIO := 0.22
## Near-zero inset weakens checker/grid seams (COMBATLEVEL de-grid).
const TOP_INSET := 0.002
const HEIGHT_SCALE_LAKE := 0.72
const HEIGHT_SCALE_ROCK := 1.18
const HEIGHT_SCALE_DENSE := 1.22
const HEIGHT_SCALE_DEFAULT := 1.0

var cell: Vector2i = Vector2i.ZERO

var _blocked: bool = false
var _terrain: TerrainType.Type = TerrainType.Type.GRASS
var _has_terrain: bool = false
var _tile_size: float = 1.0
var _base_color: Color = Color.WHITE
var _highlight: BoardTheme.CellHighlight = BoardTheme.CellHighlight.NONE
var _burning: bool = false
var _top_mesh: MeshInstance3D
var _body_mesh: MeshInstance3D
var _top_material: StandardMaterial3D
var _body_material: StandardMaterial3D
var _pulse_tween: Tween
var _height_scale: float = HEIGHT_SCALE_DEFAULT


static func get_tile_height(tile_size: float) -> float:
	return tile_size * TILE_HEIGHT_RATIO


func setup(
	p_cell: Vector2i,
	blocked: bool,
	tile_size: float,
	terrain: TerrainType.Type = TerrainType.Type.GRASS,
	has_terrain: bool = false,
	board_height: int = -1,
) -> void:
	cell = p_cell
	_blocked = blocked
	_terrain = terrain
	_has_terrain = has_terrain
	_tile_size = tile_size
	_height_scale = _resolve_height_scale(terrain) if has_terrain else HEIGHT_SCALE_DEFAULT
	if has_terrain:
		_base_color = BoardTheme.get_terrain_color(cell, terrain, blocked, board_height)
	else:
		_base_color = BoardTheme.get_base_color(cell, blocked, board_height)
	_rebuild_mesh()
	_apply_visual()


func set_highlight(highlight: BoardTheme.CellHighlight) -> void:
	if _highlight == highlight:
		return
	_highlight = highlight
	_apply_visual()


func set_burning(active: bool) -> void:
	if _burning == active:
		return
	_burning = active
	_apply_visual()


func play_impact_pulse(tint: Color, duration: float) -> void:
	if duration <= 0.0:
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	var top_base := _resolve_top_color()
	var body_base := _resolve_body_color()
	_pulse_tween = create_tween()
	_pulse_tween.set_parallel(true)
	_pulse_tween.tween_method(
		func(c: Color) -> void:
			if _top_material != null:
				_top_material.albedo_color = c,
		top_base.lerp(tint, 0.65),
		top_base,
		duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_method(
		func(c: Color) -> void:
			if _body_material != null:
				_body_material.albedo_color = c,
		body_base.lerp(tint, 0.55),
		body_base,
		duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_callback(_apply_visual)


func _resolve_height_scale(terrain: TerrainType.Type) -> float:
	match terrain:
		TerrainType.Type.LAKE:
			return HEIGHT_SCALE_LAKE
		TerrainType.Type.ROCK:
			return HEIGHT_SCALE_ROCK
		TerrainType.Type.DENSE_JUNGLE:
			return HEIGHT_SCALE_DENSE
		_:
			return HEIGHT_SCALE_DEFAULT


func _rebuild_mesh() -> void:
	if _body_mesh != null:
		_body_mesh.queue_free()
		_body_mesh = null
	if _top_mesh != null:
		_top_mesh.queue_free()
		_top_mesh = null
	_ensure_mesh()


func _ensure_mesh() -> void:
	if _body_mesh != null:
		return
	var tile_h := get_tile_height(_tile_size) * _height_scale
	var side := _tile_size * (1.0 - TOP_INSET * 2.0)
	var center_xz := Vector3(_tile_size * 0.5, 0.0, _tile_size * 0.5)

	_body_mesh = MeshInstance3D.new()
	_body_mesh.name = "BodyMesh"
	var body_box := BoxMesh.new()
	body_box.size = Vector3(side, tile_h * 0.72, side)
	_body_mesh.mesh = body_box
	_body_mesh.position = center_xz + Vector3(0.0, body_box.size.y * 0.5, 0.0)
	_body_material = StandardMaterial3D.new()
	_body_material.roughness = 0.92
	_body_mesh.material_override = _body_material
	add_child(_body_mesh)

	_top_mesh = MeshInstance3D.new()
	_top_mesh.name = "TopMesh"
	var top_box := BoxMesh.new()
	top_box.size = Vector3(_tile_size * 0.995, tile_h * 0.10, _tile_size * 0.995)
	_top_mesh.mesh = top_box
	_top_mesh.position = center_xz + Vector3(0.0, tile_h - top_box.size.y * 0.5, 0.0)
	_top_material = StandardMaterial3D.new()
	_top_material.roughness = 0.78
	_top_mesh.material_override = _top_material
	add_child(_top_mesh)


func _resolve_top_color() -> Color:
	var color := BoardTheme.apply_highlight(_base_color, _highlight)
	if _burning:
		color = BoardTheme.apply_burn_overlay(color)
	if _blocked and not _has_terrain:
		color = color * BoardTheme.get_config().blocked_modulate
	elif _blocked and _has_terrain:
		color = color * BoardTheme.get_config().blocked_modulate
	return color.lightened(0.06)


func _resolve_body_color() -> Color:
	return _resolve_top_color().darkened(0.18)


func _apply_visual() -> void:
	if _top_material == null or _body_material == null:
		return
	_top_material.albedo_color = _resolve_top_color()
	_body_material.albedo_color = _resolve_body_color()
