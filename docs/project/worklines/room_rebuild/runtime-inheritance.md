# 旧 demo 与新世界的默认入口

对照冻结平原根工程和重做版 `production/project.godot`。使用同一 Godot 4.7.2、1280×720 逻辑视口与独立空存档，分别启动各自配置的主场景，查看实际场景树和玩家能操作的界面。另行核对物理房间中的观察输入。桌面引擎的横屏触控布局用于画面对照，Android 真机显示和物理手柄需分别验收。

| 体验 | 冻结平原 | 新世界与核对依据 |
| --- | --- | --- |
| 标题与存档 | 标题插画、Logo、新游戏、继续、设定、操作说明、逐房试玩 | 新档直接到 P01，续读和重开确认已经接入独立存档。标题和 Logo 尚未挂载。[旧标题](../../../../game/presentation/ui/world/world_title.gd) · [新入口](../../../../production/rooms/world/world_game_host.gd) · [存档](../../../../production/game/platform/persistence/playable_world_save.gd) |
| 游玩 UI | HUD 绑定玩家状态，带小地图、互动提示、通用暂停菜单 | 已有触控、房名、区域地图、装备和场景互动面板。旧常驻 HUD 与通用暂停页尚未挂载，Esc 进入装备面板。[旧 HUD 宿主](../../../../game/presentation/ui/world/world_ui.gd) · [装备面板](../../../../production/game/equipment/equipment_menu.gd) · [区域地图](../../../../production/rooms/world/world_map.gd) |
| 设置、输入及声音 | 独立保存音量、减效与输入偏好；手柄、操作说明、标题与区域音乐有真实消费者 | 新房已挂键鼠、横屏触控、射击与受击音效；玩家设置页、手柄适配器及旧配乐调度尚未接入。[旧设置](../../../../game/platform/settings/world_settings.gd) · [旧手柄接线](../../../../game/platform/input/input_setup.gd) · [新输入](../../../../production/game/platform/input/room_touch_controls.gd) |
| 动作、战斗和恢复 | 玩家运动、反冲、受击判定、治疗、伤害和资源各有独立实现 | 普通房实例化玩家并挂载伤害策略、治疗、声音和能力同步。复活和进度持久化通过真实跨房、独立进程读档检查。[普通房会话](../../../../production/rooms/ordinary_room_session.gd) · [存档回归](../../../../production/tests/world_persistence.gd) |
| 镜头与跨房 | WorldCamera 读取玩家、参数与当前房间，负责死区跟随、前瞻、上下观察、区域缩放和遮挡 | 首轮核查时使用玩家子节点 Camera2D，固定缩放 1.40；P02 和 P03 有各自构图。旧版 WorldCamera 与分区脚本已在生产目录，未接入时 G12 的上观察输入轴为 −1，40 帧后屏心垂直位移仍为 0。正式门线、黑幕、接收端落稳已有实际跨房验证。[旧镜头](../../../../game/presentation/ui/world/world_camera.gd) · [新宿主](../../../../production/rooms/world/world_game_host.gd) · [接收端物理验证](../../../../production/rooms/world/world_passage.gd) |

冻结版 P-R23 作为观察对照。在可操作的稳定平台按住上看，角色位置不变，40 帧后镜头中心上移 68.74 世界单位，90 帧后上移 86.77。松开 90 帧后与起点的垂直误差为 0.32。正式新房沿用当前世界包的房号、门向和空间，旧房坐标与审核入口保留在冻结工程。
