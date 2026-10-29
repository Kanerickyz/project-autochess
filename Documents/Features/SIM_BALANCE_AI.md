# Sim Balance · 决策 AI（批跑专用）

> **范围**：仅 `scripts/sim_balance/` 与 `resources/sim_balance/`；**不是**玩家对战 AI，不影响 `run_game` 主路径。  
> **目的**：在 headless Run 里做**可复现**的商店 / 招募 / 选路 / 站位，使平衡报告能反映「某种会玩法的代理」下的遭遇胜率，而不是随机乱点。

## As-Is

- `HeuristicRunAI`：固定规则 + 少量 `SimAIProfile` 开关（优先单位 id、是否偏好商店、买旗帜、招募轮数上限）。
- 招募打分：`(atk+hp)/cost` + 合成/优先单位加分；选路：到 Boss 最短路 + 类型 tie-break；站位：按 `(atk+hp)×level` 前排居中向外。

## 平衡报告里「更智能」指什么

| 目标 | 说明 |
|------|------|
| **更像会构筑** | 会取舍合成、扩席、路线，而不是纯面板怪 |
| **可对比** | 改数值后同一策略下指标变化可归因到关卡/单位，而不是「AI 变蠢了」 |
| **可复现** | 同 seed、同 `profile_id` → 同报告；便于 CI 与回归 |
| **非目标** | 训练出超越人类的最优解；v1 不做在线学习写进 Godot |

## 推荐路线（由轻到重）

### 1. 可调效用函数（当前优先，已部分落地）

在 `SimAIProfile` 上暴露**打分权重**（招募/卖弱/选路/站位），替代代码里的魔法数。  
**调参方式**：手调、`balance-designer` 改 `.tres`、或仓库外脚本做**网格/贝叶斯/ CMA-ES**（读 `summary.json` 当 fitness）。  
**优点**：实现小、完全可解释、和 Godot 批跑天然兼容。  
**缺点**：不能自动发现「非明显」组合策略。

### 2. 多策略档案（weak / default / greedy）

维护多个 `SimAIProfile`（不同权重与 `priority_unit_ids`），报告页 `meta.ai_profile_id` 区分。  
**用途**：看同一关卡在「弱/中/强代理」下是否都过难；比单一 RL 策略更适合平衡工作。

### 3. 短视野搜索（MCTS / 有限深度 rollout）

在**招募二选一**或**地图下一格**上，用当前启发式当 rollout policy，模拟 K 次短 Run 或仅模拟到下一战斗。  
**优点**：比纯启发式强，仍不必神经网络。  
**缺点**：100 局 × 搜索 → CPU 暴涨；需缓存、降 K 或只用在关键节点。

### 4. 离线 RL（Python 环 + 导出策略）

```text
Godot headless (或 JSON 步进 API)  ←→  Gym 环境
       ↑
 Stable-Baselines3 / 自写 PPO（离散：候选招募 index、地图 option index）
       ↓
 导出：查表 / 线性权重 → 写回 SimAIProfile 或 SimPolicyWeights.tres
```

**状态（示例）**：金币、席位数、 roster 摘要向量、当前层、候选单位 atk/hp/cost、地图 option 类型。  
**奖励（示例）**：Boss 通关 +1、败局 −1、每层 small shaping（慎用，避免 AI 只刷安全层）。  
**优点**：能学非线性策略。  
**缺点**：样本贵、要固定版本与 seed 协议、策略漂移会让历史报告不可比；**必须**固定 `policy_id` + 训练 commit 归档。

**不建议 v1 在 GDScript 里直接跑神经网络**（无生态、难和 CI 100 局批跑对齐）。

## 与 `generate-balance-report` 的关系

- 报告 Schema 已有 `meta.ai_profile_id`；换策略换 profile，**不要**覆盖旧报告含义。
- 若引入 RL 导出 profile，归档命名建议含 `policy_id` 与训练 git sha（与现有 `run_id` 规则并列）。

## 当前实现检查点

- [x] `SimAIProfile` 权重字段（招募/选路/卖弱），供手调与外部优化器读取 `.tres`
- [ ] `SimAIPolicy` 接口 + `HeuristicRunAI` 实现（便于换 MCTS / 导出策略）
- [ ] 多 profile 资源 + 批跑 `--profile` CLI
- [ ] Python 调参脚手架（读 fitness = `run_complete_rate` 或分层胜率向量）
- [ ] RL 环境 PoC（非 v1 承诺）

## 验收建议

| 阶段 | 轻量 | 完全 |
|------|------|------|
| 权重 + 多 profile | 改 `.tres` + `run_sim_balance_verify.sh` | 2 个 profile 各 100 局，报告可切换对比 |
| MCTS / RL | 不纳入 CI 默认 | 单独 job + 固定 `policy_id` 文档 |

未立项前 **RL 训练 job 不进默认 Balance Report Pages**（避免 Actions 时间爆炸）。
