class_name CombatEvents
extends RefCounted

const ON_COMBAT_START := &"OnCombatStart"
## 胜负判定当时；只应由当时仍存活的单位响应。
const ON_COMBAT_END := &"OnCombatEnd"
const ON_FRIEND_SUMMONED := &"OnFriendSummoned"
const ON_SUMMONED := &"OnSummoned"
const ON_FRIEND_DEATH := &"OnFriendDeath"
## 敌方单位死亡时（小队范围对称）；payload.target = 死者。与 OnFriendDeath 同批发出，由监听方按阵营过滤。
const ON_ENEMY_DEATH := &"OnEnemyDeath"
## 其他友方受伤时（小队范围）；payload.target = 受伤者。
const ON_FRIEND_DAMAGE_TAKEN := &"OnFriendDamageTaken"
const ON_DAMAGE_TAKEN := &"OnDamageTaken"
## 护甲成功挡住本次伤害（最终扣血 0）；payload.target = 被挡者，payload.source = 攻击者，amount = 试图伤害。
const ON_ARMOR_BLOCKED := &"OnArmorBlocked"
## 单位护甲从有→0（本击耗尽）；payload.target = 耗尽者。
const ON_ARMOR_DEPLETED := &"OnArmorDepleted"
## 其他友方护甲从有→0（小队范围，过滤口径同 OnFriendDamageTaken）；payload.target = 耗尽者。
const ON_FRIEND_ARMOR_DEPLETED := &"OnFriendArmorDepleted"
## 治疗/恢复生命（仅统计实际增加量）；payload.effect_owner = 施放者。
const ON_HEAL_APPLIED := &"OnHealApplied"

const ON_DEAL_DAMAGE := &"OnDealDamage"
const ON_KILL := &"OnKill"
## 其他友方造成击杀时（小队范围）；payload.source = 击杀者。不含持有者自己的击杀。
const ON_FRIEND_KILL := &"OnFriendKill"
const ON_DEATH := &"OnDeath"
const ON_ATTACK_HIT := &"OnAttackHit"
const ON_LINE_ATTACK := &"OnLineAttack"
const ON_EFFECT_RESOLVED := &"OnEffectResolved"
const ON_EFFECT_FIZZLED := &"OnEffectFizzled"
const ON_MOVE := &"OnMove"
const ON_ROUND_START := &"OnRoundStart"
## 自己一动结束且仍存活（回合制交权前）；payload.source = 行动者。
const ON_ACTOR_TURN_END := &"OnActorTurnEnd"
## 击杀续动等：重置当前行动者步数与普攻，不广播 OnRoundStart。
const ON_ACTOR_TURN_REFRESH := &"OnActorTurnRefresh"
const ON_LEVEL_UP := &"OnLevelUp"
