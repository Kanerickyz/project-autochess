# Sim Balance · iter_001 招募策略审阅（bandit-v4）

**审阅时间**：2026-10-29  
**数据**：`docs/balancereport/summary.json`（`ai_profile_id=bandit-v4.1`，100 局，`game_version=0.5.255`）  
**说明**：仓库内尚无 `tools/sim_balance/reviews/iter_001_bundle.json`，且 Pages 归档未附带 `runs.json`，故无法输出 `recruit_picks_by_floor` / deep-shallow 差分；以下以 summary 的层胜率、败局直方图与 `roster_unit_*_stats` 为准。

---

## 1. 当前 KPI 与 F12+ 差距

| 指标 | 数值 | 与目标关系 |
|------|------|------------|
| Boss 通关率 | 0% | M-C 未启动 |
| 败局众数层 | **F2**（52 次） | M-A：浅层死亡集中 |
| F4+ Run（估） | 15%（败于 F4–F11 共 15 局 + 0 通关） | M-B 远低于可持续爬深 |
| 任一局到达 F12+ | **0%**（最深触达 F11，1 次尝试且败） | 用户目标未触达 |

**到达深度（由 death_floor 反推）**：约 52% Run 止于 F2 前失败，另有 33% 止于 F3；能通过 F3 进入 F4 的 Run 仅约 **15%**。在未到 F4 稳定之前，讨论 F12+ 主要是「远期奖励形状」问题；当前 bandit 表与启发式选路都还在 **F2–F3 遭遇墙** 上耗样本。

---

## 2. 胜率瓶颈层

### 2.1 地图层遭遇胜率（战斗节点）

| 层 | 尝试 | 遭遇胜率 | 解读 |
|----|------|----------|------|
| F1 | 100 | 100% | 开局无压力 |
| **F2** | 90 | **42.2%** | 第一道主墙；与败局众数一致 |
| **F3** | 43 | **23.3%** | **最低胜率层**；样本仍足（43 次） |
| F4 | 11 | 36.4% | 样本少，但已是「深 Run」子集 |
| F5–F8 | 4–2 | 33–100% | 噪声大 |
| F11 | 1 | 0% | 单点，仅说明偶有触深 |

**结论**：优化招募策略的**第一优先级**是提升 **F2 胜后编队质量** 与 **F3 前最后一次招募/合成决策**，使更多 Run 带着「盾/经济/稳定前排」进入 F3 遭遇，而不是继续堆 skeleton、knight、goblin 等 **高出场、低 F4+ 率** 的单位。

### 2.2 败局死亡层分布

`death_floor_histogram`：F2=52，F3=33，F4=7，F5=4，F6=2，F8=1，F11=1。

- **85% 败局** 发生在 F3 及以前（52+33=85）。
- 进入 F4 后仍败的 15 局说明：即使过了 F3 墙，**阵容强度/人数** 仍不足以支撑后续层（与席位扩展示意、金币留底相关，见 §4）。

### 2.3 阵容内单位信号（summary 已聚合）

**偏「深 Run」**（`f4_plus_rate` 相对高且有一定 `runs_present`）：

- `shield_boon`：8/12 Run 到 F4+（66.7%）；遭遇胜率 68.4%
- `paymaster`：3/5（60%）；遭遇胜率 73.7%
- `aftershock`：2/5（40%）但遭遇胜率 73.7%，且为常见起手 core

**偏「浅 Run / 拖累」**（高 `runs_present`、低 `f4_plus_rate` 或低遭遇胜率）：

- `skeleton`：5/56 到 F4+（8.9%）；遭遇胜率 **40.4%**（样本 94）— 最强负向信号
- `knight`：7/35（20%）；`goblin`：6/28（21%）；`edge_hex` / `spear_goblin`：约 22–26%
- `rune_plate`、`spike_shield`：F4+ 率 &lt;20%，遭遇胜率中等偏下

这与 v4 设计一致：**同一 `team=` 签名下，选错 `unit_id` 会污染该 state 的 w/l**；全局 boost/penalize 适合纠正「被高频误招」的单位，**seed_rows** 适合纠正「常见 shop 组合里选错人」的热点 state。

