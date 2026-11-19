# Gunman Rush 开发入口

重做游戏的工程根目录是 `production/`。在这里打开 Godot 4.7.2，所有 `res://` 路径都相对这个目录。仓库顶层的 Godot 工程用于复玩冻结平原。两个工程有各自的资源扫描范围和用户数据目录。

1. 读[当前状态](docs/project/current_state.md)、[任务表](docs/project/tasks.md)对应行及其 `docs/project/worklines/` 交接。
2. 普通房间按[房间制作](docs/bible/room_authoring.md)和[机关目录](docs/data/world_objects.md)组装。新房的几何、起点、物种和实例连线由新房数据给出。
3. 按[模块导航](docs/project/module_map.md)修改真正消费内容的代码和资源。玩家运动归 PlayerMotor，伤害、掉落和存档由对应系统提交，特效只观察已接受事件。
4. 在仓库根目录运行 `python3 tools/check_ordinary_rooms.py`。冻结试玩的检查单独运行 `python3 tools/ci.py`。文档链接运行 `python3 tools/check_docs.py`。

## 设计与交付

以最终交付件维护正文、Definition 与消费者。同一数字只在实际配置里定义；行为说明写触发、可见结果、反制、恢复和状态归属。修改机关时同步其独立定义、行为合同、对象页和适用验证。任务进度由任务表持有，工作线保存结果与下一步。

保留实际控制器验证、几何与外观分工、稳定实例 ID、带类型端口、同次状态提交和事件驱动视听。旧世界输入、逐房指标、工作台评分、实验场景与旧排期随平原归档。历史材料只在复现冻结版时加载。跨会话分支和发布操作见[协作规则](docs/project/cloud_production.md)。
