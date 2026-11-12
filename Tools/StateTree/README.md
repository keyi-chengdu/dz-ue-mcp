# StateTree 工具目录（dz-ue-tools）

> 定位：`dz-ue-tools` 内的 StateTree 领域工具包。原 `dz-ue-statetree-tools` 已于 2026-11-11 合并到这里。
> 分工勿混：**dz-st-split** = 规划知识与拆分（执行纪律在其 `references/execution-and-discipline.md`——原 DZStateTree_SkillBase 活文档，2026-10-28 整文迁入）；**本库** = 可执行工具本体。

## 工具清单

### 1. `Tools/StateTree/st_add_global_params.py` — 批量根参数注入（2026-10-28 首役：Parameters 数据面 8 主树 × 6 字段）

- **用途**：无头批量给 StateTree 主树**根参数包**（`RootParameterPropertyBag`）添加字段；参数面激活的资产侧配套。
- **依赖**：`UDZAISystemUtil::AddStateTreeGlobalParameter`（DZProject 模块，WITH_EDITOR；反射绕 `EditorData` protected / `RootParameterPropertyBag` private）——需先编译含该函数的 DZProjectEditor。
- **用法**（编辑器须关闭）：

```
:: DRY（只跑不存）
UnrealEditor-Cmd.exe DZProject.uproject -run=pythonscript -script="<本技能目录>/Tools/StateTree/st_add_global_params.py" -unattended -nopause -nosplash -NullRHI
:: Execute（强制落盘）
... -script=".../st_add_global_params.py" -Execute ...
```

- **定制**：脚本顶部 `PARAM_FIELDS`（字段名/类型/Object-Struct 路径）与 `MAIN_TREES`（树清单）两个常量按任务改。
- **类型支持**：`Bool` / `Object`（如 `/Script/Engine.Actor`）/ `Struct`（如 `/Script/CoreUObject.Vector`、`/Script/DZProject.AttackTaskData`、`/Script/GameplayTags.GameplayTag`）。
- **坑（2026-10-28 实录）**：
  1. 保存必须 `only_if_is_dirty=False`——C++ 侧未调 `Modify()` 打 dirty 标记，默认 True 会**静默跳过保存**（症状：svn 无 M、文件时间戳不变）；
  2. 无头命令行日志**中文行会被编码吞**，脚本输出一律纯 ASCII；
  3. UE svn 集成会自动 add 新资产并加 K 锁，反悔须 delete+revert 清理；
  4. 注入触发资产重编译——既有编译失败树（缺绑定等）会在日志刷 Error，**先核对是否新增**再处理。

### 2. `Tools/StateTree/st_probe_bagapi.py` — StateTree Python API 探测器

- **用途**：验证编辑器反射属性/PropertyBag API 的可达性（教训实录：`UStateTree.editor_data` 是 **protected**，Python `get_editor_property` 直接读会失败——必须走 C++ 反射工具函数）。
- **用法**：同上无头命令行；改脚本内资产路径与探测属性。

### 3. `Tools/StateTree/st_dump_bindings.py` — 资产绑定现状 dump（2026-10-28 首役：Task 绑定改接 Parameters 前核对）

- **用途**：调 `UDZAISystemUtil::DumpStateTreeBindings`，输出每棵树全部编辑器属性绑定 `<TARGET 路径 [节点]> <= <SOURCE 路径 [节点]>`（含来源类别 Context/Evaluator/StateParameter/Task/Parameter，`<out>` 标记输出绑定）。
- **关键事实（首役结论）**：资产里**没有黑板绑定**——绑定来源只有 Context / 求值器 / State 参数 / Task 输出；"黑板"从来不是 StateTree 绑定来源。
- **用法**：`... -script=".../st_dump_bindings.py"`（只读，不落盘）。

### 4. `Tools/StateTree/st_dump_states.py` — 状态与任务节点清单 dump

- **用途**：调 `UDZAISystemUtil::DumpStateTreeStates`，输出 `STATE <路径> | tasks=N | <任务名>[<类型>]...`，用于定位哪些 State 内联了需要转 out 的 Task（链接子树的 State tasks=0，实际任务在子树资产里）。
- **用法**：同上（只读）。

### 5. `Tools/StateTree/st_install_param_nodes.py` — 批量安装参数输出节点（2026-10-28 首役：33 节点 / 8 树）

