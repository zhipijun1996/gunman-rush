# 工作台数据导出与正式接入

本页说明 [手机关卡工作台](scope.md) 的源码边界和命令。正式镜头由 `construction.json` 的 `camera.zones/links` 持有；旧 `camera_interests` 字段不再导出或接受，旧草稿须先与新版目录比较迁移。正式数据所有权沿用 [世界输入](../../../data/world/README.md)：房间布置由 `config/world/rooms/<ID>.json` 持有，`.tscn` 为同源装载壳，世界身份和连接归 `world.json`，门位、落脚和房形归 `construction.json`，收集设计归 `collection_design.json`。网页草稿是这些源的编辑视图，不能成为另一份游戏世界。

## 数据来源与精确对应

源码导出包含现行施工房、显式登记的隔离房及组件目录中的完整怪物物种。PCK预算由 `tools/export_workbench.py` 的 `--max-pack-mib` 参数持有，按实际同源资源闭包验证；分块传输与哈希校验不改变该预算含义。发行新游戏版本包不等于部署Site，也不自动迁移用户草稿。

[`workbench_seed.py`](../../../../tools/world/workbench_seed.py) 接受真实Godot场景导出，读取当前世界编译结果，并检查场景字节哈希及`base_content_version`。源码编辑范围由正式施工目录和[`rooms.json`](../../../../config/workbench/rooms.json)的显式附加房共同导出；当前为43个正式房及V-R12。已部署Site的独立版本不随源码范围声明自动变化。种子同时输出相关连接、相关现有收集或主要目标、玩家参数、实际组件与怪物目录、已登记节点类型及来源哈希。正式施工与隔离预览分别按目录标记；隔离灰盒不据此改变施工验收状态。

- 房间 `properties` 和 `nodes` 由共享 `WorldRoomDraft` 编解码器提取；平台、怪物、机关及既有兼容地形用同一组字段交给真实运行时及正式保存工具。
- `bounds`、`space_rects`和完整`doors`来自施工源及原编译器。`map_position`只通过`spatial.navigation_geometry`从成对门缝推导，不接受独立地图原点。隔离审核房按源导出的`map_component`分组，当前为P-R03、V-R12与Z-R01；网页与运行时只允许源登记组件，切断平原门不能把断房伪装成合法独立地图。源登记的`front_door`正面入口保留成对身份和落脚，以遮挡方式连接室外与室内地图层；不求侧边接缝、不切开外墙，也不将两区永久合并。浏览器不能改该身份标志，位置与实际落脚仍可按既有流程微调。
- 收集项有实际唯一宿主时，才提供真实 `position`、`edit_path`、宿主路径和类型。商店及里程碑目标没有独立宿主时，不制造展示坐标。
- `source_hashes`覆盖现行世界输入、明确编辑范围内全部场景、工作台范围登记和玩家运动配置；提交版本记录为`baseline`。组件目录另外记录源码合同哈希和来源文件；seed不在每次状态和历史中复制完整运行合同。
- `review_context`从同版人工源和编译合同派生16区域、309房职责摘要、38条跨区连接的双端门位、落点、门体条件和施工状态。它不增加309个可编辑场景。区域示意位置来自`world.regions.pos`，不代表碰撞坐标或距离；世界和施工源哈希必须匹配当前基线。反馈保存scope、region_code、connection_id、door_id及来源修订，`get_world_context`读取同一对象。
- `relocatable` 与正式导入规则一致：普通地图收集物、唯一 `WorldRoomInteraction` 宿主、没有独立返程状态。当前只有 `TG01`、`part_triple` 满足简单跨房迁移条件；`part_triple` 的 Boss 领取资格保持不变。其它条目用 `relocation_reason` 说明完整用例或返程合同要求。

导出示例：

```bash
python3 tools/world/build.py
bash tools/godot.sh --headless --path . --script tools/world/workbench_scene_io.gd -- --export="$PWD/build/workbench/room-scenes.json"
python3 tools/world/workbench_seed.py --scenes build/workbench/room-scenes.json --output build/workbench/seed.json --preview-output build/workbench/preview-world.json
```

`--runtime-available` 只在对应真实试玩包已经就绪时使用。未提供该参数时，seed 明确表示试玩包尚未可用。

### 未施工房间的隔离预览目录

`preview_catalog(root)`从同一原编译结果生成`build/workbench/preview-world.json`，供专用工作台运行包使用。目录包含`schema`、`base_content_version`、登记范围的37房`rooms`、`actions`、`demo_services`、`npcs`和`map_rooms`。返程动作来自世界动作及原`build.local_returns`，不重写奖励或资格规则。小型`construction_scene_bindings`按真实施工源导出；Provider核对施工源哈希、登记表哈希、精确房间集合及场景资源，避免把4.5MB人工施工源重复放入PCK。

