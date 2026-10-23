# ENEMY-FEEDBACK-01 v3 独立审查

## 结论与审查身份

**总体 REJECT：正式移动支撑尸体恢复有已复现失败。** 当前房间尸体交接、落定、保留及静态地形恢复的有限技术样本可以作为检查点展示；不能称完整功能完成、正式回归通过或可合入。连续动作与最终影片尚待本报告追加实看记录。

**6eda 影片实看确认 EF03-R2：当时 diver 尸体落定后明显悬空，原候选保持 REJECT。** 最新 `bd8d130f3677ba80d569f16c05feee1977450c02` 已修轮廓投影并由本审查者独立重跑四项；GPU 贴地反例通过，原自然落地连续镜头仍待新片复审。正式移动支撑恢复继续失败，因此总体 REJECT 不变。各历史结论按原版本保留，最新闭环见末尾。

reviewer：独立代理 `/root/feedback_review`；implementer：`/root`。独立依据：未编写生产/测试代码，收到冻结源后自行顺序启动四个检查并保存原始输出；只写本报告与临时 build 证据。采用 [.agents/skills/gameplay-reviewer/SKILL.md](../../../../.agents/skills/gameplay-reviewer/SKILL.md)、[review_method](../../../quality/review_method.md)。这是独立审查，不是实现者自审，也不代签用户、音频试听或实体设备。

生产/测试/驱动源：`942d4ea11e05fbe211ee51196e8c8a5d318e6b9e`；content_version：`persistent_remains_v3`。对照 v2 `5de1eca` 的源码 diff，并将只读权威文件与原始 `e9ab0e0` 比较。运行前后记录 846 个生产脚本/任务测试/驱动文件 SHA256，变化 0；这不宣称整个 workspace 冻结，作者可以继续写任务文档/质量记录。

**最新复审源为 `6edaed5e7238d11e3f8a1626803117e3fb978ce2`，四项已重新独立执行，见末尾追加。** 上述 942 轮原件保留，未被覆盖或改签。

后续最新技术复审源为 **`bd8d130f3677ba80d569f16c05feee1977450c02`**；6eda 及其旧片仍保留独立归属，未追签。

原始独审证据：`build/enemy-feedback-01/v3/review-final/`。源清单 `source-before.json`，最终核对 `source-and-log-audit.json`。未修改或放宽任何断言。上轮 v2 通过及用户对粒子/死亡的拒绝不移签 v3。

## 合同、消费者与源码边界

沿用两种正式普通怪物 `plains_charger`、`plains_diver`，分别代表地面冲锋和空中运动；各自定义、AI、HP、碰撞、奖励不变。两条表现继承链分别安装相同叶组件：`EnemyPresentation` 和 `UnderworldEnemy → PixelPlainsEnemy → WindchimeEnemyVisual`。尸体是 stage sibling，逻辑生命周期仍绑定原 presentation/Actor；没有修改父类死亡计时、可见性或调制值。

静态检查：`EnemyFeedback01Remains` 仅从既有 `Damageable.damaged` 与已接受的当前 epoch/event/serial 关联启动一次；`initialize` 直接静态重建而不补死亡。host 退出显式 dispose，断开 health/damaged/tree_exiting，清空 Callable 并释放 sibling；支撑只保存 WeakRef。地形 mask1 向下 ray 只读，最多 2048，无 CollisionObject、Actor/Motor 位移写入、奖励、音频、新信号或保存 schema。粒子保留奶油/铜色、改为 6/9 条细线，没有环/十字，未消费玩法 RNG。

旧链保存所有混合帧及精确 shear draw packet，在短过渡后收束既有 authored death frame；Underworld 使用当前纹理/姿态交接及 canonical rest_size。落地使用固定 rest foot，避免插值尺寸反复改变地面基准。空中逐 physics 重新读下方支撑，接触前不横向追 ferry。落定后无 TTL/反复压缩/持续重画；支撑丢失后有界下落。首次 physics 的恢复对齐处理现有 stage 先 health 后 position/direction 的顺序，没有改总控恢复合同。

