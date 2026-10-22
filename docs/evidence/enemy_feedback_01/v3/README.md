# ENEMY-FEEDBACK-01 · feedback-sample-v3 · 检查点

当前冻结源：bd8d130f3677ba80d569f16c05feee1977450c02；完整正式恢复仍未通过。

本轮原话见user-feedback.json。用户只认可v2受击变色，明确拒绝粗粒子/廉价死亡，希望参考空洞骑士的尸体保留和自然收势。原画风/音频所有权不变；不复制其他游戏资产。沿animation-vfx、game-quality-gate和独立gameplay-reviewer执行。没有新增敌人/AI/判定/奖励，不扩展enemy-creator的行为生产。

## 修订规格

首轮采证源6edaed5e7238d11e3f8a1626803117e3fb978ce2（生产字节与首候选942d4ea相同，仅采集器观察修订），两物种仍为plains_charger/plains_diver，两个继承链分别接同一EnemyFeedback01Remains。受击flash常数/shader保持v2字节；粒子由14/18片等距方块圈＋十字改为6/9条1wu细碎屑、方向扇面、独立错开的速度/寿命，奶油/旧铜和nearest不变，不消费玩法RNG。

死亡只由真实当前epoch的唯一lethal receipt开始。即时交接当前身体，不再45%压扁、下沉溶解或满圈发光粒子；短时视觉落体/转身后只有一次3.5%轻压，0.38秒左右收束姿态，落定无呼吸/弹跳/淡出TTL。飞行对象失去支撑后向真实地面落下，不能在空中追踪渡船。保留现有PNG/atlas材质；旧链保存所有混合帧与精确shear矩阵，过渡到既有death atlas；Underworld仍只是一张身体PNG的程序姿态，未假称新画死亡/运动帧。

父类死亡clock/visible/modulate保持只读。尸体树上归stage、生命周期归原presentation/actor，避开正式stage会隐藏dead Motor的问题；安装器替换和host退出立即清理stage sibling及监听。每actor最多一个组件，不生成CollisionObject、音频、伤害或奖励。暂停/慢时沿原时钟，卸载不留孤尸。地形只读mask1向下有限2048探测，真实中心无支撑不发明地板；支撑平移用weakref跟随，支撑消失再有界落出。

initialize dead直接静态重建，不触发flash、碎屑、死亡计数或奖励；initialize alive立即清空。为既有stage先health后position/direction的恢复顺序，在首physics仅再静态对齐一次，不重播死亡。材质尺寸最终收束canonical，避免hurt/telegraph姿态被烘焙后读档变尺寸。新运动/死亡美术帧仍属待制作，整体美术未获认可。

## 真实失败与总控接口请求

首轮native378/0、GPU96/0、support133/0只为早期定位，不移签冻结后的最终源。正式default App strict测试实际62项/1失败，原件formal-v1.log、formal-v2.log与两份restore-probe保留；没有删掉“恢复尸体可见”断言换通过。

实际反例：正式diver在bell_ferry上死亡，尸体随渡船从Actor死亡x2251移动到x2475；原正式保存只有Actor位置2251，reload时渡船相位已经不同，2251向下2048的真实ray为空。不能靠改Actor坐标、伪造浮尸/地板或私设第二套保存绕过。当前房间保留/随支撑和静态地形重建可以局部评审，但移动支撑精确reload没有完成，因此不是可合入版本。

请求总控为现有stable enemy id分配一个版本化、只读的表现恢复片段：稳定support标识（模块实例＋authored平台id，不能用RID/instance_id）、support-local rest pose/朝向；在platform clock/transform和Actor saved position/direction都恢复后解析并重建。缺失/版本不匹配的support需约定静态/退场fallback，不补播death/audio/drop。只调整恢复时序无法找回未保存local pose，除非总控另保证同一支撑可唯一重算。本线不改共享Actor、Stage、region_state/schema或父类；请求只落文档，不当成已分配接口。

## 验证和交付边界

最终独审、专项原件与真实26秒长观测片将在本目录归档。影片两Underworld对象各13秒，真实Router射击、真实HP2→1→0后继续看尸体，末3.5秒检查可见且transform稳定。前后同驱动、Seed、输入、镜头和分辨率，保留raw trace与既有音轨；显式fixture原Courier/简化地面，不是正式美术黄金、自然路线或设备帧率证明。

当前交付是反馈返工检查点。完整正式消费者/Integration、移动支撑存档接口、逐帧美术、用户和真机验收仍未完成；保留之前中央tasks planned/review mismatch和其他远端候选收敛责任，不合main。


