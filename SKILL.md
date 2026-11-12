---
name: dz-ue-tools
description: DZProject UE 5.8 AI 工具统一入口：MCP 连接与编辑器操作、GAS/蓝图通用工具、StateTree 资产迁移/参数/绑定/审计工具。当需要"让 AI 操作虚幻编辑器""MCP 查引擎资产/AttributeSet""PIE 验证 GAS/StateTree 改动""批量改 StateTree 蓝图资产"，或 unreal MCP 工具调用失败需要排查时使用。
tags:
  - unreal-engine
  - ue5
  - mcp
  - dzproject
  - gas
  - statetree
  - tools
---

# dz-ue-tools — UE AI 工具统一入口

适用：DZProject（UE 5.8）+ DSH `mcp-unreal`（Streamable HTTP，`http://127.0.0.1:8000/mcp`）。
UE 官方 MCP 是**实验性**功能：工具集与 API 可能随版本变化，结论以编辑器实际状态为准。

本技能由原 `dz-ue-mcp`（MCP 传输与编辑器操作）和 `dz-ue-statetree-tools`（StateTree 领域工具）合并而来。
StateTree 的完整工具目录、执行配方与领域坑清单在 [`Tools/StateTree/README.md`](Tools/StateTree/README.md)。

## 统一路由

| 需求 | 入口 |
|---|---|
| MCP 连接、元工具调用、PIE、日志、通用资产保存 | 本文件 §1-§5 |
| 非 StateTree 的通用脚本 | `Tools/MCP/`、`Tools/GAS/` |
| StateTree 资产批量读写、参数、绑定、迁移、编译、审计 | [`Tools/StateTree/README.md`](Tools/StateTree/README.md) |
| StateTree 设计拆分、执行纪律、L1-L4 测试 | `dz-st-split` |
| 新增 C++ MCP toolset | `create-toolset` |

## 人机分工优先于工具配方

先读取 `E:/AIWorkSpace/docs/AI_UE_分工指南.md`。用户操作资产/属性面板、启动 PIE 与双端测试、执行 SVN；Agent 负责代码和日志验证。下文的 PIE 配方仅用于制定用户步骤与解释工具能力，不授权 Agent 代为启动。预计 ≥3 次 MCP 往返或约 5KB 读回而用户一分钟内可完成的操作交用户，不连环试错。涉及 Lua 结构体/Tag 容器修改时先读 [UnLua 容器安全](../知识库/references/10-unlua-struct-inout.md)。

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

- **🔴 严禁用 duplicate 复制已在生效/已被引用的蓝图资产（GA/GE/DA 等）**：复制会把源资产的全部 Tag 容器、触发器、能力阻拦/取消配置传染过来，漏清理任何一项就是线上事故（DZ 04011023 事故实证：GrantTag 残留、GA 误阻拦、AssetTag 错乱、Tag 缺功能层）。**必须用 `BlueprintTools.create` 全新创建**；若 create 受限（实测会弹父类选择对话框并卡死编辑器主线程——日志特征：`Dispatching toolset tool: '...BlueprintTools.create'` 后帧号停走），**停下报告用户手动创建模板，不得改走 duplicate 绕路**。创建后仅配身份 Tag：GE=`inheritableGameplayEffectTags.added`，GA=`abilityTags`；其余 Tag 容器默认全空。
- **创建 GE/GA 后必须配置进对应 `DA_<8位ID>_*` 的引用字段（orinAbilityArray/triggerEffectData）并保存 DA**——授予链经 DA 解析资产，漏配=道具静默不生效。这是交付闭环，不是可选项。（2026-10-23 策划会签）
- **Plan 批准前只读**：`/plan-gas` 或 plan mode 进行中，只允许查询/检查类调用（列资产、读属性、只读校验）；一切写操作（生成 Actor、创建/修改资产、改材质、改变场景状态）必须等 plan 被批准。
- 写操作执行前，向用户复述将调用的工具集、工具名与参数。
- UE MCP 无鉴权、仅回环：不得把 8000 端口暴露到局域网/公网。
- 写操作不替代版本控制：批量改动前确认项目已提交（Git / DSH undo 快照），保留可回退手段。
- PIE 运行中避免破坏性操作；不确定工具副作用时先 `describe_toolset` 读文档。

## 4. DZProject 工作流配方

