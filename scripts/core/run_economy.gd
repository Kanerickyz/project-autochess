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


## 【已否决】击杀敌方不掉金；保留签名兼容旧调用/编辑器，恒为无操作。
func grant_kill_gold(_unit_data: UnitData) -> void:
	return


## 层结算金：第 n 层胜利发 n 金（取代波次金主路径）。
## floor_index：地图层号（1=第1层）；若传入 0-based 下标 0，按第 1 层发 1 金。
func grant_floor_gold(floor_index: int) -> int:
	var amount := resolve_floor_gold_amount(floor_index)
	grant(amount)
	return amount


static func resolve_floor_gold_amount(floor_index: int) -> int:
	if floor_index < 0:
		return 0
	## 1-based 层号直接作金额；0 视为第 1 层（0-based 兼容）。
	return floor_index if floor_index >= 1 else 1


## 【遗留】旧网格/编辑器波次金；实时主路径请用 grant_floor_gold。
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
