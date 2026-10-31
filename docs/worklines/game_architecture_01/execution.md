# 架构迁移执行记录

内容底座：`2ce4ffa64ef65dd5fba892776eea019c9e2841d4`（PR122/124/125/107，排除PR123）。主工作树 `/workspace/gunman-rush-refactor`，分支 `refactor/game-architecture-02`。用户要求持续完成且再次明确可用subagent并行；采用6个隔离实现/审查代理，root统一引擎验证。

## 当前执行点（生产 a6714757，测试迁移49a298b4）

1,124 文件功能迁移与真实共享调用已完成。P9恢复所有权为 `4e91a0dd`，固定工具链真实发布安装为 `59537400`，独立Underworld生命周期缺陷修复为 `a6714757`。三份生成索引仍声明源 `6f743953`，等待root按最终源重生；不手改旧计数/来源以冒充当前图。后文阶段记录保留当时的“待验/失败”，由本节及末尾新增结果更新现状，不回写历史原件。

八个Boss/共享消费者测试及两份测试依赖已提交49a298b4，region actual03已完成current15（224.151秒）；完整182、Foundry最终、实际Web/Windows/Android游戏导出与GUI未验。统一新地图库及新算法尚未实现，现有Provider仍调用旧算法。工具链发布不等于游戏发布。

## 已整合的实际调用关系

- `DemoApp → RunSession / RunComposition`：真实创建/清理迁移，一个Flow/Lifetime/Wallet/Build；Session不暴露给地图、敌人、道具。
- `DemoApp → LevelRequest → 两区Provider → LevelPlan → LevelRuntime → 现有Assembler/模块/EnemyFactory/BossFactory`：原算法与旧Manifest回退仍在旧Provider；裸Plan不需旧Manifest即可装配。旧Stage的表现/记录仍有Manifest适配层，不宣称整个旧入口已无此依赖。
- 三个Stage快照/一个App恢复点 → Actor/Behavior的共同状态协议；保平原11字段、森林8字段+专属depth及原String/StringName键类型。候选身份只由现有Registry定义。
- Shop修复 → Build → Inventory受限提交/回滚；Shop扣款/退款/Session清空 → Wallet；收益效果 → Runtime收益命令；两个主动族 → 同一ItemActiveCast。Time仅接窄能力上下文。
- 四Study + tests shim → 唯一生产WorldAudioLifecycle。音频nearest owner/Cloud重复服务/按钮重复响是独立旧缺陷修复，不混称等价。
- 绘制 → 一次姿态预处理 + UV权重 → 唯一顶点计算；旧deform入口仅委托同核。
- P9：Stage capture/setup → ShotLatch自身快照/恢复/永久打开账本 → 原平台restore_motion；App terminal重入 → Director.prepare_terminal_stage_reentry；App普通/Pressure两处场地恢复 → 对应Encounter → Arena。七字段、调用顺序及两类断桥规则分开保持。
- a671独立缺陷：Underworld node_added → 节点/world WeakRef延迟入口 → 存活/原world身份/当前归属校验 → 原typed install_item。同步安装和活节点延迟表现不变，已失效任务被安全丢弃。

## 实际验证与失败保留

P2原core/generated-consumers/forest-campaign通过；P4九项原道具family通过；集成P2/P4会话49/0。新地图146/0、实体61/0、共享施放13/0、四Study完整切换65/0。原森林80/80路线473.659秒，在原600秒内通过（源6b3df3f7，仅性能批+内容底座，不代签后来整合）。顶点367640逐字节等价5796/0，原motion481/0。

原/新音频释放16case对照80/0：同帧play→stop均保留待启动引用，物理启动后停止均释放；旧限制单列。先前失败包装marker、WeakRef推断、错误测试同帧假设、快照键类型差异、裸Plan空数组类型错误日志全部保留；修复后数据不覆盖失败原件。