---

## 3. 可在 tools-only 下应用的 v4 patch（`iter_001_plan_balance.json`）

通过 `apply_optimization.py` 对 checkpoint（如 `tools/sim_balance/models/active.tres`）做 **w/l 偏置**，不改游戏资源：

1. **全局 boost**：`shield_boon`、`paymaster`、`aftershock`、`echo_spear`（+ 小样本深 Run 的 `mend_friar` / `horsebow`），抬高在任意 `recruit4|…|shop=…` 下选这些 `unit_id` 的 posterior。
2. **全局 penalize**：`skeleton` 为主（l_add=3），辅以 `knight`、`goblin`、`edge_hex`、`spear_goblin`、`rune_plate`、`spike_shield`，压低浅层常用但 depth 差的选项。
3. **层条件 boost**：F2/F3 对 `shield_boon`、`paymaster`、`echo_spear` / `aftershock` 额外 w_add，对准 §2 的瓶颈层。
4. **seed_rows**：从现有 checkpoint 统计（`seed_v4_stats.json` 同源形态）中摘取 **F1 空队、F2/F3 典型 aftershock+paymaster 核** 的 hotspot：在「店里有 shield_boon / paymaster」时强推对应 action，在「edge_hex vs shield_boon」「skeleton 店 vs 合成 aftershock」等分支上补 w。

**集成命令示例**（仅 tools）：

```bash
python3 tools/sim_balance/apply_optimization.py \
  --checkpoint tools/sim_balance/models/active.tres \
  --plan tools/sim_balance/reviews/iter_001_plan_balance.json \
  --report tools/sim_balance/reports/iter_001_apply_report.json
```

**后续建议**（仍属 tools 流程）：

- patch 后跑 `train_eval_round.sh` 或 `train_bandit.sh --reward-mode v4`，让 v4 奖励 \((D/F_{max})^{0.75}\) 在 **D≥8** 的 pick 上继续扩表。
- 待本地批跑产出 `runs.json` 后，用 `analyze_for_review.py` 生成 `iter_001_bundle.json`，用 `recruit_picks_by_floor` 替换 §2 的推断项并收窄 seed_rows。

---

## 4. 无法在 tools-only 下做到的项

| 用户/产品期望 | As-Is 批跑约束 | 原因 |
|---------------|----------------|------|
| **无视招募价格、直选全池** | Sim 仍 `can_afford(recruit_cost)`，shop 仅为短名单 | 需改 `RecruitSession` / Sim AI，非 checkpoint patch |
| **F4 必先扩席再买人** | 扩席依赖 `HeuristicRunAI` 买旗帜且要有金 | bandit v4 **不学选路**；招募 state 不含「是否先买旗」动作 |
| **按 unit_id 选但绕过满员** | 满员仅能合成/替换/出售 | 表无法增加「非法」动作；需改招募逻辑或 Sim 层规则 |
| **单靠冻结评估达 F12+** | 评估无 UCB，样本 &lt;3 回退启发式 | 必须 **训练 + patch 交替** 或增大 train-runs |
| **从 summary 精算 recruit 组合** | 当前归档无 `runs.json` | 需批跑输出完整 run 日志或生成 bundle |

---

## 5. 对 F12+ 目标的现实路径

1. **阶段 A（本 plan）**：把 F4+ 率从 ~15% 拉到 **≥25–30%**（M-B），败局众数从 F2 推向 F3/F4。  
2. **阶段 B**：bundle 显示 F6–F8 招募热点后，再加 **floor 6–8 的 floor_unit_boosts** 与针对性 seed_rows（合成/高星 core）。  
3. **阶段 C**：若 F8+ 仍卡在席位与 economy，需 **游戏侧或 HeuristicRunAI** 调整扩席/留金，而非仅 bandit w/l。

---

## 6. 产出物

- 优化计划：`tools/sim_balance/reviews/iter_001_plan_balance.json`
- 本审阅：`tools/sim_balance/reports/iter_001_strategy_review.md`
