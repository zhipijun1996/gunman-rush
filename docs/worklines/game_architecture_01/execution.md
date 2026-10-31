# 架构迁移执行记录

内容底座：`2ce4ffa64ef65dd5fba892776eea019c9e2841d4`（PR122/124/125/107，排除PR123）。主工作树 `/workspace/gunman-rush-refactor`，分支 `refactor/game-architecture-02`。用户要求持续完成且再次明确可用subagent并行；采用6个隔离实现/审查代理，root统一引擎验证。

## 已整合的实际调用关系

- `DemoApp → RunSession / RunComposition`：真实创建/清理迁移，一个Flow/Lifetime/Wallet/Build；Session不暴露给地图、敌人、道具。
- `DemoApp → LevelRequest → 两区Provider → LevelPlan → LevelRuntime → 现有Assembler/模块/EnemyFactory/BossFactory`：原算法与旧Manifest回退仍在旧Provider；裸Plan不需旧Manifest即可装配。旧Stage的表现/记录仍有Manifest适配层，不宣称整个旧入口已无此依赖。
- 三个Stage快照/一个App恢复点 → Actor/Behavior的共同状态协议；保平原11字段、森林8字段+专属depth及原String/StringName键类型。候选身份只由现有Registry定义。
- Shop修复 → Build → Inventory受限提交/回滚；Shop扣款/退款/Session清空 → Wallet；收益效果 → Runtime收益命令；两个主动族 → 同一ItemActiveCast。Time仅接窄能力上下文。
- 四Study + tests shim → 唯一生产WorldAudioLifecycle。音频nearest owner/Cloud重复服务/按钮重复响是独立旧缺陷修复，不混称等价。
- 绘制 → 一次姿态预处理 + UV权重 → 唯一顶点计算；旧deform入口仅委托同核。

## 实际验证与失败保留

P2原core/generated-consumers/forest-campaign通过；P4九项原道具family通过；集成P2/P4会话49/0。新地图146/0、实体61/0、共享施放13/0、四Study完整切换65/0。原森林80/80路线473.659秒，在原600秒内通过（源6b3df3f7，仅性能批+内容底座，不代签后来整合）。顶点367640逐字节等价5796/0，原motion481/0。

原/新音频释放16case对照80/0：同帧play→stop均保留待启动引用，物理启动后停止均释放；旧限制单列。先前失败包装marker、WeakRef推断、错误测试同帧假设、快照键类型差异、裸Plan空数组类型错误日志全部保留；修复后数据不覆盖失败原件。

现有Harness完整检查由172增到181，原172及预算保持。原自动跨job计划重复78次移除，实际Web仍在full生产并由消费者核同源完整指纹。architecture guard复用原structure，另有12项反例；动态加载仅披露，不冒称已静态解决。

## 第二轮原回归（源 d8144d39）

原14项计划实际执行13项：12通过；item-v5-formal的191断言全部通过，但严格清理检查发现57个ObjectDB实例和25个资源泄漏，整项失败，gear-inventory因fail-fast未执行。原基线同formal191/0且清理通过，作为本轮集成回归定位，不降低检查或清缓存掩盖。原日志见[完整运行报告](../../evidence/game_architecture_02/original-regressions-02/report.json)。

历史v11定义漂移另已由原内容基线重现280/2，独立修复afca59ec把原定义版本从生成器传至实际实体，不修改当前/v15资源。源端静态独审限定接受；原生和实际PCK验证仍待执行。Shop两个购买命令也已迁移到现有receipt重放函数（7be23e5a），原验证/扣款/信号顺序不变。

## 尚未完成

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
