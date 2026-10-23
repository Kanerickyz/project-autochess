class_name EnchantPricing
extends RefCounted
## 附魔熔合检定：固定成功率（不再用投币抬概率）。

## 融合默认成功率（百分数）。
const SUCCESS_PERCENT := 80.0


static func compute_success_percent() -> float:
	return SUCCESS_PERCENT


static func roll_succeeds(unit_roll: float) -> bool:
	return unit_roll < SUCCESS_PERCENT / 100.0
