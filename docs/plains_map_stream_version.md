# 平原地图随机流与Boss版本分离

[首区与牧风者迭代](windkeeper_plains_iteration.md)的正式Stage版本为`plains-run-v9-windkeeper`。它代表新的Boss消费者及正式运行契约，不应仅因替换Boss就重新抽取已验证的非Boss地图。

`PlainsStageGenerator.MAP_STREAM_VERSION`独立固定为`plains-run-v8-visible-windchime-recoil`；只用于`RunRandomStream(root_seed, "map", stage_id, MAP_STREAM_VERSION)`。因此同一根Seed与关号保持原来的地图派生Seed，路线、奖励与商店随机流仍各自分离。日后地图抽样本身不兼容变化才有理由升级该版本，不能为使回归通过随意改Seed。

完整生成Manifest记录`map_stream_version`，严格验证当前版本；即使修改后重算manifest_hash，缺失或伪造该字段仍拒绝。StageGenerator正式VERSION继续v9，RunManifest外层仍校验正式消费者版本，未以旧版本冒充新Boss。

原`density-passage-3`、第2金币房的低顶荆棘回归保持原坐标`Rect2(4910,-205,630,35)`及候选敌人`Vector2(5300,-68)`。地面跳跃包络必须因头顶荆棘得到`dodge_hazard`，不能实例化该不安全敌人。测试没有删除危险、挪动角色或放宽跳跃标准。

实际命令与日志：`timeout 120 bash tools/godot.sh --headless --path . --script docs/archive/retired_eight/tests/plains_encounter_density_runner.gd`，`build/verification/d071/terrain/density-map-stream-final.log`。补充契约覆盖独立Stage/map版本、精确原始Seed派生、篡改并重hash拒绝、缺失版本拒绝及JSON重放验证。最终数值由本轮交接记录；技术通过不代表真机趣味性验收。
