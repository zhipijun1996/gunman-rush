# 2026-10-23 四条工作线集成

## 2026-10-23 当前 Demo 集成范围与提效修正（最新）

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
