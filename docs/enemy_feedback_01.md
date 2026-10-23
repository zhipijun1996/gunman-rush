# ENEMY-FEEDBACK-01 · System Engineering

2026-10-23会话收口：[全部累计修改、去留与阻塞](enemy_feedback_01_session_summary.md)；[Skills改进提案与后续怪物制作卡](enemy_feedback_01_production_lessons.md)。本次仅整理交付，当前内容仍为下述v8-r2的REJECT／draft，未合main。历史各轮“最新”仅指当时检查点，以本页首当前状态为准。

## 2026-10-23 当前返工：专属受伤／死亡帧与留尸体（v8）

当前实际运行源3003bd0f10ed9c7fe51e0cdc5952aa579a87f130，两链实弹片与独审见[v8检查点](evidence/enemy_feedback_01/v8/README.md)。材质回接明显改善，结构回接仍REWORK；独立458/0、199/0、278/0、258/0与4原Harness通过，正式存档strict66/1仍失败，任务保持draft／REJECT。首候选5ffd的66/2与旧片完整保留，未以新片覆写旧失败。

用户最新原话：“这音效怪怪的。然后每个怪物应该有自己的受击死亡帧动画，感觉单纯消失好像不如开始尸体更有感觉。只是之前的应该是死亡动画帧没有做才不够好看。”本轮明确取代v5–v7消失方向及v7音色候选；保留历史证据，不把拒绝写成认可。

先为原两个样板补齐每种4受伤／4死亡姿态。两条继承链各用独立绘制图：Legacy甲虫与叶片旋翼球壳、Underworld獠牙甲兽与双翼铃虫，共4套32帧；不批量扩产、不改AI／数值／碰撞／奖励。保留已要求的命中闪色及现有方向粒子；新帧沿现有Underworld壳／青石／铜材质族显示，Legacy保留自身配色；逐Atlas局部UV保持行间光照一致。死亡以真实帧失力／折翼／倒地，落地保留末帧，不以翻转活图或爆裂消失代替。

两host停止安装v7任务死亡声覆盖，沿EnemyActor原唯一enemy_defeat提示；这只是撤回被拒音色，未声明声音审美已修复。共享GameAudio接口和旧WAV保留历史，不重写角色／武器声学管理。

当前stage尸体跟随已核实支撑，卸载／epoch清理。死档直接末帧，零短闪／动作／粒子／新死亡声；没有可验证保存接触时明确missing_saved_support，禁止吸附任意远地面。**v4移动渡船死体保存缺口重新属于当前阻塞**，不再引用v5–v7消失政策豁免。具体帧／锚点／来源与限制见[帧样板合同](enemy_feedback_01_frames.md)。首候选5ffd经独审发现受伤回接色调／比例跳变，原片与REWORK保留在v8-first-review；当前按原live实际alpha主体统一整套比例、锚点与材料范围，不逐帧强行归一，不改变玩法。当前仍是Development候选，完整Integration、持续运动帧、合屏美术、用户／设备均未完成；不合main。


## 2026-10-23 最新：正式死亡链的实体爆裂声（v7）

用户要求“怪物死亡应该增加一个音效”，本轮只解除两个样板的死亡声暂缓；枪声/普通命中声保持原样。沿原EnemyActor→GameAudio.enemy_defeat唯一触发，为两条表现链配置任务短裂/躯体/碎屑声；最小逐origin音色接口见[具体写集与合同](enemy_feedback_01_audio_interface.md)。没有再接第二次死亡演出，原池/节流/暂停/restore规则保留。实际源码0e37e04528b4f71af75e74c5370d656e1e122588；新声实弹影片、失败与验证见[v7检查点](evidence/enemy_feedback_01/v7/README.md)，仍未合main。


## 2026-10-22 最新：更强命中与死亡爆裂（v6）

