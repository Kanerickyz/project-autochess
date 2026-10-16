class_name RunEconomy
extends RefCounted

signal gold_changed(new_amount: int)

var gold: int = 0
var _config: EconomyConfig


func configure(config: EconomyConfig) -> void:
	_config = config


func reset() -> void:
	if _config == null:
		gold = 0
	else:
		gold = _config.starting_gold
	gold_changed.emit(gold)


func can_afford(amount: int) -> bool:
	return amount >= 0 and gold >= amount


func spend(amount: int) -> bool:
	if amount <= 0:
		return true
	if not can_afford(amount):
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func grant(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)


## 【已否决主路径】击杀敌方不掉金；保留 API 兼容旧调用/编辑器，战斗主路径勿再调用。
func grant_kill_gold(unit_data: UnitData) -> void:
	var amount := _resolve_kill_gold(unit_data)
	grant(amount)


func grant_wave_gold(wave: WaveData) -> int:
	var amount := _resolve_wave_gold(wave)
	grant(amount)
	return amount


func get_sell_price(entry: DeckEntry) -> int:
	return DeckUpgradeService.get_sell_price(entry)


func get_refresh_cost() -> int:
	if _config == null:
		return 0
	return _config.refresh_cost


func _resolve_kill_gold(unit_data: UnitData) -> int:
	if _config == null:
		return 0
	if unit_data != null and unit_data.kill_gold_reward >= 0:
		return unit_data.kill_gold_reward
	return _config.default_kill_gold


func _resolve_wave_gold(wave: WaveData) -> int:
	if _config == null:
		return 0
	if wave != null and wave.wave_gold_reward >= 0:
		return wave.wave_gold_reward
	return _config.default_wave_gold
