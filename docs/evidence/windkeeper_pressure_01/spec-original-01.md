# WINDKEEPER-PRESSURE-01：牧风者主动追压

用户2026-10-30明确要求：保留三阶段/当前体型/旧黄铜、苔绿、褪帆与暖钟芯，60HP；主动接近、六种全身动作、按距离/高差/近期招式加权且组前冻结的一至三招组合；组内保持进攻张力，整组最终恢复提供稳健两枪及撤离、贪第三枪自然挤占余量。速度首轮240/420/260/地波300，起手0.5–0.7秒、衔接0.2–0.35秒；大扫/踏台允许更充分预警。短扑锁方向、踏台锁真实平台，基础移动有退路；伤害/动作共姿态，普通命中不重置招式，致死立即止伤/止风，失力落位后金币喷到可达平台。

六招：重踏（单/双足提前分辨）、低身短扑（真实起落/落地承重）、风叶横扫（肩背侧转/高低预告）、展帆风压（方向风与帆/环境一致）、仰首三枚扇形风籽、三阶段抬肢踏台（真实伸向锁定平台）。阶段一重踏/短扑/风籽单/双；二双连加入风压/横扫；三断桥后两至三招追压真实落脚点，不固定顺序桥墩巡回。最多三次主攻，恢复不补发新弹。

正式消费者为BossFactory windkeeper_storm、PlainsRegionStage地图二；历史WindkeeperEncounter/旧Lab与鸣铃巡游机保持原机制。采用新WindkeeperPressureEncounter子类/独立场景，以父契约兼容App、WindkeeperArena、保存、HUD与一次奖励。共享玩家Motor/武器/资源/概率掉落/BGM不改，不将先前PR119合main授权外推。

采用boss-creator、animation-vfx、audio-director、game-quality-gate；沿原G0–G5/十一维，不另造验收体系。用户设计已授权制作，不重新要求选方向。读取当前Bible/共享画风；独立G0核公平、消费者和动作共锚，源码冻结后真实专项与独立实片审查。原失败/预算/断言保留。实际完整连续带原声战斗需展示站桩追压、六招、两/三连最终恢复、三阶段及两枪/贪第三枪对照；受控分阶段片不替代完整自然战斗，AI不签用户/设备。

文件所有者：root负责BossFactory/正式scene/App/Stage/HUD/奖励、任务/质量/最终验证/发布；combat负责新Encounter/Definition/攻击实体；art负责新Rig/Presentation；audio负责新Audio及自有资产/音频测试；capture负责录制driver/合法输入pilot，root独占Godot/GL；test负责专项独立测试；binding/reviewer只读G0/最终独审及当前Bible绑定元数据，不改已审生产。

协作接口：Encounter继承WindkeeperEncounter，signal presentation_event(row: Dictionary)。mode统一intro/observe/approach/turn、stomp_warning/stomp、lunge_warning/lunge、sweep_warning/sweep、gust_warning/gust、seeds_warning/seeds、platform_warning/platform、link/recover、phase_transition/dead。rig_pose()为唯一姿态入口，调用WindkeeperPressureRig.sample(data)，返回body_transform/head_transform/core_transform、hips/knees/feet四足local Vector2数组、blade_start/blade_end、sail_open、bell_swing；投射/横扫/足击与绘制读同一姿态，渲染不推进战斗。数据包含mode/phase/direction/state_age/state_duration/fight_age/travel/speed/group_remaining/group_total/attack_target_local/sweep_high/death_age/击伤age。presentation_state/core/intro保父接口；combat_metrics()、combat_snapshot()/restore、_event_history用于只读录片。