独立字节比较确认以下 10 项仍与原始基线相同：PixelPlainsEnemy、WindchimeEnemyVisual、EnemyActor、ForestBibleActors、PlainsRegionStage、EnemyDropService、charger/aerial PNG、两份正式 terrain shader。详见 source-and-log-audit.json。未选物种不安装新组件；但森林 retained charger 和 Action Studio 仍是真实受影响消费者，不能因其代码没改而免验。

## 独立执行记录

环境：仓库 `tools/godot.sh` 锁定 Godot 4.7.2 Standard；Linux；固定 60 fps；Dummy audio。GPU 为 Xvfb 1280×720、`gl_compatibility`、Mesa llvmpipe 软件渲染，不是设备性能证据。

| 检查 | 实际命令（从仓库根目录） | 结果与原件 |
|---|---|---|
| native | `bash tools/godot.sh --headless --path . --audio-driver Dummy --fixed-fps 60 --script tests/enemy_feedback_01_tests.gd` | 378 checks / 0 failures，exit 0；native.log、native-runtime.json |
| support | 同上，script 改为 `tests/enemy_feedback_01_support.gd` | 133 / 0，exit 0；support.log、support-runtime.json |
| formal | 同上，script 改为 `tests/enemy_feedback_01_formal.gd` | **62 / 1，exit 1**；formal.log、formal-runtime.json |
| GPU | `bash tools/godot.sh --path . --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 60 --script tests/enemy_feedback_01_pixels.gd` | 96 / 0，exit 0；pixels.log、pixels-receipt.json、pixels/report.json 与 PNG |

四项按上述顺序执行，只有本审查者占用 engine。结束后已向实现者归还租约。逐项日志未见 SCRIPT ERROR、ERROR、ObjectDB/RID/资源泄漏诊断；formal 的 FAIL 是真实断言失败。GPU 有一条不支持调整 VSync 的驱动 warning，原样保留。

`python3 tools/quality.py check docs/quality/records/ENEMY-FEEDBACK-01.json` 独立执行 exit 0，格式 errors=[]，内容 verdict=REJECT、task_complete=false。quality-check.log 保留完整 blockers；格式通过不签内容通过。

## 状态×时间×消费者的实际覆盖

| 范围 | 实际方法与观察 | 有限判定 |
|---|---|---|
| 两对象×两链的正式伤害 | native 使用现有场景、实际 Router/弹体/HP，检查接受、拒绝/旧 epoch/重复、死亡唯一性、暂停、初始化及卸载/安装器替换 | 所运行样本技术 ACCEPT；不是新伤害系统证明 |
| 当前房间尸体 | native 真实弹体死亡后观察超过父类淡出；唯一 sibling、无碰撞体、暂停冻结、重复终态不新增尸体、卸载 WeakRef 释放 | 所运行样本技术 ACCEPT；动画自然程度待连续片 |
| 支撑/虚空/恢复顺序 | support 的六个显式 charger fixture：两链各测真实死亡后虚空有界退场、支撑平移和释放、health 后写 position/direction 的静态恢复 | ACCEPT 仅限这六例；不是斜坡、one-way、狭窄边缘或所有移动平台认证；未以 charger 样本覆盖 diver 全几何 |
| 默认正式 App | seed `enemy-feedback-01-formal`，实际默认生成池，Manifest `f93cd6fbf4b8be98e00af8ada184f4ad44d3c047f2a6ce0c5d56e43ecb745b7d`；仅初始玩家位置使用既有 safe terrain fixture，后续真实射击 | 两对象各 3 次 HP 提交、2 次 hurt、1 次 death；charger coin/1 pickup，diver none/0；重复及 reload 未重结算；**移动尸体恢复失败** |
| 闪色、恢复、尸体像素 | GPU 实际弹体，opaque source mask；另死亡后超过两秒捕获尸体并暂停再捕获 | 96 项有限技术 ACCEPT；不签美术/动作质量 |
| 森林/Action Studio/全 Integration | 本轮没有运行这些正式消费者/完整受影响检查 | UNVERIFIED，旧轮证据仅保留原版本归属 |
| 音频/设备/用户 | 音频按用户指令 deferred；无试听、无实体设备、无新用户认可 | 不代签；实际运动帧及整体美术的原失败仍保留 |