目录将未正式施工的房间标记为`preview_only`，仅对已在编辑范围内的目标提供跨房预览。正式`construction.implemented`、由施工源派生的正式`runtime.json`和正式存档语义均不因此改变。V-R12邻房未登记，边界仍封闭。预览旧内部场景不表示它已按新房形施工或完成体验验收。完整运行目录进入PCK，不进入网页每次状态快照。

## 游戏目录与版本更新

主游戏拥有组件行为、怪物物种、镜头、NPC及剧情规则。`workbench_scene_io.gd` 从真实注册表、Definition 和场景编解码器导出字段与默认值，`workbench_catalog.py` 提供手机控件所需的类型、标签、范围和合法引用。网页只解释该目录。新增行为先在主游戏实现、登记并验证资源闭包，再更新工作台；已有落点仅微调位置，NPC和动作宿主遵循既有身份及唯一性，引用收据与创建宿主分别约束。水平地面、垂直墙面和台阶沿现行房间规则制作。

`.github/workflows/workbench-release.yml` 在主游戏或工作台开发分支更新后构建专用运行包和目录。`tools/workbench/release.py` 要求种子、运行包及源码提交一致，核对实际资源闭包，发布不可变GitHub资源，全部完成后才更新 `workbench-feed` 的 `channels/main.json` 或 `channels/preview.json`。该公开发行仅包含仓库游戏来源，不包含私有草稿或反馈，不需要模型API。主游戏尚未合入构建入口或构建未完成时，网页明确报告可用版本，不能假称已同步最新源码。

当前游戏预览通过 GitHub 公开发行交付。工作台包含世界审核、同版房间说明与公开发行薄清单；确切线上身份见当前交接。大运行资源从不可变 GitHub 发布读取，经原字节数与哈希验证后缓存，避免把完整运行包重复写入 Site 源码。薄清单仍保留同一源码、seed 与运行包身份，并沿相同版本比较和 CAS 迁移；不能使用 `--retained` 伪装新源码的构建证明。

网页“更新主游戏”读取发布索引，验证清单、种子、实际build-info与文件哈希。当前草稿继续绑定原运行包；只在明确应用通过比较的版本后切换。三方比较使用原始游戏快照、当前草稿及新游戏快照。稳定实体按身份合并；旧索引身份无法证明对应关系时显示整组冲突，不猜测重排。修订或锁定变化导致应用拒绝，旧冲突选择不能自动套到新稿。更新前保存检查点，恢复时同样检查锁定并保留恢复前状态。

运行版本由源码提交、组件合同、内容与来源哈希、运行包身份共同区分。纯怪物逻辑或镜头代码更新也卸载旧iframe并重新握手；普通位置和参数草稿继续复用驻留引擎。同源运行入口按不可变版本路由，原版资源保留供检查点恢复。

## 整区审核展示

整区统计与房间卡片分别呈现灰盒制作和正式主线接入。灰盒依据同版 review_context 的 authoring_status，正式接入依据 implemented；两者可重叠，不相加为房间总数，不用正式接入数代替已制作数量。没有制作证据的房间保持待制作。

有空间规划稿的区域在整区审核目录内直接显示完整图、路线、逐房职责、Boss、休息与收集要素；世界连接页也能进入同一审核组件。森林展示读取 forest_review.py 由唯一候选生成的 forest.json，不另存一份手绘坐标，不伪装成已制作灰盒或提供试玩。规划意见沿既有本机反馈格式保存并复制提交；其状态与可玩草稿隔离。

## 定稿范围

手机可固定某修订中选定房间的接受包。连接条件和收集文字修改也会推导所属房间，不能仅依据脏房间标记。明确选中的房间接受完整快照；跨房收集和成对门位自动纳入必要宿主或唯一支撑，依赖房的其他微调不混入定稿。依赖房整体几何已变或支撑无法唯一识别时，要求把该房明确加入范围。

接受包保存后保持不可变，用户可继续编辑。原始来源哈希和组件合同随包保留，代码接入使用下面的同一编解码器流程；固定接受包不等于提交PR、合并或正式发布。正式游戏接入后再执行三方更新：已接入的相同改动清除待接入状态，未接入及后续改动继续保留，同字段的新旧差异仍需明确处理。完整接受修订不能当作新游戏来源，否则会误吞未接受内容。

## 接受包与执行流程

网页或 MCP 可导出当前全部待接入内容，也可读取固定ID的定稿范围，格式均为 `gunman-workbench-change/v1`。包包含基线、内容版本、草稿修订、来源哈希、明确的脏房间 `properties/nodes/geometry`、全部平原连接视图及奖励视图。AI 直接把该 JSON 交给 [`workbench_apply.py`](../../../../tools/world/workbench_apply.py)，无需人工转述坐标或重新生成场景文本。

默认命令只准备候选：

```bash
python3 tools/world/workbench_apply.py accepted-change.json --output-dir build/workbench/revision-8
```

输出目录必须为空，以保留不同修订的证据。成功后输出 `receipt.json` 和候选源文件。只有明确指定 `--write` 才写回正式源：

