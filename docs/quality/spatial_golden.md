# PR72后空间黄金生产：当前证据与验收

**最终：艺术REWORK，未达到本轮核心黄金空间交付标准。** 真实可玩实验与生产守门已有进步，首G2未准入，按14:49UTC艺术预算停止；第二结构、多Seed及最差Seed均未制作，不能声称有限库稳定复现商业品质。

直接证据：[PR72原实机](../evidence/spatial_golden/media/pr72-before.mp4) / [当前18.35秒正常速度实机](../evidence/spatial_golden/media/spatial-v2-current.mp4)；[之前截图](../evidence/spatial_golden/media/pr72-before-frame300.png) / [当前反冲](../evidence/spatial_golden/media/current-recoil.png) / [RootBell](../evidence/spatial_golden/media/current-rootbell.png) / [高台回望](../evidence/spatial_golden/media/current-lookback.png)。[最终独审](../evidence/spatial_golden/final-macro-independent-review.md)保留失败，不代签用户/设备。

可复现运行树`26cf2267da84f22d2a1a0004e1dd7223a37482fd`；最终录像与原包构建实际HEAD为`27c63f948d17fe01a42936784700b56a2bcff89c`，当时我漏add实际使用的布局JSON。后续仅补相同字节，原电影/原构建标记不改签；[逐路径闭包校验](../evidence/spatial_golden/final-runtime-tree-closure.json)确认1118份source_before在26cf中全部存在且SHA256完全相同。


任务`SPATIAL-PRODUCTION-01`、`SPATIAL-GOLDEN-01`，基线PR72 `1597db583a6ade25a469cb9ecb99b5762d6f76db`，开发分支`feature/spatial-golden-production`。沿用用户已选择的“逆风送钟的草海”。这是隔离空间实验，不自动加入正式随机池，不改写上轮RETHINK。

## 为什么规范存在而画面仍回到矩形覆材

[源码审计](../evidence/spatial_golden/root-cause-audit.md)逐项对应Skill、路由、租约与真实消费者。保护基础玩法的无条件表述冻结了局部布局/相机；黄金实现缺visual/scene/encounter联合职责；原黄金仅G0/G1，扩产先于实机独审；原表现消费者只与现成矩形求交覆材。笼统目录写权限其实已存在，不能误报为引擎或harness禁止任何几何修改。

本轮在原route/production_loop修正这些边界，不新增Skill或质量框架：显式空间合同冻结总谱SHA与精确写集；核心契约不开放；黄金必须当前G2真实媒体/实际独审且整合首次lease再次核验。独审曾发现quality_record越权、旧总谱绑定和伪媒体准入三项P1，原REJECT与修复复审均[保留](../evidence/spatial_golden/control-independent-review.md)。

## 真实制作与当前边界

新`PlainsSpatialGolden`在组装前消费版本化布局；碰撞和绘制共用真实多边形。原DemoApp显式flag启用，原PlayerMotor/输入/武器/资源/保存/RNG不改。正式普通入口保持原生成器，实验包不等于正式发布。模块库是一张六件独立atlas，实际消费其中五件；另复用已有石材/草顶/天空/远山。没有整屏专绘、逐Seed生成图片或概念图冒充游戏。

| 实机候选 | 实际观察与决策 | 后继 |
| --- | --- | --- |
| 01 | 真实20.35秒/60fps、完整去返；拼山横缝、草比例、远钟连接/根基及HUD失败；独审REWORK | 禁止第二空间 |
| 02 | 消除拼山横缝、改善层级/比例/HUD；与01逐tick物理和事件一致；远钟柱脚悬空，独审REWORK | 禁止第二空间 |
| 03 | 同视差承重岩体接柱脚，真实20.35秒/60fps与01同轨迹；独审RETHINK：主要动作窗围合/焦点仍弱且远景岩基有假落点风险 | 禁止第二空间，回联合布局 |

原始失败、源码快照、逐tick与原比较器结果位于`build/spatial_golden/`，不覆写。PR72同Seed/map1 before_02由干净原提交实际重采20.083秒；旧路线20秒内未完成，不能签旧玩法通过。由于空间与相机已重构，新旧只作同Seed重构观察，不冒充严格纯美术同轨迹；01→02/03才符合原比较器。

## 当前验证与成本

三项受影响Python模块共144测试通过，45.751秒，实际命令包络45.914887秒，exit0；日志`build/spatial_golden/final_python_control_01.log`。实际CLI成功生成当前总谱/布局绑定的五任务mission，但只是计划，没有声称这轮经新host全自动生产。

路线原生正例与不射击/移除恢复岸负例使用真实输入、HP、能量和实体支持，不搬角色、不补资源、不禁AI。负例采证工具exit0表示成功记录失败路线，不表示游戏路线成功。完整原生路线HP5保持、四次射击、活RootBell/机关和连续返回、严格退出；不等于真人可玩性认可。

一次新图生成44.750秒；01/02/03共享采证完整管线分别170.81/113.07/120.20秒，同为20.35秒60fps。后两次没有新增图片。录制为软件渲染MovieWriter，耗时不能作实体设备FPS比较。实际阶段账本`build/spatial_golden/stages.jsonl`；未获token/价格数据不估算AI金额，也不把并行包络相加冒充总耗时。

艺术G2、用户/设备、复用第二空间/随机最差Seed、完整CI和发布须各自有证据。历史森林/encounter阻塞不在本次范围，未以本轮局部绿覆盖旧失败。