- **GAS 资产核查**：plan 批准后，用工具集查询 GA_/GE_/GC_ 资产、Blueprint 类默认值与 Tag 配置，与 `dz-gas-split` 产出的 Master Plan 比对（GA/GE/GC 数量与职责、`Item.<8位ID>` Tag、Asset Tags 与 Granted Tags 区分）。
- **验证纪律**：涉及 GA/GE/网络同步的改动，验证必须覆盖单机 PIE + 双端 PIE（或 DebugNetwork）；DZ 行为类 PIE 一律开在 `/Game/Maps/Test_Level/Lv_Test_AI`（**真实路径，2026-11-05 实证**；旧文档口径 `/Game/SandBox/Demo_Maps/Lv_Test_AI` 不存在；gymlevel 全木桩、无 AI 行为，不可用于测试，2026-10-22 用户拍板）；跑 PIE/自动化测试前先保存当前关卡与 dirty 资产（`AssetTools.save_assets`）。
- **PIE 行为验证配方（2026-11-05 实战定型）**：① `SceneTools.load_level(level_path)`（加载时关卡蓝图可能报 Accessed None 运行时警告，不影响）；② `LogsToolset.SetVerbosity` 预热——`category` 参数是**日志分类名**（LogDZAI/LogStateTree/LogDZAbilitySystem），`GetLogEntries` 的 `pattern` 才是正则过滤；**LogDZAI/LogDZAbilitySystem 默认 Display 级吞 Log 级行为日志**，须开 Verbose；③ `EditorAppToolset.StartPIE(options={bSimulate:false, playMode:"PlayMode_InViewPort"})`（返回 null=成功；编辑器重启后 verbosity 重置需重开）；④ **行为分析首选日志文件直读**（`DZ_Content/Saved/Logs/DZProject.log`，文件内时间戳为 UTC）——比 GetLogEntries 可靠（PIE 期间引擎日志线程可能滞后、Verbose 洪流下 MCP 分页难截全）；⑤ `StopPIE` 收尾。**关闭编辑器前必须 save_assets**（否则下次启动卡崩溃还原界面，用户拍板）；当前 EditorAppToolset 不暴露 `CloseMainWindow`，可用 `st_parallel_event_remote.py quit`（内部 `QUIT_EDITOR`）优雅退出，15s 后仍活再处理。
- **Simulate / Play 验证域分流（2026-11-09）**：`bSimulate=true` 只跑当前关卡模拟与测试 runner，不完整创建玩家；涉及玩家 `BeginPlay`、GAS 授技、UI 初始化时必须跑非 Simulate Play。若 Play 崩溃而 Simulate 通过，不要把崩溃强行归到同帧的 StateTree/测试 runner，先读崩溃栈。
- **蓝图手术配方（2026-11-05 GA 改造实战）**：`BlueprintTools.set_parent(blueprint, parent_class)` 换父类（空蓝图风险低）；`get_default_object(blueprint)` 拿 CDO → `ObjectTools.set_properties(instance=CDO, values=<JSON字符串>)` 配 Class Defaults（AbilityTriggers/数组清空等——values 是 JSON 字符串而非对象）；`read_graph_dsl(graph={refPath:"...:EventGraph"})` 读图 DSL；`connect_pins(output_pin/input_pin={direction:"EGPD_Output/EGPD_Input", index_id, node})` 连线（PinID 结构，非 pin_name）；`delete_node`/`compile_blueprint`/`save_assets` 收尾。**ObjectTools.get/set_properties 的对象参数名是 `instance`**；每工具首调偶发空响应（重试 3 次）；PS 函数参数名禁 `$args`（自动变量吞参）。
- **C++ 改动流程**：DSH 侧改代码 → 编译 → Live Coding/重启 → MCP 验证；不要期望 MCP 能触发 UBT 编译，除非工具集明确提供该工具。**新增 UFUNCTION 必须关编辑器全编**（Live Coding 不传播新声明，Ctrl+Alt+F11 对新 UFUNCTION 报错）；编译循环配方见 `dz-ue-tools/Tools/StateTree/st_ref_build_dzproject.cmd`。
- **编辑器未开时的降级**：改用文件级检查（`Source/`、`Config/`、`*.uproject`），把"需要编辑器验证"列入待办；不要硬凑结论。

## 5. 故障排查

