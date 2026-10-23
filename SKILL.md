---
name: dz-ue-mcp
description: 通过 DSH 的 unreal MCP 驱动 UE 5.8 官方编辑器工具：自检连接、发现工具集、查询资产与场景、运行 PIE 验证、执行编辑器写操作。当需要"让 AI 操作虚幻编辑器""用 MCP 查引擎资产/AttributeSet""PIE 验证 GAS 改动"，或 unreal MCP 工具调用失败需要排查时使用。
tags:
  - unreal-engine
  - ue5
  - mcp
  - dzproject
---

# dz-ue-mcp — UE 官方编辑器 MCP 使用规范

适用：DZProject（UE 5.8）+ DSH `mcp-unreal`（Streamable HTTP，`http://127.0.0.1:8000/mcp`）。
UE 官方 MCP 是**实验性**功能：工具集与 API 可能随版本变化，结论以编辑器实际状态为准。

## 1. 前置自检（按顺序）

1. **工具存在性**：本会话应有 `mcp__unreal__list_toolsets` / `mcp__unreal__describe_toolset` / `mcp__unreal__call_tool`。没有 → `cordis.patch.yml` 的 `mcp-unreal` 条目缺失或未加载；提示用户新开会话或检查配置。
2. **调用失败先怀疑编辑器**：编辑器没开 / 服务器没启动是最常见原因。
   - 编辑器端：启用 **Unreal MCP** + **All Toolsets** 插件；Editor Preferences → Model Context Protocol → **Auto Start Server**（或控制台 `ModelContextProtocol.StartServer`）。
   - 默认端口 8000、路径 `/mcp`；绑定失败看输出日志中的 `LogModelContextProtocol`。
3. 没跑通 `list_toolsets` 之前，不要尝试任何具体工具调用。

## 2. 调用规范（工具搜索模式）

- 编辑器默认开启 Tool Search：只暴露三个元工具。**不要假设**存在 SceneTools 等具体工具的直接句柄。
- 标准流程：`list_toolsets`（有什么）→ `describe_toolset`（某工具集的参数 schema）→ `call_tool`（toolset + tool + args）。
- 工具调用在**游戏线程串行执行**：不要并发重叠调用；单次调用超时 60s，长操作（打开大地图、批量生成）拆步执行。
- 编辑器侧新增/修改工具集（Python toolset 或 C++ `UToolsetDefinition`）后：控制台 `ModelContextProtocol.RefreshTools`；新增 C++ `UFUNCTION` 需重启编辑器（Live Coding 不传播新声明）。

## 3. 安全边界（硬性）

- **Plan 批准前只读**：`/plan-gas` 或 plan mode 进行中，只允许查询/检查类调用（列资产、读属性、只读校验）；一切写操作（生成 Actor、创建/修改资产、改材质、改变场景状态）必须等 plan 被批准。
- 写操作执行前，向用户复述将调用的工具集、工具名与参数。
- UE MCP 无鉴权、仅回环：不得把 8000 端口暴露到局域网/公网。
- 写操作不替代版本控制：批量改动前确认项目已提交（Git / DSH undo 快照），保留可回退手段。
- PIE 运行中避免破坏性操作；不确定工具副作用时先 `describe_toolset` 读文档。

## 4. DZProject 工作流配方

- **GAS 资产核查**：plan 批准后，用工具集查询 GA_/GE_/GC_ 资产、Blueprint 类默认值与 Tag 配置，与 `dz-gas-split` 产出的 Master Plan 比对（GA/GE/GC 数量与职责、`Item.<8位ID>` Tag、Asset Tags 与 Granted Tags 区分）。
- **验证纪律**：涉及 GA/GE/网络同步的改动，验证必须覆盖单机 PIE + 双端 PIE（或 DebugNetwork）；DZ 行为类 PIE 一律开在 `/Game/SandBox/Demo_Maps/Lv_Test_AI`（gymlevel 全木桩、无 AI 行为，不可用于测试，2026-10-22 用户拍板）；跑 PIE/自动化测试前先保存当前关卡。
- **C++ 改动流程**：DSH 侧改代码 → 编译 → Live Coding/重启 → MCP 验证；不要期望 MCP 能触发 UBT 编译，除非工具集明确提供该工具。
- **编辑器未开时的降级**：改用文件级检查（`Source/`、`Config/`、`*.uproject`），把"需要编辑器验证"列入待办；不要硬凑结论。

