class_name CritRoll
extends RefCounted
## 普攻暴击保底掷骰：标称率 p 表示约每 1/p 次必出一次。
## 未暴击后实际概率升为 1/(N-k)（玩家不可见）；暴击后清零。


## 保底间隔 N：crit_chance=0.05 → 20。
static func pity_interval(crit_chance: float) -> int:
	var chance := clampf(crit_chance, 0.0, 1.0)
	if chance <= 0.0:
		return 0
	if chance >= 1.0:
		return 1
	return maxi(1, int(round(1.0 / chance)))


## 当前实际概率；miss_streak = 自上次暴击后连续未暴击次数。
static func current_chance(crit_chance: float, miss_streak: int) -> float:
	var interval := pity_interval(crit_chance)
	if interval <= 0:
		return 0.0
	if interval == 1:
		return 1.0
	var streak := clampi(miss_streak, 0, interval - 1)
	return 1.0 / float(interval - streak)


## 解析倍率；非法值回退默认 1.5。
static func resolve_multiplier(crit_multiplier: float) -> float:
	if crit_multiplier < 1.0:
		return 1.5
	return crit_multiplier


## 掷一次普攻暴击并推进来源的保底计数；无来源/无基数则原样返回。
static func roll_attack(
	source: UnitInstance,
	base_amount: int,
	rng: RandomNumberGenerator,
) -> DamageRoll:
	var amount := maxi(0, base_amount)
	if source == null or source.stats == null or amount <= 0 or rng == null:
		return DamageRoll.new(amount, false)
	var chance := current_chance(source.stats.crit_chance, source.crit_miss_streak)
	if chance <= 0.0:
		return DamageRoll.new(amount, false)
	var is_crit := rng.randf() < chance
	if is_crit:
		source.crit_miss_streak = 0
		var mult := resolve_multiplier(source.stats.crit_multiplier)
		amount = maxi(1, int(round(float(amount) * mult)))
		return DamageRoll.new(amount, true)
	source.crit_miss_streak = mini(
		source.crit_miss_streak + 1,
		maxi(0, pity_interval(source.stats.crit_chance) - 1),
	)
	return DamageRoll.new(amount, false)