一次宏观RETHINK预算截止14:49UTC：缩短为2000×1350，入口爬坡、升高裂隙、活RootBell观察岸、再升100的回望台；左右真碰撞钟肋向中间延伸并与实际镜头同设计。先原生路线/普通相机截图，不成立即停；不是第四轮覆材补丁或提前第二空间。路线driver改为读取实际同一合同，不写角色位置。真实采证：首次坡折出生点被原安全检查拒绝；仅补64px水平出生台。probe185ticks/1枪成功，无枪192ticks/0枪与删岸213ticks/1枪均实际坠落失败。首full1119ticks返程撞锯失血/换session，且host ALSA未配置造成严格ERROR；均保留红证据。仅把返程起跳点1740改1780，不改物理/伤害/资源/断言。新full02共1096ticks、4edges、4shots、HP5、同session、0returns且strict exit0，89.09秒。正式最终录像在提交27c63f948d17fe01a42936784700b56a2bcff89c后重新采证，旧并发启动attempt中止保留，未改签提交。

## 对本轮自身失败的判断

真实多边形和前置独审已经能阻止错误方案扩产，却不能自动提供商业画面。前三版把“共同空间创作”过度收缩为可通行三岸+旁置地标，资产只有柱/钟/草，实际地形仍主要靠通用石材连续填充。宏观重构才把钟肋与动作真正放入同屏；这证明旧的矩形并非不可替换，也暴露了“物理轮廓变化”与“有艺术身份的完整空间”之间仍有差距。

本轮先制作六件atlas、后用真实正常镜头检验首空间，是生产顺序仍不足的证据；新增媒体守门本身不修复这一创作缺口。不能把更多技术绿、资产件数或G2表格当成画质改善。后续若继续，应先在真实相机内批准进入/反冲/观察/回望的完整大形及材质体积处理，再决定有限轮廓件/拼接族；本轮不追加空规范或再开同义Skill冒充已完成。

多专业协同是真实的：level作者负责同一JSON的实体地形/敌位/机关/相机，root负责读取该JSON轮廓/架构锚点的有限美术组装，验证作者只用实际Motor输入并回报坡折出生/返程撞锯，独立像素作者连续拒绝不成立的构图。协同与工程可玩进步不等于黄金已经合格。

## 最终停止与交付

候选04的首反冲/RootBell/抬高回望已是新的真实空间。最终独审仍REWORK：frame240/960钟肋方切和错层、岩梁覆铜件的拼接感；入口/返程草遮住腿和部分身体；frame480/720锯盘部分嵌入高台前沿，实际危险不够直观。完整录像18.35秒、1101视频帧/60fps、1280×720、实际音轨；独审实际查看全20采样帧，未完整正常播放或听音，不签声音/真人手感。没有用技术通过覆盖艺术失败。

有限库真实消费：一张6件atlas中5类、20个实际Sprite实例，另4张既有空间纹理；[实际node/parent/Atlas region/世界变换与来源](../evidence/spatial_golden/actual-finite-library.json)。第6件wedge未使用，不虚计复用。仅证明一个空间内的模块实际消费，不证明第二空间或随机稳定性。Seed当前仍只标识该固定实验布局，没有实现跨Seed结构生成，最差Seed未测。普通三个preset排除新kit，未作默认PCK包体排除验证，不能宣称所有实验脚本字节都不入包。

最终闭包后只重验受变化影响的5项空间守门和19项路由（2.563秒/0.770秒，退出0）；此前144项Python45.751秒、控制独审三P1修复接受保留原范围。最终原普通home_app_runner19断言/0失败、严格音频释放，4.099秒。135个基础契约文件最终再次逐字比对PR72，差异0。完整CI/正式发布/手机PC实体设备/手柄/用户艺术或趣味认可未执行或未通过，历史forest/encounter红不改签。

本地Linux手动试玩：`build/spatial_golden/local_review_02/gunman-rush-spatial-review-linux-x86_64.zip`，解压`bash play.sh`，build_id `91f6c28c117a`，ZIP171156645字节，SHA256 `bdc049e0d1a852e66cdba10117c027dd63449a925ec1f8d92225a31fe5fa2fa2`。附官方Godot4.7.2，不自动驾驶、不注入能力、不写Meta。隔离空目录由PCK真实启动、ready与原清理完成、exit0无Godot/泄漏错误；不是正式发布包。[准确版本](../evidence/spatial_golden/local-review-version.json)、[启动日志](../evidence/spatial_golden/local-review-pack-smoke.log)。

包导入8.916秒、导出6.567秒、隔离启动4.102秒，成功包络31.602秒；首许可提取错误依赖显示环境失败1.940秒，原日志留存，仅build脚本改headless许可提取；闭包说明仅README/version重打ZIP9.313秒，不重导出、不冒新启动。PCK99001340字节不变。约39.36MB精选对照媒体作为审计证据，不属于正式运行资产。所有模型token/单价和实体性能未知；不编造金额或笼统“效率提升百分比”。

明确未完成：合格黄金艺术空间、通过准入的第二结构、多个随机Seed与最差样本、有限资产库的跨空间稳定复现、完整自主host生产、商业/玩家/设备与正式发布。下一轮应重新建立可信钟肋/地形轮廓拼接和动作窗的大中小形体，而不是继续增加草、远钟或技术测试；本轮不再扩产。

实际full02与最终movie的玩家位置/速度/HP/能量/动作/相机逐tick一致；锯与RootBell存在一物理tick初相位差，跨进程事件owner/ID不同，原值保留在final_native_movie04_trajectory_comparison.json，不能声称整个仿真逐帧相同。可观测起始时钟13:42:54UTC，艺术生产按14:49预算停止；账本只计实际工具命令包络，不覆盖全部Agent思考/等待或API账单。流程记录一致性ACCEPT仅签流程范围；内容记录明确REJECT/blocked。