## 实际查看的 GPU 原像素

打开了本次独立 GPU 输出的两对象 before/impact/recovered/actual-persistent-corpse 的 128×128 原像素裁片汇合图 `pixels/review-contact-sheet.png`，另打开原尺寸 1280×720 `plains_diver-actual-persistent-corpse.png`。这些是实际游戏 GPU 输出，汇合图仅用于查看，未冒充连续镜头。

可见两对象命中时奶油色覆盖身体，恢复后回到各自铜暗材质；血条没有变成身体闪色。原始 opaque-mask 统计：charger cream fraction 0.9757、diver 0.9941；命中 luma 约 .924/.932，恢复约 .134/.126。暂停恢复死体时 flash=0。死亡超过两秒后父 presentation 隐藏，stage sibling 仍有可见身体；charger/diver 暂停前后 128×128 crop SHA 分别完全一致，且记录的 transform/phase 一致。没有将 cyan 既有弹体接触特效误认成新增碎屑。

此 GPU fixture 背景与地面不提供正式关卡美术构图，不足以裁决脚底浮空、斜坡贴合、自然场景遮挡或整体商业美感。尚未完整播放本轮长片、未听音轨；连续交接和后段静止须追加影片证据。

## 发现与处理边界

| ID / 严重性 | 实际反例、证据与期望 | 处理 / 结论 |
|---|---|---|
| EF03-R1 / 阻断正式恢复 | 本次 strict formal 原样报 `official restored corpse stays visible despite hidden saved EnemyMotor`。实际 App 默认 diver 死体 reload 后不可见；同一重建的 charger 可见。作者 probe 进一步定位 bell_ferry 随动后的 corpse x 与保存 Actor x 不同，reload ferry 相位已变；这一坐标诊断来源是保留的作者 probe，本次独立重跑证实断言失败，不把 probe 宣称成自己的额外引擎实验。 | **REJECT 正式移动支撑恢复**，保留 62/1 和原始失败，不能删断言换通过。由总控分配稳定 support id、support-local rest pose/朝向的版本化表现恢复片段，以及平台/Actor 变换完成后的只读解析时序；仅时序不能找回已丢失 local pose。严禁本线写 Actor 保存位置或虚构浮空地板补洞。 |
| EF03-U1 / 覆盖缺口 | 地形算法取中心与旋转 footprint 两侧向下 ray，并以最高命中构造水平 rest plane；当前实跑只有宽水平矩形、平移和虚空，尚无坡/窄台/one-way 的真实连续像素。 | UNVERIFIED，不能把几何代码或 133 checks 宣称成全地形通过；这是待验范围，不声称已证实穿插。 |
| EF03-U2 / 视觉未验 | 新版稀疏碎屑和持续尸体的连续质感尚未在最终冻结长片核验；旧链 mixed/shear 交接已读代码，但 GPU 原件仅 Underworld。 | 待最终片；用户是否认可丝滑/风格仍须原反馈。Underworld 新运动/死亡帧未制作，不把程序转动称 authored animation。 |

当前房间的技术结果与 strict formal 失败可以同时交付审查。任何“持久尸体已完成”的描述须限定当前房间和已验静态地形恢复，移动支撑精确读档与完整 Integration 继续阻断总体完成。本报告不批准批量推广或合入。

## 6edaed5 最终采集驱动复审

审查提交：`6edaed5e7238d11e3f8a1626803117e3fb978ce2`。独立确认 `942d4ea..6edaed5` 只修改 `tools/enemy_feedback_01_remains_capture.gd`（13 行插入、3 行删除）；两轮 846 个路径 hash 的唯一差异也为此驱动。修改由按显示节点名搜索，改为优先读取正式 presentation.feedback_remains owned 引用；不具此属性的旧基线继续 fallback。installer 旧 sibling queued free 时替代节点可能被 Godot 自动改名，显示名不能作为对象身份。没有改生产/测试/模拟逻辑或断言。