- **用途**：调 `UDZAISystemUtil::InstallParamOutNodes`，对含目标 Task 的 State 追加 `STT_SetTreeParam` 节点，并把 Task 的 out 属性绑定到该节点输入（写穿 Parameters + 黑板镜像）。
- **幂等**：State 内已有写同参数的节点则跳过（重跑 `added=0`）。
- **规则表**：C++ 内 `FParamOutRule Rules[]`（Task 类型名 → out 属性 → 参数名/值类型/目标字段）；**Task 类型名不带 F 前缀**（UHT 生成的 UScriptStruct 名是 `STT_AskForBattleTarget`，不是 `FSTT_AskForBattleTarget`——首跑 `added=0` 的坑）。**仅收录瞬时任务**（EnterState 内完成并赋值 out）；Running 多帧任务（FindTarget/Attack）禁止入表，见坑 6。
- **用法**：`... -script=".../st_install_param_nodes.py" -Execute`（编辑器须关闭）。

### 6. `Tools/StateTree/st_remove_param_nodes.py` — 按来源任务类型摘除参数输出节点（2026-10-28 首役：47 节点 / 21 树）

- **用途**：调 `UDZAISystemUtil::RemoveSetTreeParamNodesBySource`，摘除"绑定来源为指定 Task 类型"的 `STT_SetTreeParam` 节点及其绑定——用于 Running 多帧任务的回退（out 到完成帧才有值，节点首帧会写空）。
- **用法**：`... -script=".../st_remove_param_nodes.py" -Execute`（编辑器须关闭）；`SOURCE_TASKS` 常量指定来源任务名。
- **幂等**：摘除后重跑 `total=0`。

### 6b. `Tools/StateTree/st_fix_05002102_parallel_actor_ref.py` — 05002102 并行树目标 Ref 化修复（2026-11-09）

- **用途**：把 `ST_Sub_05002102_ParallelAttack` 的 `ACTOR_TARGET` 从普通 `Object /Script/Engine.Actor` 修复为 `Struct /Script/StateTreeModule.StateTreeBlueprintPropertyRef` 接线柱，保存后重载 Battle 并给 RunParallel 的 `StateTree.Parameters.Value.ACTOR_TARGET` 建指定绑定。无 `-Execute` 为 DRY。
- **用法**：`... -script=".../st_fix_05002102_parallel_actor_ref.py" [-Execute] -unattended -nopause -nosplash -NullRHI -noscc`（编辑器须关闭）。
- **关键顺序**：先改/编译/保存 Parallel，再卸载 Parallel、新载 Battle，最后绑 RunParallel；顺序颠倒会用旧内嵌参数包做出错误判定。
- **坑**：下游绑定回读路径可能是显示名，重建前必须映射为真实 FName（当前 `In Target Actor -> RefTargetActor`）；RayCheck 旧节点删除要按实例视图 ID（`Node.ID`），工具集节点查找已兼容 `GetNodeID()` 与 `Node.ID`；私有 slot 枚举不暴露 Python，任务节点用 `AddStateTaskNode`；Ref 默认值用 `SetTreeParameterRefDefault`；保存用 `only_if_is_dirty=False` 并核对 mtime/size。

### 7. `Tools/StateTree/st_doc_push_feishu.ps1` — 规范文档推送飞书（lark-cli 封装，2026-10-28 首役：StateTree 规范文档 8 节）

> StateTree 规范文档的本地源与 Token/覆盖命令已按项目惯例登记在 `DZ_Content/Document/StateTree/飞书同步.md`（本地源 `StateTree系统规范.md`，单文档直连模式）。

