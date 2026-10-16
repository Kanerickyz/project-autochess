extends SceneTree

const RecruitShopFloorGoldTestScript := preload("res://scripts/ui/realtime/recruit_shop_floor_gold_test.gd")


func _initialize() -> void:
	var ok: bool = RecruitShopFloorGoldTestScript.run_all()
	quit(0 if ok else 1)
