class_name CombatEvents
extends RefCounted

const ON_COMBAT_START := &"OnCombatStart"
const ON_FRIEND_SUMMONED := &"OnFriendSummoned"
const ON_SUMMONED := &"OnSummoned"
const ON_FRIEND_DEATH := &"OnFriendDeath"
## 其他友方受伤时（小队范围）；payload.target = 受伤者。
const ON_FRIEND_DAMAGE_TAKEN := &"OnFriendDamageTaken"
const ON_DAMAGE_TAKEN := &"OnDamageTaken"

const ON_DEAL_DAMAGE := &"OnDealDamage"
const ON_CRIT := &"OnCrit"
const ON_KILL := &"OnKill"
const ON_DEATH := &"OnDeath"
const ON_ATTACK_HIT := &"OnAttackHit"
const ON_LINE_ATTACK := &"OnLineAttack"
const ON_EFFECT_RESOLVED := &"OnEffectResolved"
const ON_EFFECT_FIZZLED := &"OnEffectFizzled"
const ON_MOVE := &"OnMove"
const ON_ROUND_START := &"OnRoundStart"
## 击杀续动等：重置当前行动者步数与普攻，不广播 OnRoundStart。
const ON_ACTOR_TURN_REFRESH := &"OnActorTurnRefresh"
const ON_LEVEL_UP := &"OnLevelUp"