- 工具列出但调用失败：编辑器是否在跑？8000 端口是否监听？控制台 `LogModelContextProtocol Verbose` 看详情。
- **PIE crash 首选证据**：读最新 `DZ_Content/Saved/Crashes/<GUID>/CrashContext.runtime-xml` 的 `ErrorMessage`/`CallStack`，再看同目录 `DZProject.log` 尾部。`Test-NetConnection` 显示端口可连不等于 MCP 路由可用，仍需 `initialize` 200 才算恢复。
- 反复失败：DSH 侧重载配置或重启 harness（dsh-mcp-client 连续失败 10 次会停止重连）。
- 协议级怀疑：`npx @modelcontextprotocol/inspector`，Streamable HTTP 指向 `http://127.0.0.1:8000/mcp`。
- DSH 侧配置：`<dsh-home>/profiles/web/cordis.patch.yml` 的 `- id: mcp-unreal` 条目；改动前已有 undo 快照可回退。

## 6. Tools 目录（2026-11-11 统一）

可复用脚本放在本技能 `Tools/<模块>/`，并登记对应 README；不要散落在仓库根或 `.dsh/st_work`：

- `Tools/MCP/mcp_direct.py`：会话内没有 unreal MCP 元工具时的 HTTP 直连兜底，支持 `init/call/list/describe`，自动解码 JSON/SSE 并把工具错误转为非零退出。
- `Tools/GAS/ga_blueprint_parent_tool.py`：GA 蓝图父类无头审计/修复。默认 `audit`；只有显式 `-GasMode=fix` 才写入，单资产用 `-Asset` + `-Parent` 覆盖。
- `Tools/StateTree/`：原 `dz-ue-tools/Tools/StateTree/` 全量并入。StateTree 深度资产操作先读 [`Tools/StateTree/README.md`](Tools/StateTree/README.md)；批量/无头优先复用已有脚本，不要复制临时脚本。

## 7. 已验证记录（2026-10-07）

### 端到端验证

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
| `DZStateTreeToolset.DZStateTreeEditTools` | **DZ 自研 ST 编辑工具集（2026-10-22 装验）**：ST 资产读+写+编译+属性绑定，dz-st-split（`references/execution-and-discipline.md` §2.1）首选通道 |

常用配方映射：PIE 验证 = `EditorAppToolset`（启动/停止 PIE）+ `LogsToolset`（读报错）；GAS 运行时验证 = `AbilitySystemInspectorToolset`；Tag 核查 = `GameplayTagsToolset`；回归 = `AutomationTestToolset`；ST 编辑 = `DZStateTreeToolset.DZStateTreeEditTools`（配 `editor_toolset...asset.AssetTools.save_assets` 落盘）。

- 2026-10-26 增补（**MCP 客户端工具未挂载时的直调兜底** + PIE 网络验证突破）：本会话工具表里没有 `mcp__unreal__*`，但编辑器 MCP 服务正常 → 直接打 Streamable HTTP 端点 `http://127.0.0.1:8000/mcp` 即可：① `initialize`（`{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{…}}`）拿响应头 `mcp-session-id`；② 发 `notifications/initialized`；③ 后续每次 POST 都带 `mcp-session-id` 头 + `Accept: application/json, text/event-stream`；④ 调用固定形态 `{"jsonrpc":"2.0","id":N,"method":"tools/call","params":{"name":"call_tool","arguments":{"toolset_name":…,"tool_name":…,"arguments":{…}}}}`（`list_toolsets`/`describe_toolset` 同理走 `tools/call`）。返回体可能是 SSE，取 `data:` 行拼接后再解析；PowerShell 里 `Invoke-WebRequest -Body([byte[]])` 会因数组展开丢内容，用 `[System.Net.HttpWebRequest]` 手写 POST 最稳。**PIE 网络验证结论更新**：`StartPIE` 起的 listen server（`serverPort=17777`）是**真 socket**，外部 `-game` 进程可连入——客户端需 `-NetDriverOverrides=/Script/OnlineSubsystemUtils.IpNetDriver` + `bUseSteamNetworking=false`（否则 SteamSockets 传输层对不上，表象恰是"PIE 不回包"），且必须换成与主机互异的稳定身份（NULL OSS + `-StableNullID`），否则被 `incompatible_unique_net_id` 拒绝。掉线/重连全链路（硬杀客户端 → `LogsToolset.GetLogEntries` 读登记 → 重启客户端 → 读重连接管）已按此跑通，详见 `Document/网络系统/断线重连系统设计.md` §13.6。

- 2026-11-06 增补：DataTable 读写形状不对称、`add_rows` 清表、`set_properties` 的 JSON 字符串、CDO 与配置文件双写等通用写入坑，见 `references/dt-object-write-pitfalls.md`。
