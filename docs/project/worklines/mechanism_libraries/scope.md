# 基本机关与预组制作交接

本批基于合入 PR #163、#164 后的 main `2b8be9a9`，分支 `feat/basic-mechanism-library`。行为定稿见[基本机关库](../../../data/失序之钟_基本机关库.md)，装配合同见[预组与组合推荐](../../../data/失序之钟_预组与组合推荐.md)。总范围 46 个基本定义、8 个预组及依赖的共用驱动。[游戏对象目录](../../../data/world_objects.md)只列实际可创建的定义。

| 条目或接口 | 本批交付与实机证据 |
| --- | --- |
| 区域范围 | 游戏目录、作者查询、创建与房间加载共享定义级 `usable_regions`。指定多区及组合的有效范围取交集；区域外观仍按单独区域配置读取。 |
| C01 射击风铃、C02 砌体机关门 | 验证 C15 所用的永久一次／临时限时信号、重复命中、延迟关闭、实际身体碰撞与存储恢复。风铃增加切换初态；门的房内单向模式待实现。 |
| C15 风铃与机关门 | once／timed 的开放参数、两成员位置和连线、原来源版本及场景往返。正式控制器射中风铃并穿过实体门，门中等待超过时限后离开，门关闭。[可运行场景](../../../../production/tests/bell_gate_demo.tscn) |
| G15 通过感应器 | 真实角色跨线驱动实体门，覆盖双向、两个单向、一次、切换、空中高速、端点之外、停在线上、重新定位及重入。[可运行场景](../../../../production/tests/crossing_sensor_demo.tscn) |

运行 `python3 tools/check_ordinary_rooms.py` 复验上述交互、普通房间和装备，`python3 tools/check_content_channel.py` 复验世界内容接入。两间演示可在 Godot 中单独打开运行，均使用正式角色与普通房间宿主。可在有显示设备的环境运行 `bash tools/godot.sh --path production --fixed-fps 60 --write-movie /tmp/bell.avi --script res://tests/bell_gate.gd` 录制实机过程；感应器验证脚本为 `res://tests/crossing_sensor.gd`。

后续先完成 C02 单向通行和 C03 载台各运动模式，复验其余已有定义，再按共用时钟、玩家运动、弹体类别与世界行动依赖接入剩余基本件和预组。目录中已有定义只说明可摆放；未经逐模式验证的条目保留待验。
