# 固定世界输入与来源

现行世界为 PR141 评论附件中的 **v07.1**：309 房、409 条现行连接（按已确认的平原调整从附件411条收敛），平原 P-R01—P-R35。旧 v04 地图退出生成、运行与现行设计；历史由 Git 保留。附件身份、哈希与原评论见 [provenance.json](../../../config/world/provenance.json)。

| 所有权 | 当前入口 |
| --- | --- |
| 房间、分区、连接、资格、永久动作身份 | [world.json](../../../config/world/world.json)，以最新 ZIP 主数据为基线，按用户确定的现行设计直接维护 |
| 施工尺寸、门位、来向落脚、镜头与场景绑定 | [construction.json](../../../config/world/construction.json)；实际碰撞和对象放置由各房 `.tscn` 持有 |
| 平原逐房用途与遭遇职责 | [room_design.json](../../../game/world/regions/P/room_design.json)，引用稳定房号和动作，不复制碰撞 |
| 森林整区与逐房候选 | [room_design.json](../../../game/world/regions/F/room_design.json)，现行24房/30区内连接/5跨区接口的待审占地与玩法；不自动替换施工源。审核页由 `tools/world/forest_review.py` 派生 |
| 星桥天门挑战灰盒职责 | [room_design.json](../../../game/world/regions/V/room_design.json)与[设计规范](../../bible/regions/starbridge_gate.md)，当前仅V-R12；真实几何仍归该房场景 |
| 收集系统与来源槽 | [collections.json](../../../config/world/collections.json)、[collection_design.json](../../../config/world/collection_design.json)；新版为 50 件装备来源槽，原包未提供全部最终效果、价格与平衡 |
| 已有试制服务 | [demo_services.json](../../../config/world/demo_services.json)，独立保留试制物品、委托、价格；不冒充完整 50 件装备 |
| 玩家参数与文本 | [player.json](../../../config/world/player.json)、[ui_texts.json](../../../config/world/ui_texts.json)；运动参数仍归共用 PlayerMotor 配置 |
| 世界路线回归输入 | [routes.json](../../../config/world/routes.json) |
| 附件设计参考 | `source-v07/design/` 仅保留未重复的世界设计参考；运行不读取，施工以本表现行源为准 |
| 编译与正式运行 | `python3 tools/world/build.py` → `build/world/contracts.json`、`runtime.json`；FixedWorldProvider 只读派生包并装载手工场景 |

平原35房使用已审核的真实占地与门位，按人工草稿初审逐房接入正式目录；当前源码与公开运行包的装载范围见[当前状态](../../project/current_state.md)。另按用户明确授权开放Z-R01钟心门厅，另按用户授权接入F-R01、C-R02、M-R02、S-R01、K-R01、N-R02、G-R02七间可往返的区域示例占位；只实现平原接近段与返回，其余266房保留接口，正式路径未声明可玩。Z-R01以既有C07正面入口接入正式游戏及工作台，与前庭采用显式遮挡切换及独立室内地图层；不开启其上层未施工出口。V-R12通过`config/workbench/rooms.json`明确登记为隔离审核灰盒，正式`implemented`仍为false；这不解锁V-R11/V-R13。示例房的后续出口使用连续实体边界；外区示例不冒充整区完成。C02由P27西口接C-R02，工城由P18下层东岸接G-R02，避免穿越平原其它房间。P03原两处下方外区口撤除并补平；C03改为P03左上钩索高洞口接M-R02下口，H门槛由房内高差、索点与侧壁荆棘实现，缺H可预览并退回。C04改为P20左下接S-R01上口，两侧保留基础动作可完成的安全返回。不能把309房合同的通过等同于309房实现。

地图接缝、房间形态与真实通行的要求统一见 [房间制作](../../bible/room_authoring.md)。正面建筑入口由construction门对的`front_door`显式标记：配对身份、资格与落脚仍校验，室内坐标层不强行与室外边缘拼接，也不在房界开假洞；普通侧门继续校验实际接缝。宏观图提供空间意图，施工门位、落脚和地图须共同校准；构建检查不能替代连续地区的实际体验审查。

按房查询：`python3 tools/world/room_context.py P-R15 --contract`。附件中的世界、收集与路线数据已融入本表现行文件。一次性导入器、旧地图快照、重复施工合同、模拟回放和过程报告已退役；原包通过来源评论和哈希追溯。后续直接维护现行源，不重新导入覆盖已确认的设计。

验证入口由 [模块导航](../../project/module_map.md) 和 `tools/harness.py --list` 查找。图路线只验证资格和状态；真实动作、所有来向落脚、Boss、保存恢复及原生画面分别验证。当前覆盖和未决内容只写 [本轮交接](../../project/worklines/plains_bible_v2_01/scope.md)，临时日志、截图及录像在 `build/`。
