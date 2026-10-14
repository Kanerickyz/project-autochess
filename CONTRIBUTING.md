# 开发与代码规范

## Git

从 `main` 创建 `feat/<topic>`、`fix/<topic>`、`docs/<topic>` 或 `chore/<topic>`；提交用 `feat(shop): ...`、`fix(combat): ...` 等格式，一个提交解决一个问题。PR 说明行为、验证与必要画面证据。

项目使用 UTF-8。保留 `.uid` 和资产 `.import` 侧车，不提交 `.godot/`、`.artifacts/`、凭据或导出包。大文件接近 GitHub 单文件限制前评估 LFS，不只提交指针而遗漏对象。

## GDScript

- 遵循现有代码：tab 缩进；文件/函数/变量 `snake_case`，`class_name` PascalCase，常量/枚举 `UPPER_SNAKE_CASE`，私有成员前缀 `_`。
- 公开接口、资源字段和集合尽量声明类型；`:=` 仅用于明确类型，动态 `Dictionary.get()` 显式转换。
- 按类声明、常量、导出变量、状态、生命周期、公开接口、私有实现组织；顶层函数间保留两行空行。
- 用信号和明确接口连接模块；避免把无关系统继续堆进 `board_controller.gd` 或单个 UI 脚本。
- 资源使用 `res://`，玩家数据使用 `user://`，不写死个人路径。
- 缓存稳定引用，避免每帧扫描全树、加载资源或创建材质；清理信号和临时节点，遵守 `queue_free()` 生命周期。
- 边界处校验输入/资源；错误包含上下文，不能用静默回退隐藏逻辑错误。
- 邻接/距离使用现有棋盘网格接口；随机数通过传入或可复现的 `RandomNumberGenerator` 控制，复现记录种子。

## Godot 资源与编辑器

- 数值改 `resources/units/`、`resources/abilities/`、`resources/buffs/`、`resources/levels/`、`resources/encounters/`、`resources/economy/`、`resources/shop/`、`resources/deck/` 等 `.tres`，保留加载接口兼容。
- 修改枚举须检查序列化整数及 `.tres`，不重排现有成员。
- 场景尽量用编辑器修改；文本修改保持资源 ID/UID 与引用。提交前确认没有丢失 `.uid` 或 `.import`。
- 共享 `Resource` 进入运行时实例前判断是否需 `duplicate()`，避免商店、牌库、战斗单位串数值。
- 视觉效果保持 **GL Compatibility**（WebGL 2）可用；不要依赖仅 Forward Plus 的特性。2D 精灵与图标放 `assets/`；生成脚本会覆盖同名文件时，执行前核对范围并保留原资产。浏览器试玩见 [Documents/WEB_DEPLOY.md](Documents/WEB_DEPLOY.md)。
- 策划改单位数据优先用 `addons/unit_catalog_editor/`；改波次时间表用 `addons/wave_spawn_editor/`。改完实时主路径单位后同步 [Documents/Content/UNITS_ROSTER.md](Documents/Content/UNITS_ROSTER.md)。
- Python 工具沿用 stdlib 风格，路径相对脚本根目录。

## Cursor

- 项目规则以根目录 [AGENTS.md](AGENTS.md) 为准。`.cursor/rules/` 只做入口，不复制长表。
- 跨模块功能按 [Documents/DEVELOPMENT_WORKFLOW.md](Documents/DEVELOPMENT_WORKFLOW.md) 派发；小型串行修改由主代理完成。
- Customize 里看不见的角色文件不算已加载；手读 `.cursor/agents/<role>.md` 再传合同。
- 可重复步骤用 `.cursor/skills/`：`design-brainstorm`、`implement`、`vertical-slice`、`verify-godot`、`gui-acceptance`。
- 开需求先确认验收方式（轻量 / 完全），见 [Documents/DEVELOPMENT_WORKFLOW.md](Documents/DEVELOPMENT_WORKFLOW.md)。
- 不把 Plan 草稿、提案文档或未跑过的测试写成已完成。

## 完成条件

按合同中的**验收方式**：

- **轻量**：`bash tools/run_light_verify.sh` 通过（关键场景可加载、无 SCRIPT/Parse Error）；效果与画面由用户自验；交付注明未代验项。
- **完全**：验收可复现，受影响的 test runner 通过，无新增解析错误，UI/图标有 GUI 验收，文档符合实装，独立审查无未处理阻断问题。

数值修改说明金币、强度、商店节奏与站位压力的影响。
