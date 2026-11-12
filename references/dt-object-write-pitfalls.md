# UE MCP 写入与读取坑位（DataTable / Object / Asset / Scene）

> 来源：2026-11-05 至 06 关卡流池配置的实测。本档只收**通用工具行为**；关卡流池专属的写入规程见 `.agents/skills/DZLevel-关卡流池配置-Skill/00_Rules/02_写入纪律.md`。

## 1 DataTableTools

| 行为 | 说明 |
| :--- | :--- |
| 读写形状不对称 | `get_rows` 读出 `{"键": {"RandomWeightSetting": 1.0}}`，`set_rows` 必须写 `{"键": 1.0}`（裸 float）。拿读出形状回写，会把该行所有组的内层权重清成空 map，且不报错 |
| 结构操作会清空既有行 | `add_rows` 在副本上复现：写入行 10、11 后仅调一次 `add_rows(["997"])`，行 10、11 变 0 条。`rename_rows` 同样会改名成功但内层清空 |
| 返回值 | `set_rows` / `rename_rows` 返回 `{"returnValue":null}` 属正常形状，**不代表成功**，必须回读判断；`save_assets` 返回 true 后再核文件修改时间 |
| 一次取多行 | 会撞探针 60000 字符截断，逐行 `get_rows` |
| 规程 | 结构操作前全表快照；操作后全表逐行 diff；优先用 `set_rows` 一次写全表（含新增行） |

## 2 ObjectTools

| 行为 | 说明 |
| :--- | :--- |
| `set_properties` 的 `values` | 必须是 **JSON 字符串**，传对象会报参数错误 |
| `get_properties` | 传入不存在的属性名会导致整次调用报错，成功读到的值一并丢弃；属性名是小驼峰 |
| 读取其它地图里的 Actor | 必须用显式对象路径，如 `/Game/Maps/.../<地图>.<地图>:PersistentLevel.<Actor 名>`，并先 `AssetTools.load_asset` 载入 |
| CDO 属性 | `/Script/DZProject.Default__DZSetting` 可读写；Map 属性的键首字母会被小写化，比对不区分大小写 |

## 3 AssetTools / SceneTools

| 行为 | 说明 |
| :--- | :--- |
| 没有创建资产的工具 | 新建数据资产用 `duplicate` 复制范本再覆盖字段；复制会**重新分配** `packageAssetId` |
| `find_assets` 的 `name` | 子串匹配；`recursive` 控制是否递归 |
| `is_dirty` | 参数是单数 `asset_path`（字符串），不是数组 |
| `SceneTools.find_actors` | 只作用于**当前已打开的世界**；`name`、`tag`、`collision_channels` 三个参数都是必填，不过滤时传空串与空数组 |

## 4 配置类属性的持久化

`ObjectTools.set_properties` 写 CDO 是**裸属性写入**，不触发 `SaveConfig`：编辑器内存立即生效，但重启会回退；反过来只改 ini 文件，编辑器之后保存设置会用内存旧值覆盖。涉及配置文件的属性，**CDO 与文件必须双写**，写完两边各读一次比对。

## 5 编辑器离线

`127.0.0.1:8000` 拒绝连接 = 编辑器未开或 MCP 服务未启动。资产（`.uasset` 二进制）与地图不得直读，离线时只能读文本配置与文件修改时间；随机表与 Actor 属性读不到，文档与 Plan 里必须写明「未回读」。