现有Harness完整检查由172增到181，原172及预算保持。原自动跨job计划重复78次移除，实际Web仍在full生产并由消费者核同源完整指纹。architecture guard复用原structure，另有12项反例；动态加载仅披露，不冒称已静态解决。

## 第二轮原回归（源 d8144d39）

原14项计划实际执行13项：12通过；item-v5-formal的191断言全部通过，但严格清理检查发现57个ObjectDB实例和25个资源泄漏，整项失败，gear-inventory因fail-fast未执行。原基线同formal191/0且清理通过，作为本轮集成回归定位，不降低检查或清缓存掩盖。原日志见[完整运行报告](../../evidence/game_architecture_02/original-regressions-02/report.json)。

历史v11定义漂移另已由原内容基线重现280/2，独立修复afca59ec把原定义版本从生成器传至实际实体，不修改当前/v15资源。源端静态独审限定接受；原生和实际PCK验证仍待执行。Shop两个购买命令也已迁移到现有receipt重放函数（7be23e5a），原验证/扣款/信号顺序不变。

## 当时尚未完成（后续P8/P9与工具链进度见新增记录）

- 整合后的原core/生成消费者/森林保存与实体/道具/Boss/音频回归正在排队，完整181/GUI/实际导出待最终源冻结。
- P8.1已冻结旧style25/creative28有限原源（精确4bb7aa96）；当前live绑定仍失配，必须在全部调用者迁移后一次升技术style26/creative29，不重签旧SHA、不换图声。
- P8.2按功能路径迁移、动态与协议路径审核、35入口逐项盘点、全文件用途清单与最终依赖图仍待完成，不能以目前新目录或新增接口冒称全仓重构完成。
- 原能量初始化失败无回滚、Inventory patch失败后效果拒绝的原事务局限、同帧音频停止限制单独保留，不混改玩法。

每批回退父提交由Git历史真实记录；重构整体回退底座为2ce4ffa6。原dirty `/workspace/gunman-rush` 从未套用/覆盖。

## 历史缺陷与后续对照

源5a15414a：新历史v11真实App专项45/0、raw-export计划反例19/0；原完整forest-depth-versions、core、gear-inventory、item-v5-economy四项全部fresh通过。真实PCK仍待最终导出，不以源码计划代签。见[原始运行报告](../../evidence/game_architecture_02/legacy-and-shop-01/report.json)。

正式道具退出泄漏二分首次出现在地图接口761adec5：其父f44无泄漏，但另有一次原心形多边形绘制错误，不记该运行全通过；2ce内容基线严格formal通过。解除Runtime/Assembler直接依赖环cd71c538（主树7b5ad80d）已独审并保模块循环逐语句顺序；对照仍57泄漏，明确不是泄漏修复。正在进一步定位，原失败全部保留。

## P8 实际整合与当前阻断（源 6584d48b）

功能路径整合提交 e4915fa8，后续工具与边界守门至 6584d48b。已迁移 1,124 个文件；491 个 UID 配对保持。图提取器当前 842 源、510 类、3,450 静态边，118 个动态表达式仍须按消费者验证。原 181 项前缀保留，追加真实 v11 定义检查为 182（95/87），不代表全部运行完成。上文 P8 尚未实施及181数量是较早进度。

最新原 Harness 六项全 fresh 通过（报告 `20261031T051250.127716Z`），包括 Bell 八组真实原生消费者、地图146/0、enemy结构、Study65/0、owner84/0、v11 45/0。详见[原报告](../../evidence/game_architecture_02/post-layout-01/native-six-report.json)。正式道具 warm import 后仍191/0与57/25退出失败；cold import 的四条字体错误和运行时类型候选失败都原样保留，候选生产改动已回退。解除直接依赖环不是泄漏修复。

上游 Godot PR117991 的五行脚本基类引用清理修复正在独立构建对照；官方4.7.2工具链未变。修复涉及脚本卸载与语言结束，不能说只影响quit；任何后续采用须以真实差异和严格验证为据，不能绕过版本守门。

