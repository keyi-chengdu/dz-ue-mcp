# 项目工具：UnLua蓝图父类与事件空桩

这两个是已实装的项目CLI工具，不是ToolsetRegistry中的新工具名。入口脚本：[migrate_passive_parent.py](../../../../DZ_Content/Tools/Editor/migrate_passive_parent.py)，UE侧：[passive_parent_backend.py](../../../../DZ_Content/Tools/Editor/passive_parent_backend.py)、[unlua_event_stubs.py](../../../../DZ_Content/Tools/Editor/unlua_event_stubs.py)。

## DZ.UnLua.MigratePassiveParent

用于本项目Item/Energize中误以GAP_Player_DamageRecord为直接父类的Lua能力。默认只选这类错误资产，目标为原生DZGA_PassiveSkill；正式方案若明确需要其他继承关系，不套此工具。

保存原资产、GetModuleName、自有变量和业务默认值→换父类→仅删除旧GetModuleName→UnLua工具栏Bind→显式编译目标→恢复原Lua路径和业务参数→修复生命周期空桩→核对、编译、保存。仅数据蓝图先Open Full Blueprint Editor。清除与旧父类完全相同的无关Tag门，GAP清除误继承的DamageRecord触发；条目自有触发、身份、网络策略和GE引用保留。

第三步通过MCP Slate控件执行标准Bind命令，会操作编辑器UI；它不是直接写受限ImplementedInterfaces数组。首次单例后批量。Bind尚未成功时失败可恢复当前条目，失败立即停止；已成功条目在重跑时自动跳过。原资产备份与逐项结果在work目录。

```powershell
$UnLuaWork = Join-Path "E:/Project_DZ_Real/DZ_Content/Saved/AgentTools" ("UnLua-" + (Get-Date -Format yyyyMMdd-HHmmss))
python "E:/Project_DZ_Real/DZ_Content/Tools/Editor/migrate_passive_parent.py" --limit 1 --work $UnLuaWork
# 单例通过后继续其余错误父类；可复用本批work以保留结果。
python "E:/Project_DZ_Real/DZ_Content/Tools/Editor/migrate_passive_parent.py" --work $UnLuaWork
```

## DZ.UnLua.ActivateEventStubs

用于Item/Energize的Lua能力空桩事件：ActivateAbility、ActivateAbilityFromEvent、OnEndAbility、K2_OnAvatarSet。已有业务节点的执行链保留并在skipped中报告，不盲删Parent后续的业务逻辑。

1. 快照Lua绑定、CDO参数、EventGraph及原uasset。
2. 删除空桩直接相连、无业务后续的Parent或旧Anchor调用；保留事件节点。
3. 事件then接临时Development|PrintString，编译。
4. 删除临时PrintString，再编译；最终then空置，不留Parent、Anchor或PrintString。
5. 检查生成类中相应K2函数仍存在，且Lua路径、参数和其余原节点不变，再保存。无引用的旧空Anchor辅助函数一并清理。

```powershell
$UnLuaWork = Join-Path "E:/Project_DZ_Real/DZ_Content/Saved/AgentTools" ("UnLua-Stubs-" + (Get-Date -Format yyyyMMdd-HHmmss))
python "E:/Project_DZ_Real/DZ_Content/Tools/Editor/migrate_passive_parent.py" --activate-stubs --asset "/Game/Blueprint/Energize/06000026/GAP_06000026_AuraField" --work $UnLuaWork
# 同类授权范围内批量处理，已启用且干净的事件跳过。
python "E:/Project_DZ_Real/DZ_Content/Tools/Editor/migrate_passive_parent.py" --activate-stubs --work $UnLuaWork
```

## 参数与核验

- **新建事件路由 GAE（2026-11-06 06000029 实证）**：BlueprintTools.create 全新建的 GAE 只补 UnLuaInterface+GetModuleName 不够——**必须再用 `BlueprintTools.add_event` 补 `K2_ActivateAbilityFromEvent` 空桩节点**（无连线的裸事件节点）并编译保存。缺此桩时 BlueprintNativeEvent 在生成类无 UFunction 覆写，引擎直走 C++ 默认实现，UnLua 同名接管零调用（表象：模块加载成功、触发事件正常、Lua 永不执行）；在役先例 06000013/06000017 的 GAE 均带此桩。验收以 `list_events` 中 K2_ActivateAbilityFromEvent implemented=True + 生成类含该 UFunction 为准。

- **编辑器桥直调 BlueprintTools 的三个坑（2026-11-10 02000032 武器 GA 迁移实证，工作目录 `Saved/AgentTools/UnLua-032`）**：
  1. `write_graph_dsl` 经 Python 桥**直调时异常被 @tool_call 装饰器吞掉**（图写空、无报错）：必须包 `with toolset_registry.tool_raising_exceptions():`，否则坏 DSL 静默失败、只留半成品节点。
  2. DSL 调用含 **self 引脚**的成员函数（如 `Ability|ExecuteGameplayCueOnOwner`，数据引脚序 [self, GameplayCueTag, Context]）必须用**关键字参数**（`:GameplayCueTag "(TagName=\"...\")" :Context <expr>`）；位置参会错位到 self，报 "Could not connect pin ReturnValue to GameplayCueTag"。
  3. **子蓝图绑自有模块不需要 Slate Bind**：父类已实现 UnLuaInterface 时，`add_function_graph(子蓝图,'GetModuleName')` + DSL return 模块名 + 编译保存即可（接口继承）；只有"父类是原生 C++（如 DZGA_ManualSkill）"才必须走 UnLua 工具栏 Bind。Slate 自动化 Bind 的可行序列（多轮实证）：**先激活目标 BP 标签页**（后台标签工具栏不渲染、快照无按钮）→ Click UnLua 按钮 → **PressKey Enter** 开下拉（合成 Click 不触发）→ 精确文本匹配 `Bind`（防 "Parameter Bindings" 误报）→ Click。**PIE 运行中点 Bind 无效**：ImplementNewInterface 静默失败但触发保存，需 PIE 结束后重做。
  4. 静态 GC（MakeInstancedStruct→MakeEffectContextFromInstancedStruct→K2_ExecuteGameplayCue）因 FInstancedStruct 对 UnLua 不透明（061/04011021 实证），装箱执行留蓝图小助手函数（读成员变量、无参），Lua 只写变量字段后调用助手（02000042 同架构）。

- `--work`：本任务可写的绝对快照/回执目录；不得覆盖其他任务的产物。
- `--asset`：只选一个完整对象路径或包路径。`--limit`限制本次资产数。
- `--snapshot-only`：只预检/快照，不改UE资产；可与任一工具模式组合。
- `--engine`：引擎根目录，默认本机E:/UnrealEngine/UE_5.8。`--mcp-url`默认回环http://127.0.0.1:8000/mcp。换机先核实际工程/引擎路径。
- 运行条件：编辑器Python远程执行已启用、编辑器不在PIE；父类迁移还需要现成MCP Slate工具集。不要为运行工具擅自修改工程安全设置或启动PIE。

验收以资产读回和生成UFunction为准，不以事件节点存在、看似连线或编译返回成功代替。编译/绑定核验本身不等于PIE或双端通过，也不自动升级或回退工作台状态。首次落地按工作流进入待验证；已有用户验收状态按其明确指示保留或变更，本次技术改动与回归范围另记回执。PrintString方法的既有机制依据见[implementation-pitfalls](../../dz-gas-split/references/implementation-pitfalls.md)。
