# dz-ue-tools

DZProject UE 5.8 AI 工具统一入口。它合并了原 `dz-ue-mcp` 和 `dz-ue-statetree-tools`：

- UE MCP 连接、安全边界、编辑器资产/PIE/日志操作。
- 通用 MCP 直连与 GAS 蓝图维护脚本。
- StateTree 参数、绑定、迁移、审计、编译与批量资产手术工具。

## 目录

| 路径 | 用途 | 索引 |
|---|---|---|
| `Tools/MCP/` | MCP HTTP 直连兜底 | [Tools/MCP/README.md](Tools/MCP/README.md) |
| `Tools/GAS/` | GA DSL 生成与 Blueprint 父类维护 | [Tools/GAS/README.md](Tools/GAS/README.md) |
| `Tools/StateTree/` | StateTree 领域工具包 | [Tools/StateTree/README.md](Tools/StateTree/README.md) |
| `references/` | 通用 UE 编辑器/蓝图/DataTable 经验 | 见主 `SKILL.md` |

## 安装与前置

当前 GitHub 远端仓库名仍是 `keyi-chengdu/dz-ue-mcp`；本地技能目录与注册名已先行迁移为 `dz-ue-tools`。远端改名或重定向建立前，安装仍可使用现有仓库：

```bash
git clone https://github.com/keyi-chengdu/dz-ue-mcp.git .agents/skills/dz-ue-tools
```

编辑器需要启用 **Unreal MCP**、**All Toolsets**（GAS 项目建议 GASToolsets），并在 Editor Preferences 开启 MCP Auto Start Server。默认端点是：

```text
http://127.0.0.1:8000/mcp
```

## 使用入口

完整规范、安全边界、PIE 配方、StateTree 路由和工具索引见 [SKILL.md](SKILL.md)。StateTree 深度操作先读 [Tools/StateTree/README.md](Tools/StateTree/README.md)。