当前在收口一次 style26/creative29 技术版本绑定，补齐真实203引用及既有缓存输入；历史style25原件不回写，图声字节不改。独审发现遗漏入口路径与旧测试路径，逐个迁移其真实消费者，原断言保留。仍需最终源完整回归、35入口覆盖、既有Foundry重建、实际导出/raw旧定义PCK隔离、GUI与公开版本核对；未执行不标通过。

## P6B 与固定引擎修复选择

063d6ccb独立提交8文件，Boss健康/家族快照/决斗恢复与原非duel位置恢复移回现有Encounter；两个Stage和App真实委托，原forest测试三处调用同步，41个check和负例不减。原Bell/Pressure/core/forest-depth-restore已过；入口回归的三次实际路径/技术metadata失败已分别修正，四批合计11个不同check通过，见closeout-02各原report。其dirty状态和精确源仍各自保留，不签full182。

用户2026-10-31明确选择“采用固定的上游修复版，继续完整验证（推荐）”。独立A/B/C证明完整上游117991+120976四文件修复使最新原formal191/0且严格退出通过，单五行修复失败仍保留。正式工具链在fix/godot-shutdown-toolchain-01隔离建设，拟固定源码/补丁/容器/SDK和实际产物SHA，保Web、Windows、Linux及现Android能力；不把O0诊断binary或官方模板混装当作正式交付。完整182/目标平台/真实PCK与GUI继续待验。

## 原文档与工具消费者完整收口

原docs33在bc576b63及报告记录的候选写集全部fresh通过，318.136秒；源projection/fixture两根、保留P1路径、当前与历史文档引用、旧metadata证据及森林真实Provider链均已迁。旧失败和独审原件位于static-closeout-03。森林源码观察采用有限单行词法与有序调用检查，明确runtime_available=None，不等于执行可达/正式开放；原36测试保留、新6反例已接原入口。未新增运行registry或修改玩法。

引擎构建390的Android原生库完成，但Gradle查找scons失败；仅锁定命令入口补丁184970c7重建全部10lane，保同commit/run门禁，未拼旧成功包。安装器62eceec4及补丁已有独审，真实完整产物和原182/实际PCK仍待验。


## 2026-10-31 换模型暂停节点

用户要求先暂停并留下后续指导。暂停前05c3干净源上38个诊断启动检查完成，source_unchanged=true；独审仅接受启动/清理。随后三个原音频脚本按180秒预算运行：Lab25/0、V2 66/0，Reels126/3（enemy_hurt A/B/C候选播放次数）退出1，116.009秒；未定位原因、不修改断言或生产代码。完整日志、报告、独审和构建快照见[暂停证据](../../evidence/game_architecture_02/pause-checkpoint-04/index.json)。

本地引擎与持续监测结束，远端41180438395不取消；Windows debug已成功，其他任务接手再查。正式工具链仍官方、未发布新Release/重构PR或预览。详细接手顺序与回退注意见[continuation_guide](continuation_guide.md)。


## 2026-10-31 恢复：AUDIO-LAB-MATERIAL-01

精确main2ce同C原126/3，确认旧缺陷；修复只为显式hurt试听委托原候选播放器，正常材质路径保留。原126逐字可还原，增加28实际stream/计数边界。C154/0（116.478/180）、优化editor184 154/0（32.176/180），1905文件源码向量一致并独审。实际editor产物与构建命令已独立核，优化生命周期28/0+负例4/0，原正式191/0严格退出及V2 66/0补充通过。完整工具链锁仍未激活，full182/GUI/导出未完成。证据及未签范围见独立修复说明；不冲销原失败或代签正式音效听感。


## 2026-10-31 OWNERSHIP-02 有限实现收口

7生产/4测试冻结，原schema与调用顺序独审通过。actual optimized editor预检11调用及Bell8套全过；core5686、Session54、Latch26、Windkeeper175、Pressure六组0失败。扩大region第3套旧cohesion19/5失败，精确ed95同引擎也19/5，原测试与源未改；因此独立CI-BOSS-CONSUMERS-01测试迁移，P9卡expanded criterion明确failed而非完整通过。原scope/spec/候选SHA及所有成功/失败证据在ownership-closeout-02，整个full182未验。


