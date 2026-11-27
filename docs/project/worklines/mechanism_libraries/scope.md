# 基本机关与预组制作交接

PR #165 在 PR #163、#164 已合入的 main 上接入两份定稿。重做工程为 `production/`，交付分支为 `feat/basic-mechanism-library`，基线为 `2b8be9a9`。[逐件目录](../../../data/world_objects.md)列出全部 46 个基本件与 8 个预组，每个定义对应一页对象说明。[基本件合同](../../../data/失序之钟_基本机关库.md)和[预组合同](../../../data/失序之钟_预组与组合推荐.md)持有验收要求。

## 房间作者入口

在 Godot 4.7.2 打开 `production/project.godot`。机关库面板打开 schema 3 房间 JSON 后，可以按编号、中文名或定义 ID 找件，选模式、设参数，校验并预览后写入。单个成员可继续编辑，预组可整体移动、复制或解除分组。复制涉及外部世界行动时须指定新组要绑定的行动。命令行查询和 16 区域的可用范围见[机关目录](../../../data/world_objects.md)。

房间数据持有稳定 ID、版本、位置、成员参数与连线。运行时以同一目录检查区域、实例引用、带类型端口、分区和状态寿命。射击、交互、运动、战斗与世界行动复用普通房间中的正式消费者。以下独立场景在 Godot 里打开后可按 F6 试玩。它们位于测试目录，正式世界内容由房间设计工作线独立交付。

## 核对与复验

在仓库根目录运行 `python3 tools/check_ordinary_rooms.py`。它核对设计对照表与机器目录、逐文件说明及区域贴图，导入工程并运行下列真实 Godot 验证。单独复验可运行 `bash tools/godot.sh --headless --path production --fixed-fps 60 --script res://tests/脚本名.gd`。世界内容与经济回归入口为 `python3 tools/check_content_channel.py`。

| 实现范围 | 实际验证与可玩入口 |
| --- | --- |
| C01、C02、C15、G15 | 风铃实际中弹、一次与限时开门、防夹和过期释放。四个单向入口、延迟关闭，感应线的方向、端点、重复与重入。[风铃门](../../../../production/tests/bell_gate_demo.tscn) · [通过感应器](../../../../production/tests/crossing_sensor_demo.tscn) |
| C03、C16、G03、G12、G30、P01、P06 | 循环、两岸呼叫、驾驶、浮水载台；滑轨受击换站、配重、风车同轴、载人下沉与离台回升。路径、载荷、水面和时钟使用正式碰撞及输入。[载台脚本](../../../../production/tests/carrier_library.gd) · [试玩](../../../../production/tests/carrier_demo.tscn) |
| C04、C08、C09、C13、G16 | 齿轮直线及圆弧、捷径挡板和返程踏台、读牌关闭、行动宿主；一次开路三种终态的拒写回滚、重试、分区复位及载入。预组复制核对引用与行动归属。[集成脚本](../../../../production/tests/mechanism_integration.gd) |
| C05、C11、G01、G05、G06、G36 | 附着与伸缩刺、坍塌和恢复、顶面承压及重物资格、两路输出与关门防夹；局部护罩仅拦截关联危险实例。[危险与开关脚本](../../../../production/tests/hazard_library.gd) · [试玩](../../../../production/tests/hazard_library_demo.tscn) |
| C06、C07、C10、C12、G04、G07、G09、G22、G26、G29、G35 | 固定与移动钩点、弹射、传送带、运动表面、环境区、上升泡、成对传送及钩拉块；失败时按实际进入侧选择可站立恢复点，释放运动占用并按区复位。[穿越脚本](../../../../production/tests/traversal_library.gd) · [试玩](../../../../production/tests/traversal_mechanisms_demo.tscn) |
| C14 | 保存站的真实交互、恢复、休息、装配和读档在已有装备及普通房回归运行。[装备回归](../../../../production/tests/equipment.gd) |
| G02、G11、G13、G23、G24、G28、G32 | 分格破坏、爆炸、周期喷射／弹体、弹道减速、选择性屏障、格栅和动态反射。实际玩家与敌方弹体共用路径查询，覆盖薄几何、筛选、同帧接触顺序和存储失败重试。[弹道脚本](../../../../production/tests/projectile_library.gd) · [试玩](../../../../production/tests/projectile_library_demo.tscn) |
| G08、G10、G14、G20、G21、G31、P02、P04 | 转梁、落块、切换路线、冲压机、推箱及伸展台；双路、同步翻桥和顺序走廊验证预告、受阻、真实承载与状态恢复。[梁与路线脚本](../../../../production/tests/beam_library.gd) · [试玩](../../../../production/tests/beam_library_demo.tscn) |
| G17、G25、G27、G33、G34 | 声音调查、视线遮挡、固定灯与引路灯虫、受光开关、前景显露。从正式角色、怪物感知、光源与相机取样。[感知脚本](../../../../production/tests/perception_library.gd) · [试玩](../../../../production/tests/perception_demo.tscn) |

六个内部驱动各自有定义、运行组件与说明。配重及共轴驱动归载台回归，顺序波和路线切换归梁与路线回归，布尔条件与永久结果归集成回归。布尔组合以同次候选状态计算，G16 等待实体结果及世界行动成功提交后确认永久完成。演示和验证均可从本 PR 源码重跑。后续房间的实际接入与试玩入口见[普通房间工作线](../room_rebuild/scope.md)。

编辑器的检索、中文字段、模式、放置、重编成员、整组操作及并发写入保护由[作者侧栏回归](../../../../production/tests/mechanism_editor.gd)验证。独立录制时可用 Godot 的 Movie Maker，例如在有显示设备的环境运行下面的命令，可得到真实控制器乘坐配重台和风车的短片。

```sh
bash tools/godot.sh --path production --fixed-fps 60 --write-movie /tmp/carrier.avi --script res://tests/carrier_showcase.gd -- drives
```

## 美术快审

[美术快审](https://clockwork-mechanisms-pr165.zhipijun1996.chatgpt.site)提供两种实机视角。区域对照使用同一普通房、取景、输入和时间轴，可以暂停后切换任意区域，对比风铃、门框、支座、灯盘及转梁。11 段分类录像展示机关运动、攻击反馈、危险边缘及世界交互，其中[月冠古堡交互实录脚本](../../../../production/tests/mechanism_services_showcase.gd)用同一条连续路线走过恢复点、打开宝箱和捷径并到达充电站。房间使用正式实例；录制时按区域加载已登记的背景原图，位于 `art/world-art-v2/`。

从仓库根目录复验 16 区的区域解析、材质及射击开门，运行：

```sh
bash tools/godot.sh --headless --path production --fixed-fps 60 --script res://tests/regional_mechanism_art.gd
```

在有显示设备的环境下移除 `--headless`，加 `--resolution 960x540` 和用户参数 `-- capture=/绝对路径`，即可按区域输出 30 fps 的实机帧序列。每区 72 帧，第 20 个物理帧通过正式输入开枪。分类场景及独立玩法回归入口见上表。