按用户“爆炸和受击的特效可以再夸张一点。增加玩家打击反馈感”，仅加强两个任务leaf的短接触尖芒、飞溅空间与分层死亡压力轮廓；普通body flash保留，演出时长/3并发burst/80纹理片上限/0.55秒spent合同不变。玩家/相机/全局时钟/音效和任何玩法所有权不扩。两种对象与两套继承链均需独立实弹验证。当前源73556539d4337065eb73537ce2fc2c03d7729c18，媒体、实测与未完成范围以[v6检查点](evidence/enemy_feedback_01/v6/README.md)为准；未合main。


## 2026-10-22 最新：用户选择爆裂后消失（v5）

用户明确指出死亡只是翻转原图、没有重画，提出“或者增加爆炸效果消失吧”。本轮采用这个替代方向，撤销两个样板的持久尸体需求；不是补画动作帧或修复旧support-local存档。复用同一个死亡叶，当前身体短闪后碎解为原材质小片/细屑，0.55秒内消失；dead restore直接spent，不爆裂/不闪/不补掉落。原受击变色、v4亮材料、两条继承链与正式接受门继续保留。

首源167ff99矩形切片被实际影片独审判视觉REWORK；修订3c5338552b2f7ac275203c4bbf1003e29520a312换原UV渐尖小片及更短的死亡材质闪色，另采/另验。当前媒体、质量和未完成范围以[v5检查点](evidence/enemy_feedback_01/v5/README.md)为准，v4下述持尸方向/62-1阻塞是保留的历史，不覆盖最新用户合同。完整运动帧/正式美术/手感/受影响Integration/用户与设备仍未完成，不合main。


## 2026-10-22 用户第四轮：更大接触、活死区分和明亮材料

生产源8f0fd51；新增GPU检验源0d5b72c，生产树相同。只两个已有对象，保留批准flash，扩大精细方向碎屑包络和短接触碎芒；Underworld opt-in草甲/青石/铜材料面，alpha轮廓不变；地面翻背/空中侧倒，尸体低饱和且持续保留。旧EnemyPresentation不换活体palette，两个继承链分别验证。具体媒体、同条件事实、失败与来源见[v4检查点](evidence/enemy_feedback_01/v4/README.md)。

《空洞骑士》参考用于简洁形体、真实关键帧及明确的接触/身体/余势层次；本线未核实其内部顿帧参数，不改全局时钟/相机/音频。原PNG/共享母版未改，完整新运动、收腿/收翼/死亡帧未制作。移动渡船死体存档仍严格失败；总控已有接口请求继续有效。新样板不等于整体美术、手感、正式整合或可合main；这不是新增AI或敌人行为，无需扩大enemy-creator生产范围。

最新：feedback-sample-v3 当前房间尸体/细粒子检查点，源`bd8d130`；正式移动渡船尸体读档62/1失败，非可合入版本。见[v3规格、失败、总控接口请求与实际媒体](evidence/enemy_feedback_01/v3/README.md)。

## 检查点 1：复用与代表对象

