# Project Autochess：项目级工作规则

## 开始工作
- 用中文沟通；先读 [Documents/INDEX.md](Documents/INDEX.md)、相关设计文档和目标模块；检查 `git status`，保留用户修改。
- 设计意图来自 [Documents/GAME_VISION.md](Documents/GAME_VISION.md)、[Documents/SHOP_SYSTEM.md](Documents/SHOP_SYSTEM.md)、[Documents/BUFF_SYSTEM.md](Documents/BUFF_SYSTEM.md)、[Documents/ABILITIES.md](Documents/ABILITIES.md)；现有行为来自代码、场景与资源。发现冲突要说明，不把建议写成已完成。
- [Documents/ABILITY_PROPOSALS.md](Documents/ABILITY_PROPOSALS.md) 是提案，不是实装。胜负与主循环以 [Documents/GAME_VISION.md](Documents/GAME_VISION.md) 定稿为准（文档定稿 ≠ 代码已对齐时须对照实现）。写文档时遵守 [Documents/DEVELOPMENT_WORKFLOW.md](Documents/DEVELOPMENT_WORKFLOW.md)「养成规范」：**当前不做的默认不写进规格**。
- Godot 4.6、GDScript，默认入口 `scenes/main/main_menu.tscn`。
- Cloud Agent 环境应提供 PATH 上的 `godot`（4.6）；可用 `GODOT_BIN` 覆盖。Headless 验证：`godot --headless --path . --script res://scripts/**/*_test_runner.gd`。GUI 验收用桌面 DISPLAY（常见为 `:1`）；无声卡时引擎会回退 dummy 音频驱动，属预期。
- 用户当前请求优先于项目默认规则；只解决当前范围，不顺带重写游戏系统。
- **提出需求时先问验收方式**（见 [Documents/DEVELOPMENT_WORKFLOW.md](Documents/DEVELOPMENT_WORKFLOW.md)「验收方式」）：**轻量** = `bash tools/run_light_verify.sh` 加载通过即可，效果由用户验；**完全** = 现行 runner + 按 L 级 QA/GUI。未指定先问再做。

## 游戏约束
- 关卡制 / 爬塔 PvE 自走棋：商店构筑牌库、准备预布阵、战斗中 **cycle 补人**（人口上限；玩家不可拖动已上场单位）、上场单位自动实时战斗。新增 PVP、羁绊或单位微操走位需明确设计需求。
- v1 不含种族/职业羁绊。流派来自单位内建技能、增益卡与站位。若将来加羁绊必须复用 `EffectSpec` / `EffectResolver`，禁止另写一套 Buff。
- 所有战斗增益经 `EffectSpec` + `EffectResolver`；`AbilityData` 引用 `Array[EffectSpec]`。
- 战斗触发只经 `CombatEventBus`；`DamagePipeline` / `UnitBrain` 只 emit，不直接改其他单位属性。流程与 UI 可用 Autoload；战斗内触发不走全局 Bus。
- 战场是 18×32 矩形逻辑格（竖屏、我下敌上）：格子只用于投放吸附与半场判定；开战后单位在连续坐标上实时移动与攻击（`scripts/combat/realtime/`，长度单位为格、固定步长），不用六边形替代。旧回合制格子战斗（`main.tscn` / 沙盒）为旧工具环，仍用 `BoardGrid`。
- 数值优先改 `resources/` 下的 `.tres`（单位、技能、波次、经济、增益、牌库、商店池），避免新增重复硬编码。
- 主题是中世纪幻想 2D（设定定稿；单位命名/美术可能仍为旧动物占位）；表现与逻辑分离，战斗结果不依赖帧率。

## 实现与验证
- 规范见 [CONTRIBUTING.md](CONTRIBUTING.md)。保留 `.uid` 和导入侧车，不提交 `.godot/`、`.artifacts/`、导出凭据、日志与缓存。
- 不编辑生成缓存、不批量重写场景/资源；修改共享 Resource 前判断是否需 `duplicate()`，避免实例串色/串数值。
- **轻量验收**：`bash tools/run_light_verify.sh`；不跑全套 runner、不代做 GUI/效果验收。
- **完全验收**：按改动跑现有 `scripts/**/*_test_runner.gd`（或 `bash tools/run_verify_runners.sh`）。不删断言或屏蔽错误来使检查变绿。UI/图标/相机须 GUI 证据；Headless 通过不代表视觉通过。
- 交付说明验收方式、原因、验证结果与未覆盖项；日志、退出码和证据必须一致。

## Sub-agent 流程
- 主代理负责需求、任务拆分、共享文件、集成和交付；小型串行修改由主代理完成。跨模块切片按 [Documents/DEVELOPMENT_WORKFLOW.md](Documents/DEVELOPMENT_WORKFLOW.md) 派专职角色，并用 `vertical-slice` skill。
- Cursor 角色在 `.cursor/agents/*.md`，用 Task 委派。Customize 里看不见就不算已加载；改为手读对应 `.md` 再传合同。不能声称文件已自动加载。
- 每个纵切片自带目标等级 L0–L5。同时最多三个子代理。未触达的职业不强制到场。`project.godot`、共享场景与枚举由主代理统一修改。
- **完全验收**下：集成后 QA 按目标等级给出结论，reviewer 只读审查；阻断退回实现。L5 只修缺陷。验证用 `verify-godot`，画面用 `gui-acceptance`。**轻量验收**不派 QA/GUI，加载烟测即可。
- 切片等级不取代文档里的 M1–M3 / Run 里程碑；里程碑描述已实现范围，L0–L5 描述当前切片质量；验收方式见 DEVELOPMENT_WORKFLOW。

## Git
- `main` 保持可验证；新工作使用 `feat/`、`fix/`、`docs/` 或 `chore/` 分支，按功能拆提交。
- 不改全局身份、不强推、不重置用户修改。发布、可见性改变和版本打标按用户任务授权执行。