## 5. 故障排查

- 工具列出但调用失败：编辑器是否在跑？8000 端口是否监听？控制台 `LogModelContextProtocol Verbose` 看详情。
- 反复失败：DSH 侧重载配置或重启 harness（dsh-mcp-client 连续失败 10 次会停止重连）。
- 协议级怀疑：`npx @modelcontextprotocol/inspector`，Streamable HTTP 指向 `http://127.0.0.1:8000/mcp`。
- DSH 侧配置：`<dsh-home>/profiles/web/cordis.patch.yml` 的 `- id: mcp-unreal` 条目；改动前已有 undo 快照可回退。

## 6. 已验证记录（2026-10-07）

端到端验证通过（编辑器 UE 5.8，`http://127.0.0.1:8000/mcp`）：

- `initialize` HTTP 200，协议版本 `2025-11-25`，会话头 `mcp-session-id` 正常。
- `tools/list` 只返回 3 个元工具（Tool Search 模式确认）：`list_toolsets` / `describe_toolset` / `call_tool`。
- `list_toolsets` 调用成功，本机当前可用工具集：

| 工具集 | DZProject 用途 |
|---|---|
| `EditorToolset.EditorAppToolset` | 控制台变量、选择、视口相机、Content Browser、**PIE 会话控制** |
| `EditorToolset.LogsToolset` | 读输出日志、调日志级别（排查 PIE 报错首选） |
| `GASToolsets.AttributeSetToolset` | 发现 AttributeSet 类与属性（GAS 资产核查） |
| `GASToolsets.AbilitySystemInspectorToolset` | 运行时 ASC 状态检查（双端验证时用） |
| `GASToolsets.GameplayCueToolset` | GC 及其 notify 资产的检查与执行 |
| `GameplayTagsToolset.GameplayTagsToolset` | 读取/管理项目 GameplayTag（对照 Master Plan 的 Tag 计划） |
| `AutomationTestToolset.AutomationTestToolset` | 自动化测试：Discover → List → Run → GetResults |
| `ConfigSettingsToolset.ConfigSettingsToolset` | 检查/编辑 Config 节（网络配置核查用） |
| `GameFeaturesToolset.GameFeaturesToolset` | Game Feature 插件列表与启用 |
| `ToolsetRegistry.AgentSkillToolset` | 编辑器内技能管理 |
| `DataRegistryToolset` / `DataflowAgentToolset` / `PCGToolset` | 按需（数据表、Dataflow、PCG 图） |
| `DZStateTreeToolset.DZStateTreeEditTools` | **DZ 自研 ST 编辑工具集（2026-10-22 装验）**：ST 资产读+写+编译+属性绑定，dz-statetree §2.1 首选通道 |

常用配方映射：PIE 验证 = `EditorAppToolset`（启动/停止 PIE）+ `LogsToolset`（读报错）；GAS 运行时验证 = `AbilitySystemInspectorToolset`；Tag 核查 = `GameplayTagsToolset`；回归 = `AutomationTestToolset`；ST 编辑 = `DZStateTreeToolset.DZStateTreeEditTools`（配 `editor_toolset...asset.AssetTools.save_assets` 落盘）。

- 2026-10-22 增补（A 机复查 `list_toolsets`）：工具集已大幅扩容——DZ 自研 `DZStateTreeToolset.DZStateTreeEditTools`（ST 编辑，见 dz-statetree §2.1）与 `editor_toolset.*` 家族（`AssetTools` 含 save_assets/is_dirty/get_referencers/find_assets/delete、`ObjectTools` 通用属性读写、`ProgrammaticToolset` 工具编排、Scene/Blueprint/DataTable 等）、引擎 `state_tree_toolset`（ST 只读）、Niagara/PCG/Sequencer/SlateInspector 等均已注册。上表只列 DZ 常用项，完整清单以 `list_toolsets` 实时输出为准。
