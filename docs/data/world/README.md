# 固定世界输入与来源

现行世界为 PR141 评论附件中的 **v07.1**：309 房、411 条连接，平原 P-R01—P-R35。旧 v04 地图退出生成、运行与现行设计；历史由 Git 保留。附件身份、哈希与原评论见 [provenance.json](../../../config/world/provenance.json)。

| 所有权 | 当前入口 |
| --- | --- |
| 房间、分区、连接、资格、永久动作身份 | [world.json](../../../config/world/world.json)，与最新 ZIP 主数据一致 |
| 施工尺寸、门位、来向落脚、镜头与场景绑定 | [construction.json](../../../config/world/construction.json)；实际碰撞和对象放置由各房 `.tscn` 持有 |
| 平原逐房用途与遭遇职责 | [room_design.json](../../../game/world/regions/P/room_design.json)，引用稳定房号和动作，不复制碰撞 |
| 收集系统与来源槽 | [collections.json](../../../config/world/collections.json)、[collection_design.json](../../../config/world/collection_design.json)；新版为 50 件装备来源槽，原包未提供全部最终效果、价格与平衡 |
| 已有试制服务 | [demo_services.json](../../../config/world/demo_services.json)，独立保留试制物品、委托、价格；不冒充完整 50 件装备 |
| 玩家参数与文本 | [player.json](../../../config/world/player.json)、[ui_texts.json](../../../config/world/ui_texts.json)；运动参数仍归共用 PlayerMotor 配置 |
| 世界路线回归输入 | [routes.json](../../../config/world/routes.json) |
| 冻结附件资料 | [source-v07](source-v07/README_LIGHT.txt)，只供设计与来源查询，运行不读取此目录 |
| 编译与正式运行 | `python3 tools/world/build.py` → `build/world/contracts.json`、`runtime.json`；FixedWorldProvider 只读派生包并装载手工场景 |

平原 35 房已绑定正式场景；其它 274 房保留接口，未声明可玩。外区未施工入口使用连续实体边界。不能把 309 房合同的通过等同于 309 房实现。

地图保留房间的真实尺寸和局部玩家坐标，以施工 `map_origin` 表达最新宏观图的相对位置；连接线从成对实体门口出发。它是有明确过房连接的区域示意图，不宣称所有矩形共享无缝边界。构建拒绝房形重叠、同边拥挤出口、断开的施工图与错误配对；宏观 polygon 不作碰撞。

按房查询：`python3 tools/world/room_context.py P-R15 --contract`。`tools/world/import_v07.py` 是一次性迁移工具，导入前核 ZIP 清单，现行编辑不再次覆盖施工。原始附件的手册、地图及复现资料被冻结保存，不产生第二套可编辑拓扑。

验证入口由 [模块导航](../../project/module_map.md) 和 `tools/harness.py --list` 查找。图路线只验证资格和状态；真实动作、所有来向落脚、Boss、保存恢复及原生画面分别验证。当前覆盖和未决内容只写 [本轮交接](../../project/worklines/plains_bible_v2_01/scope.md)，临时日志、截图及录像在 `build/plains_v07/`。
