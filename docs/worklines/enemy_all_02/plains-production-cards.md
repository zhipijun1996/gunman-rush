# ENEMY-ALL-02 平原身体制作卡

本卡记录本轮实现候选，采用现有 enemy-creator → art-director → animation-vfx 流程及E01–E12/G0–G5；不签画面、完整实录、声音、用户或设备通过。所有源SHA见[局部源合同](source-contract.json)，运行证据以root冻结commit后的实际影片与收据为准。

## 消费者与同体母版

平原7物种各有scene与Underworld两个宿主链；root_bell另有实际RootBellPresentation链，共15条平原宿主链。正式Underworld样式由原installer/metadata选择，不能以legacy镜头冒称正式身体。EnemyFeedback01的authored身体／留尸仍仅支持charger/diver，未扩大supports或改accepted计数。

冲锋／俯冲两个skin的live统一读 `EnemyFeedback01Frames.canonical_live_texture()/canonical_live_bounds()`，精确返回原 `texture(3)/bounds(3)`。原H0–3及D4–7共8个distinct像素、固定clip比例／锚点、Shader材质、尸体source接口不变；仅移除hurt退出时换回另一张小原图的身份跳变路径。受伤进入与退出沿同一个PlainsMotion02实例、真实当前位移与phase推进，不重启动作。此实现针对旧CHR-VIS-01故障，仍须新连续像素验证才能关闭问题。

其余live用原透明母版：Underworld的6张sprites原图、legacy meadow_actions的idle_a（地面甲虫／炮哨）及独立rootbell idle。动作来自母版内部关节；不靠全身体积缩放或两个全身PNG交叉淡化。原PNG／manifest／provenance未覆盖重写，不宣称重新生产了美术。

| 物种 | 原行为与本轮关节 | 移动／hurt恢复／终态 |
| --- | --- | --- |
| patrol_drone / graybox_patrol_drone | 真实巡逻接触，无虚构远程攻击；原甲壳刚性，底部前后足错相、顶触角独立摆动 | 实位移驱动足相；当前sample受伤衰减到当时巡逻，不冻结AI；保原死亡图／淡出政策 |
| plains_charger | idle→telegraph→attack→recovery；足肢错相、壳体绕髋承压、头／角绕颈独立蓄势及前送 | 两skin均H3同体母版；hurt0–3仍被读取，末H3→live保持source/bounds；D4–7及原支持面／持久尸体／保存／静态恢复所有者不变 |
| plains_diver | 真实环飞、锁定俯冲目标、attack与原物理回返；Underworld背翼扇绕翼根，铃腹独立滞后；legacy叶转子绕冠中轴、下铃腿滞后 | 透明H3及固定世界锚，连续悬浮bob；hurt进入／退出继续当时飞行相位；原D4–7、尸体支撑／落地和保存政策不改 |
| plains_hopper | 真实锁定抛物跃击；后髋／大腿先收，实际attack相位释放，当前recovery收势 | 原母版不按相位换身份；原Motor/落点/碰撞不搬；当前hurt只作用局部肢体；保原退场政策 |
| plains_sentry | 根脚承重；颈／腔蓄势，真实attack相位炮管回缩 | 原弹体origin、locked_direction与射线预警独立；hurt后返回当前蓄势／发射／恢复，保原终态 |
| plains_fan_sentry | 与sentry同炮哨母版，增加蓄势期炮颈小幅扫开与释放反摆；不新增炮口或三弹规则 | 三角度弹体仍由原行为决定，身体扫摆不改射线／伤害；保原终态 |
| plains_root_bell | Underworld原root_bell图／legacy原宿主体及独立RootBellPresentation原idle母版；根脚固定，主茎由根部弯、两侧枝按蓄势／pulse释放分别反摆 | pulse真实脚／宽高及原地面预警独立；被接受命中取消预警仍由原行为负责；原死亡图／0.8s独立链alpha或原宿主退场，不强制新增尸体 |

## 连续性、事件及技术边界

PlainsMotion02在完整纹理上建立8×8共享顶点UV网格（81顶点／128三角），单次draw_mesh；首次或authored cell切换重建surface，其他帧只更新顶点。UV显式映射到原Atlas底图，固定源比例与已测alpha>16身体范围。相邻三角共用顶点，避免独立裁片缝口；关节权重和弯曲是否自然仍需实机审查，不能以网格存在签同体动作完成。

步相按实际位移×TAU/20推进；单帧≥48wu的恢复／传送跳量不积步，停步travel按0.07s衰减。telegraph/attack/recovery读取原state_time和Definition时长，关节目标按0.045s收放。它们只改绘制顶点，不延长攻击、不延迟伤害、不加stagger或root motion。

accepted sample仍由原健康事件驱动，body.source/destination等旧验证表面保持。非致死recoil按原hurt_remaining衰减，返回**当前实际phase**；terminal关闭live关节循环，保原死亡／尸体所有者。各Presentation暂停显式返回；epoch变化清关节、步相和位置历史，恢复terminal不播放live循环。body child只画身体，父层HP／警告与子粒子仍各自绘制。

当前没有为转向新增玩法状态或改brain.direction；身体镜像仍读原方向。真实左右转身、墙边脚点、连续命中、慢时、暂停、同实例恢复和卸载需在新源审查。动态ArrayMesh兼容性、采样边缘及多怪帧时必须由实际Godot／目标设备测量；本卡不以静态检查替代。

## 原回归与待看片段

保留原native／formal／support／corpse-save／snapshot检查和预算、原H0–3/D4–7 distinct像素断言、真实HP提交、重复event／旧epoch拒绝、support释放／静态恢复。新增全怪实录不冒充这些原checks已经通过。

优先看片：charger移动或attack→hurt0–3→真实当前动作，尤其旧94→95/143→144对应的退出边界；diver真实attack而非仅telegraph取消；hopper承重／离地／落点；两炮哨发射与预警坐标；rootbell独立链pulse真实脚。每链需实际非致死恢复、死亡和原终态尾段，缺口明确记unverified。声音沿原唯一事件和当前选声，本卡不签听感。

E01/E02/E09沿原权威与准入；E03/E04/E05/E07为实现候选，E06/E08沿原反馈并待新源回归，E10仅静态无新事件订阅／Timer／节点持有，E11/E12帧时、实体设备、玩家与用户审核均未验。影片实际完整性、正式遭遇与导演连续性分别记录，不将本制作卡标done。
