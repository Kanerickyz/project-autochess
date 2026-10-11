# Project Autochess：项目级工作规则

## 开始工作
- 用中文沟通；先读 [Documents/INDEX.md](Documents/INDEX.md)、相关设计文档和目标模块；检查 `git status`，保留用户修改。
- 设计意图来自 [Documents/GAME_VISION.md](Documents/GAME_VISION.md)、[Documents/SHOP_SYSTEM.md](Documents/SHOP_SYSTEM.md)、[Documents/BUFF_SYSTEM.md](Documents/BUFF_SYSTEM.md)、[Documents/ABILITIES.md](Documents/ABILITIES.md)；现有行为来自代码、场景与资源。发现冲突要说明，不把建议写成已完成。
- [Documents/ABILITY_PROPOSALS.md](Documents/ABILITY_PROPOSALS.md) 与愿景里未决的胜利条件是提案，不是实装。
- Godot 4.6、GDScript，默认入口 `scenes/main/main_menu.tscn`。
- Cloud Agent 环境应提供 PATH 上的 `godot`（4.6）；可用 `GODOT_BIN` 覆盖。Headless 验证：`godot --headless --path . --script res://scripts/**/*_test_runner.gd`。GUI 验收用桌面 DISPLAY（常见为 `:1`）；无声卡时引擎会回退 dummy 音频驱动，属预期。
- 用户当前请求优先于项目默认规则；只解决当前范围，不顺带重写游戏系统。

## 游戏约束
- 关卡制 / 爬塔 PvE 自走棋：商店构筑、手牌布阵、自动战斗。新增 PVP、羁绊或实时微操需明确设计需求。
- v1 不含种族/职业羁绊。流派来自单位内建技能、增益卡与站位。远期羁绊必须复用 `EffectSpec` / `EffectResolver`，禁止另写一套 Buff。
- 所有战斗增益经 `EffectSpec` + `EffectResolver`；`AbilityData` 引用 `Array[EffectSpec]`。
- 战斗触发只经 `CombatEventBus`；`DamagePipeline` / `UnitBrain` 只 emit，不直接改其他单位属性。流程与 UI 可用 Autoload；战斗内触发不走全局 Bus。
- 逻辑网格是矩形棋盘，邻接与距离用现有 `BoardGrid` / 战斗网格接口，不用六边形或曼哈顿距离替代。
- 数值优先改 `resources/` 下的 `.tres`（单位、技能、波次、经济、增益、牌库、商店池），避免新增重复硬编码。
- 主题是小动物 2D；表现与逻辑分离，战斗结果不依赖帧率。

## 实现与验证
- 规范见 [CONTRIBUTING.md](CONTRIBUTING.md)。保留 `.uid` 和导入侧车，不提交 `.godot/`、`.artifacts/`、导出凭据、日志与缓存。
- 不编辑生成缓存、不批量重写场景/资源；修改共享 Resource 前判断是否需 `duplicate()`，避免实例串色/串数值。
- 仓库尚无统一 `tools/verify.ps1`。按改动跑现有 `scripts/**/*_test_runner.gd`（以及同目录的 SceneTree runner）。不删断言或屏蔽错误来使检查变绿。
- UI、图标、相机改动必须 GUI 验收；记录入口、操作、实际结果与截图路径。Headless 通过不代表视觉或体验通过。
- 交付说明原因、验证结果与未覆盖项；日志、退出码和证据必须一致。

## Sub-agent 流程
- 主代理负责需求、任务拆分、共享文件、集成和交付；小型串行修改由主代理完成。跨模块切片按 [Documents/DEVELOPMENT_WORKFLOW.md](Documents/DEVELOPMENT_WORKFLOW.md) 派专职角色，并用 `vertical-slice` skill。
- Cursor 角色在 `.cursor/agents/*.md`，用 Task 委派。Customize 里看不见就不算已加载；改为手读对应 `.md` 再传合同。不能声称文件已自动加载。
- 每个纵切片自带目标等级 L0–L5。同时最多三个子代理。未触达的职业不强制到场。`project.godot`、共享场景与枚举由主代理统一修改。
- 集成后 QA 按目标等级给出结论，reviewer 只读审查；阻断缺陷返回实现阶段。L5 只修缺陷。验证用 `verify-godot` skill，画面用 `gui-acceptance` skill。
- 切片等级不取代文档里的 M1–M3 / Run 里程碑；里程碑描述已实现范围，L0–L5 描述当前切片质量。

## Git
- `main` 保持可验证；新工作使用 `feat/`、`fix/`、`docs/` 或 `chore/` 分支，按功能拆提交。
- 不改全局身份、不强推、不重置用户修改。发布、可见性改变和版本打标按用户任务授权执行。
