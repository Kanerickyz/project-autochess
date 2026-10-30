# Sim Balance · iter_016 招募策略审阅

**数据**：`tools/sim_balance/reviews/iter_016_bundle.json`（apply iter001 plan 后 train 500 / eval 100，`bandit-v4`）  
**对照**：iter001 后 F4+ 从约 15% 升至 **34%**，F2/F3 遭遇胜率明显改善，但 **败局众数仍为 F2**，**F12+ 仍为 0**，最深 **F10**。

---

## 1. KPI 快照

| 指标 | iter_016 | 含义 |
|------|----------|------|
| `f4_plus_rate` | **0.34** | M-B 达标方向正确 |
| `death_floor_mode` | **2** | 仍有大量 Run 倒在 F2（与 reach F3=64% 一致：约 36% 未过 F2） |
| `death_floor_mean` | **3.58** | 比 iter001 前浅层集中略好，但众数未迁移 |
| `max_floor_any_run` | **10** | 4% Run 触达 F10 |
| `reach_floor_12_rate` | **0** | 用户目标未触达 |
| F10 遭遇 | **4 尝试，胜率 0%** | 当前唯一 `weak_encounter_floors` 条目 |

**到达率阶梯**（`reach_floor_rate`）：F3 64% → F4 34% → … → F10 **4%**。瓶颈呈 **双段**：浅层 **F2 众数死亡** + 深层 **F10 全灭**。

---

## 2. F2 众数：招募仍在「养废表」

iter001 已抬 `shield_boon` / `paymaster`，但 bundle 显示 **浅层 pick 仍偏多**：

### 2.1 `units_in_shallow_runs` vs `units_in_deep_runs`

| 信号 | 浅层高频 | 深层高频 | 结论 |
|------|----------|----------|------|
| 核心误招 | `skeleton` 25 / `echo_spear` 22 / `archer` 18 | `skeleton` 仅 3 | **继续强 penalize skeleton**；echo_spear/archer 浅层偏置 |
| iter001 误伤 | — | `spear_goblin` **8**、`rune_plate` **6**、`edge_hex` **6** | **撤销** iter001 对 spear_goblin/rune_plate 的 penalize，改为 boost |
| 仍有效 | `paymaster` 浅 14 / 深 8 | 深 Run 常带账房 | 维持并加大 F1–F3 paymaster |
| 顶层 core | `aftershock` 浅 32 / 深 7 | 双高因 F1 合成 | 保留轻 boost，F3 优先合成而非扩 skeleton |

### 2.2 `recruit_picks_by_floor` 热点

- **F1**：aftershock/crossbow/echo_spear/skeleton 仍并列 30+ 次；`shield_boon` 仅 22 → **F1 floor_boost + seed** 继续压 skeleton、抬 paymaster/shield_boon。
- **F3**：**skeleton 9 次为层内第一**（aftershock 仅 6）→ 这是 **death_floor_mode=2 的残留根因之一**：F3 招募仍在补 skeleton 链而非盾/账房/合成。
- **F2**：aftershock 14、paymaster 8 尚可；需避免 edge_hex/knight 回流。

**审阅结论（F2 众数）**：数值墙已从「F3 遭遇 23%」缓解，但 **败局直方图仍钉在 F2**，说明 **第一次 F2 胜后至 F3 前的 roster 方差**仍大。tools-only 手段 = **F1–F3 更狠的 skeleton penalize + F3 seed_rows 推 shield_boon/aftershock 合成**。

---

## 3. F10 墙：遭遇 0/4，招募在前层已定型

### 3.1 遭遇曲线（iter_016 summary）

F6–F8 胜率 69% / 60% / 67%，F9 仅 1 次尝试且胜；**F10 四次全败**。样本小但 **0% 一致**，符合「进 F10 的 4 局阵容未达层需求」而非噪声。

### 3.2 深层招募（`recruit_picks_by_floor` F6–F9）

| 层 | 常见 pick | 与 deep_runs 关系 |
|----|-----------|-------------------|
| F6 | flower_drum, gravewright, wardrum | gravewright 在 deep 向 F6 出现 |
| F7 | blood_wage, spear_goblin, mend_friar | spear_goblin **deep 8**；mend_friar 仅 1 次 pick |
| F8 | horsebow, dirge_horn, armorer, mend_friar | **dirge_horn deep 4**；F8 是最后一次大规模招募 |
| F9 | spear_goblin, crossbow 各 1 | 样本极少 |

**bundle 无 F10 recruit**（胜后招募发生在进下一层战斗之前）：**F10 战时的队伍 = F6–F9 决策累积**。当前 patch 方向：

1. **Boost** `dirge_horn`、`mend_friar`、`armorer`、`horsebow`、`gravewright`、`musketeer`（deep_runs + F6–F8 pick 交集）。
2. **F8 `floor_unit_boosts` + seed_rows**：在 checkpoint 常见 `g35`/`g40` 富金状态下，店含 `dirge_horn|mend_friar|musketeer` 时避免再选 `spike_shield`/`crossbow` 重复堆叠。
3. **Penalize** `spike_shield`、`wood_drum`（F8 shop 里拖 deep 的重复防御位）。

** realistic 预期**：w/l patch 可 **提高 F10 到达率与 F10 遭遇胜率**，但 **F12 需要 F10–F11 连续胜**；在 100 局 eval 下 F11 样本仍可能为 0，须 **patch + train 500+ 再 eval** 验证 `max_floor_any_run` 与 `reach_floor_12_rate`。

---

## 4. iter_016 plan 相对 iter001 的调整

| 项 | iter001 | iter016 修正 |
|----|---------|--------------|
| spear_goblin | penalize | **boost**（deep 8） |
| rune_plate | penalize | **boost**（deep 6） |
| edge_hex | penalize | **不再 penalize**（deep 6） |
| echo_spear | boost | **penalize**（浅 22、深榜外） |
| skeleton | l_add 3 | **l_add 4**，F3 seed 推合成 |
| 层域 | F2–F3 为主 | **+ F4 过渡 + F6–F9 深招** |

产出：`tools/sim_balance/reviews/iter_016_plan_balance.json`

---

## 5. tools-only 边界（仍成立）

- 无法保证 **F4 先扩席**、无法 **无视 recruit 价**；F10 若因 **席位/人数** 不足失败，需 HeuristicRunAI 或游戏规则变更。
- F10 样本 n=4，eval 波动大；应以 **train 后 frozen eval 200 局** 或多次 iter 观察 F10 尝试次数与胜率。
- **max_floor≥12** 最终依赖 v4 奖励在 D≥8 的招募上积累足够 `(state, unit_id)` 样本，单轮 patch 仅为偏置。

---

## 6. 建议集成顺序

```bash
python3 tools/sim_balance/apply_optimization.py \
  --checkpoint tools/sim_balance/models/active.tres \
  --plan tools/sim_balance/reviews/iter_016_plan_balance.json \
  --report tools/sim_balance/reports/iter_016_apply_report.json
bash tools/sim_balance/train_eval_round.sh
```

观察：`death_floor_mode` 是否从 2→3、`reach_floor_rate["10"]` 与 F10 `win_rate`、`max_floor_any_run` 是否 ≥11/12。