## 2026-10-31 已提交工具链、P9及独立生命周期修复

P9七生产/四测试已提交 `4e91a0dd1d6c02e6a7466368e91665d2a6a7a71a`。Scope此前为2e1c，不能再将其叫作仅候选；11原生预检与Bell8真实结果见上文，扩大cohesion19/5及同源ed95对照仍是失败。P9整体回退点为 `ed95d67d8c19988ab6af3b720aa07a17fd1f59cf`，包含随后范围文档应按批处理。

工具链提交 `59537400af06a26046037840e28989f75933a265`：4.7.2官方源加精确117991+120976的Standard custom，10lane同source184/run41180438395构建；editor4成员、模板18成员、8个分发文件实际字节与重包一致，独审通过。f91 promoter的run41188433036已将固定tag184的Release429822541公开为prerelease；八URL实际HTTP200/SHA通过。当前lock精确84522f…，主树原安装实际通过，原26 downloader/build/identity及91 Harness单元通过。身份、模板与缓存消费者已迁，原预算保留。回退基点 `4e91a0dd1d6c02e6a7466368e91665d2a6a7a71a`；回退仓库配置不等同删除已公开工具链Release，也不覆盖保留的官方控制安装。原A/B/401/415/元数据拒绝失败全部保留，源及证据见[已归档工具链结果](../../evidence/game_architecture_02/engine-toolchain-01/active-main/active-toolchain-main-integration-independent-review.json)。

独立生命周期修复提交 `a6714757ed59aa698027669ed2f11d8f346d4a93` 仅UnderworldPresentation及原formal测试扩8项，回退点 `59537400af06a26046037840e28989f75933a265`。精确2ce诊断319条deferred参数错误说明原缺陷；首轮导入失败不当复现。修复后原formal96+8=104/0、cache444/0，11.549秒，原wrapper120秒及Harness150秒不变且严格退出通过。[报告](../../evidence/game_architecture_02/underworld-deferred-lifetime-01/native-01/report.json)运行时还有精确测试WIP向量，本提交只绑定生命周期两文件及其结果；不把共享quality测试迁移混称等价生产修复。

## CI-BOSS-CONSUMERS-01 当前八测试迁移已提交

原五文件迁移复用现有campaign helper，让当前Bell/Pressure走真实死亡、实体币和切图；Energy第六文件锁明确历史16HP测试资源与来源，原540断言/循环/预算保留，不修改当前40HP定义。Pressure第七文件分类保留完整D077旧合同为 `--legacy-d077-boss` 显式诊断，默认检查原共享背景/App/Camera/Run→Home；这是覆盖分类调整，不能把当前Bell8/Pressure6套称为旧D077算法等价。quality第八文件把正式map1身份显式核为Bell，六模式继续检查，phase_transition遵现有solid copper规则，intro/inactive负例保留并加dead负例。

八个最终测试及两份测试依赖已提交49a298b4。先前quality1044/1及317条deferred错误保留：前者属于当前Boss身份失配，后者已独立由a671处理。region actual03全部current15已通过（224.151秒），原五个共享wrapper另有分次有限通过；full182仍未执行。技术binding仍待最终收口，不将历史D077延期、未跑legacy27或旧失败改签为通过。

剩余执行仍是当前源完整182、最终入口有限交互（Foundry不能只等ready、Graybox RESET与旧Boss8/AudioLabs/named roots不能拿启动代替交互）、Foundry原重建/录制/导出basis、实际Web/PCK和Windows/Android游戏导出运行、GUI/设备与公开网页提交核对。新统一地图库、新算法和旧算法整体替换未实施。所有回退按后续依赖逆序操作；上述基点是版本边界，不授权覆盖当前未提交工作。