独立获得第二次 engine 租约，原命令顺序重跑 native、support、formal、GPU，证据全部保存到 `build/enemy-feedback-01/v3/review-final-v2/`：**378/0 exit0、133/0 exit0、62/1 exit1、96/0 exit0**。正式失败仍是 `official restored corpse stays visible despite hidden saved EnemyMotor`，不追签通过。四日志未见脚本/资源/退出泄漏诊断，GPU 仍只有相同 VSync warning。运行前后 846 源路径变化 0；原回执、source-before.json、source-comparison.json、source-and-log-audit.json 保留。本轮 engine 已归还实现者。

本节确认最终记录源与检查实际执行相符，未扩大前文技术范围或改变总体 **REJECT**。最终 MovieMaker 比较尚待独立实看；基线若叠加新采集驱动，必须明确是旧生产源加相同驱动的非 clean baseline，不把它称原提交全 clean。

## 6edaed5 最终候选影片实看：EF03-R2

实际输入：`final-movies/after.mp4`、after.json、after-report.json。独立核 MP4 SHA256 为 `32faace17b404942abe78f15df31435ec08e428cc9ca51aed91f5c8c06a28c81`，ffprobe 为 1280×720、60fps、26.133333 秒、1568 视频帧；trace 有 1560 个玩法帧。报告记录 clean `6edaed5` 与 source_stable=true；此处实际核对报告及文件字节，不把作者采集过程冒充审查者录制。

after.json 各对象三个真实 accepted HP 事件：charger trace frames 59/124/182，diver 839/901/966；均 HP 2→1→0、各一次 death。死亡后 trace 分别继续观察 598/594 帧，末 210 帧为稳定可见记录。视频有准备/切换帧，以下 **v 编号指 0 起始 MP4 解码帧，不等同 trace frame**。

审查者以 ffmpeg 解码原 MP4，实看原像素连续邻帧与独立全尺寸图，非完整正常速度播放：

| 对象/动作 | 实际查看视频范围 | 原件/抽帧 |
|---|---|---|
| charger 首次非致死命中 | v55–76，每一邻帧，0.917–1.267s | review-media/charger-hit.png |
| charger 致死、交接与收势 | v177–232，每一邻帧，2.950–3.867s | charger-death.png；另全尺寸 v185 |
| diver 首次非致死命中 | v834–855，每一邻帧，13.900–14.250s | diver-hit.png |
| diver 致死、转身下落至停止 | v961–1024，每一邻帧，16.017–17.067s；另以较大裁片完整显示身体与地面复看 | diver-handoff.png、diver-contact.png；另全尺寸 v1004 |
| charger 后段保留 | v574、589…784，每 15 帧，9.567–13.067s，覆盖最后 3.5 秒 | charger-tail.png |
| diver 后段保留 | v1354、1369…1564，每 15 帧，22.567–26.067s，覆盖最后 3.5 秒 | diver-tail.png；另全尺寸 v1504=25.067s |

临时抽帧、未缩放裁片汇合图和编号选择保存于 `build/enemy-feedback-01/v3/review-media/`，selection.json 可复核；汇合图只辅助逐帧查看，不作为伪造影片交付。未完整正常速度播放、未听音轨、未测实体设备；音频仍 deferred。旧链的连续实机像素尚未在该片覆盖。

有限实际观察：奶油闪→原材质恢复清晰，HP 行没有被统一染白；可见身体交接后保留，未见该取样范围中的第二次死亡或满圈新粒子。charger 没有旧的压扁到消失，后段稳定；diver 确有连续转身和下落，随后固定姿态。新增细碎屑较少，但既有 cyan 接触特效仍明显，不能宣称所有命中特效的粗糙程度已解决。关于“丝滑/不违和”的最终接受不能代替用户。

**EF03-R2 / 高优先级视觉缺陷 / animation-vfx / 已证实，REJECT 当前 diver 自然落地。** diver 在停止下落后，实际清晰身体最低像素约 y477–483，而真实地面顶为 y510；约 27–33px 的空气一直保留到最后。v1504 全尺寸 `diver-tail-full.png` 清楚可见，v985–1024 邻帧及末段抽样反证它不是仍在落下的过渡帧。trace 此时 settled=true、transform 不变；因此“稳定可见”测试可以通过，同时画面仍浮空。

