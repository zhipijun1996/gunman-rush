# ENEMY-ALL-02 森林身体制作卡

本卡补原[森林生态设计](../../design/forest_enemy_ecology_v2.md)、[森林反馈生态](../../design/forest_feedback_ecology.md)及[Forest Depth v2](../../design/forest_depth_v2/README.md)的开发实现事实。采用 enemy-creator → art-director → animation-vfx 顺序，E01–E12/G0–G5口径不变。状态为 **REVIEW**：本轮实现与基本链真实Godot实录已交付，根代理实跑及独立像素审查见末尾当前结果；音频听感、设备或用户审美未签。

## 真实消费者与身体

七种 `scenes/enemies/forest_*.tscn` 的 `Presentation` 委托 `ForestBibleActors.draw_enemy_body`；最终显示须由正式森林stage的 `forest_bible_actor_art` metadata 开启。只改备用几何无法改变该身体。新 `ForestMotion02` 由四个正式森林Presentation安装。独审R1发现原矩形切片会拉断不透明接边，故改成完整原PNG的16×16连续UV网格（289共享顶点、512三角形、一次draw_mesh），原相位／pivot调度保留，跨关节6sourcepx平滑权重归一，脚／荚柄独立锁定；helper Boss分支原字节保留。

森林七种PNG均复用当前源，原同体材质／nearest／world尺寸沿用；两个候选的新透明母版另见下文。初版失败源清单保存在 [forest-source.json](forest-source.json)，当前明确修因与源闭包见 [source-contract.json](source-contract.json)。离线三角包络诊断见 [forest-mesh-diagnostics.json](forest-mesh-diagnostics.json)，它不替代实际GPU、遮挡及脚点审查。初始化信号会在暂停时立即同步epoch／朝向／关节／settled终态，不等下一process；卸载显式断连。原生反例为 `tests/enemy_all_02_motion_lifecycle.gd`，实际执行结果由root证据单列。

| 物种 | 真实源/原相位 | 本轮身体实现 | 锚与终态 |
|---|---|---|---|
| forest_lantern | fine_32/lantern.png；dwell→telegraph→travel→dwell | 胸部/灯腹/双翼分别铰接；停驻14rad/s翼摆，移动19rad/s翼摆；蓄势拢翼、移动灯腹反摆、受伤翼收、致死翼下垂 | 原36×30身体和24×24碰撞；灯腹中心不搬Actor；0.38s后保原暗色终态 |
| forest_seed_sentry | fine_32/seed_sentry.png；idle→telegraph→attack→recovery | 根座固定；冠/种腔分别蓄势和反向释放；恢复向当前相位收回；受伤关节折回，死亡冠/腔枯折 | 原33×39/30×36；根座及真实弹体origin/落点保持；保原暗色终态 |
| forest_bark_beetle | fine_32/beetle.png；idle patrol→telegraph→attack→recovery | 三组原图腿条按Motor真实位移交替；甲壳与头部独立小角度承压/出击；受伤头缩、死亡腿卷 | 原36×24；盾接触仍唯一ForestBarkDamageable事件；0.38s收束后原隐藏终态 |
| forest_swing_pod | fine_32/swing_pod.png；swing↔turn；blocked | 顶盖固定，下面荚体按真实x速度滞后；转端收紧，受伤围绕顶点，死亡荚身弯垂 | 原27×33/26×30；HitPose围绕tether(0,-13)，真实host/root metadata与绳端不搬；0.38s后原隐藏 |
| forest_crossbranch | fine_32/crossbranch.png；rest→telegraph→flight→settle→rest及真实失败跌落 | 两侧枝肢蓄势/飞行收肢、中央头节独立，落地后随真实phase展开；受伤枝肢收，死亡折枝 | 原36×36/28×32；中央根脚固定，落点/flight/支撑不改；0.38s后原隐藏 |
| forest_thread_spider | native/weaver_silk_bell_v5.png；idle→telegraph→extend→hold→retract→recovery | 原身体中央腹与左右腿扇分开；蓄丝外撑、extend收送、hold保持张力、retract/recovery退回；受伤收腿、死亡卷腿 | 原32×32/26×28；真实有限线的端点/宽度/激活时钟保持；保原暗色终态 |
| forest_bible_weaver | 同一当前正式silk-bell源；同样有限线相位，交替双入口 | 腿扇张力幅度与腹反摆区分旧单线蛛；读真实当前strand的既有相位，未复制玩法 | 原体积/双入口线锚不改；保原暗色终态 |

## 过渡、接受事件与生命周期

- 移动脚相 `stride += 实际位移*0.32`，忽略单帧≥32wu恢复/传送跳量；不以墙钟让停住的甲虫走路。
- 身体转向0.12s侧转，行为/盾方向/预警仍保真实已提交方向。蓄势、释放和空中姿态用0.065s指数收放，只读真实behavior.state。没有移动Actor、延长攻击、延迟伤害或新增stagger。
- HitTemplate仍是唯一accepted反馈消费者；非致死hurt沿原sample姿态衰减，各关节同时反应；hurt退出自然回到**当时实际phase**，不重启攻击。终态覆盖hurt，不叠第二接受/音效事件。
- epoch变化清掉关节/步相/旧位置；已恢复terminal直接终态，不播死亡。首次process前致死用已有sample.restored_terminal辨别真实致死，避免误当恢复。
- 四Presentation显式暂停不推进本地钟。无新Timer、Signal、粒子、音频、节点回调或持久尸体。原先隐藏的3种只增加0.38s同体局部收束；原保留暗色终态的4种继续保留。Stage、save、清理和掉落所有者未变。
- helper每次部件绘制完成重置DrawTransform，危险线/瞄准/护盾/落点在原坐标绘制。悬荚盖及绳端在hurt变形中仍以(0,-13)为固定点。