- **用途**：把本地 Markdown 推送到飞书 wiki/docx 文档（append 或 overwrite），写后自动回读目录验证。
- **依赖**：项目内 `DZ_Content\.lark-cli\lark-cli.exe`（user 身份须已授权）。
- **用法**（本机执行策略禁未签名脚本，须带 Bypass）：
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\tools\st_doc_push_feishu.ps1 -DocUrl "https://pcnnehcdhvg9.feishu.cn/wiki/<token>" -ContentFile "doc.md"
  ```
- **命令链参考**（脚本内部即此序列，手动操作时用）：
  1. `wiki +node-get --node-token <URL>` → 解析 obj_token/obj_type（wiki 链接必须先转 docx token）
  2. `docs +fetch --doc <URL> --scope outline` → 读现状（判断文档为空/已有结构，决定 append 还是分节改）
  3. `docs +update --as user --command append --doc-format markdown --content @file` → 写入（**多行内容必须 @file**，命令行内联会转义失败）
- **坑（2026-10-28 实录）**：
  1. **DSH 沙箱内 `auth login` 必败**——授权能确认但保存 token 报 `failed to acquire token storage lock`（跨进程锁用 Windows 命名互斥量，被沙箱命名管道限制掐死）。**解法：请用户在自己的终端跑一次 `lark-cli auth login --domain docs,wiki`**（授权长期有效）；普通 API 调用（读写文档）在沙箱内正常。
  2. **token 过期后沙箱内所有 API 调用同样碰锁（2026-10-29 实录）**——`--as user` 的 access token 隔夜过期后，任何调用都先走 refresh，refresh 同样要拿命名互斥量锁 → 沙箱内必败（删残留锁文件无效）。**解法：请用户在自己终端跑一次任意 lark-cli 命令（fetch/update 均可，不必重新 auth login）完成 refresh；token 新鲜期（约 2 小时）内沙箱调用恢复**。
  2. bot 身份通常无 wiki 文档编辑权（缺 `wiki:wiki` 等 scope 且无协作者授权）——一律用 `--as user`。
  3. 残留锁文件在 `C:\Users\02\.lark-cli\locks\*.lock`（真实原因是沙箱互斥量，删锁治标）。
  4. **含中文的 .ps1 必须存为 UTF-8 with BOM**——无 BOM 时 PowerShell 5.1 按 ANSI 解析中文变乱码，here-string 直接语法崩（本脚本已带 BOM；用编辑器/工具重写时注意）。
  5. **捕获 lark-cli 输出勿走 PowerShell 管道**（2026-10-29 实录）——PS 5.1 管道把 UTF-8 stdout 按 GBK 误解码，中文损坏、JSON 可能解析失败；应使用 `cmd /c "<cli> ... > file 2>&1"` 原始字节重定向，再按 UTF-8 读文件。

### 8. `Tools/StateTree/st_parallel_event_remote.py` — ST_Test 并行事件测试台远程脚本

- **用途**：通过 UE Python Remote Execution 检查 `/Game/Blueprint/StateTree/Temp/ST_Test` / `ST_ParTest` 状态与节点参数，把 `Lv_Test_AI` 内 `StateTreeComponent` 绑定到 Temp 备份主树，并确保编辑器 MCP 回到默认端口 8000。
- **用法**：编辑器运行时执行 `python st_parallel_event_remote.py inspect|actors|bind|setup|ensure|probe|simulate|stop|quit`；`bind` 绑定现有组件；`setup`/`ensure` 在无 runner 时从 `ASceneSTRunner` 生成一个带 `StateTreeComponent` 的测试 Actor（5.8 Python 不支持对裸 `Actor` 新建组件并 `register_component`）；`simulate` 先加载 `Lv_Test_AI` 再开 Simulate PIE；`stop` 结束 PIE。
- **验证**：Simulate PIE 后看日志三元组：`STT_TestADD` 并行值、`[ParallelEvent] Sent ... with 1 bag values`、主树 `STT_Test1` 同值；2026-11-09 当前工作副本 9/9 轮 1→9 对齐，早前 23/23 轮 1→23 对齐。2026-11-10 根目录 StateTree 已回退 SVN，测试链仅保留在 `StateTree/Temp`，不要再用 `/Game/ST_Test`。
- **合并期类型后缀**：本地 C++ 节点含 `_New` 时，资产节点必须引用 `STT_SendParallelEvent_New` / `STT_ApplyParallelEvent_New` / `ParallelEventPayload_New`；旧 USTRUCT 名加载会变成空 `FInstancedStruct`，日志见 `Unable to find serialized UScriptStruct -> ... StateTreeEditorNode:Node/Instance`，不能只靠 C++ 编译通过判断资产可用。

#### 8.1 通用 Bag 任务测试配方（2026-11-09，推荐）

测试台当前链路已不再依赖蓝图任务手拼 `FStateTreeEvent`：

| 节点 | 作用 | 关键配置 |
|---|---|---|
| `STT_TestADD` | 并行树累加测试值 | `InInt` 为 `FStateTreePropertyRef`，绑并行树 `Out_INt` |
| `STT_SendParallelEvent` | 把树参数写入事件 Bag | `EventTag=StateTree.ParTest.Done`；`ParameterBindings=(EventName=ParallelTestInt, ParameterName=Out_INt, bUseTreeParameter=True)` |
| `STT_ApplyParallelEvent` | 从 Enter Event 解包写回主树 | `InEvent ← Enter Event`；`InPayload=(EventName=ParallelTestInt, ParameterName=ParalleTestInt, bUseTreeParameter=True)` |

接收状态必须配置 `bHasRequiredEventToEnter=true` 且 `RequiredEventToEnter.PayloadStruct=/Script/DZProject.ParallelEventPayload`。日志验收：

1. `[ParallelEvent] Sent StateTree.ParTest.Done with 1 bag values`
2. `[ParallelEvent] Applied 'ParallelTestInt' (IntProperty)`
3. `[ParallelEvent] Apply complete: 1 values`
4. 主树 `STT_Test1` 打印值 == 并行树 `STT_TestADD` 当前值

**红线**：发送/接收 Bag 必须走 `FInstancedPropertyBag::SetValue/GetValue`；不要 `Detach()` 后 `InitializeFromBagStruct()`，会出现“字段存在但值恒 0”的假成功。

### 9. 全量 `_New` 复刻迁移（2026-11-11）

| 脚本 | 用途 |
|---|---|
| `Tools/StateTree/st_inventory_trees.py` | 只读递归 dump 根/状态参数、LinkedAsset、节点实例、转移、绑定到 `.dsh/st_work/st_inventory_trees.json` |
| `Tools/StateTree/st_migrate_state_trees_to_new.py` | 从零在 `/Game/Blueprint/StateTree/Temp/<原目录>/<资产>_New` 重建 24 张生产/测试树；升级 DZ Task/EC 到 `_New`、重挂 LinkedAsset/RunParallel、重建 Ref feed，并支持 `ListOnly/Execute/Verify-New/Upgrade` |

用法（编辑器关闭）：

```
UnrealEditor-Cmd.exe DZProject.uproject -run=pythonscript -script="<本技能目录>/Tools/StateTree/st_migrate_state_trees_to_new.py" [-Execute|-Verify-New|-Upgrade] ...
```

关键事实与坑：
1. `CloneEditorDataFromTree` 用引擎 `DuplicateObject` 重映射 IDs/绑定，不要手工恢复旧 ID；否则转移和绑定错位。
2. 子树必须先于消费方建树；`ST_Sub_Turn` 要放最前。同进程引用未保存目标时用内存对象表，不要依赖 Asset Registry。
3. LinkedAsset 指向的子树换 schema 后，链接态的 Ref 柱字段必须 `Override + BindLinkedStateParametersFromTree`；不只是主树。
4. 新建资产从零 `CreateStateTree`，禁止整树 duplicate。失败目标不要在同进程删除重建；先修复或下轮直接 repair。
5. `STT_PlayMontage_New.RefMontageTag` 是 Output PropertyRef，UE 不允许普通绑定；现改 `WriteAIParam("EnemyPlayMontageTag")`，Ref 字段预计删除。
6. `STT_RandomAndSetVal_New` 已补齐；`-Upgrade` 可对已生成 `_New` 树原地替换残留映射任务。
7. RunParallel 必须在 `FStateTreeRunParallelStateTreeTaskInstanceData.StateTree` 内直接指定目标对象路径；`ParallelAttackBehavior` 这类根参数 `StateTreeReference` 变量形态退役。先移除旧变量/绑定，再 `SetStateTree` 同步出嵌套 `Parameters`，最后把主树/子树参数绑到 `StateTree.Parameters.Value.<Field>`。编辑器回读可能显示 `State Tree.Parameters.Value.*` 和嵌套参数包 GUID，不是绑定丢失。

## MCP 工具集：参数面 CRUD（`DZStateTreeToolset.DZStateTreeEditTools`，2026-11-03）

编辑器内 MCP 工具

- **用途**：按规则表把任务/条件 InstanceData 的显式 `InXxx` 输入绑定到匹配的树级根参数，替代运行时 `GetTreeParam` 回退。
- **依赖**：`UDZStateTreeEditTools::BindTaskInputsFromTreeParameters`（DZToolsets 插件）。
- **用法**：编辑器须关闭；无 `-Execute` 为 DRY，加 `-Execute` 才保存：
  ```
  UnrealEditor-Cmd.exe DZProject.uproject -run=pythonscript -script=".../st_bind_task_inputs.py" -unattended -nopause -nosplash -NullRHI -Execute
  ```
- **规则表**：脚本内 `RULES`（节点 UHT 类型 → 输入属性 → 根参数名）；动态 Key 节点不处理，须先拆显式输入；蓝图任务按需加蓝图类路径。
- **坑**：节点类型不带 F 前缀；C++ 未标 dirty 时仍须 `only_if_is_dirty=False` 保存；写后按执行纪律回读、编译并跑 L0/L1/L2。

## MCP 工具集：参数面 CRUD（`DZStateTreeToolset.DZStateTreeEditTools`，2026-11-03）

编辑器内 MCP 工具（`call_tool`，toolset_name=`DZStateTreeToolset.DZStateTreeEditTools`）；与无头 py 脚本互补：交互/单点改动用 MCP，批量/无头用本库脚本。

| 工具 | 说明 |
|---|---|
| `GetTreeParameters(StateTree)` | 返回根参数包全部字段（Name / ValueType / TypeObjectPath / ContainerType）。诊断"某参数到底配没配"的第一入口 |
| `GetStateParameters(State)` | 返回状态 State Parameters（链接态为链接资产根参数的镜像字段） |
| `AddTreeParameter(StateTree, ParamName, ValueType, ValueTypeObjectPath)` | 幂等加根参数字段；ValueType 扩到 Bool/Byte/Int32/Int64/Float/Double/Name/String/Text/Object/Struct/Enum/Class/SoftObject/SoftClass（后 7 类必须给类型路径，标量传 None） |
| `AddStateParameter(State, ...)` | 幂等加状态参数字段（同上类型集） |
| `RemoveTreeParameter(StateTree, ParamName)` | 删根参数字段，**同时删以它为源的绑定**（否则编译报错）；字段不存在时静默 |
| `RemoveStateParameter(State, ParamName)` | 删状态参数字段 + 源绑定 + 对应 PropertyOverrides；链接态字段删了会在下次链接刷新时复原 |
| `AddPropertyBinding / RemovePropertyBinding / GetPropertyBindings / GetBindableSources` | 绑定 CRUD；`GetPropertyBindings` 的 TargetStructID 传全 0 GUID = 返回全部；**AddPropertyBinding 支持输出绑定方向**（source=节点输出属性 → target=树参数）；**2026-11-05 起双视图 ID 自动归一**（传模板 ID 自动转 `Node.ID`，见坑 11/16） |
| `SetTreeParameterRefDefault(StateTree, ParamName, RefTypeName, TypeObjectPath)` | **2026-11-05**：给 `FStateTreeBlueprintPropertyRef` 类型根参数字段配默认值（链式 Ref 接线柱必备；内部 `ImportText_Direct`——反射 setter 写该 struct 会写坏，坑 15） |
| `MigrateWriteParamToPropertyRef(StateTree)` | **2026-11-05**：旧「STT_SetTreeParam 值中转」形态批量迁移为任务 Ref 直写（删旧节点/绑定→固定映射建 Ref 绑定→DoOnce 转换；幂等） |
| `BindLinkedStateParametersFromTree(StateTree, ParamNames)` | 批量给链接态建「根参数→State.Parameters」feed（字段为 Ref 接线柱时即链式指定绑定） |
| `CompileStateTree(StateTree)` | 编译并返回消息（`bSucceeded` / `messages[].severity|message`；**返回字段名是 `bSucceeded`，不是 `succeeded`**） |

配套：保存资产用 `editor_toolset.toolsets.asset.AssetTools.save_assets`（`asset_paths`），工具自身不落盘。

## 链式 Ref 迁移配方脚本（2026-11-05 首役，`Tools/StateTree/st_ref_*.ps1`）

按执行顺序（参数 `-Session <mcp-session-id>`；含中文已存 UTF-8 BOM）：

| 脚本 | 用途 |
|---|---|
| `st_ref_build_dzproject.cmd` | DZProjectEditor 编译循环（新增 UFUNCTION 需关编辑器全编——Live Coding 不传播） |
| `st_ref_migrate_round2.ps1` | 全量迁移：22 树 `MigrateWriteParamToPropertyRef` + 编译验证（**子树优先主树殿后**——链接子树未迁移时主树 schema 检查失败） |
| `st_ref_linkify_selecttarget.ps1` / `st_ref_linkify_all.ps1` | 子树参数链式化：bag 字段换 Ref 接线柱（Remove+Add+SetDefault）→ 迁移工具重建链式绑定 → 编译 |
| `st_ref_main_feed.ps1` | 7 主树链接态 feed（`BindLinkedStateParametersFromTree`） |
| `st_ref_bind_cond_refs.ps1` | 条件 Ref 读字段批量绑定（HasBattleTarget/CheckHasTarget/CheckDistance） |
| `st_ref_bind_read_refs.ps1` | 任务 Ref 读字段批量绑定（MoveToTarget/FindTarget/Attack） |

坑：MCP 每工具**首调偶发空响应**（脚本内置重试 3 次）；session 失效需重 `initialize` + `notifications/initialized`；**新增 Ref 字段（条件读/任务读）不在迁移工具固定映射内**，须用后两个脚本单独补装。

## 早期 Vector Payload 测试配方（2026-11-08 首役，`Tools/StateTree/st_evt_payload_link.ps1`；已由通用 Bag 任务取代）

并行树/子树事件从"Tag 通知级"升级到"Payload 数据级"的一键建链（MCP 直驱，编辑器须运行）：

| 步骤 | 动作 | 关键约束 |
|---|---|---|
| S1 发送 | `SetNodeProperties` 给发送任务**节点实例**注入 `EventToSend`（Tag + FInstancedStruct 载荷文本） | 勿写 CDO（蓝图任务实例属性初始化自 InstanceObject）；勿用蓝图 `set_pin_value`（FInstancedStruct 文本静默解析失败） |
| S2a 接收状态 | `ObjectTools.set_properties`：`bHasRequiredEventToEnter=true` + `RequiredEventToEnter=(Tag,PayloadStruct=Vector)` | PayloadStruct 必须与到达事件 payload 类型 IsChildOf 匹配（StateTreeTypes.cpp:249-263），**不匹配=状态静默拒选** |
| S2b 取源 | `GetBindableSources(接收任务ID)` 过滤 `source=='StateEvent'` 拿 "Enter Event" desc ID | TransitionEvent 源对任务禁闭（StateTreeEditorData.cpp:428-458），只能走 StateEvent |
| S2c 绑定 | `AddPropertyBinding(InInt ← Enter Event.Payload.X)` | 接收任务 Input 属性强制要求绑定（摘旧绑定须同步补占位） |
| S2d 编译 | 双树 `CompileStateTree` | `bSucceeded` 字段名核对 |
| S3 判定 | PIE 9s + `GetLogEntries` 比对接收方打印值 == 载荷值（`-SkipPIE` 可跳） | bSimulate 即可；日志 pattern 按小时抓防旧日志混入 |

首役 PIE 铁证：并行树发 `Vector(222)` → 主树 ParDone 连续 10 轮打印 222（跨 RunParallel 隔离边界）。该脚本保留为引擎文本注入/StateEvent 绑定测试工具；新多字段链路优先用 `STT_SendParallelEvent` / `STT_ApplyParallelEvent`。坑全表见 `dz-st-split/references/implementation-pitfalls.md`「Payload 数据级闭环与通用 Bag 任务坑」与实测报告 §6.1/§9。

## 全树递归 dump + 生产落地配方（2026-11-08 首役，`Tools/StateTree/st_dump_tree_full.ps1` / `Tools/StateTree/st_pa_stage3c.ps1`）

| 脚本 | 用途 |
|---|---|
| `st_dump_tree_full.ps1` | **全树递归精简 dump**（每状态一行：类型/EC/任务带 ID/转移带目标与 Tag/子态数）——侦查替代逐层 DescribeState 手拼；`-Tree <refPath>`，PS5.1 注意勿用内联 `if` 表达式 |
| `st_pa_stage3c.ps1` | **05002102 并行树 Payload 通知落地配方**（新框架首个生产落地）：AddState 通知态 + AddStateNode(STT_ParallelNotify_C) + `SetTransition` 重定向攻击成功转移 + AddTransition 通知→检测循环 + SetNodeProperties 注入 Tag+Payload + 双编译 + save_assets |

配方增量坑（2026-11-08 实录）：①**PS 5.1 无 BOM 脚本内嵌中文经 GBK 读——AddState 状态名乱码**，修复用 write 工具落 UTF-8 JSON 文件后 `Get-Content -Encoding UTF8` 读入 `ObjectTools.set_properties`（UStateTreeState.Name 反射可写）；②`AssetTools.move` 一步完成资产改名+挪目录（new_path 给完整对象路径），旧位留重定向器、引用自动修复；③蓝图任务带 `FStateTreeBlueprintPropertyRef` 变量（如测试残留在 `InInt`）时**该 Ref 字段强制要求绑定**（编译 "expected to have a binding"）——转生产前 `remove_variable` 清掉测试残留变量；④`AddTransition` 对个别合法目标偶发 `IsStateInTree` 误拒（时序抖动）——换语义等价目标重试即过（如 Root 不可达就指子入口态）；⑤**Simulate PIE 关卡流不自动跑**（无玩家触发）——刷怪/进战链不激活，生产行为级 PIE 需人工进战（用户 PIE 打怪），自动化不可达。

## C++ 工具索引（源码内，随 git 提交团队可用）

| 函数 | 位置 | 说明 |
|---|---|---|
| `AddStateTreeGlobalParameter(StateTree, ParamName, ValueType, ValueTypeObjectPath)` | `AISystem/DZAISystemUtil.h/.cpp`（WITH_EDITOR） | 幂等加根参数字段；ValueType ∈ Bool/Object/Struct；**仅根参数**（状态级参数无工具）；无 Remove（CRUD 待补） |
| `DumpStateTreeBindings(StateTree)` → FString | 同上 | 全量绑定 dump（多行文本；`FPropertyBindingPath::ToString` 需 `PropertyBindingUtils` 模块依赖——已加 Editor 分支） |
| `RebindBindingsToTreeParameter(StateTree, TargetPathFilter, ParamName)` | 同上 | 把 target 路径含 filter 的绑定**原地改接** Parameters.<ParamName> |
| `DumpStateTreeStates(StateTree)` → FString | 同上 | 状态路径 + 任务节点清单 |
| `InstallParamOutNodes(StateTree)` → int32 | 同上 | 批量挂 `STT_SetTreeParam` + 绑定（幂等；仅瞬时任务入表） |
| `RemoveSetTreeParamNodesBySource(StateTree, SourceTaskTypeName)` → int32 | 同上 | 按绑定来源摘节点+绑定（Running 任务回退用） |
| `DumpBlueprintVariables(Blueprint)` → FString | 同上 | Blueprint 变量名/分类/flags/元数据 dump；排查 Task Blueprint 的 required input |
| `SetBlueprintVariableOptional(Blueprint, VariableName, bOptional)` → bool | 同上 | 幂等增删 `Optional` 元数据；误建 Input 未绑定时让 StateTree 可链接 |

## 坑清单（2026-10-28 全量实录）

1. **绑定时序铁律**：绑定拷贝发生在 `TickTasks` 循环内、**每个任务 Tick 之前**（`StateTreeExecutionContext.cpp:4970-4978`；State 参数绑定在 4820-4826）。所以 `STT_SetTreeParam` 这类"消费上游 out 属性"的节点**必须在 Tick 里写**（EnterState 读到旧值）；同理"上游赋值 → 下游立即消费"必须同帧内 Tick 顺序，不能依赖 EnterState。
2. **UHT UScriptStruct 名不带 F**：`FSTT_XXX` 结构在资产/绑定系统里的名字是 `STT_XXX`。
3. **UStateTree 的 Parameters/Nodes/property_bindings 全是 protected**（Python 读不了）；编辑器绑定真源在 `UStateTreeEditorData::EditorBindings`（`GetPropertyEditorBindings()` public），编译产物 `UStateTree::PropertyBindings` 会被重编译覆盖——**改绑定要改 EditorData**。
4. **`STT_SetTreeParam` 类型约束**：覆盖 Bool/Float/Actor/Vector/Tag；struct 类型（如 `FAttackTaskData`）绑定目标类型受限，且 GA 同帧读黑板必须立即有值——`EnemyAttackData`/`EnemyPlayMontageTag` 这两类保留代码写穿。
5. 无头资产写入必须**编辑器关闭**（15:43 实录：编辑器开着时 `save_loaded_asset` 静默失败但日志报成功）。
6. **Running 多帧任务禁止挂 `STT_SetTreeParam`**（2026-10-28 晚实录，最严重）：节点首帧 Tick 无条件写 out 属性 → 首帧把空值写进参数（FindTarget 的 POINT_TARGET/HAS_POINT_TARGET、Attack 的 ATTACK_TARGET 全被清空，寻点/攻击当场坏）。判定标准：**out 属性是否在 EnterState 内赋值**（瞬时任务）——是则挂节点；否则走代码写穿（同帧语义），并确保 out 属性在**所有成功路径**上赋值（复用/维持分支也要写当前值，否则节点写空）。
20. **FInstancedStruct 文本注入三坑**（2026-11-08 PIE 实证）：①TBaseStructure 注册的 ScriptStruct 对象名**无 F 前缀**（`/Script/CoreUObject.Vector`✓、`FVector`✗ 静默失败；`FIntPoint` 无反射注册整体不可用）——文本注入限引擎预注册类型集合；②蓝图 `set_pin_value` 对 struct 引脚文本**静默解析失败**（编辑器显示正确、编译无警告、运行时值为空）——载荷一律走 `SetNodeProperties`（节点实例）或 `ObjectTools.set_properties`（UObject 属性）；③蓝图任务实例属性初始化自**资产节点实例 InstanceObject**，改 CDO 变量默认值对 PIE 运行时无效（此前"实例不可写 struct 变量"结论仅限引擎节点结构体容器，蓝图普通变量在实例层可写）。
21. **FInstancedPropertyBag 禁止 Detach 重建**（2026-11-09 PIE 实证）：以局部副本 `Detach()` + `InitializeFromBagStruct()` 制造事件载荷时，字段描述和计数存在，但值始终为默认 0；日志 `Sent ... with 1 bag values` / `Apply complete: 1 values` 会误导成成功。发送端只调用 `SetValue(EventName, SourceProperty, SourceAddress)`；接收端只调用 `GetValue()` + `FindPropertyDescByName()` 读取真实存储。
22. **USTRUCT 改名后资产节点会静默变空**（2026-11-10 合并期实证）：`_New` 类型改名后，旧 `FStateTreeEditorNode.Node/Instance` 找不到原 struct，加载只丢 Warning，随后 StateTree 编译报 `Malformed task, missing instance value`。修复必须重建节点并补绑定；无头脚本可先用 `StateTreeEditorData.get_editor_data` 枚举 state/task，再走 `AddStateTaskNode/RemoveNode/MoveNode/SetNodeProperties/AddPropertyBinding`。
23. **整事件绑定空 SourcePath 合法**（2026-11-10）：`InEvent ← Enter Event` 在绑定表里是 `SourcePath=""` 的整 struct 绑定。`AddPropertyBinding` 的 source 空路径应转换为 `FPropertyBindingPath(SourceStructID)`；target path 不能为空。

## 贡献规则（以后新工具往这放）

1. 新工具脚本 → `dz-ue-Tools/StateTree/Tools/StateTree/`，命名 `st_<动词>_<对象>.py`，头部注释含用途/依赖/用法/坑；
2. 本文件登记条目（名称/用途/依赖/用法/坑），坑随发现随记；
3. 涉及引擎语义结论的知识 → 同步 `dz-st-split/references/` 对应模块（本库不囤知识）；
4. 涉及执行流程/测试/提交纪律 → 迭代回 `dz-st-split/references/execution-and-discipline.md`。

## 交叉引用

- 参数面架构与逐键安全表：`dz-st-split/references/net-server-client.md`（「Parameters 数据面源码落地」节）
- 执行通道选择（MCP vs 无头）与 L1-L4 测试：`dz-st-split/references/execution-and-discipline.md` §2/§4