源码/纯图像几何反证：`_foot()` 将 alpha used_rect 的四角旋转后当最低接地点。aerial.png 为 36×40，used_rect 恰为全幅；旋转 .96 后矩形最低点 26.21585wu，而实际 alpha>0 的像素中心最低点约 15.27917wu，空角多算 10.93668wu。fixture zoom2.5 时相差约 27.34px；仅最不透明像素的差约 32.67px，与实际帧一致。这是旋转透明矩形的空角包络问题，不是新存档接口或舞台层级缺口。数值方法与阈值完整保存在 foot-support-audit.json；像素中心计算含半像素采样误差，不把估算写成 GPU 几何精确接触。

最小修复层：本任务叶组件从现有纹理 alpha 轮廓缓存实际投影 support extrema（同时审查横向 footprint），用于 rest foot / 当前接触计算；不改 PNG、母类、Actor、碰撞、奖励。加实际地面合屏的像素反例，不能只以 remains.visible 或 settled 通过代替贴地。保留本候选和两轮 378/133/62/96 原证据；修后需新冻结源与连续地面镜头复审，不能把当前片标通过。

最终局部结论：**当前房间唯一性/暂停/卸载/可见保留的已运行技术事实成立；diver 自然落地失败；正式 moving-support 精确 reload 仍失败；整体继续 REJECT。** before 正在采集，本次尚未独立核对 1560 帧 gameplay equality，不提前签同条件前后比较。

## bd8d130 轮廓修复复审：GPU 部分关闭 EF03-R2

最新源 `bd8d130f3677ba80d569f16c05feee1977450c02`。独立 diff 确认只改 remains 叶组件、GPU 任务测试和采集驱动的缺 presentation fail-fast 守门。仍无父类/Actor/Stage/碰撞/保存/奖励改动。

根因修复：从既有纹理/Atlas 实际 alpha>=.5 的每行左右边界提取像素边缘并构建缓存 convex contour，foot 及横向包络改用真实轮廓的旋转投影。线性投影取 convex hull 极值与取轮廓全部点极值相同，因此此处 convex hull 不会重新引入原矩形的空角。没有改图，也没有挪动实际 Actor 或地形。

本审查者再次独占 engine，按原顺序自行重跑四项，全部另存 `build/enemy-feedback-01/v3/review-final-v3/`，不覆盖前两轮：

| 检查 | 结果 | 退出 |
|---|---|---|
| native | 378 checks / 0 failures | 0 |
| support | 133 / 0 | 0 |
| formal | **62 / 1，同一 restored corpse visibility 失败** | 1 |
| GPU | **98 / 0**，新增两物种实际像素贴地断言 | 0 |

运行前后 846 源路径 hash 无变化；source-before.json、source-comparison.json、source-and-log-audit.json 和原始 logs/runtime 保留。所有运行未见 SCRIPT ERROR/ERROR/ObjectDB/RID/资源泄漏诊断；只有 GPU 同一 VSync warning。检查结束后已归还租约，不与实现者录像并发使用 engine。

独立 GPU 原件：charger/diver 各自死亡后和暂停图的 bottom_pixel=379、terrain ray floor_screen_y=380、body_floor_gap_pixels=0；暂停前后 crop/状态一致。新断言为 gap 绝对值<=3。审查者用旧 6eda 实际 PNG 和同一 arena 顶 y380 复算：旧 diver bottom=369、gap=10，会被新条件拒绝；旧 charger gap=1。该对照保存在 foot-counterexample.json，表明新守门针对实际可见失败，不只是镜像实现状态。

实际打开新 diver 原尺寸 `pixels/plains_diver-actual-persistent-corpse.png` 与 `pixels/review-foot-comparison.png`。后者为未缩放原像素裁片，红色短刻度是审查叠加的实际 ray floor 指示，未冒充游戏地面；原始 GPU fixture 地面仍不绘制。看到新轮廓相对于射线地面降到贴合高度；与数值结果一致。**EF03-R2 的该平地 GPU 贴地反例已关闭，有限技术 ACCEPT。** 新版带实际可见地面的最终片尚待检查接触/收势是否 snap，未预签连续自然程度、斜坡或 one-way。

