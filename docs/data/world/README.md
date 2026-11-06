# 固定世界输入与来源

当前唯一人工拓扑源：[world-room-layout-v04.json](import-v04/world-room-layout-v04.json)。它拥有房间、分区、连接、能力条件及永久事件身份；不得另抄一份到 config。当前是导入过渡期，游戏不直接加载本目录。

| 所有权 | 入口与生成关系 |
| --- | --- |
| 收集规则、装备来源映射 | [collection-catalog-v04.json](import-v04/design/collection-catalog-v04.json)，人工维护，以 action/stock/reward ID 引用世界；48件效果尚未选定 |
| 候选尺寸、门台、镜头、场景接口 | [逐房合同](import-v04/design/room-graybox-contracts-v04.json)，生成物；scene_ref 为计划路径，尚无对应 Godot 场景 |
| 合同生成 | import-v04/design/build_room_contracts_v04.py 仍读 v03 世界和合同；人工施工输入尚待提取，不能直接编辑派生合同后重建 |
| 路线输入 | import-v04/simulation/build_route_plans.py 仍读 source_inputs/route-plans-v03.json；下一阶段冻结现行路线为独立回归输入 |
| 一次迁移 | migrate_world_v04.py 会覆盖现行世界，只可在临时副本复现；不是日常构建 |
| 交接检查 | build_handoff.py 检查跨文件摘要、catalog 引用及与 v03 的 ID 集合相等，不会修复 catalog；长期应改为稳定身份迁移检查 |
| 图册与 QA | 静态图/图状态证据，不是引擎可玩证明；世界图坐标不能等比当碰撞坐标 |

原样导入轻量 ZIP 的52个文件，MANIFEST.json 是本包清单，MANIFEST.full-original.json 仅追溯。24个 PNG/SVG/PDF 预览刻意省略，重建方法见 [轻量说明](import-v04/README-LIGHTWEIGHT.txt)。原 CODEX_START_PROMPT.txt 仅为后续施工资料，本轮不执行。文件大小/SHA 校验用 `python3 tools/world/verify_import.py`；按房提取用 `python3 tools/world/room_context.py P-R03`，需要完整目标房合同加 `--contract`。不得全文加载大型 JSON。

原设计规则已按主题整合到 [设计圣经](../../bible/game_design.md)。确认程度仍分已确认、实施解释、试制默认/候选；附件原字节用于溯源及现行空间数据，不产生第二套正文。

MV-RUNTIME-01 先提取人工尺寸/门台/镜头/场景绑定输入，再证明合同重建等价，一次切换到 config/world/world.json、construction.json、collections.json；导入包届时退为档案。生成合同/运行数据进入 build/world，显式纳入运行包并查 PCK；不得覆盖手工房间场景。source_inputs 在脱钩前保留。map-edit/map-gen 不再是新世界运行依赖。

转型基线与未合入成果见 [唯一当前交接](../../project/worklines/mv_migration/scope.md)，[用户方案原件](metroidvania-migration-handoff.md)供追溯。

验证入口：`python3 tools/world/validate_routes.py` 在build/world/validation副本重新模拟A/B/C/D、运行反例审计并重建合同，比较语义等价；不运行migrate_world_v04.py、不覆盖导入源。Harness专项为`world-migration`与`world-routes`。当前导出preset排除docs/*，raw_exporter仅处理显式素材/旧敌人源，导入包不进入游戏；本轮仅核配置与插件，未声称完成新世界PCK验收。
