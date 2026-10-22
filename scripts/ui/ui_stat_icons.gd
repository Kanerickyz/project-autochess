class_name UiStatIcons
extends RefCounted
## 纸片属性/金币图标路径；缺失时回退为 null，调用方勿崩。

const STAT_ATTACK_PATH := "res://assets/sprites/paper_cutout/ui/stat_attack.png"
const STAT_HP_PATH := "res://assets/sprites/paper_cutout/ui/stat_hp.png"
const STAT_ARMOR_PATH := "res://assets/sprites/paper_cutout/ui/stat_armor.png"
const STAT_GOLD_PATH := "res://assets/sprites/paper_cutout/ui/stat_gold.png"

static var _cache: Dictionary = {}


static func load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _cache.has(path):
		return _cache[path] as Texture2D
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Texture2D:
			tex = loaded as Texture2D
	_cache[path] = tex
	return tex


static func armor_texture() -> Texture2D:
	return load_texture(STAT_ARMOR_PATH)


static func gold_texture() -> Texture2D:
	return load_texture(STAT_GOLD_PATH)


static func format_gold_label(amount: int) -> String:
	## 有图时仍保留文案，图标由旁挂 TextureRect 显示。
	return "金币 %d" % amount


## 在父 HBox 内保证存在金币图标节点（缺图则隐藏）。
static func ensure_gold_icon(parent: Control, icon_name: String = "GoldIcon") -> TextureRect:
	if parent == null:
		return null
	var existing := parent.get_node_or_null(icon_name) as TextureRect
	if existing == null:
		existing = TextureRect.new()
		existing.name = icon_name
		existing.custom_minimum_size = Vector2(22, 22)
		existing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		existing.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(existing)
		parent.move_child(existing, 0)
	var tex := gold_texture()
	existing.texture = tex
	existing.visible = tex != null
	return existing