先前 `6eda` 悬空失败片现归档至 `alpha-aabb-rejected-movies/`，上节 MP4 SHA/所看帧号不变；不得用新片覆盖原失败归属。总控报告的旧基线首录因未 import、全局类缺失而 timeout 属录制准备失败，日志保留；本审查者未亲自重跑该录制，不把后续作者补 import 的 headless 成功移签自己的四项或完整片比较。

整体仍 **REJECT**，因为 EF03-R1 的正式移动支撑精确恢复失败没有解决；本轮没有要求本线越过保存所有权。作者可交付新当前房间候选以供有限观感审查，完整 Integration、森林/Action Studio、真实运动帧、美术/用户/设备范围保持未验或原失败。

## bd8d130 最终地面影片复审：EF03-R2 样本关闭

新 `final-movies/after.mp4` 实际 SHA256 为 **`823206c1814d11077b4e836a9e205513234225d67afbeb4259e00b0895af00c5`**，报告归属 clean `bd8d130f3677ba80d569f16c05feee1977450c02`、source_stable=true。这与归档的旧 6eda 悬空片是不同原件，旧失败不追签。审查者没有运行引擎。

实际重新解码并查看以下新版原像素：**diver v961–1028 每一连续邻帧（16.017–17.133s）**，覆盖存活末态、奶油命中、转身、下落、接触和最终停止；**v1354、1369…1564 每15帧（22.567–26.067s）**，覆盖末3.5秒；另打开 **v1504=25.067s 原尺寸1280×720整图**。编号为0起始MP4帧。抽帧和未缩放大裁片为 `build/enemy-feedback-01/v3/review-media-final/diver-handoff.png`、diver-contact.png、diver-tail.png、diver-tail-full.png。

实际观察：新版身体继续下落到可见地面顶边，足/翼的最下缘与地面接触；旧版约30px的空气间隙已消失。所看接触/收势邻帧中没有明显的额外位置跳切、再次弹起、反复压缩或淡出；末段尸体稳定保留且贴地。**EF03-R2 在这个平地 Underworld diver 连续影片反例上已关闭，有限 ACCEPT。** 这不代签用户的丝滑/美术偏好；仍未完整正常速度播放整片、未听音轨、未覆盖斜坡/one-way或旧链连续镜头。新 charger 全段没有在本追加中重新逐帧观看，不把旧片的观看记录移给它。

另独立核对两报告：baseline 为生产 `5de1eca1f3150289c2dc3bc72b206ac2efc326d9` + 三个未跟踪任务采集驱动文件，明确 **非 clean baseline**；候选 clean bd8。两者 GDScript driver SHA256 均为 `8efcbef8ba9a32323776ec1ad0b17320bcf70f5f2e9064050595d78758b13c06`，报告 source_stable=true。before.mp4 实际 SHA256 为 `236bec9e41636ad8d72f72d6793a9c988acd3ade646594e4892febb2b34e6aef`。

审查者自行读取 before.json/after.json 并逐项比较：**1560 帧**的 frame/case/local_frame/paused/player_position/player_velocity/enemy_position/enemy_velocity/HP/state 严格全等；两 case 的 inputs 和 shots 原字段严格全等。HP events 的 epoch/frame/amount/HP/terminal 及 event_id 中 session/shot 后缀相同，但**完整 event_id 字符串不同**，因为两次进程的 Actor 前缀不同；只有显式去掉该进程局部前缀后事件语义才全等。因此 `comparison-runtime.json` 的 same_actual_inputs_and_events 应理解为这种身份归一化后的语义比较，不能扩写成原始 events JSON 逐字全等。显式对照与哈希见 review-media-final/independent-comparison.json。

截至本次审查，**EF03-R2 已按新源闭环；EF03-R1 正式 moving-support 精确 reload 仍是62/1严格失败，总体REJECT保持**。当前房间有限样本可供用户观感评审；完整受影响系统/正式消费者、运动新帧、整体美术、用户与设备认可仍需各自证据。本审查到此停止写报告，供任务文档冻结守门。