长片首轮确实失败（capture-v1-failed-*原件）：采集器按节点名找Remains，但安装器queue_free旧同名sibling时Godot会自动改名新节点，因此漏记真实尸体。6eda仅改观察者读实际presentation.feedback_remains引用，模拟/生产/输入不改。没有放宽末210帧可见/静止要求；headless实际1560帧/6次HP/2次死亡通过后，用新目录重新MovieMaker。6eda四专项独立重跑native378/0、support133/0、GPU96/0，formal62/1同一真实恢复失败，原件final-tests-v2保留。


## EF03-R2：实际悬空失败与修复

6eda真实长片被独审拒绝：diver落稳时主体离地约27–33screen px，因为旋转后的透明矩形空角被当作脚底。旧片/trace/报告完整保存在alpha-aabb-rejected-movies，不把378/96技术通过冒称自然接地。bd8d130改为缓存现有PNG/Atlas alpha>=.5的真实轮廓凸包，随实际rotation/scale投影支持点与横向包络，不改图片或碰撞。GPU新增从实际渲染crop底部像素到真实地形ray的屏幕间距检查，定位实跑98/0，两body及暂停图gap均为0；冻结终源后独立重验另存final-tests-v3。

baseline首轮MovieMaker也真实失败：旧工作树切到5de后忘记刷新import cache，导致EnemyFeedback01Particles全局类缺失、未生成Presentation，错误循环至原300秒timeout。原日志gzip和report保留，未增加预算。补原工具链editor import并用同driver真实headless6HP/2死先通过，再在新目录重采；driver增加缺Presentation时立即退出守门，不把错误画面算作成功基线。


## 最终媒体与实际复核

- [26秒新版](final-movies/after.mp4)：每种怪13秒，死亡后继续观察约9.9秒，末210帧/3.5秒确认尸体可见、settled且world transform完全静止。
- [26秒同条件对照](final-movies/comparison.mp4)：旧charger→新charger→旧diver→新diver，四段均取真实连续源片，剪辑命令/区间在[recipe](final-movies/comparison-recipe.json)。[完整旧片](final-movies/before.mp4)与新片均26.133秒/真实音轨；没有插值或静图动画。
- [原始比较回执](final-movies/comparison-runtime.json)：两轮source_stable；候选clean bd8，基线为5de生产字节＋三个同字节新采集driver未跟踪文件，非clean baseline，metadata完整保留。1560个玩法投影帧、inputs/shots全等，accepted events比较frame/amount/HP/epoch/terminal，忽略各进程不同的event_id Actor前缀；raw trace保留原ID，不声称原JSON事件字节全等。
- [独审](review.md)及[最终独立原件](final-tests-v3/native.log)：native378/0、support133/0、GPU98/0；两尸体实际渲染到底面gap=0。新影片的diver转身/下落/接触/收势邻帧和尾段整图也复查，不以旧失败媒体追签。
- [原Harness四项fresh定向回归](final-affected/report.json)通过：actor-actions、underworld-damage-feedback、underworld-formal、forest-bible-integration-tests。它们不替代[本任务更严格formal62/1](final-tests-v3/formal.log)，更不等于完整146项Integration。

总体独审仍REJECT：EF03-R2的平地真实接地反例已关闭；EF03-R1移动支撑精确保存/恢复仍失败。整体美术与完整逐帧图集、用户/真机和完整正式消费者仍未完成。当前Room尸体反馈可供用户评价，不具备合入条件。


## 运行源恢复与发布元数据

本轮Git CLI的GH_TOKEN已失效（未读取/导出任何凭据）。连接的GitHub接口写入可用，因此用Git Data API发布同一交付树的checkpoint；API生成的commit元数据与本地提交可能不同，不把发布元数据SHA冒称已执行运行源。

[可恢复运行源Git包](runtime-source.bundle)保留942d4ea→6edaed5→bd8d130真实提交，依赖远端已有5a04517；[manifest](runtime-source-manifest.json)记录完整SHA/大小及scripts/tests/tools/assets/resources树。实际执行/录制源始终bd8d130。恢复命令：在具备5a04517的克隆中运行 `git fetch <下载的runtime-source.bundle> HEAD`，然后 `git checkout --detach bd8d130f3677ba80d569f16c05feee1977450c02`。bundle verify实跑成功。发布时逐blob及最终tree对照本地Git SHA，branch只做带expected-head租约的fast-forward，不强推/合main。

本轮docs profile实际前7项通过，quality在中央任务planned/本卡review不同步处失败；[原日志](final-docs/quality.log)保留。单卡格式一致、diff写集守门和project/docs静态检查通过，内容仍REJECT；不把它们改写为整体验收通过。
