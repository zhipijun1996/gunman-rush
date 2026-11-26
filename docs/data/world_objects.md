# 普通房间机关库

每项机关／组合件有一个定义文件与一页对象说明。定义声明版本、可配置值和行为，行为合同声明合法字段、输入输出与可保存状态；房间只记录实例、连线与覆盖参数。定义中的 documentation 以仓库根目录为基准。

[基本机关库定稿](失序之钟_基本机关库.md)记录 46 项设计及模式，[预组与组合推荐](失序之钟_预组与组合推荐.md)记录 8 个预组及用法。下方对象目录列出游戏当前可以创建的实例；逐模式验收见[制作交接](../project/worklines/mechanism_libraries/scope.md)。

## 制作时怎样选库

正式房间在 `root.properties.region_id` 指定所属区域。可摆放清单从[机关定义](../../production/config/world_elements/definitions)的 `usable_regions` 生成。`["*"]` 向所有区域开放；具体区域列表可以覆盖一个或多个区域。预组取自身和全部成员可用范围的交集。未指定区域的房间只取公有清单，未知区域或越区引用会在装配前报错。区域 ID 与[地形登记表](../../production/config/terrain_materials.json)一致。房间可独立选择地形材质。

在仓库根目录查询作者可用的机关，每项输出定义 ID、中文名和对象页。省略区域只列公有库。

```sh
bash tools/godot.sh --headless --path production --script res://scripts/list_mechanisms.gd -- --regions
bash tools/godot.sh --headless --path production --script res://scripts/list_mechanisms.gd -- thorn_forest
bash tools/godot.sh --headless --path production --script res://scripts/list_mechanisms.gd -- --describe assembly.bell_gate
```

- **公有机关**承担跨区通用的动作、交互或组合。各区引用同一份定义及行为合同。区域清单的 `skins` 按定义 ID 提供外观，只能填写该定义声明的 `region_skin_fields`。材质引用地形登记表，贴图引用游戏实际导入的 PNG。未配置的外观沿用机关自身默认值。
- **区域特色机关**用于该区独有的玩法，或具有区域特色、应能整体复用的组合。先创建独立定义和对象页，在机器索引登记定义，并在定义的 `usable_regions` 写入适用区域。能由现有组件实现的组合直接引用其定义和端口。组合只在全部成员均可用的区域列出。创建组合时将来源定义随子实例保存，换区后重新校验。
- **判断归属**时先看玩家动作、触发条件、反馈和恢复方式。只变化贴图或材质就在区域清单配置外观；单房的位置、速度、行程和连线写入实例。改变共用行为合同或新增独特玩法时，再评估是否需要独立定义。

## 公有机关目录

目录包括 15 个可直接放置的单项和 2 个可展开的组合件。组合件中的风铃、门和载台继续使用各自的单项定义。

| 定义 ID | 对象说明 |
| --- | --- |
| `switch.crossing` | [通过感应器](mechanisms/switch.crossing.md) |
| `switch.shot` | [射击风铃](mechanisms/switch.shot.md) |
| `gate.masonry` | [砌体机关门](mechanisms/gate.masonry.md) |
| `platform.moving` | [移动载台](mechanisms/platform.moving.md) |
| `hazard.gear` | [移动齿轮](mechanisms/hazard.gear.md) |
| `hazard.spikes` | [附着尖刺](mechanisms/hazard.spikes.md) |
| `assembly.bell_gate` | [风铃与机关门](mechanisms/assembly.bell_gate.md) |
| `assembly.bell_carrier` | [风铃与升降台](mechanisms/assembly.bell_carrier.md) |
| `traversal.hook` | [钩索锚点](mechanisms/traversal.hook.md) |
| `interaction.return_gate` | [捷径门](mechanisms/interaction.return_gate.md) |
| `interaction.action` | [世界行动宿主](mechanisms/interaction.action.md) |
| `zone.environment` | [环境区域](mechanisms/zone.environment.md) |
| `hazard.area` | [危险区域](mechanisms/hazard.area.md) |
| `traversal.hook_point` | [固定钩索点](mechanisms/traversal.hook_point.md) |
| `recovery.anchor` | [安全恢复点](mechanisms/recovery.anchor.md) |
| `interaction.sign` | [告示](mechanisms/interaction.sign.md) |
| `recovery.station` | [充电保存站](mechanisms/recovery.station.md) |

[机器索引](../../production/config/world_elements/index.json) · [房间组装](../bible/room_authoring.md)