基线 `origin/main e9ab0e0743466b8983e34cc7de17bab1abf9d53a`（PR103实际合并），独立分支 `feature/enemy-feedback-01-accepted-sample`，工作区 `/workspace/gunman-rush-work`。v1运行源 `82940b7f057d74bfadf5855b1d489c38619c4a00`；草稿[PR104](https://github.com/zhipijun1996/gunman-rush/pull/104)。任务类型 animation；采用 animation-vfx、game-quality-gate，未扩展行为，因此不触发 enemy-creator。

选择 `resources/enemies/plains_charger.tres`（plains_charger，地面冲锋）与 `resources/enemies/plains_diver.tres`（plains_diver，空中俯冲）。两者现有碰撞均28×32；选择依据是不同支撑/运动方式和现有身体轮廓，不冒称尺寸差异，不改Definition。地面保持脚底锚与冲锋节拍，空中保留flutter/lean与俯冲预告；分别用较宽的压缩和较轻的纵向反应。

| 已有系统 | 复用结论 |
| --- | --- |
| PlayerProjectile → Damageable → FrameDamagePolicy → HealthState.changed | 正式命中入口；仅APPLIED、damage、负增量、当前health epoch与唯一event_id驱动样板。接触火花不能作为HP已接受证明。无需新信号。 |
| EnemyPresentation | 旧消费者保留；选中两种接共享状态，其他继续原反馈；已有动作帧/材质/预告保留。 |
| UnderworldActorInstaller → UnderworldEnemy → PixelPlainsEnemy → WindchimeEnemyVisual | 正式安装器移除旧Presentation，因此必须独立接入；选中实例不再安装Windchime匿名受伤监听，避免两套计时并行。 |
| ForestBibleActors.install | 森林保留的plains_charger也会经UnderworldEnemy消费同组件；没有新增第三物种，仍须在完整Integration覆盖森林该消费者，不能只看平原。 |
| PixelPlainsEnemy._death / visible / modulate.a | 父类独占、只读；不重置或改写。新死亡姿态在原0.65s淡出内结束。 |
| EnemyActor / Damageable.died / GameAudio | 原死亡/击伤声音和击退保持；组件不发声、不发defeated、不驱动AI或伤害。 |
| DemoApp._settle_enemy_drops / EnemyDropService | 原奖励所有者继续结算；组件不创建掉落。验证幂等，不改奖励。 |
| HealthState initialize / restore_instance_health | 清空短时表现；terminal初始化为恢复死体，不演出新死亡。已死亡身体恢复时不绘制短时粒子/动作。 |

修订：检查点初选的graybox_patrol_drone仅在旧场景，不在默认正式生成池。正式池审计后改为plains_charger，确保两个对象都具备默认地图消费者。旧巡逻组合154断言0失败只保留为历史定位证据，不移签最终组合。

## 写集与所有权

仅修改 enemy_presentation.gd / underworld_enemy.gd（现有UID保持），新增 enemy_feedback_01.gd 及其UID、任务专属测试/录屏驱动、本文、docs/evidence/enemy_feedback_01 与本任务质量记录。EnemyActor、Definition、ForestBibleActors、共享材质、音频、父类、正式场景、Harness、中央任务/状态/交接均归总控只读。本文件兼任务交接，不并改中央文件。

## 状态、锚点与时间轴

- 正式非致死命中：组件在health提交信号当帧设置hurt_remaining；持续时间直接读既有feedback.tres。ground压缩与aerial拉伸经平方衰减归一，保留原AI动作层。没有额外stagger/force。
- 致死命中优先：停止hurt，死亡计数仅一次；地面压扁、空中收拢及轻倾。旧表现短时mote沿原绘制；正式表现沿父类下沉/0.65s淡出。组件0.5s后结束，不生成节点/粒子/Timer/Tween。
- 暂停不推进；慢时消费现有delta，不改time_scale。initialize清除hurt/death和当前epoch去重集，恢复死体不产生新事件。
- uninstall/_exit_tree显式disconnect并dispose，移除旧表现后不留signal持有RefCounted；无异步回调跨场景。
- 父类已有同实例死后reset活体仍隐藏的限制不在本线改动范围；若要求该路径，先由总控分配父类可见性/计时接口，不能偷偷重置。

## 可证伪验收与阶段

| 场景 | 方法 | 失败条件 |
| --- | --- | --- |
| 两对象×两继承链正式受击/死亡 | 原Router发射真实弹体、原碰撞/帧伤害提交，记录HP/事件/表现 | 无HP提交却反馈，漏一继承链，非致死和致死重复计数 |
| 重播/无效/旧epoch | 将真实命中context重试、失效target epoch与旧stage token反例 | 新hurt/death/audio/drop或HP变化 |
| 暂停/恢复/慢时 | 中断hurt/death并观察时钟、恢复自然消退 | 暂停推进、恢复重复开始 |
| 恢复死体/卸载/重装 | 正式恢复接口、安装器替换和weakref释放 | 新死亡演出、旧signal残留、掉落重结算 |
| 非样板消费者 | 原underworld反馈专项与正式消费者回归 | 不相关物种变化或shared母版漂移 |

先Development专项定位；新组件/driver不在影响映射中会按原planner升级full，保留该计划，不自行缩减或改配置。合入前完整Integration由总控安排；本线不合main。G2交真实正常速度、真实音轨、同输入/镜头/分辨率before/after MP4，定位fixture明确标注，不冒称自然路线。当前只是可观察反馈，不新增可操作机制，按用户交付条件优先短片；用户要求操作后补独立Preview。AI审查、用户视觉/手感认可和真机分别记录。

## 当前恢复点

任务版本 feedback-sample-v1，workflow=review；实现与有限原生/媒体独审已完成，完整Integration及用户/设备仍未验。两链两对象154断言、默认DemoApp真实弹体击杀/掉落/重载44断言均通过且由独立审查者重跑；额外原Harness actor-actions2872、Underworld正式两图96、森林Bible集成54及原伤害专项通过，不外推完整Integration。

同驱动基线/候选各20.233秒真实MovieMaker带音轨短片，1200个gameplay帧严格相等；旧链死亡alpha硬截止候选已按独审修到有界归零，保留旧审查发现。精选原件与音效25秒离线A/B见[证据入口](evidence/enemy_feedback_01/README.md)。用户声音返工原话、网络方法与最小总控音频写集请求见[参考与返工](enemy_feedback_01_references.md)，不称当前正式音效已修。

推送时发现远端已存在 `feature/enemy-feedback-01 @ ce84d01`（另一个root_bell/diver样板），因此本线更名并保留原分支，未强推/覆盖/合并其内容。PR104是从main建立的独立charger/diver候选；总控必须择一或收敛组件与消费者后集成，不能把两份共享反馈实现同时合入。

本线中央文件只读：任务索引仍planned而卡为review，会被check_quality.py诚实拒绝；请求总控同步ENEMY-FEEDBACK-01索引及最终集成口径。新增路径原planner保守选择146项full；本线未删映射、改预算或自行合main。完整Integration必须在总控收敛两个远端候选后执行。

质量记录 `docs/quality/records/ENEMY-FEEDBACK-01.json`；原失败与证据放 `build/enemy-feedback-01/`，精选归档到任务证据目录。工具链初始系统Godot4.6.3不符，已用仓库setup安装锁定4.7.2，未放宽检查。文档输入恢复第一次因并行提交改变HEAD被拒绝，原退出保留，固定新HEAD后重新按原工具恢复；不是玩法失败。docs首轮发现稀疏漏掉两个既有.gdignore，已恢复原字节；第二轮source snapshot在新证据写入期间被原守门拒绝，未追签通过；最终冻结后再执行原检查。

最终docs实跑：docs/world/world-design-tests/structure/harness-tests/quality-drills/quality-tests七项通过；quality因中央任务planned与卡review不一致失败，其余fail-fast未执行。单卡quality.py check errors=[]、内容判定仍REJECT（当前音色被用户拒绝），记录格式一致不代表内容通过。PR自动Integration状态另以Actions实际结果为准，执行中不签通过。

恢复命令：先核PR104当前head与运行源三生产文件SHA（review-v2.md），再运行 `python3 tools/production_plan.py --stage integration --base origin/main`。原生专项命令与正式App命令见证据入口。运行与音频试听产物、完整门槛及用户反馈分开，不以文档提交冒称新运行构建。


## 2026-10-22 用户返工 · feedback-sample-v2

音效按用户最新指令暂不处理；未来由人物按当前武器管理。本轮不改正式音频，也不继续音色试听选型。此前用户对音色的负面评价与离线候选保留在v1证据，不自动变成通过。

用户看到击退但看不到Underworld变色。复核发现暗像素的乘法染色不能产生足够明亮的受击轮廓；正式Underworld链也没有消费样板的受击碎片。本轮只在既定charger/diver双样板中修复：共享接受事件状态提供0.12秒flash envelope，Underworld身体叶节点使用实例私有shader把RGB短暂混到奶油色，保留原alpha、原动作姿态与材质退出；血条和预告不被染色。身体仍处于原actor的世界绘制层，仅在自身血条/预告之后绘制；不写父类死亡时间、visible、modulate.a。

两套继承链分别挂同一个任务专属像素碎片组件：普通接受命中14片，致死18片；奶油/旧铜共族、2wu像素步长、短寿命、小范围有方向散开，最多3组。世界接触点来自真实context，不跟着怪物漂走，不复用拒绝命中的碰撞火花冒充HP提交。不生成音频、碰撞、奖励或新伤害，不新增信号。

独立审查指出暂停时restore可能留下已缓存的身体闪色。增加只消费现有HealthState.initialize的清屏监听，立即清除自有身体/碎片缓存；不依赖暂停中的_process推进。GPU专项用第二发真实弹体后暂停，再调用正式restore_instance_health(0)作为反例，直接读实际屏幕像素；不是直接调用反馈方法伪造命中。

当前生产源固定为 `5de1eca1f3150289c2dc3bc72b206ac2efc326d9`。新录制仍为同驱动、同Seed/输入/镜头/分辨率的显式战斗fixture，并不是正式人物/正式地形的美术黄金。v2实际执行、像素原件、前后短片与独立审查见[v2入口](evidence/enemy_feedback_01/v2/README.md)，v1历史不覆盖或追签。

用户同时明确拒绝现有整体美术，要求各种运动都有实际动画帧。本轮已完成[材质/轮廓建议与两对象逐状态动作卡](enemy_feedback_01_art_direction.md)，没有制作新PNG/图集或批量推广。当前每物种一张身体PNG，整图位移/缩放/翻转不算新帧；全套待机、移动、转向、预警、攻击、恢复、受伤、死亡及空中拍翼/拉起图集仍未完成。质量记录visual/animation保持failed，不以本次闪色/粒子修订代签。后续新资产优先使用任务专属atlas/manifest，正式绑定/共享资产路径须由总控分配。

完整Integration、中央任务planned/review同步和两远端候选收敛仍未完成；不合main。此文件是本线写集内的版本化交接，中央handoff/tasks由总控持有。

本轮最终独立专项240/0、默认正式App50/0、GPU50/0；原Harness四项受影响定向回归通过；最终短片12次真实HP提交/4次死亡，1200玩法帧与旧源完全一致。新docs profile前7项通过、quality仍因中央planned/review不一致失败；单卡格式和diff写集守门通过不代表整体任务完成。新生产文件及UID均已完整纳入质量写集，保留上轮CI漏记UID的真实失败。


## feedback-sample-v3 恢复点

用户保留v2受击变色，拒绝粗粒子和廉价消失死亡。两链现分别接stage sibling遗骸叶节点：只消费唯一已接受致死事件，沿实际身体packet交接、轻转身/落地/收势后当前房间持续保留；恢复静态死体不补演、不掉落。shared parent clock/visible/alpha、Actor、AI/Definition/碰撞/奖励/音频/正式Stage保存均保持原字节。粗圆环/十字改为更少的细向碎屑；没有制作新Underworld死亡/运动图集。

最终独立native378/0、support133/0、GPU98/0；严格formal62/1真实失败保留：渡船已携尸体离开Actor保存x，旧存档没有support-local pose，重载无法精确保留该尸体。总控需分配stable support id/local rest pose/version和恢复完成后的只读resolver；本线不另造保存系统，不删失败断言换通过。具体原件、接口请求和局部交付边界见v3入口；整体仍REJECT/未完成，不合main。
