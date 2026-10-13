# Risk of Rain 2 参考 — 基础版

> 外部游戏资料汇总，供策划对照；**非**本项目实现规格。
> 数据来源：[RoR2 Wiki (wiki.gg)](https://riskofrain2.wiki.gg/) · 收录范围：**基础版**（不含 SoTV / SoS / Alloyed Collective）· 数据快照：**2026-06-02**

相关文档：[INDEX.md](../INDEX.md) · [GAME_VISION.md](../GAME_VISION.md) · [BUFF_SYSTEM.md](../BUFF_SYSTEM.md) · [Features/UNIT_ABILITIES.md](../Features/UNIT_ABILITIES.md) · [SUPER_AUTO_PETS.md](./SUPER_AUTO_PETS.md)

---

## 1. 术语对照

| RoR2 | 中文 | 本项目近似概念 |
| --- | --- | --- |
| Passive Item | 被动道具 | 增益卡 / `DeckEntry` 永久加成 |
| Equipment | 装备（主动） | 单槽主动技能 / 消耗型道具 |
| Lunar Item | 月球道具 | 高收益 + 明确代价的设计模式 |
| Boss Item | Boss 道具 | 绑定 Teleporter Boss 的稀有掉落 |
| Survivor / Loadout | 幸存者 / 配装 | `UnitData` + 可选技能变体 |
| Stack | 叠层 | 同效果多次获取的数值叠加规则 |
| Proc Coefficient | 触发系数 | 技能触发 OnHit 类道具效果的权重 |

## 2. 核心机制摘要

### 2.1 道具稀有度与获取

| 边框 | 稀有度 | 获取途径 |
|------|--------|----------|
| 白 | Common 普通 | 小箱、终端、机遇神龛 |
| 绿 | Uncommon 罕见 | 大箱、传送 Boss 奖励（非 Boss 专属黄装） |
| 红 | Legendary 传奇 | 稀有箱（约 1%），后期质变 |
| 黄 | Boss / Planet | 特定 Teleporter Boss ~15% 替代绿装；部分为净化池等特殊区域 |
| 蓝 | Lunar 月球 | **不进**普通箱；月球舱 / 时隙集市，消耗月球币 |
| 橙 | Equipment 装备 | 独立装备槽，主动使用 + 冷却 |

### 2.2 叠层类型

同种被动可无限叠层；叠层公式见 [Item Stacking](https://riskofrain2.wiki.gg/wiki/Item_Stacking)。

| 类型 | 说明 | 代表道具 |
|------|------|----------|
| Linear 线性 | 每层 +固定数值/百分比 | 士兵注射器、撬棍 |
| Hyperbolic 双曲 | 多层收益递减，趋近上限 | 艰难时世、旧断头台 |
| Exponential 指数 | 多层倍增 | 成型玻璃、异星头颅 |
| Reciprocal 倒数 | 多层收益递减（另一公式） | H3AD-5T v2 |

### 2.3 被动 vs 装备

- **被动**：显示在顶栏；种类与层数无硬上限；可用 3D 打印机消耗换指定道具。
- **装备**：单槽（MUL-T 除外）；按交互键主动释放；Fuel Cell 等可增充能/减 CD。

### 2.4 Loadout（Skills 2.0）

选角界面 **Loadout** 可切换四技能槽（Primary / Secondary / Utility / Special）的**替代技能**；替代技能通过角色挑战解锁。

### 2.5 与本项目差异

- RoR2 为单人/合作 **动作 Roguelike**，实时移动与射击；本项目为 **PvE 自走棋**，战斗全自动。
- RoR2 道具为 run 内拾取叠层；本项目构筑来自商店牌库、增益卡与单位内建技能（见愿景 / 架构摘要）。


## 3. 被动道具（100）

> Wiki「Base Game Item Counts」标 **102**（25+26+22+15+14）；本表按可核对条目收录 **100** 条（Boss 黄装 13 条；与 Wiki 15 黄装统计口径差 2 条 quest/区域键）。


### 3.1 普通（白）25

| 英文名 | 中文名 | 效果摘要 | 叠层 |
| --- | --- | --- | --- |
| Backup Magazine | 备用弹匣 | Add +1 (+1/层) charge of your Secondary skill. | Linear |
| Bison Steak | 野牛排 | 最大生命 +25 (+25/层). | Linear |
| Bundle of Fireworks | 烟花捆 | Activating an interactable launches 8 (+4/层) fireworks that deal 300% base damage. | Linear |
| Bustling Fungus | 忙碌真菌 | After standing still for 1 second, create a zone that heals for 4.5% (+2.25%/层) of your health every second to all allies within 3m (+1.5m/层). | Linear |
| Cautious Slug | 谨慎蛞蝓 | Increases base 生命回复 by +3 生命/秒 (+3 生命/秒/层) while outside of combat. | Linear |
| Crowbar | 撬棍 | 造成 +75% (+75%/层) damage to enemies above 90% health. | Linear |
| Energy Drink | 能量饮料 | Sprint speed is improved by 25% (+25%/层). | Linear |
| Focus Crystal | 聚焦水晶 | Increase damage to enemies within 13m by 20% (+20%/层). | Linear |
| Gasoline | 汽油 | 击杀敌人时ignites all enemies within 12m (+4m/层) for 150% base damage. Additionally, enemies burn for 150% (+75%/层) base damage. | Linear |
| Item Scrap, White | 白色废料 | 无效果. Prioritized when used with 3D Printers. | - |
| Lens-Maker's Glasses | 透镜制造者眼镜 | Your attacks have a 10% (+10%/层) 概率'暴击', dealing double damage. | Linear |
| Medkit | 医疗包 | 2 seconds after getting hurt, heal for 20 plus an additional 5% (+5%/层) of maximum health. | Linear |
| Mocha | 摩卡 | 攻击速度 +7.5% (+7.5%/层) and movement speed by 7% (+7%/层). | Linear |
| Monster Tooth | 怪物之牙 | 击杀敌人时spawns a healing orb that heals for 8 plus an additional 2% (+2%/层) of maximum health. | Linear |
| Paul's Goat Hoof | 保罗羊蹄 | 移动速度 +14% (+14%/层). | Linear |
| Personal Shield Generator | 个人护盾发生器 | Gain a shield equal to 8% (+8%/层) of your maximum health. Recharges outside of danger. | Linear |
| Repulsion Armor Plate | 斥力装甲板 | Reduce all incoming damage by 5 (+5/层). Cannot be reduced below 1. | Linear |
| Roll of Pennies | 硬币卷 | Gain 3 (+3/层) gold on taking damage from an enemy. Scales over time. | Linear |
| Rusted Key | 生锈钥匙 | A hidden cache containing an item (80%/20%) will appear in a random location on each stage. Opening the cache consumes this item. | — |
| Soldier's Syringe | 士兵注射器 | 攻击速度 +15% (+15%/层). | Linear |
| Sticky Bomb | 粘性炸弹 | 5% (+5%/层) chance 命中时 to attach a bomb to an enemy, detonating for 180% TOTAL damage. | Linear |
| Stun Grenade | 眩晕手雷 | 5% (+5% on stack) chance 命中时 to stun enemies for 2 seconds. | Hyperbolic |
| Topaz Brooch | 黄玉胸针 | Gain a temporary barrier on kill for 15 health(+15/层). | Linear |
| Tougher Times | 艰难时世 | 15% (+15%/层) 概率block incoming damage. Unaffected by luck. | Hyperbolic |
| Tri-Tip Dagger | 三刃匕首 | 10% (+10%/层) 概率bleed an enemy for 240% base damage. | Linear |
### 3.2 罕见（绿）26

| 英文名 | 中文名 | 效果摘要 | 叠层 |
| --- | --- | --- | --- |
| AtG Missile Mk. 1 | AtG 导弹 Mk.1 | 10% 概率fire a missile that deals 300% (+300%/层) TOTAL damage. | Linear |
| Bandolier | 子弹带 | 18% (+10%/层) chance on kill to drop an ammo pack that resets all skill cooldowns. | Special |
| Berzerker's Pauldron | 狂战士肩甲 | Killing 4 enemies within 1 second sends you into a frenzy for 6s (+4s/层). 移动速度 +50% and attack speed by 100%. | Linear |
| Chance Doll | 机遇玩偶 | 40% (+10%/层) 概率get higher rarity items from chance shrines on success. | Linear |
| Chronobauble | 时空球 | Slow enemies 命中时 for -60% movement speed for 2s (+2s/层). | Linear |
| Fuel Cell | 燃料电池 | Hold an additional equipment charge (+1/层). Reduce equipment cooldown by 15% (+15%/层). | LinearExponential |
| Ghor's Tome | 霍尔之书 | 4% (+4% on stack) chance on kill to drop a treasure worth $25. Scales over time. | Linear |
| Harvester's Scythe | 收割者镰刀 | Gain 5% critical chance. Critical strikes heal for 8 (+4/层) health. | Linear |
| Hopoo Feather | 霍普羽毛 | Gain +1 (+1/层) maximum jump count. | Linear |
| Hunter's Harpoon | 猎人鱼叉 | 击杀敌人时increases movement speed by 125%, fading over 1 (+0.5/层) seconds. | Linear |
| Ignition Tank | 点火罐 | Ignite effects deal +300% (+300%/层) more damage over time. | Linear |
| Infusion | 灌注 | 击杀敌人时increases your health permanently by 1 (+1/层), up to a maximum of 100 (+100/层) health. | Linear |
| Item Scrap, Green | 绿色废料 | 无效果. Prioritized when used with 3D Printers. | - |
| Leeching Seed | 吸血种子 | Dealing damage heals you for 1 (+1/层) health. | Linear |
| Lepton Daisy | 轻子雏菊 | Release a healing nova during the Teleporter event, healing all nearby allies for 50% of their maximum health. Occurs 1 (+1/层) times. | Linear |
| Old Guillotine | 旧断头台 | Instantly kill Elite monsters below 13% (+13%/层) health. | Hyperbolic |
| Predatory Instincts | 掠食本能 | Gain 5% critical chance. Critical strikes increase attack speed by 12%. Maximum cap of 36% (+24%/层) attack speed. | Linear |
| Razorwire | 剃刀线 | Getting hit causes you to explode in a burst of razors, dealing 160% damage. Hits up to 5 (+2/层) targets in a 25m (+10m/层) radius | Linear |
| Red Whip | 红鞭 | Leaving combat boosts your movement speed by 30% (+30%/层). | Linear |
| Rose Buckler | 玫瑰圆盾 | Increase armor by 30 (+30/层) while sprinting. | Linear |
| Shipping Request Form | 货运申请表 | A delivery containing 2 items (79%/20%/1%) will appear in a random location on each stage. (Increases rarity chances of the items/层). | Special |
| Shuriken | 手里剑 | Activating your Primary skill also throws a shuriken that deals 400% (+100%/层) base damage. You can hold up to 3 (+1/层) shurikens which all reload over 10 seconds. | Linear |
| Squid Polyp | 鱿鱼息肉 | Activating an interactable summons a Squid Turret that attacks nearby enemies at 100% (+100%/层) attack speed. Lasts 30 seconds. | Linear |
| Ukulele | 尤克里里 | 25% 概率fire chain lightning for 80% TOTAL damage on up to 3 (+2/层) targets within 20m (+2m/层). | Linear |
| Wax Quail | 蜡制鹌鹑 | Jumping while sprinting boosts you forward by 10m (+10m/层). | Linear |
| Will-o'-the-wisp | 鬼火 | 击杀时ing an enemy, spawn a lava pillar in a 12m (+2.4m/层) radius for 350% (+280%/层) base damage. | Linear |
### 3.3 传奇（红）22

| 英文名 | 中文名 | 效果摘要 | 叠层 |
| --- | --- | --- | --- |
| 57 Leaf Clover | 57 叶四叶草 | All random effects are rolled +1 (+1/层) times for a favorable outcome. | Linear |
| Alien Head | 异星头颅 | 技能冷却 -25% (+25%/层). | Exponential |
| Brainstalks | 脑茎 | Upon killing an elite monster, enter a frenzy for 4s (+4s/层) where skills have 0.5s cooldowns. | Linear |
| Brilliant Behemoth | 辉煌巨兽 | All your attacks explode in a 4m (+2.5m/层) radius for a bonus 60% TOTAL damage to nearby enemies. | Linear |
| Ceremonial Dagger | 仪式匕首 | 击杀敌人时fires out 3 homing daggers that deal 150% (+150%/层) base damage. | Linear |
| Defensive Microbots | 防御微机器人 | Shoot down 1 (+1/层) projectiles within 20m every 0.5 seconds. Recharge rate scales with attack speed. | Linear |
| Dio's Best Friend | Dio 挚友 | Upon death, this item will be consumed and you will return to life with 3 seconds of invulnerability. | Linear |
| H3AD-5T v2 | H3AD-5T v2 | Increase jump height. Creates a 5m-100m radius kinetic explosion 命中时ting the ground, dealing 1000%-10000% base damage that scales up with fall distance. Recharges in 10 (-50%/层) seconds. | Reciprocal |
| Happiest Mask | 至乐面具 | Killing enemies has a 7% 概率spawn a ghost of the killed enemy with 1500% damage. Lasts 30s (+30s/层). | Linear |
| Hardlight Afterburner | 硬光加力器 | Add +2 (+2/层) charges of your Utility skill. Reduces Utility skill cooldown by 33%. | Linear |
| Item Scrap, Red | 红色废料 | 无效果. Prioritized when used with 3D Printers. | - |
| Laser Scope | 激光瞄准镜 | 暴击 deal an additional 100% damage(+100%/层). | Linear |
| N'kuhana's Opinion | N'kuhana 之见 | Store 100% (+100%/层) of healing as Soul Energy. After your Soul Energy reaches 10% of your maximum health, fire a skull that deals 250% of your Soul Energy as damage. | Linear |
| Rejuvenation Rack | 回春架 | Heal +100% (+100%/层) more. | Linear |
| Sentient Meat Hook | 感知肉钩 | 20% (+20%/层) chance 命中时 to fire homing hooks at up to 10 (+5/层) enemies for 100% TOTAL damage. | HyperbolicLinear |
| Shattering Justice | 破碎正义 | After hitting an enemy 5 times, reduce their armor by 60 for 8 (+8/层) seconds. | Linear |
| Sonorous Whispers | 洪亮低语 | When a large monster is killed it will always drop an item. All elites have a 5% chance of dropping an item (+1% per item stack). | Linear |
| Soulbound Catalyst | 灵魂绑定催化剂 | Kills reduce equipment cooldown by 4s (+2s/层). | Linear |
| Spare Drone Parts | 备用无人机零件 | Gain Col. Droneman. Drones gain +25% (+25%/层) attack speed and cooldown reduction. Drones gain 10% 概率fire a missile 命中时, dealing 150% TOTAL damage. Drones gain an automatic chain gun that deals 6x50% damage, bouncing to 2 enemies. | LinearExponential |
| Symbiotic Scorpion | 共生毒蝎 | 100% chance 命中时 to reduce armor by 2 (+2/层) permanently. | Linear |
| Unstable Tesla Coil | 不稳定特斯拉线圈 | Fire out lightning that hits 3 (+2/层) enemies for 200% base damage every 0.5s. The Tesla Coil switches off every 10 seconds. | Linear |
| Wake of Vultures | 秃鹫之迹 | Gain the power of any killed elite monster for 8s (+5s/层). | Linear |
### 3.4 Boss（黄）13

| 英文名 | 中文名 | 效果摘要 | 叠层 |
| --- | --- | --- | --- |
| Charged Perforator | 充能穿孔器 | 10% chance 命中时 to down a lightning strike, dealing 500% (+500%/层) damage. | Linear |
| Genesis Loop | 创世循环 | Falling below 25% health causes you to explode, dealing 6000% base damage. Recharges every 30 / (2 +1/层) seconds. | Linear |
| Halcyon Seed | 宁静之种 | Summon Aurelionite during the teleporter event. It has 100% (+50%/层) damage and 100% (+100%/层) health. | Linear |
| Irradiant Pearl | 辐光珍珠 | Increases ALL stats by 10% (+10%/层). | Linear |
| Item Scrap, Yellow | 黄色废料 | 无效果. Prioritized when used with 3D Printers. | - |
| Little Disciple | 小门徒 | Fire a tracking wisp for 300% (+300%/层) damage. Fires every 1.6 seconds while sprinting. Fire rate increases with movement speed. | Linear |
| Mired Urn | 泥沼瓮 | While in combat, the nearest 1 (+1/层) enemies to you within 13m will be 'tethered' to you, dealing 100% damage per second, applying tar, and healing you for 100% of the damage dealt. | Linear |
| Molten Perforator | 熔火穿孔器 | 10% chance 命中时 to call forth 3 magma balls from an enemy, dealing 300% (+300%/层) damage each. | Linear |
| Pearl | 珍珠 | 最大生命 +10% (+10%/层). | Linear |
| Planula | 扁形虫 | Heal from incoming damage for 15 (+15/层). | Linear |
| Queen's Gland | 女王腺体 | Every 30 seconds, summon a Beetle Guard with bonus 300% damage and 100% health. Can have up to 1 (+1/层) Guards at a time. | Linear |
| Shatterspleen | 碎脾 | Gain 5% critical chance. 暴击 bleed enemies for 240% base damage. Bleeding enemies explode on death for 400% (+400%/层) damage, plus an additional 15% (+15%/层) of their maximum health. | Linear |
| Titanic Knurl | 泰坦节瘤 | Increase maximum health by 40 (+40/层) and base 生命回复 by +1.6 生命/秒 (+1.6 生命/秒/层). | Linear |
### 3.5 月球（蓝）14

| 英文名 | 中文名 | 效果摘要 | 叠层 |
| --- | --- | --- | --- |
| Beads of Fealty | 忠诚念珠 | 看似无效果；用于进入隐藏 realm（忠诚念珠）。 | - |
| Brittle Crown | 脆冠 | 命中 30% 获 2（+2/层）金币；受伤时按损失生命百分比失去等量金币。 | — |
| Corpsebloom | 尸花 | Heal +100% (+100%/层) more. All healing is applied over time. Can heal for a maximum of 10% (-50%/层) of your health per second. | LinearReciprocal |
| Defiant Gouge | 挑衅凿痕 | Using a Shrine summons enemies (stronger/层) nearby. Scales over time. | Linear |
| Eulogy Zero | 零之挽歌 | Items have a 5% (+5%/层) 概率become a Lunar item instead. | Linear |
| Focused Convergence | 聚焦汇聚 | Teleporters charge 30% (+30%/层) faster, but the size of the Teleporter zone is 50% (-50%/层) smaller. | LinearReciprocal |
| Gesture of the Drowned | 溺水者姿态 | Reduce Equipment cooldown by 50% (+15%/层). Forces your Equipment to activate whenever it is off cooldown. | Exponential |
| Light Flux Pauldron | 光通肩甲 | Decrease skill cooldowns by 50% (+50%/层). Decrease attack speed by 50% (+50%/层). | ExponentialReciprocal |
| Longstanding Solitude | 长久孤独 | On level up gain a free unlock for the next purchase (+1/层) but all gold is converted to experience. Anything that costs gold is increased by 50% (+50%/层). | Linear |
| Mercurial Rachis | 水银脊柱 | Creates a Ward of Power in a random location nearby that buffs both enemies and allies within 16m (+50%/层), causing them to deal +50% damage. | Exponential |
| Purity | 纯净 | All skill cooldowns are reduced by 2 (+1/层) seconds. All random effects are rolled +1 (+1/层) times for an unfavorable outcome. | Linear |
| Shaped Glass | 成型玻璃 | 基础伤害 +100% (+100%/层). 最大生命 -50% (+50%/层). | Exponential |
| Stone Flux Pauldron | 石通肩甲 | Increase max health by 100% (+100%/层). Reduce movement speed by 50% (+50%/层). | LinearReciprocal |
| Transcendence | 超凡 | Convert all but 1 health into regenerating shields. Gain 50% (+25%/层) maximum health. | Linear |

## 4. 装备（32）

### 4.1 主动装备（22）

| 英文名 | 中文名 | 效果摘要 | 冷却 |
| --- | --- | --- | --- |
| Blast Shower | 净化淋浴 | Cleanse all negative effects. Includes debuffs, damage over time, and nearby projectiles. | 20s |
| Disposable Missile Launcher | 一次性导弹发射器 | Fire a swarm of 12 missiles that deal 12x300% damage. | 45s |
| Foreign Fruit | 外来水果 | Instantly heal for 50% of your maximum health. | 45s |
| Forgive Me Please | 请原谅我 | Throw a cursed doll out that triggers any On-Kill effects you have every 1 second for 8 seconds. | 45s |
| Fuel Array | 燃料阵列 | Looks like it could power something. EXTREMELY unstable... | - |
| Gnarled Woodsprite | 虬曲林精灵 | Gain a Woodsprite follower that heals for 1.5% of your maximum health/second. Can be sent to an ally to heal them for 10% of their maximum health. | 15s |
| Goobo Jr. | 小 Goobo | Spawn a gummy clone that has 300% damage and 300% health. Expires in 30 seconds. | 100s |
| Gorag's Opus | Gorag 杰作 | All allies enter a frenzy for 7 seconds. 移动速度 +50% and attack speed by 100%. | 45s |
| Jade Elephant | 玉象 | Gain 500 armor for 5 seconds. | 45s |
| Milky Chrysalis | 乳白蛹 | Sprout wings and fly for 15 seconds. Gain +20% movement speed for the duration. | 60s |
| Ocular HUD | ocular 平视显示器 | Gain +100% Critical Strike Chance for 8 seconds. | 60s |
| Preon Accumulator | 前子蓄能器 | Fires preon tendrils, zapping enemies within 35m for up to 600% damage/second. On contact, detonate in an enormous 20m explosion for 4000% damage. | 140s |
| Primordial Cube | 原初立方 | Fire a black hole that draws enemies within 30m into its center. Lasts 10 seconds | 60s |
| Radar Scanner | 雷达扫描仪 | Reveal all interactables within 500m for 10 seconds. | 45s |
| Recycler | 回收器 | Transform an Item or Equipment into a different one. Can only be converted into the same tier one time. | 45s |
| Royal Capacitor | 皇家电容器 | Call down a lightning strike on a targeted monster, dealing 3000% damage and stunning nearby monsters. | 20s |
| Seed of Life | 生命之种 | Revive dead, friendly Survivors upon activation. Dying while holding this Equipment returns only you to life. Reviving gives 3s of invulnerability and consumes the equipment. | 60s |
| Super Massive Leech | 超巨水蛭 | Heal for 20% of the damage you deal. Lasts 8 seconds. | 60s |
| The Back-up | 后备支援 | Call 4 Strike Drones to fight for you. Lasts 25 seconds. | 100s |
| The Crowdfunder | 众筹者 | Fires a continuous barrage that deals 100% damage per bullet. Costs $1 per bullet. Cost increases over time. | - |
| Trophy Hunter's Tricorn | 猎宝者三角帽 | Execute any enemy capable of spawning a unique reward, and it will drop that item. Equipment is consumed on use. | 0s |
| Volcanic Egg | 火山蛋 | Turn into a draconic fireball for 5 seconds. 造成 500% damage on impact. Detonates at the end for 800% damage. | 30s |

### 4.2 月球装备（4）

| 英文名 | 中文名 | 效果摘要 | 冷却 |
| --- | --- | --- | --- |
| Effigy of Grief | 悲伤雕像 | ALL characters within are slowed by 50% and have their armor reduced by 20. Can place up to 5. | 15s |
| Glowing Meteorite | 发光陨石 | Rain meteors from the sky, damaging ALL characters for 600% damage per blast. Lasts 20 seconds. | 140s |
| Helfire Tincture | 地狱火酊 | Ignite ALL characters within 15m for 12s. 造成 5% of your maximum health/second as burning as damage. The burn is 0.5x stronger on yourself, 0.25x stronger on allies, and 24x stronger on enemies. | 45s |
| Spinel Tonic | 尖晶石 tonic | 60s | — |

### 4.3 精英装备（6）

> 精英装备主要为被动「aspect」变身；由对应精英怪极低概率掉落。

| 英文名 | 中文名 | 效果摘要 | 备注 |
| --- | --- | --- | --- |
| Her Biting Embrace | 刺骨拥抱 | Become an aspect of ice. | 被动 |
| His Reassurance | 大地 reassurance | Become an aspect of earth. | 被动 |
| Ifrit's Distinction | 伊芙利特印记 | Become an aspect of fire. | 被动 |
| N'kuhana's Retort | N'kuhana 反驳 | Become an aspect of corruption. | 被动 |
| Silence Between Two Strikes | 两击之间的寂静 | Become an aspect of lightning. | 被动 |
| Spectral Circlet | 幽灵头环 | Become an aspect of incorporeality. | 被动 |

## 5. 幸存者技能（10）

基础版可玩：**Commando、Huntress、Bandit、MUL-T、Engineer、Artificer、Mercenary、Rex、Loader、Acrid**。



#### Commando 指挥官

- **解锁**：默认
- **基础属性**：110 HP · 12 伤害 · 1/s 回血 · 7 m/s · 0 护甲

| 槽位 | 技能 | 解锁 | 效果摘要 |
| --- | --- | --- | --- |
| Primary | Double Tap 双连射 | 默认 | 快速射击，100% 伤害/发 |
| Secondary | Phase Round 相位弹 | 默认 | 穿透弹 300% 伤害，每穿透 +40% |
| Secondary | Phase Blast 相位爆 | Rolling Thunder | 两发近距霰弹 8×200% |
| Utility | Tactical Dive 战术翻滚 | 默认 | 短距翻滚 |
| Utility | Tactical Slide 战术滑铲 | Godspeed | 滑铲，可射击 |
| Special | Suppressive Fire 压制火力 | 默认 | 眩晕连射 100%/发，攻速加成弹数 |
| Special | Frag Grenade 破片手雷 | Incorruptible | 700% 爆炸，最多 2 枚 |

#### Huntress 女猎手

- **解锁**：Warrior 挑战
- **基础属性**：110 HP · 12 伤害 · 1/s 回血 · 7 m/s · 0 护甲

| 槽位 | 技能 | 解锁 | 效果摘要 |
| --- | --- | --- | --- |
| Primary | Strafe 扫射 | 默认 | 敏捷，追踪箭 150% |
| Primary | Flurry 连射 | Finishing Touch | 3 箭各 100%，暴击 6 箭 |
| Secondary | Laser Glaive 激光飞刃 | 默认 | 最多弹 6 次 250%/次，每次 +10% |
| Utility | Blink 闪现 | 默认 | 向前传送 |
| Utility | Phase Blink 相位闪现 | One Shot One Kill | 最多 3 充能短距传送 |
| Special | Arrow Rain 箭雨 | 默认 | 传送到空中，范围减速 +330%/s |
| Special | Ballista 弩炮 | Piercing Wind | 向后传送，最多 3 发各 900% |

#### Bandit 强盗

- **解锁**：Classic 挑战
- **基础属性**：110 HP · 12 伤害 · 1/s 回血 · 7 m/s · 0 护甲

| 槽位 | 技能 | 解锁 | 效果摘要 |
| --- | --- | --- | --- |
| Passive | Backstab 背刺 | 默认 | 背后攻击必暴击 |
| Primary | Burst 霰弹 | 默认 | 霰弹 5×100%，4 发弹仓 |
| Primary | Blast 步枪 | Classic Man | 单发 330%，4 发弹仓 |
| Secondary | Serrated Dagger 锯齿匕首 | 默认 | 冲刺 360%，暴击流血 |
| Secondary | Serrated Shiv 锯齿飞刀 | Sadist | 飞刀 240%，暴击流血 |
| Utility | Smoke Bomb 烟雾弹 | 默认 | 200% + 隐身 + 200% |
| Special | Lights Out 熄灯 | 默认 | 600% 处决，击杀重置冷却 |
| Special | Desperado 亡命 | B&E | 600% 处决，击杀叠伤害 token |

#### MUL-T MUL-T

- **解锁**：Verified 挑战
- **基础属性**：200 HP · 11 伤害 · 1/s 回血 · 7 m/s · 12 护甲

| 槽位 | 技能 | 解锁 | 效果摘要 |
| --- | --- | --- | --- |
| Passive | Multifunctional 多功能 | 默认 | 可同时持有两件装备 |
| Primary | Auto-Nailgun 钉枪 | 默认 | 70%/发 + 12 钉齐射 |
| Primary | Rebar Puncher 钢筋拳 | 默认 | 穿透 600% |
| Primary | Scrap Launcher 废料发射 | Pest Control | 爆炸 360%，4 发 |
| Primary | Power-Saw 电锯 | Gotcha! | 1000%/s 范围锯 |
| Secondary | Blast Canister 爆破罐 | 默认 | 220% + 5×44% 眩晕弹 |
| Utility | Transport Mode 运输模式 | 默认 | 冲刺 250%，+200  armor |
| Special | Retool 改装 | 默认 | 切换装备与主武器 |
| Special | Power Mode  power 模式 | Seventh Day | 双主武 +100 护甲 -60% 移速 |

#### Engineer 工程师

- **解锁**：Engineer 挑战
- **基础属性**：130 HP · 14 伤害 · 1/s 回血 · 7 m/s · 0 护甲

| 槽位 | 技能 | 解锁 | 效果摘要 |
| --- | --- | --- | --- |
| Primary | Bouncing Grenades 弹跳雷 | 默认 | 最多 8 雷各 100% |
| Secondary | Pressure Mines 压力地雷 | 默认 | 两阶段 300%/900%，4 个 |
| Secondary | Spider Mines 蜘蛛雷 | 100% Calculated | 600% 追踪，4 个 |
| Utility | Bubble Shield 气泡盾 | 默认 | 不可穿透护盾 |
| Utility | Thermal Harpoons 热追踪 | Zero Sum | 锁定发射 500%×4 |
| Special | TR12 Gauss 高斯炮塔 | 默认 | 继承物品，100%，2 座 |
| Special | TR58 Carbonizer 碳化炮塔 | Better With Friends | 移动激光 200%/s 减速 |

#### Artificer 工匠

- **解锁**：Pause 挑战
- **基础属性**：110 HP · 12 伤害 · 1/s 回血 · 7 m/s · 0 护甲

| 槽位 | 技能 | 解锁 | 效果摘要 |
| --- | --- | --- | --- |
| Passive | ENV Suit 环境服 | 默认 | 长按跳跃悬浮 |
| Primary | Flame Bolt 火焰弹 | 默认 | 点燃 280%，4 充能 |
| Primary | Plasma Bolt 等离子弹 | Massacre | 280% 小范围爆炸 |
| Secondary | Charged Nano-Bomb 充能纳米弹 | 默认 | 400%–2000% 爆炸 |
| Secondary | Cast Nano-Spear 纳米矛 | Chunked! | 400%–1200% 穿透冻结 |
| Utility | Snapfreeze 急冻 | 默认 | 屏障 100%/s |
| Special | Flamethrower 喷火 | 默认 | 点燃 2000% |
| Special | Ion Surge 离子涌动 | Orbital Bombardment | 升空 800% 眩晕 |

#### Mercenary 佣兵

- **解锁**：True Respite 挑战
- **基础属性**：110 HP · 12 伤害 · 1/s 回血 · 7 m/s · 20 护甲

| 槽位 | 技能 | 解锁 | 效果摘要 |
| --- | --- | --- | --- |
| Passive | Cybernetic Enhancements 义体 | 默认 | 二段跳 |
| Primary | Laser Sword 激光剑 | 默认 | 敏捷 130%，每 3 击大范围暴露 |
| Secondary | Whirlwind 旋风 | 默认 | 2×200% 横斩（空中纵斩） |
| Secondary | Rising Thunder 升龙 | Demon of the Skies | 550% 升龙击飞 |
| Utility | Blinding Assault 盲攻 | 默认 | 300% 冲刺，最多 3 连 |
| Utility | Focused Assault 专注突击 | Flash of Blades | 700% 冲刺 +1s 暴露 |
| Special | Eviscerate 剔骨 | 默认 | 110% 连击，期间无敌 |
| Special | Slicing Winds 风刃 | Ethereal | 8×100% 风刃，末击暴露 |

#### Rex REX

- **解锁**：Power Plant 挑战
- **基础属性**：130 HP · 12 伤害 · 1/s 回血 · 7 m/s · 20 护甲

| 槽位 | 技能 | 解锁 | 效果摘要 |
| --- | --- | --- | --- |
| Passive | Natural Toxins 天然毒素 | 默认 | 部分攻击弱化敌人 |
| Primary | DIRECTIVE: Inject 注射 | 默认 | 3×80%，末针弱化并吸血 60% |
| Secondary | Seed Barrage 种子弹幕 | 默认 | 15% HP，迫击 450% |
| Secondary | DIRECTIVE: Drill 钻探 | Bushwhacked | 450%/s 种子雨 |
| Utility | DIRECTIVE: Disperse 驱散 | 默认 | 音波弱化 |
| Utility | Bramble Volley 荆棘齐射 | Dunked | 20% HP，550% 音波，命中回血 |
| Special | Tangling Growth 缠结生长 | 默认 | 25% HP，定身 200%，命中回血 |
| Special | DIRECTIVE: Harvest 收割 | Full of Life | 330% 注入，死亡掉治疗果 |

#### Loader 装载机

- **解锁**：Guidance Offline 挑战
- **基础属性**：160 HP · 12 伤害 · 2.5/s 回血 · 7 m/s · 20 护甲

| 槽位 | 技能 | 解锁 | 效果摘要 |
| --- | --- | --- | --- |
| Passive | Scrap Barrier 废料屏障 | 默认 | 免疫坠落；拳套命中获屏障 |
| Primary | Knuckleboom 指节爆裂 | 默认 | 320% 近战 |
| Secondary | Grapple Fist 抓钩拳 | 默认 | 拉向目标 |
| Secondary | Spiked Fist 尖刺拳 | Swing By | 320% 眩晕，轻重目标拉扯方向相反 |
| Utility | Charged Gauntlet 充能拳套 | 默认 | 重击 600%–2700% 穿透 |
| Utility | Thunder Gauntlet 雷霆拳套 | Earthshatter | 2100% 单目标 + 1000% 锥形电击 |
| Special | M551 Pylon 电桩 | 默认 | 浮空电桩 100%×6，可抓钩 |
| Special | Thunderslam 雷霆猛击 | The Thunderdome | 2000% 砸地眩晕 |

#### Acrid 腐蚀兽

- **解锁**：Experiment and Error 挑战
- **基础属性**：160 HP · 15 伤害 · 2.5/s 回血 · 7 m/s · 20 护甲

| 槽位 | 技能 | 解锁 | 效果摘要 |
| --- | --- | --- | --- |
| Passive | Poison 毒素 | 默认 | 毒伤 DOT |
| Passive | Blight 枯萎 | Easy Prey | 毒改为可叠 Blight 60%/s |
| Primary | Vicious Wounds 凶创 | 默认 | 200%，每 3 击再生 400% |
| Secondary | Neurotoxin 神经毒素 | 默认 | 毒性 spit 240% |
| Secondary | Ravenous Bite 贪婪撕咬 | Bad Medicine | 320% 处决再生 |
| Utility | Caustic Leap 腐蚀跃击 | 默认 | 320% + 酸池 25% |
| Utility | Frenzied Leap 狂跃 | Pandemic | 550%，每命中 -2s CD |
| Special | Epidemic 瘟疫 | 默认 | 100% 可扩散至 20 目标 |

#### Heretic 异端者（隐藏）

非商店解锁：收集异端系列月球道具后，本 run 内替换当前幸存者。高 HP/高伤/负回血，技能含 Hungering Gaze、Shadowfade、Slicing Maelstrom、Ruin。**本文不展开异端配装。**


## 6. 设计模式摘要（策划向）

| 模式 | 说明 |
| --- | --- |
| 叠层经济 | 白装数量堆线性收益（注射器、撬棍），红装/月球提供质变；构筑在「广度 vs 尖峰」间取舍。 |
| OnHit 触发链 | AtG 导弹、尤克里里、粘性炸弹等由攻击触发；高 Proc 系数技能更易联动。 |
| OnKill 正反馈 | 怪物之牙、汽油、仪式匕首等击杀链；类比 `OnKill` / `OnFriendDeath` 联动技能。 |
| 月球双刃剑 | 成型玻璃（+100% 伤 / -50% 血）、溺水者姿态（强装备 + 强制自动）——强效果必带明确代价。 |
| Boss 绑定掉落 | 黄装与 Teleporter Boss 绑定（如泰坦节瘤 ↔ 石巨人）；可类比 milestone / 关底专属奖励。 |
| Loadout 流派 | 同角色多技能变体（佣兵冲刺 vs 风刃）对应不同 playstyle；类比单位技能分支或合成换技能。 |
| 团队增益 | 忙碌真菌、战旗、Lepton Daisy 等范围治疗/ buff；类比 `ALL_ALLIES` 目标选择器。 |
| 装备 vs 被动 | 主动装备提供 burst（皇家电容器），被动提供持续修饰；类比战斗内主动技能 vs 永久增益卡。 |

## 7. 外部链接

- [Items](https://riskofrain2.wiki.gg/wiki/Items)
- [Item Stacking](https://riskofrain2.wiki.gg/wiki/Item_Stacking)
- [Survivors](https://riskofrain2.wiki.gg/wiki/Survivors)
- [Skills/Data](https://riskofrain2.wiki.gg/wiki/Module:Skills/Data)
- [Commando](https://riskofrain2.wiki.gg/wiki/Commando)
