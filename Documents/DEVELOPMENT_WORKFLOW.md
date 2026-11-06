# 游戏开发与 Sub-agent 工作流

> **权威源在 Notion。** 完整流程正文见 Notion Doc ID `process-dev-workflow`；**请勿**在本地修改规格正文。

| 字段 | 值 |
|------|-----|
| Doc ID | `process-dev-workflow` |
| Notion | https://app.notion.com/40ff89936db6814a87cdccecdf1d2c19 |
| Kind | `Process` |

Hub：https://app.notion.com/p/40ff89936db681b5880cec3af0087789  
设计文档库：https://app.notion.com/p/9293e582b53d437dbe88b28d21251a5f

本地 `Documents/` 仅为指针；Sub-agent 角色表、验收方式与 L0–L5 等**规格正文**请在 Notion 对应页编辑。下文 **养成规范** 为 harness 保留摘要（写入目标 = Notion 页）。

## 设计文档与 Sub-agent 养成规范

子代理与主代理写设计规格时遵守（正文写入 Notion「Autochess — 设计文档」库对应行，**勿**在本地指针 `.md` 改正文）：

1. **只写当前要做的事**：当前版本不做的玩法、已否决方案、纯远期脑暴，**默认不写进** Notion 规格页（如 Doc ID `game-vision`、`feature-*`、`content-*`）。
2. **例外**：用户明确要求保留；或实现上必须防回归（例如「主题团队层必须走统一效果管线」一句边界）。此时用**一句**说清，不展开候选对比、不堆「非目标清单」。
3. **提案归提案**：未立项内容留在对话里，或写入 Content 技能库草案并标明未实装；**不要**为了「以后可能做」在愿景里占整节。
4. **未决列表要短**：只保留实现前必须拍板、且与当前循环直接相关的项。数值可后定的参数用「可配置 / 默认值」写在规则旁，不必单开未决条目。
5. **As-Is / To-Be**：规格定稿 ≠ 代码已对齐；新循环写 To-Be 时标明，勿把旧「仅 PREPARE 布阵」说成仍是目标。
6. **角色短合同**：`.cursor/agents/*.md` 只写本职边界与当前玩法约束，不复制本表长文；玩法表述与 Notion Doc ID `game-vision` 冲突时以愿景为准并回写角色文件。
