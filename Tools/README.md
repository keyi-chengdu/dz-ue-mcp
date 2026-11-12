# UE AI 可复用工具目录

本目录存放 DZProject **UE AI 工具链**的非 C++ 可执行工具（Python、PowerShell、批处理等），按项目模块分目录管理。StateTree 领域工具已统一并入 `Tools/StateTree/`。

## 目录规范

- `Tools/<项目模块>/`：通用模块工具目录，例如 `Tools/GAS/`、`Tools/Level/`（有实际工具时再建目录）。
- 新增模块目录时，在本 README 的模块索引中登记职责与工具清单入口。
- 工具头部注明用途、依赖、用法与已知坑；模块工具索引同步登记，不能只散落脚本。
- **C++ 不放在这里**：UE MCP 工具集相关 C++ 统一放 `DZ_Content/Plugins/DZToolsets`。
- 临时一次性脚本、输出日志、测试快照和缓存不得混入本目录。

## 工具链规则（2026-11-04）

1. UE MCP 优先；连接或工具不可用时先按 `dz-ue-tools` 自检。
2. UE MCP 不可用或现有工具集能力不足时，按 `create-toolset` 扩充工具集。
3. 通用非 C++ 工具放本目录对应项目模块；可复用工具不再散落项目根或 `.dsh/st_work`。
4. StateTree 相关 C++ 仍统一归 `DZ_Content/Plugins/DZToolsets`。

## 模块索引

| 模块 | 工具目录 | 使用与索引 |
|---|---|---|
| StateTree | `Tools/StateTree/` | `Tools/StateTree/README.md`：参数 CRUD、绑定/状态 dump、迁移/审计、参数节点安装/摘除、飞书文档推送 |
| GAS | `Tools/GAS/` | `Tools/GAS/README.md`：GA 蓝图图表 DSL 生成器（GA_Player_Down / GA_Player_Rescue；2026-11-06 自项目根 `Tools/ga_dsl/` 迁入），产出供 `BlueprintTools.write_graph_dsl` 消费 |
| MCP | `Tools/MCP/` | `Tools/MCP/README.md`：MCP 元工具未挂载时的本地 HTTP 直连初始化、列表/schema 查询与工具调用 |