## 两开发候选

初版审计：原 `guard_moth.png` 是1536×1024双排6姿态且包含不透明棕黑背景，姿态间身体比例/足点不稳定；仅消除交叉叠加重影仍不足E03，故继续返工。

返工结果：根代理按逐字指令真实调用imagegen两轮，原输出与拒绝原因均保留。新 `assets/enemy_all_02/prototype_sheet.png` 保持2172×724 RGBA原字节；只采用manifest审计的两个中性母版，未采用比例不稳定的其余姿态。guard可见高度45wu、moth47wu，分别用固定比例和脚／悬浮锚。实际presenter使用一个6×8动态ArrayMesh（63共享顶点、96三角形、一次draw_mesh），真实位移驱动腿步，甲壳／盾叶／翅根／腹／触角分别关节化；真实phase平滑收放，accepted受伤退出回当时状态，死亡按原0.6s淡出，暂停不推进。没有12帧完成或正式入池声明，两者保持开发候选。E03／E04／E05／E07仍待新源实机与独审，不以生成PNG代替动作审查。

## root单引擎采证与失败条件

本代理执行 `git diff --check` 成功，没有运行引擎。以下是待执行案例，不是结果：

1. 先正常速度合屏看灯翼/甲腿/悬荚柄；再放大逐帧，切片缝口、身体断裂、腿穿支撑或灯翼中心漂移即REWORK。实际metadata不成立导致备用几何不可作本体证据。
2. 七物种分别当前移动/停驻→真实接受受伤→恢复到实际phase；在telegraph、attack/extend/hold/flight、recovery再各命中。受伤不冻结AI、不重头播放phase、被拒盾击不显示hurt。
3. 同epoch连续接受、重复event_id拒绝、致死覆盖hurt；死亡0.38s→原终态，恢复terminal不重播。检查甲虫盾面在侧转0.12s内是否仍读得清，必要时缩短侧转或保留盾锚覆盖。
4. 悬荚摆端/高速时受伤，看真实root→(0,-13)及荚盖是否连通；crossbranch上/下岸飞行及blocked后的真实恢复，落点/触地不受身体变换影响。
5. pause/resume、慢时、同实例health.initialize、切区恢复terminal、卸载重进；无旧epoch姿态残留或死亡重播。原唯一音频沿真实接受事件实听；有声轨不代签听感。

E01/E02/E09原机制和准入按原证据，不升签；E03/E04/E05/E07本轮实现候选，E06/E08沿原accepted实现且待新源回归；E10只静态无新生命周期对象；E11/E12性能/设备/玩家与用户实机视频审查待root集中采证。不能以本表代替录像或独审。

## 本轮采证与完成口径（2026-10-29，当前）

本段覆盖上文制作阶段的“root仍需执行／静态未验”描述。当前为 **review：制作与基本链采证已交付，等用户审核**；不签done或G5。当前运行实现源为`d91b27377c88e039560140deb87e0a67052a716b`，旧片保留94／b71实际来源；森林荚帽绳端与保守屏外裁剪后已按d91重录7种。逐链时间、真实phase／HP和终态见[采证矩阵](completion_matrix.md)及[影片索引](../../evidence/enemy_all_02/README.md)。

| 标准 | 本轮实际结果／保留边界 |
| --- | --- |
| E01／E02 身份、母版与准入 | 复用既有物种家族，实际消费者逐链分列；2候选仅开发、旧/正式Definition分列，不扩大随机池 |
| E03／E04 身体与动作 | 每例真实AI承诺及同体动作有连续影片；独审R1/R2返工、R3限定接受，R4绑定d91；不穷尽所有招式变体 |
| E05 受伤与恢复 | 每例真实非致死HP提交后观察恢复；charger/diver的H3→live同母版，旧CHR-VIS-01历史失败原件不改 |
| E06 反馈 | 仍由accepted事件驱动，警告／功能胸心／HP独立；原引擎音轨与PCM保留，听感未签 |
| E07 死亡与原终态 | 各例致死及至少210帧终态；charger/diver另精确settled后210帧×4链；其他保原隐藏／暗色／Boss政策 |
| E08／E09 权威与消费 | 真实Router、AI、发射物、双方伤害；实验台与实际App分列，不写玩法权威、不代签自然全campaign |
| E10 生命周期 | d91原生90／708／209及hit-template426均0失败，暂停／epoch／终态恢复／卸载断连反例；原b71的五套反馈／保存检查另保实际来源 |
| E11 技术预算 | 原森林80图矩阵540.378秒／600预算通过；GPU裁剪44／0；不是实体设备帧时通过，完整远端CI另记 |
| E12 导演／用户 | R3/R4仅独立审查的候选范围；成品审美、完整全速观看、音轨听审、实体设备与玩家乐趣等审核 |

真实命令、源与原失败见[验证摘要](../../evidence/enemy_all_02/validation/summary.json)；完整原件归档附SHA。不以本卡或零gap自动签整怪完成。
