# D071 连续草坡、根系与荆棘基底

上位权威为[牧风者与首区迭代](windkeeper_plains_iteration.md)，视觉锚点为用户风格板第一格；本次只改表现，不改角色、碰撞、危险体积、通道、端口或随机抽样。

## 实际表现消费者

`PlainsTerrainSkin`继续将草坡实体与`PlainsGroundSupports`真实岩体按同一世界坐标采样，跨模块不重开岩石贴图；悬空实体保持明确木架，单向台保持薄木板。

新原创透明素材`assets/plains_v4/ground/soil_root_bands.png`增加两种浅层材质：土壤/根系与荆棘根床。原始RGBA与SHA保留，压缩只在Godot导入缓存。素材仅是美术候选，不冒称用户已认可。

草坡：已有花草草缘→不规则棕土、常春藤和垂根→原有厚石灰岩支撑。根系固定0.17倍比例，仅裁切至原始实体平台厚度；不再用一排石砖作为土壤过渡，不把根系当额外墙体。同高接缝仍只绘一遍草缘和根系，横向纹理以世界坐标连续采样。

荆棘：危险尖端继续使用既有保守危险矩形；根床只覆盖既有危险底部最多12单位。危险下方最多18单位的根床必须落在实际实体平台内，坑底无实体则不画虚假土层或桥。单向台不提供实体根床，空隙不被装饰连接。根床的少量短刺裁切于已有危险或真实实体内部，不能扩大危险。

此实现不会凭视觉补齐旧模块中实际没有地面的危险坑；后续若要改变坑底实体结构，须作为版本化关卡几何任务另行验证，不能伪装成美术补丁。

## 技术证据与未验证

Godot 4.7.2 Standard实际运行：

- `timeout 90 bash tools/godot.sh --headless --path . --script tests/plains_terrain_cohesion_runner.gd`：735断言，0失败，退出0。
- 同命令添加`-- --prove-failure`：736断言，1个刻意失败，退出1。
- `tests/plains_ground_support_runner.gd`：474断言，0失败，12个正式生成房间186根实体支撑，退出0。
- `docs/archive/retired_eight/tests/plains_v3_runner.gd`：456断言，0失败，退出0。
- `python3 tools/check_plains_ground_art.py`：原图SHA、RGBA、透明边界、浅层比例、区域与导入检查通过。

日志位于`build/verification/d071/terrain/`。技术测试确认材质裁切、源区域、同世界坐标接缝及原有实体语义，不能替代实际合屏截图或手机审美/辨识验收。最终合屏检查由本轮主任务记录，Android/iPhone真机仍独立待验。

## 浮点分块回归修复

整套核心回归曾两次在`random_preview_tests`实际绘图过程中OOM被SIGKILL。原因是原有横向切片循环以`fposmod`求剩余块宽，在浮点块边界得到小于坐标精度的正数，`x += width`不再推进，仍不断追加字典。

`clipped_strip_pieces`现按有限整数块索引枚举，再与目标范围相交；`ground_edge_pieces`复用同一切片方式。没有用提前break漏画末块。新增真实`preview-contract-proof` manifest全部草缘、土根、岩层与荆棘基底的有限数量/非零宽/完整覆盖检查，并实际执行Canvas绘图；负坐标与非整数块边界同样覆盖。30秒timeout命令在1秒内完成，735/0；失败探针736/1退出1。修复日志`cohesion-bounded-tiles.log`和`cohesion-bounded-failure-probe.log`，OOM历史由整体交接保留。
