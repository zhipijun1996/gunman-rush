# 世界内容接入

世界、路线、剧情、任务和经济在[世界工作台](https://clock-world-explorer-1117.zhipijun1996.chatgpt.site/)迭代。工作台发布带版本和哈希的内容包，开发时明确导入一个版本；游戏运行时只读取仓库内已锁定的包。

## 数据归属

| 内容 | 归属 |
| --- | --- |
| 区域、房间身份、连接、能力与事件资格 | 工作台内容包 |
| 对白、任务步骤、NPC身份、奖励身份 | 工作台内容包 |
| 商品、目标等级强化价、独立敌人掉落档案、一次性散币 | 工作台内容包 |
| 实机地形、材质、机关实例、敌人种类、数量与摆放、入口与镜头 | `production/` 的 schema 3 房间 |
| 内容身份到实机定义、房间文档的绑定 | `production/config/imported_world/bindings.json` |
| 战斗、拾取、支付、永久进度和保存 | 现有游戏所有者与正式世界宿主 |

世界地图的物理邻接、共用门线和出入侧约束施工。门线的轴标记描述线的走向；真实角色沿垂直于这条线的方向跨房。房间内的碰撞、平台尺寸与怪物出生点使用局部游戏单位。内容包描述尚未施工的房间是合法的；请求装载该房时必须有明确的实机文档绑定。网页敌群是规划建议，实际布怪种类、数量和位置由 schema 3 房间设计决定，不以建议数作为上限或自动填怪配额，也不要求实机组合属于本房的规划敌群。普通敌群总金币只用于估算，实际游戏按每只死亡生成掉落、实际拾取后入账；`coin_each`由独立的 `enemy_drop_profiles` 提供。网页探索存档不作为游戏存档导入。

## 固定协议

协议格式为 `clock-world-content`，`schema_version: 1`，世界身份为 `clock-world`。`content_version` 标识设计内容版本，与协议版本分开。发布链为：

1. `exports/channel-v1/latest.json`：开发期发现当前包，声明不可变 manifest 的路径、大小和 SHA256。
2. `exports/channel-v1/releases/<SHA256>/manifest.json`：声明 `content.json` 的原始字节大小和 SHA256、源模型哈希、版本及表计数。
3. 同目录 `content.json`：结构化数据、条件语义、所需实机绑定和显式身份迁移声明。

房间、门、任务、奖励和人物等身份保持稳定。普通数值修改和增量内容可沿用协议；删除既有身份必须列明对应旧包、删除原因与替代身份。迁移声明记录设计身份变化，不自动改写玩家存档。

[contract.py](../../../tools/content_channel/contract.py)是生产者验证器的同字节副本，权威源位于工作台的 `tools/content_channel/contract.py`。协议修改时同步生产者和消费者，更新对应检查；不要分别手改两份不同规则。

条件数组 `requires` 表示全部满足，`excludes` 表示全部不具备；`equipped:<ID>`检查装备状态。位置、首次开侧、反向房内资格、剧情可见性和完成资格各自保留，不把这些不同含义合并成一个布尔门槛。

## 导入与回退

在仓库根目录运行：

```sh
python3 tools/content_channel/sync.py --check
python3 tools/content_channel/sync.py
```

第一条只检查拟更新内容，第二条明确导入。指定固定版本时使用完整 manifest URL，并可加 `--expect-sha`：

```sh
python3 tools/content_channel/sync.py --manifest <固定版本的HTTPS-manifest地址> --expect-sha <内容SHA256>
```

离线包与回退：

```sh
python3 tools/content_channel/sync.py --package /absolute/path/manifest.json
python3 tools/content_channel/sync.py --rollback <已导入的内容SHA256>
```

导入器仅允许当前工作台的 HTTPS 通道地址，拒绝跨域重定向、路径逃逸、不支持的版本、错误哈希、悬空引用和未声明身份删除。网络失败或校验失败时原锁保持。包先完整写入不可变目录，最后原子替换 `current.lock.json`；重复导入同一个包不重写锁。回退只选择已安装并重新验证的包。

导入结果写入：

```text
production/config/imported_world/
  bindings.json
  current.lock.json
  releases/<SHA256>/manifest.json
  releases/<SHA256>/content.json
```

导入不覆盖 `bindings.json`、房内地形、美术或玩家存档。提交锁与对应内容包后，构建和运行使用同一版本，断网也可读取。程序启动不会追随远端 `latest.json`。

## 运行时读取

[WorldContentCatalog](../../../production/game/content/world_content_catalog.gd)负责本地校验、索引与只读查询。所有结果包含 `ok`；失败返回具体 `error`，不默默使用旧默认值。失败加载不会替换已经加载的有效 catalog。

| API | 结果 |
| --- | --- |
| `load_locked()` | 核验锁、manifest、字节SHA、版本、计数和引用，再安装目录索引 |
| `table(name)`、`lookup(table, id)` | 返回独立数据副本；未知表或ID拒绝 |
| `room_context(room_id)` | 房间、连接、当地内容及多地交互事件 |
| `connections(room_id)` | 保留首开侧、永久旗标、门口分区等字段 |
| `physical_passage(room_id, door_id)` | 由锁定门线及两侧房间轮廓给出本端向外方向、对端房号和地图门段。室内正面门另读 `entrances` |
| `condition_match(row, flags, equipped)` | 已知条件的满足情况、缺失与排除项；未知条件拒绝 |
| `dialogues_for(room, flags, equipped, zone)` | 按位置和状态选取各说话者最高优先级对白；相同优先级采用源顺序中最后匹配的一行 |
| `quest_status(id, flags)` | 步骤、发现、接受、完成和下一步；普通核心状态不泄露未遇见的地方任务 |
| `shop_quote(id)`、`upgrade_quote(id, target_level)` | 读取包内价格和内容哈希；调用方仍需执行资格、余额及事务检查 |
| `enemy_drop_profile(profile_id)` | 按独立档案返回物种、档位与单只金币，不依赖房间或敌群 |
| `enemy_drop(group_id, species_id)` | 规划与兼容查询，返回档案身份、所在房间、`planned_count`和单只金币；`count`为兼容别名，均不限制实际布怪，也不发放整组总额 |
| `load_bindings(path)`、`room_document(room_id)` | 验证游戏侧绑定，未施工房拒绝装载 |
| `bound_definition(section, id)` | 验证内容身份映射到已登记实机定义 |

`bundle_sha256`应进入实际宿主的内容身份，避免同一存档被不同内容版本静默解释。Catalog不提交金币、任务进度或角色状态；这些变化继续由现有事务与保存系统处理。

## 实机绑定

绑定表有 `rooms`、`npcs`、`enemy_species`、`equipment_effects`、`event_triggers` 五个部分。P02 已绑定至可独立试玩的房间文档。绑定使宿主能够装载此房间；试玩评审及发布状态见[当前开发基线](../../project/current_state.md)。

房间绑定示例：

```json
{
  "document_path": "res://rooms/world/P04.json",
  "status": "authored"
}
```

绑定的键为内容房间ID，目标文档必须为 schema 3 且 `room_id` 相同。用于验证的绑定使用 `status: integration_test`，只有显式允许测试绑定时可用。测试房不会自动成为正式地图。

物种绑定使用 `definition_id`，例如 `enemy.patrol`；内容物种身份与显示名称分开。房内具体实例继续由 schema 3 数据摆放，文档的 `content_bindings.enemy_instances` 将实例ID映射为 `{species_id, drop_profile_id}`。接入桥核对实例实机定义、物种身份与掉落档案的物种一致性。该映射不引用规划敌群，不把宏观敌群锚点当成实机出生点。

掉落档案提供稳定的 `id`、`species_id`、`tier` 和 `coin_each`。规划敌群的每个敌人项通过 `drop_profile_id` 引用同一档案，其数量和总收益仍用于设计估算。房间可以使用任意已登记且绑定到正确实机定义的物种及其档案；增加新物种或新经济档位时明确增加内容定义，不从显示名称或金币数临时推断身份。实际布怪数量与估算的差异可以报告给设计者，不作为装载门槛。

生产者的持久敌人目录保留当前没有规划组引用的物种和掉落档案；删除最后一个候选组不会使已施工房间丢失其经济定义。明确删除已发布身份仍须迁移。`WorldContentRoomBridge` 在 `room_context.enemy_budget_review` 返回候选数量/金币、实际实例数量/基础金币及差值；这是静态预算，包含当地全部候选组，不模拟玩家清怪比例或装备加成。

## 已接通的游戏行为

`OrdinaryRoomSession.open_content()` 校验并装载已绑定房间。每只敌人死亡时读取其掉币档案作为基础额，再沿用现有装备金币加成、小数累积、掉落与拾取事务。候选敌群总额不会重复发放。

接入内容的房间将同一 catalog 交给 `WorldServices`。强化菜单与实际交易统一使用 `equipment_upgrade_quote(id, target_level)`，从包内读取目标等级价格；报价失败时拒绝操作。没有接入世界内容的独立房继续使用原本的组件验证配置。装备效果、参数和图标仍由实际游戏实现持有。

本轮未接入世界商品购买及奖励授予的完整表现。已接入世界内容的房间拒绝旧 `equipment.reward`／本地 `claim` 路径，避免把网页中需要购买的装备免费授予；后续消费者必须显式绑定世界奖励和商品身份。NPC、事件、任务和房门目前有完整设计查询，实际交互与跨房资格由对应宿主继续接入。

保存身份包含房间文档和内容包哈希。接入房间拒绝直接恢复不同身份的非空存档，拒绝在跨房过程中混用两个内容包；失败不改写存档。旧内容存档须使用其原包，或由正式世界宿主执行明确迁移。

## 验证边界

运行 `python3 tools/check_content_channel.py`。目录检查覆盖真实导入包、任务发现、对白、条件和未绑定拒绝；经济检查覆盖统一报价、真实扣款、重复收据、余额不足和保存失败；房间检查覆盖自由组合与增减、真实击杀与拾取、读档和不兼容存档拒绝。跨端导入检查覆盖坏包、引用、幂等与锁的原子性。`python3 tools/check_ordinary_rooms.py` 继续验证普通房与现有永久装备。

数据通道通过不等于整个世界已经可玩。新房仍按[普通房间制作](../../bible/room_authoring.md)制作、接入并验证动作、跨房与恢复。
