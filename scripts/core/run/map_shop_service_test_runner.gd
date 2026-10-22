extends SceneTree

const MapShopServiceTestScript := preload("res://scripts/core/run/map_shop_service_test.gd")


func _initialize() -> void:
	var ok: bool = MapShopServiceTestScript.run_all()
	quit(0 if ok else 1)
