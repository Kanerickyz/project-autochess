class_name SimRunEconomy
extends RunEconomy
## 批跑专用经济：训练时可开启招募/商店 **无限金币**（仅 sim_balance，不影响 run_game）。

## true 时招募与商店标价恒可支付，且不扣金（主路径仍用 RunEconomy）。
var unlimited_recruit_spending: bool = false


func can_afford(amount: int) -> bool:
	if unlimited_recruit_spending:
		return amount >= 0
	return super.can_afford(amount)


func spend(amount: int) -> bool:
	if unlimited_recruit_spending:
		return amount >= 0
	return super.spend(amount)
