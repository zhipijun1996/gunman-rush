# 地区数量设计契约迁移

本次仅迁移设计 JSON 与文档校验。最新 [地区 V0.3 §0.1](../design/player_actions/regions_v0.3.md) 和本轮用户指令明确：**16 个地区组成候选池，一局依 S1–S6 选择 6 个地区**。框架已确认，具体新增连边、机关、数值和美术仍按原候选状态；正式运行仍只有平原两张地图。

| 旧字段 | 新语义 |
| --- | --- |
| `design_contract.formal_run.biome_count=6` | 删除歧义字段；`formal_run.regions_per_run=6`，`world_design.region_pool_count=16`，`world_design.stage_count=6`。 |
| `world_regions.formal_region_count=6` | 删除歧义字段；`region_pool_count=16`、`regions_per_run=6`。 |
| 旧总共六地区计划 | 两份 JSON 的 `legacy_total_region_plan` 保留旧值、已被覆盖的状态及迁移前整文件 SHA256；不再决定当前数量。 |

两文件共享 `regions_v0.3` 版本、路径、SHA 与 §0.1 来源。`framework_status=confirmed` 只确认阶段/地区池框架；目录 `world_plan_status=tentative` 继续约束具体候选连边/内容。旧 `proposed_layer_count` / `proposed_region_pool_count` 是既有目录兼容字段，校验必须同时满足 6/16，不能让它们覆盖新的明确语义。

`tools/check_world_design.py` 同时验证实际 16 条唯一记录、权威矩阵名称/阶段、每局 6 阶段和 `implemented_regions=[plains]`；`tools/check_docs.py` 同步使用新语义。原导入附件 Hash、29 条候选连接、两张地图、阶段类型、开发流程边界和未实现地区防开放检查保留。反例覆盖六地区旧总量、虚报目录数量、每局十六阶段、未来地区开放、旧歧义字段、历史丢失、权威 Hash 修改及跨层连接。

```bash
python3 -m unittest discover -s tests -p 'test_world_design.py'
python3 tools/check_world_design.py
python3 tools/check_docs.py
python3 tools/level_region_context.py --region thorn_forest --output build/level_design_v2/forest_context.json
```

源码搜索未找到 `scripts/` 或 `config/` 读取这两个设计 JSON 或旧 `biome_count`。已知消费者为文档校验和离线地区输入，不改变 PlayerMotor、能力授予、正式生成器、RunManifest 或保存格式。森林输入重新提取最新 JSON SHA，继续保持 H 单能力与正式未开放，不能从 Studio 的 H/W/D 授予推断森林合法能力。

历史 `docs/evidence/delivery_efficiency/` 中有旧文件源 SHA 与 diff，`DELIVERY-EFFICIENCY-01` 的文件清单也引用设计合同。它们属于原执行证据，本次不修改、重签或伪装成新源验证。需要重放旧记录时取原提交文件或归档原件；新设计使用新的执行结果。
