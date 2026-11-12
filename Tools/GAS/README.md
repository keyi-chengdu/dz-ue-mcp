# ga_dsl — GA 图表 DSL 生成器（长期维护）

> 迁移记录：2026-11-06 自项目根 `Tools/ga_dsl/` 迁入本技能 `Tools/GAS/`（原位置留指路 README）。
> 产出供 `BlueprintTools.write_graph_dsl` 消费；蓝图手术配方见 `dz-ue-tools/SKILL.md` §4。

本目录的脚本是对应 GameplayAbility 蓝图图表的 **DSL 生成器，即该系统逻辑的唯一可读源码**。
蓝图资产是二进制，无法 review/diff；调整系统流程时应优先修改这里的脚本并重新生成，
而不是在编辑器里手改蓝图节点。

| 脚本 | 对应系统 | GA 资产 |
|---|---|---|
| gen_ga_player_down.py | 倒地生命周期（V2：Downed Tag 由 activationOwnedTags 授予） | GA_Player_Down |
| gen_ga_player_rescue.py | 救援流程（V1：开始后不可中断） | GA_Player_Rescue |

通用 GA 蓝图维护工具：

| 脚本 | 用途 |
|---|---|
| ga_blueprint_parent_tool.py | 无头审计/修复 GA Blueprint 父类；`-GasMode=fix` 才写入，单资产用 `-Asset` + `-Parent` 覆盖。 |

脚本头部注释记录了设计决策与版本变更原因，修改时请同步更新。
若蓝图后来在编辑器中被手工改过而未重新生成，本目录即退化为设计快照——请如实标注。
