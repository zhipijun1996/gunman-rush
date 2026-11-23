# 公有及区域机关库交接

基于 main 的 `4d7dadd2`，分支为 `feat/regional-mechanism-libraries`。本次范围是普通房间的机关分类、实例化与区域外观。冻结工程和正式地图在各自工作线维护。

[机关目录](../../../data/world_objects.md)连接单项定义与对象页。[区域清单](../../../../production/config/world_elements/mechanisms/regions)持有各区专属定义和公有机关外观。schema 3 房间增加可选的 `root.properties.region_id`。作者查询、定义实例化、组合展开和房间装配共同使用这份登记。未指定区域的房间继续加载公有机关。越区引用在创建节点前返回错误。外观在绘制阶段解析，房间往返保存区域、实例配置和组合来源。

运行 `python3 tools/check_ordinary_rooms.py` 验证库归属、区域资源、跨区拒绝、场景往返、实际门体材质和钩点贴图，同时回归普通房间及装备。文档入口由 `python3 tools/check_docs.py` 检查。

后续从区域的目标动作和主题确定首项特色机关，按所属区域登记定义、对象页及对应验证，再由正式房间实例化。