```bash
python3 tools/world/workbench_apply.py accepted-change.json --output-dir build/workbench/revision-8-apply --write
```

默认通过 `tools/godot.sh` 执行锁定引擎。需要指定已安装的二进制时可传 `--godot /absolute/path/godot-linux-x86_64`；该参数仍经同一引擎身份及哈希检查，不绕过工具链锁定。

接入顺序为：

1. 检查包的基线属于当前提交历史，全部来源哈希及存在时的组件合同仍一致，编译内容版本一致，每个房间的内部身份、修订和场景哈希与包一致。
2. 用共享 Godot 编解码器重新提取当前场景，核对收集宿主和支持的编辑字段。
3. 在独立候选目录更新明确提交的世界输入；实际布置由共享 Godot 编解码器保存为房间JSON，并通过真实装载器重新载入比较；保留无布置的场景壳以兼容直接消费者。
4. 在隔离候选树运行原 `build(root)`，检查全世界合同、已采用房形、成对门缝和内容版本；再次核对地图位置由提交的门缝推导。
5. 产生含候选文件 SHA256、场景回读证明和候选内容版本的收据。未指定 `--write` 时正式源不变。
6. `--write` 再核来源哈希，逐文件以原子替换写入已经核对的候选字节，运行正式编译并比较内容版本。捕获的写入或编译错误会恢复所有已改文件的原字节，并重建派生包；恢复失败单独报告，不谎称源未变化。

接入工具没有重新实现世界编译规则，也不手工拼装 `.tscn`。文件发布采用逐文件替换和整组异常回滚，不是跨文件系统数据库事务。

## 支持范围与拒绝边界

| 编辑 | 精确行为与边界 |
| --- | --- |
| 平台、怪物、已登记机关及场景表现参数 | 传递共享 codec 的明确字段；保存后的同 codec 回读必须相等。未知节点、身份冲突或不支持的字段由 codec 拒绝 |
| 房形和已有门位 | 写入明确 `bounds/space_rects` 及完整门位、落脚合同；原编译器拒绝不一致的占地、接缝和回路 |
| 门位联动 | 门的 `position_candidate`、`landing_contract`、方向由包明确提供。`entry_spawns` 的出生点、最终站位、分区、落脚引用同步到同一显式合同；该门的来向恢复锚点使用显式安全站位；镜头区与入口连接保留主游戏现行配置，不再按每块房形生成镜头区。实际支撑平台必须已随 `rooms.properties` 提交，CLI 不替作者移动或猜测平台 |
| 连接条件及已有连接属性 | 更新已有稳定连接身份；`requires` 同步原编译器消费的 `effective_door_requires`。资格变化需要重编世界运行包，不能用旧包宣称条件已生效 |
| 连接端点、增加或删除门 | 当前明确拒绝。端点变化需要新门、来向恢复、分区路线等完整源合同；复杂拓扑继续由 AI 在现行世界源上成组编辑、编译并重新导出，不能只改网页线段 |
| 普通收集物跨房 | 包必须同时从旧房删除、向新房加入唯一同 `action_id` 的物理宿主，目标房、分区和坐标必须一致。CLI 同步永久动作、来源、宏观锚点绑定、房间奖励索引、收集设计及其房间索引，不自行搬节点 |
| 复杂奖励 | 能力、NPC、商店、独立返程闩等拒绝简化迁移。奖励身份、永久收据、领取资格和数量预算不能作为位置编辑修改 |
| 删除或复制唯一奖励宿主 | 即使奖励列表没有改，也会因宿主不唯一或缺失而拒绝，不能让列表和真实场景脱节 |
| 设计文字 | `challenge/discovery/return_route` 对应收集合同的明确文字字段。没有独立场景宿主的目标不能伪造坐标 |

候选编译通过和保存回读证明数据一致，不证明真实跳跃、战斗、初见可读性、艺术效果或完整区域体验。收据始终将 `actual_controller_playtest` 记录为 `false`；真实控制器与浏览器证据由该任务其它验证记录提供。未施工房间只有场景字节变化时，正式运行内容版本可以不变，场景来源哈希仍会记录该变化。

## 快速迭代与实际验证

版本身份与部署状态见[当前交接](scope.md)及实际在线版本接口，不在协议正文保存过去的发布流水和草稿修订。源码更新先生成同版seed／运行包，经原编译器、共享编解码器和真实装载器验证；采用更新必须读取当前草稿并执行三方比较，不因新包已发行就覆盖用户数据。

`tools/check_editor_protocol.py` 检查完整房间回读、真实App／隔离预览、原编译和旧工作台接入；`test_workbench_review.py`／`test_workbench_apply.py`检查范围、门缝、来源哈希、收集宿主及失败回滚。浏览器、具体动作、性能和真机按本轮实际写集另验。构建与数据检查不等于整段关卡体验通过。
