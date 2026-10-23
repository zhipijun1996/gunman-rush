# 2026-10-23 四条工作线集成

## 2026-10-23 当前验证收口（最新）

实现冻结于 `a861406e699e95553b56a7f1a53edbafe4da7cfd`。12f6 CI实际88通过／BGM失败／53未执行；补跑其中50项实际47通过、家园和图一两路线失败。现仅修四个测试文件：真实200ms音频等待、当前标题到家园的真实点击、森林跳跃松键时机；原预算／目标／资源不变，运行代码未再修改。BGM89/0、家园181/0在精确a861原Harness fresh通过；森林两图四条原wrapper24/24、32/32、35/35、43/43在明确候选覆盖源通过，连续腾空及原目标保留。三专项及最终采纳独审限定ACCEPT，不替代下一最终PR CI或G5。

最新[可玩开发Preview](https://zhipijun1996.github.io/gunman-rush-previews/previews/FOUR-LINE-INTEGRATION-01/a074a709ffa64c1382d73d2dab6dcff673222728/d38c8a407473/)为a074／d38c8a407473，完整公开包与真实浏览器已核；后续测试修改不改签旧包。main尚未合并，正式站仍旧版。下一步只推一次冻结head，完成原Integration后按用户既有授权普通合main，再核main自动Release。[失败／证明／独审／提效审计](../evidence/four_line_integration_20261023/final-synchronization/README.md)保留准确来源。以下为历史时点，不代表最新结果。


## 2026-10-23 当前 HUD 与资源契约集成（冻结检查点）

实现冻结 `cc46ff5bb84dac1d7946fcc0e55bf1cfa487b92f`，PR [#106](https://github.com/zhipijun1996/gunman-rush/pull/106) 的下一次精确 head Integration 尚待执行，main／正式发布尚未完成。本节记录冻结时已知事实；随后合并和发布状态以该 PR、Actions 和实际公开构建为准。

当前免费射击／基础空中一发保留；共享验证绑定实际配置、投射物身份和真实 AirFocus 流水，旧付费断言不回写。纯旧 v9 自主路线与可选 encounter 历史比较移至显式手动 `legacy-compat`（现15项）；当前检查不伪称历史通过。

实际修复新 HUD 的位置标签压左摇杆，以及新导航覆盖既有避敌布局：App 在控件真实尺寸确定后沿既有边缘候选避让，使用真实缩放范围、触控／控件保留区和稳定位置缓存，不移动游戏身体。共享画风为 HUD 专用 v9 绑定、两区 creative-v12；原 v7／两份 v10、其他35引用及全部像素保留。

原 scene wrapper 候选完整通过：8场景94/0、10真实负例和15数据篡改拒绝；两实际引擎分片共133.386秒，全部8场景的父总预算仍180秒，wrapper共226.592／900秒。原 HUD R3 为140/0。家园／区域109/0、奖励跨区56/0、菜单触控44/0各自实测；Canopy使用官方 cab 原捕获离线全验与8拒例，不冒称重新录制。Experience保原332/0捕获，最终reader离线49拒例；encounter full3保持失败，最终reader尾段、剩余真实 nonkill 和29原单测通过，不冒称fresh完整 wrapper。最终cc46ff5另外收紧JSON合并后的总时限守门；两真实分片输出离线回放的正常情况通过，合并超时／子进程非零／缺标记／子超时／缺覆盖均拒；未重录native。上述候选与原冻结9a9eb86的32／10／29／16／21 Python测试及文档检查分别保来源，不替代下一轮全 CI。

上一轮 cab CI 为75通过／2失败／66未执行，两个实际失败与修复证据均保留。精选原件、压缩恢复 SHA 和审查见[当前证据](../evidence/four_line_integration_20261023/current-plains/README.md)。[四线可玩 F 开发版](https://zhipijun1996.github.io/gunman-rush-previews/previews/FOUR-LINE-INTEGRATION-01/fbb417cb4d4d4d8d2500d7c4bed11cebf681dd46/7f88f353bfb4/)仍属于 F／7f88f353bfb4，不能称为本轮 HUD 修复或 main 新版本。最终新 Web／Windows／公开版本验证及用户／实体设备仍未验。

## 2026-10-23 当前 audit 与 CPU 隔离修复（最新）

实现冻结`ca371639209e7dbe5a4a5e4c034bcf2613a36d23`。上一轮精确5502 CI真实66 passed／1 failed／1 timeout／75 not_run：current audit误带历史输入与旧raw Manifest字节复现；森林80和另9项引擎检查争CPU，在37例通过后触发原600秒。失败与源码归属保留，不改签本地5502原80/80（369.678秒）的通过结果。

现在`--current-g1`明确贯穿Python→Godot runner→当前40图audit：原当前生成／实际tuning hash／候选验证、物理10与准入11反例保留；旧rawbytes明确not_run，手动历史audit原正文保留。缺失历史fixture的真实隔离环境已通过32.140秒，另8个范围／配置反例全部拒绝；ca3716的原Harness fresh同样通过31.806秒。森林完整80改为独占Harness，保原80／native240／import90／总600，未增预算。`--disable-render-loop`实测仅1%–4%波动，已拒绝采用。

最新源码仍待下一轮精确Actions结果；main尚未合并／正式发布。沿用已验证的F开发试玩，链接与source/build身份见下文。原始CI报告、当前真实消费者与限定独审见[修复证据](../evidence/four_line_integration_20261023/ci-current-fix/ci-5502-identity.json)。后续只处理真实当前失败，不扩历史兼容。

## 2026-10-23 当前源码冻结与可玩开发版（最新）

实现冻结于 `4ef092e889f187da4ce1030b1c87146456d5d30f`。当前平原15项原suite在cbce源全部通过（165.948秒），同源完整森林敌人检查通过；森林图二fast30/30、growth46/46与5个反例在各自收据源通过。c934源完整森林语料在45/80全部通过时主动取消，不是完整通过或超时；原始捕获已无损归档并逐文件核SHA。为避免固定双进程预计约717秒耗尽原600秒，当前corpus默认有界4进程，可用`--case-workers 2`适配低核环境；非corpus仍串行，全部80场景、240秒native、90秒导入和600秒总预算不变。14项真实子进程检查通过，独审仅签实现范围；新四进程完整语料与最终Actions尚待执行。

[四线组合开发试玩](https://zhipijun1996.github.io/gunman-rush-previews/previews/FOUR-LINE-INTEGRATION-01/fbb417cb4d4d4d8d2500d7c4bed11cebf681dd46/7f88f353bfb4/)已由独立Pages工作流39920819858实际发布。它复用真实F源`fbb417cb4d4d4d8d2500d7c4bed11cebf681dd46`、build`7f88f353bfb4`，不冒称最终源码或main已合。公开完整184478012字节PCK与SHA一致，真实Chromium点击进入平原、爱心HUD与输入后非零混音通过；五曲听感、手感、用户审美及实体设备未验。完整游戏实际默认地图Seed为`level-design-v2-baseline/08`，与Preview标签`four-line-review`分开记录。两旧开发包可恢复归档后，全站635.029MiB，正式站尚未替换。

[原始收据与限定独审](../evidence/four_line_integration_20261023/final-current/preview-F-delivered.md)保留各自来源。PR #106等待精确新head Integration，成功后按已授权普通合入main，由原Release/Web/Windows/公开版本检查发布。旧兼容仍仅手动延期，未执行不得记通过。实际回收约654MiB废弃导入缓存/中断包；当前输入准备约353秒/3.3GB仍是后续专项，批量Git读取/输入缓存另做，不在本次集成继续扩框架。

## 2026-10-23 当前 Demo 集成范围与提效修正（最新）

当前森林v15的fast/growth已在同一候选源分别真实完成28/28、23/23段；旧双发程序改用合法挂点跳脱/已有钩索再接近，实际执行与原来源程序分开记录，不称旧RHR通过。原几何、目标、HP/碰撞、事件身份和时间能量回放继续严格验证。headless鼠标使用项目实际1280×720窗口，修复64×64默认物理窗口导致的新UI过大。敌人低能量样板用真实AirFocus消耗，不再以免费射击伪造耗能。候选证明限实际两条路线，完整80例仍由当前正式检查执行。

另将固定旧Queen/v7战役、v10 expedition/root-entry及旧双发/射击扣20的air/cavity三微场景延期至manuallegacy；它们未作为当前通过。当前geometry仅按实际经过实例验证，不声称fast替代完整cavity微场景验收。平原region默认保全部15个current suites（含原150种子/50自动族与实际App baseline、lifecycle/Boss），27个旧独立v10整图走法通过`--with-legacy-fixtures`手动恢复；完整28清单/原断言/1500秒预算保留，默认明确not_run27。当前RootBell40/spaces40/ecology/currentGolden64及森林v15正式路线仍为守门。

用户明确“暂时可以不考虑旧存档旧特性兼容”，并指出本次集成过慢。本轮撤回额外旧存档兼容开发，当前画风/方向恢复 style-v7/creative-v10。旧失败保留，历史检查改为显式手动 `legacy-compat`，未跑标延期，不能标通过；当前保存、真实玩法、资源、音画、导出及公开版本校验继续执行。

已定位的浪费：共享 wrapper 后段失败引发整段重跑（generated-consumers 两次约125/129秒）；生态路线退出清理错误耗尽300秒；当前1发免费射击与历史2发耗能fixture混用，引发无关历史修复。修复先单runner复验，最终冻结后一次集中CI，按依赖复用已有证明。当前Root Bell保留40图/物理/11准入反例，Golden默认当前64图；旧165/历史64不冒称通过。另将纯旧版本的 `forest-region-matrix`、`forest-formal-combat`、`plains-action-golden` 移至同一手动profile；当前森林与新版平原专项保留。菜单/BGM退出清理是当前问题，须修复而非忽略。

四线功能已接入的事实与下文真实B/F/E2证据保持各自来源；PR #106尚待新范围的最终Actions结果与普通合并，main自动Release/公开试玩核验随后执行，不预填成功。原作者美术、动作、手感及实体设备边界保留。


## 最终收口状态补充（以本节纠正早期“待接入／完整往返未验”描述）

四线合成已完成新版人物默认适配、家园“织时匠”真实外观选择和五首用户原 MP3 的正式 BGM 接入。经典外观及原 `p1` 定义保留，选择可在本次游戏进入区域、死亡回家及再开局间延续；刷新后恢复新版默认。BGM 使用既有主音量来源与双声部交叉淡入淡出。这是功能与技术集成完成范围，不是美术、手感、趣味性或 G5 的人工签收，原作者卡和历史失败证据保持其原身份与范围。

证据必须按源码归属阅读：B（`88560578914de808a6e3cae6d5c4391d96a9205b`）七项专项 **1266/0**；F（`fbb417cb4d4d4d8d2500d7c4bed11cebf681dd46`）真实 Web 构建 `7f88f353bfb4`。后续重新绑定元数据不能把 F 包或 B 结果改签为 D／最终 E。F 的 `browser-final-extra/partial-report.json` 已有 **7/7** 真实浏览器检查，覆盖打开原菜单、真实家园、与织时匠交互、新版默认、切经典、切回新版和身体区域实际像素变化。随后森林入口 OCR 子进程因 `SIGFPE` 终止，森林后续操作未完成；不能将其算作玩法失败，也不能签为通过。既有桌面与模拟触控证据不扩展为实体设备或人工体验认可。

D 已将两区方向绑定更新为 `creative-v10`，所绑定的共享画风仍是 `style-continuity-20261023-v7.json`；方向全量检查、原 Bible **32** 项与方向 **10** 项测试均通过。这不新增任何画风版本，也不重签先前素材／运行截图。

原 Actions CI `39900795369` 主动取消，不是通过。检查器修正三项独审反例及调用 token 边界后，精确 E2 `5c835d58af0a0f1db8d48be1e68594818ce4bcc8` 的原路径 **152+10+32** 测试全部通过。原125方法AST保留，新增27反例；当前资产窄守门1022/0。E源完整152/1失败和独审4/1原件保留，未追认为通过。B→E2没有生产文件变化；不把原B/F证据改签为E2 fresh。最终PR Integration、main合入与Release仍由随后真实Actions决定。


主体任务 `FOUR-LINE-INTEGRATION-01`：review。用户明确授权下列四线整理后合入main；当前在 `integration/four-lines-20261023` 普通合并，精确专项冻结检查点为 `88560578914de808a6e3cae6d5c4391d96a9205b`；本文件在PR创建前冻结，main合入与公开发布以其后的真实Git/Actions状态为准。暂停的黄金切片 `68bd037` 不属于本次范围，未合入。

| 来源工作线 | 精确输入head | 本次范围 |
| --- | --- | --- |
| player-presentation-01-motion-candidate | `b1069762731e0cdb39f003f2dd2474ba5d8de058` | 新人物动作候选、武器／反馈音画及正式共享接口；原卡in_progress |
| enemy-feedback-01-accepted-sample | `080ac505f8fb6b6af6bd964348a952f73483ece1` | 两表现链的命中／受伤／死亡帧、粒子与尸体候选；原卡review，视觉缺口保留 |
| demo-ui-01 | `ea2d6fd7c9d11c226ce52fe8885443137cdc077e` | UI、HUD、菜单及家园交互；原卡review |
| art/formal-fine-depth | `02031d718d5b24f32ef0a257c048121d93ed756b` | 用户选择的细粒度、正式材质、根基、背景／前景、地标及共享森林表现；原内容卡review |

旧美术949d884不是本次新美术线，未用它覆盖当前实现。各线的原始来源、失败、限定独审与历史媒体保持原SHA，不将分支局部证据追认为本轮fresh。`ART-SESSION-CLOSEOUT-09`的done只签文档／skills归整，不签美术完成；`CLOUD-EFFICIENCY-01`现有v3 done及A1完整146项证据已保留在Git树，属于此前提效基线，不是本次四线组合通过。

## 冲突与正式消费者

合并顺序为enemy→player→UI→art。`DemoApp`、`HomeScene`保留UI行为与美术组合根attach／parallax可见性／实际HUD尺寸保护；资产清单按新增内容合并，避免整文件覆盖。Animation Skill同时保留人物实证与当前细粒度入口。无文本冲突的父子材质、受伤flash、前景保护和保存仍须真实消费者验证。

尸体保存修复 `f38c608` 已将原严格66/1复验为66/0；原失败保留。EnemyFeedback01Frames改为显式manifest路径及4个PNG资源声明，区域／锚点仍从原manifest读取；原资产消费者守门已自然识别全部真实文件，未豁免动态加载或修改通用验证器。新来源登记保留unknown／not_exposed和视觉未验，旧death音按仍有preload的legacy用途登记。manifest及人物JSON已加入3个导出preset；实际导出仍待组合验证。

当前[style-v6](../creative_direction/bibles/style-continuity-20261023-v6.json)仅因正式Stage尸体表现保存接口版本化重绑一个引用，保留其他19项和v5像素字节，限定独审已ACCEPT；原v5不回写。下述新默认人物会新增正式适配与绑定工作，不能把现有v6结论提前签给后续运行源。

## 新增授权与进行中的适配

用户提供的5首原MP3已接入家园、平原／平原Boss、森林／森林Boss；原字节与项目内授权见[来源](../../assets/audio/bgm/provenance.json)，没有生成／重采样或声称CC0。BGM提交 `01e5183` 已cherry到集成树；独立私有树89项定向通过，最终组合尚未验证。音乐切换、暂停／重载／Boss退出及浏览器真实播放继续检查。

用户又明确要求新人物作为默认，并在家园“织时匠”更换外观，保留现有id及位置。正式适配已由3d0dce2接入：新人物为courier默认，courier_classic用原UnderworldPlayer身体，p1历史定义保留，织时匠提供实际选择，当前选择跨本次游戏进出地区／死亡回家／重新开局保持；刷新网页回新版默认。单一PlayerWeaponFeelAudioV2同时作为BGM总音量来源。style-v7保留v6全部引用并绑定真实新增消费者；私有235项通过，最终组合回归与独审另列。

## 验证与交接

先冻结最终源码、物化选定必要输入，再执行一次组合CI；当前尚未运行完，不能预签全部passed。重点覆盖：固定Godot导入／UID／资源引用、原质量diff与证据守门、尸体支撑保存／epoch、正式新人物与换装、受伤／死亡／声音、UI实际指针／触屏／手柄、前景与HUD保护、5首BGM切换、Web／Windows导出及真实公开包身份。按原正式门槛执行，不因本次合并删断言、放预算或以局部结果替代Release。

下一步由总控接收默认人物适配，更新绑定和任务卡，冻结组合版本后跑唯一正式验证；失败、未执行、用户审美／手感及实体设备分别保留。所有main／部署状态以实际PR、Git与公开构建元数据为准，本文没有新的CI号或发布URL。

首次组合检查保留真实失败：正常时钟的enemy support199/1，恢复作者固定60帧运行条件后重验；正式66/0仍有菜单实例释放后的_restore_focus coroutine ERROR，生产代码已改为随Menu销毁断开的单次信号回调，未修改原测试断言。最终7项与全CI尚未完成，不能引用初次summary作清洁通过。

## 冻结后的实际结果与执行入口

B源7项原Harness fresh全部passed，1266检查：enemy native458、formal66、support199、corpse save72、snapshot147、BGM89、default player235。原core5681、actor-actions2872、all-weapons2381、action-budget7305、UI time-energy140也全部通过；后者只带记录在report内的纯metadata overlay，无运行源漂移。菜单延迟回调、原1000ms范围新增真实音乐释放、原strict退出守门均通过。当前文档严格绑定D084已授权一发/60Hz，保留历史两发fixture。

5份资产记录漂移已版本化影响分析与独审：manifest是281条准确并集，Home只增grounding；Scenery确有新的quietmeadow/地标世界锚定与前中景构图变化，不能称纯hash刷新。4份原作者格式不完整的质量卡迁移原schema，旧原件逐字节保留，旧局部passed不扩大为新source技术或用户验收。所有原资产来源/未知许可与未验边界保留。

真实GL为UI147、R2223、terrain GPU、foreground506样本/23身份，无脚本/音频退出错误。Web为真实Godot F源fbb417c包7f88f353bfb4，4新增JSON与5MP3实际导入bytes在PCK一致。F→B生产diff为空；不把旧F包重标成B新包。真实本地Chromium24GUI＋4原生音频运行/非零混音通过；追加真实家园／织时匠／新版默认与切经典已观察，随后OCR失败保留，完整切回、森林及五曲浏览器逐曲听音未验。新manual driver为tools/verify_four_line_browser.py，参数必须绑定实际Web包source/build、真实CJK OCR和全新build下输出目录；不改历史driver断言、不注入引擎。

精选日志/实际图/失败/限定独审见[证据说明](../evidence/four_line_integration_20261023/README.md)。PR创建前执行原check_docs、check_quality、check_quality_diff、check_release_evidence；PR只开一次Production impact Integration，用户已授权成功后正常合main，main自动原Godot core完整Release/Web/Windows/公开PCK验证，不再重复手动dispatch完整CI。G5/全图美术、听感、手感与物理设备仍未验。

原Bible32测试的当前fixture仍写v4／16px／16引用／旧shader路径，已保存真实2F1E失败。只迁移为用户已选的v7／32px／36引用及实际fine资源；保留v2/v3旧绑定拒绝，新增v4/v5/v6拒绝、factory／新人物PNG／avatars漂移零调用与恢复阻断，逐条核v6全部20引用精确保留。32原测试现全通过，完整creative方向10原测试亦通过；不声称v2旧地形仍是当前，也不改变校验器或预算。
