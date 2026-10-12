extends Node

const CONFIG_PATH := "user://settings.cfg"

const KEY_MASTER_VOLUME := "master_volume"
const KEY_FULLSCREEN := "fullscreen"

const DEFAULT_MASTER_VOLUME := 1.0
const DEFAULT_FULLSCREEN := false

var _master_volume: float = DEFAULT_MASTER_VOLUME
var _fullscreen: bool = DEFAULT_FULLSCREEN
var _loading: bool = false

var master_volume: float:
	get:
		return _master_volume
	set(value):
		_master_volume = clampf(value, 0.0, 1.0)
		if not _loading:
			apply_master_volume()
			save()

var fullscreen: bool:
	get:
		return _fullscreen
	set(value):
		_fullscreen = value
		if not _loading:
			apply_fullscreen()
			save()


func _ready() -> void:
	load_settings()
	apply_all()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	_loading = true
	_master_volume = config.get_value("settings", KEY_MASTER_VOLUME, DEFAULT_MASTER_VOLUME)
	_fullscreen = config.get_value("settings", KEY_FULLSCREEN, DEFAULT_FULLSCREEN)
	_loading = false


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", KEY_MASTER_VOLUME, _master_volume)
	config.set_value("settings", KEY_FULLSCREEN, _fullscreen)
	config.save(CONFIG_PATH)


func apply_all() -> void:
	apply_master_volume()
	apply_fullscreen()


func apply_master_volume() -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index < 0:
		return
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(_master_volume))


func apply_fullscreen() -> void:
	# Browsers only allow fullscreen from a user gesture; skip silent apply on web boot.
	if OS.has_feature("web") and not Input.is_anything_pressed():
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
