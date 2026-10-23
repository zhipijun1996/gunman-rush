# 当前状态

## 2026-10-23 实际Ubuntu镜像入口补齐（最新）

7ab4仅补两workflow六处实际mirrorlist入口。f57的安装虽通过，下载仍走Azure：日志显示file:/etc/apt/apt-mirrors.txt，原两sources只是引用它；此前切源成功的表述已纠正。现在追加此已观测文件，原sed／GPG／套件／APT／预算／断言／合流全保；真实临时三文件与原五组、精确Git独审、官方Actionlint通过。下一CI须看到实际官方HTTPS获取URL；main／Release仍未完成，游戏源／a074Preview不变。

[准确日志节选与限定修复](evidence/four_line_integration_20261023/apt-mirror/mirrorlist-entry/README.md)。本地163ad原专项308.524秒通过保持其原源，未追加原生重跑。以下为历史时点。

## 2026-10-23 Ubuntu依赖镜像修复（最新）

实现77eca16已冻结：88a08的parallel在原生测试前因Azure下载过慢触发原五分钟安装上限，serial状态单列，不冒称整轮通过。现仅将两workflow六处精确Azure URI改为Ubuntu官方HTTPS；GPG／套件／APT参数／原预算／检查与合流全保，精确Git采纳独审及官方Actionlint通过。本地163ad原专项308.524秒的通过保持原源；新镜像实际CI及main／Release仍待结果。

[真实失败、原日志及有限修复证据](evidence/four_line_integration_20261023/apt-mirror/README.md)。游戏源和a074开发Preview不变；Git存在性与批处理候选未采纳。以下为历史时点。

## 2026-10-23 原专项预算内调度修复（最新）

实现163ad已冻结。8ca6远端serial实际8通过／1超时／44未跑：最后bait到573秒才启动，因整个600秒上限被终止，不能说bait死锁。现将六个独立当前采集有界双worker调度，原场景／验证／反例／240与600秒预算全保；独审限定ACCEPT。精确163ad原Harness本地两核条件fresh通过308.524秒，source稳定；精确8ca6场景专项亦通过，native130.160秒在原180秒内。实际完整CI／main／Release仍待下一精确head结果。

[原失败、审查与准确专项证据](evidence/four_line_integration_20261023/encounter-scheduling/README.md)。a074开发Preview游戏内容不变，不重建或重签旧包；APT和Git链接存在性原型未采纳。以下为历史时点。

## 2026-10-23 CI 门禁修复（最新）

实现17cd已冻结：原97通过／1失败／44未执行的CI保留；缺件为两个便携工具fixture共977249B，原24测试与native未改。现在选中便携自测前置引擎／Foundry，精确full142复用原两物理通道与合流，局部保持相关检查；最终affected完整成功才绿，失败job的产物重跑已修。本地精确17cd planner21／无引擎24及Actionlint通过，独审限定ACCEPT；远端新流程／性能／main合并仍待实际结果。

[准确失败、源身份与门禁证据](evidence/four_line_integration_20261023/ci-gate-repair/README.md)。当前游戏仍可在原a074独立开发Preview体验，链接见证据；新流程不重标旧包或签G5。下一步只推一次冻结head，核完整真实合流后普通合main，随后原main Release。以下为历史时点。


## 2026-10-23 当前 HUD 与资源契约集成（冻结检查点）

实现 `cc46ff5bb84dac1d7946fcc0e55bf1cfa487b92f` 已冻结。8场景94/0＋10真实负例＋15篡改拒绝通过；双引擎总133.386秒，原180/900预算不变。实际新HUD避敌／触控修复、当前免费一发验证和15项手动历史分流已接入；HUD专用style-v9／creative-v12保旧原件及其他35引用。encounter full3仍为失败，最终尾段证据不冒称fresh完整；下一精确PR CI、main与正式新Web尚未完成。见[准确来源、当前证明与试玩边界](integration/four_lines_20261023.md)。以下段落保留各历史检查点，不代表最新运行或发布状态。

## 2026-10-23 当前 audit 与 CPU 隔离修复（最新）

实现冻结`ca371639209e7dbe5a4a5e4c034bcf2613a36d23`。当前RootBell40/物理10/准入11已在原Harness fresh通过；历史字节复现明确延期，手动原断言保留。森林80隔离CPU，原80/240/90/600不变。精确5502旧CI为66pass/1fail/1timeout/75未跑，本地同源80pass仍保持来源；下一轮CI与main尚未完成。见[准确失败、修复、证据与试玩](integration/four_lines_20261023.md)。

## 2026-10-23 当前源码冻结与可玩开发版（最新）

实现已冻结于`4ef092e`；当前平原15项suite通过，森林敌人通过。四进程语料保80场景/原600秒，14项真实子进程检查通过；完整80与PR #106新head CI待执行，main尚未合并。已发布可玩的四线组合F开发版，源码/build/公开PCK和真实浏览器入口已核，不能冒称最终main。见[准确版本、试玩链接与验证边界](integration/four_lines_20261023.md)。

## 2026-10-23 当前 Demo 集成范围与提效修正（最新）

当前森林v15的fast/growth已在同一候选源分别真实完成28/28、23/23段；旧双发程序改用合法挂点跳脱/已有钩索再接近，实际执行与原来源程序分开记录，不称旧RHR通过。原几何、目标、HP/碰撞、事件身份和时间能量回放继续严格验证。headless鼠标使用项目实际1280×720窗口，修复64×64默认物理窗口导致的新UI过大。敌人低能量样板用真实AirFocus消耗，不再以免费射击伪造耗能。候选证明限实际两条路线，完整80例仍由当前正式检查执行。

另将固定旧Queen/v7战役、v10 expedition/root-entry及旧双发/射击扣20的air/cavity三微场景延期至manuallegacy；它们未作为当前通过。当前geometry仅按实际经过实例验证，不声称fast替代完整cavity微场景验收。平原region默认保全部15个current suites（含原150种子/50自动族与实际App baseline、lifecycle/Boss），27个旧独立v10整图走法通过`--with-legacy-fixtures`手动恢复；完整28清单/原断言/1500秒预算保留，默认明确not_run27。当前RootBell40/spaces40/ecology/currentGolden64及森林v15正式路线仍为守门。

用户明确“暂时可以不考虑旧存档旧特性兼容”，并指出本次集成过慢。本轮撤回额外旧存档兼容开发，当前画风/方向恢复 style-v7/creative-v10。旧失败保留，历史检查改为显式手动 `legacy-compat`，未跑标延期，不能标通过；当前保存、真实玩法、资源、音画、导出及公开版本校验继续执行。

已定位的浪费：共享 wrapper 后段失败引发整段重跑（generated-consumers 两次约125/129秒）；生态路线退出清理错误耗尽300秒；当前1发免费射击与历史2发耗能fixture混用，引发无关历史修复。修复先单runner复验，最终冻结后一次集中CI，按依赖复用已有证明。当前Root Bell保留40图/物理/11准入反例，Golden默认当前64图；旧165/历史64不冒称通过。另将纯旧版本的 `forest-region-matrix`、`forest-formal-combat`、`plains-action-golden` 移至同一手动profile；当前森林与新版平原专项保留。菜单/BGM退出清理是当前问题，须修复而非忽略。

四线功能已接入的事实与下文真实B/F/E2证据保持各自来源；PR #106尚待新范围的最终Actions结果与普通合并，main自动Release/公开试玩核验随后执行，不预填成功。原作者美术、动作、手感及实体设备边界保留。


## 2026-10-23 四线集成（最终专项冻结，PR #106）

四条授权工作线已集成；黄金切片 `68bd037` 保持暂停。新版 Courier 已成为正式默认人物，家园“织时匠”保留原 id 与位置并可切换经典外观；原 `p1` 定义保留。五首用户提供的原 MP3 已接入家园、平原、平原 Boss、森林与森林 Boss 场景及交叉淡入淡出。上述为功能实现状态，不代表作者美术、手感、趣味性或 G5 人工认可。

技术证据身份保持分离：B 源码 `88560578914de808a6e3cae6d5c4391d96a9205b` 的七项专项为 **1266/0**；真实 Web 包仍属于 F 源码 `fbb417cb4d4d4d8d2500d7c4bed11cebf681dd46`、构建 `7f88f353bfb4`，不得改签为 B、D 或最终 E。F 包的 `browser-final-extra` 已实际完成新版→经典→新版往返及家园身体像素变化，部分报告 **7/7**；随后森林入口 OCR 子进程 `SIGFPE`，该森林后续路径未验。桌面浏览器与模拟触控不等同实体设备认可。

D 的两区方向已重绑为 `creative-v10`，共享画风权威仍为 `style-continuity-20261023-v7`；完整方向检查与原 Bible 32 项、方向 10 项测试通过。原 CI `39900795369` 为主动取消，不能作为通过证据。资源检查器已修正三项独审漏检及真实调用 token 边界。精确 E2 `5c835d58af0a0f1db8d48be1e68594818ce4bcc8` 原路径完整 **152+10+32** 项全部通过；原125方法AST保留，新增27反例。E源断call反例失败与修复前独审原件保留。最终PR Integration与main Release仍待Actions实际结果。上述局部证据不替代完整 Integration、Release 或原作者质量卡结论。


## 2026-10-23 四线集成（合入前冻结检查点）

人物b106976、怪物080ac505、UI ea2d6fd及正确美术02031d7已合入集成分支；黄金68bd037暂停不入。新版人物正式默认，家园“织时匠”可切新／经典外观，保留id／位置；当前选择跨本次游戏进区／死亡回家／重开保持，刷新后默认新版。5首用户原MP3接入家园、平原／Boss、森林／Boss，单一SFX服务音量与两voice音乐交叉切换。当前style-v7保留v6原20引用并追加真实人物消费者。

精确B源8856057的7项原Harness fresh通过1266检查；原core／actor-actions／all-weapons／action-budget／R3 energy另外全部通过（5681／2872／2381／7305／140）。F源fbb417c实际Web包7f88f353bfb4与GL证据单列，F→B生产diff为空，不能改签新包。浏览器原24GUI＋4音频输出通过；真实家园／织时匠／新版默认及切经典已观察，后续OCR失败保留，完整往返／森林／五曲逐曲浏览器听音与实体设备未验。技术通过不签审美或G5。

[来源、修复、验证与后续](integration/four_lines_20261023.md)、[原始/失败/独审证据](evidence/four_line_integration_20261023/README.md)。这是PR创建前可知状态，不预填未来merge SHA或CI成功；合入用户已授权，由总控在原Integration守门后执行，main自动原Release／完整PCK公开核验。四线作者卡review／in_progress保留；以下为历史时点。

## 2026-10-23 ART-SESSION-CLOSEOUT-09 会话归整与skills回流

本会话01–08轮17笔提交已完整累积在`art/formal-fine-depth`，最后运行源6befe56、上轮交付head42f673c。[归整索引](art_session_20261023.md)记录各轮采用/替代关系、正式消费者、历史证据/视频、未验与恢复；本轮仅文档/skills，不合main、不新开触发Integration的PR。修正六份skills当前入口的旧v4/16px指向，增加[共享执行说明](quality/art_consistency_workflow.md)和现有Asset Specification像素字段，区分全局规格/区域身份/资产接口；不修改原Bible/style-v4/v5、运行参数或素材。仅定向文档/记录核对，不跑完整CI或重导出/发布。Git最新head与远端一致性以收口证据为准；跨区品质、用户与真机仍不代签。其他工作区须先取得本分支提交，不假定main已含。


## 2026-10-23 FOREGROUND-CONTINUITY-08 固定前景与稳定恢复

用户明确选择固定前景物件＋离屏回收＋提前淡化＋稳定后恢复。`art/formal-fine-depth`运行源6befe56：固定世界身份/尺寸/风相位，完整框+4wu离屏才回收；动态危险64wu提前淡化，安全0.3秒后渐入；常驻HUD/边缘使用即时局部strict mask，保留全部保护。实际Home506采样/23身份失败0、GPU387080保护像素差0及非零前景贡献、六正式定位窗（Home/两图×两Seed）失败0。原首版常驻HUD全抹草叶失败另存。完整CI未跑，不合main；用户/真机/完整战斗仍review。[证据与命令](evidence/foreground_continuity_08/README.md)。[24秒实机视频/截图](https://zhipijun1996.github.io/gunman-rush-previews/reviews/FOREGROUND-CONTINUITY-08/6befe56/)已公开验证播放与完整字节，Pages39887917620 success；观察页，不是可玩Web更新。


## 2026-10-23 SPATIAL-RHYTHM-07 沿途疏密与留白

用户否定06中景均匀满铺，要求有的地方多、有的地方空旷，前进不断变化。运行源f554e6b、art/formal-fine-depth：低草坡连续底景与独立世界锚定风车/钟塔组分离，缩小地标并留无建筑窗口；Home焦点归还人物/功能屋，06前景完整保护不变。正式30张（29个Underworld窗口：25组景/4无建筑；Forest独立背景不冒充空段），旧景层450/0。真实24.283秒电影：4s家园输入+20s图一8400wu连续镜头诊断，不代表正常行走/通关。独立看11图确认局部改善，草坡密度、侧肩雾化与正常节奏/设备/用户仍review。完整CI未跑，不合main。[证据/恢复](evidence/spatial_rhythm_07/README.md)；[公开连续视频/对照页](https://zhipijun1996.github.io/gunman-rush-previews/reviews/SPATIAL-RHYTHM-07/f554e6b/)已验证完整字节、实际浏览器播放及全图加载，Pages39882280474 success；仅观察评审，不是可玩Web。


## 2026-10-23 DEPTH-FRAME-06 中景与前景迭代

用户要求更大、更丰富的风车钟塔中景，以及人物前方可见的氛围层。`art/formal-fine-depth`，运行源4a41fd7：新细源三风车/两塔/层叠石村，移开主角背后的主塔并把假路石桥改为远谷断桥；原高细母版Atlas前景、较大侧枝/草与稀疏世界候选，整框+3wu功能/HUD避让保持。正式两图×三Seed、Home/Forest30图通过，21镜头有可见前景，采样保护重叠0，原景层450/0；实际24.3667秒MovieWriter，前12秒真实Home输入、后2×6秒平原镜头诊断。详情与恢复见[evidence](evidence/depth_frame_06/README.md)。review而非done；大钟塔重复、低处偏满和显隐跳变仍需审美/运动复核，未签用户/设备，不跑完整CI、不合main。[公开视频/前后对照](https://zhipijun1996.github.io/gunman-rush-previews/reviews/DEPTH-FRAME-06/4a41fd7/)已验证完整字节与Chromium实际播放；Pages39877020268 success，未声称更新可玩Web。


## 2026-10-22 FINE-SPACE-05 最新交付

FINE-SPACE-05：用户明确选择细粒度。正式Home/Plains及森林共享消费者接入32px/32wu与1wu表现、根接触/暖光/景深/稀疏前景，原Bible/v4保留，现用style-v5。运行源efd7843，Web524396d0cd10已本地5例GUI验证；公开可玩发布被900MiB cap及新仓库权限阻挡，公开[视频/实机评审页](https://zhipijun1996.github.io/gunman-rush-previews/reviews/FINE-SPACE-05/efd7843/)已核实际字节/播放。无完整CI，未合main；森林木台造型/前景贡献/用户和真机仍review。[证据与恢复](evidence/fine_space_05/README.md)。


## 2026-10-22 总控与提效生产基线（最新）

当前主会话为总控。用户已授权先完成CLOUD-EFFICIENCY-01并通过普通PR合入main，再从PR103的实际merge SHA启动三条独立工作线；[本批Prompt、写集及共享依赖](demo_wave_01.md)为本批调度合同。合入与最终CI状态以[PR103](https://github.com/zhipijun1996/gunman-rush/pull/103)的精确head／merge及check为准，不把执行中签成通过。

本轮提效修复Harness稀疏隔离、增加原preflight驱动的按需输入物化、统一五份相关Skills的短反馈规则。PR使用sparse＋选定输入恢复、两隔离lane与Foundry后重plan；原serial顺序、158项原定义／预算和main完整Release守门保留。历史证据／资源删除0项，冷归档须先恢复原字节与真实消费者。恢复命令与退出码见[Harness](harness.md#稀疏检出与选定输入预检)。

下一批为PLAYER-PRESENTATION-01、ENEMY-FEEDBACK-01、PLAINS-GOLDEN-01。主角脚本本身被共享母版SHA绑定，由总控协调影响分析／独审／重绑；两种敌人表现继承链分别验证。各线独占分支／工作树，不改中央任务文件或自行合main。当前工具可启动本会话的隔离代理；真正独立Cloud会话通过同一Prompt、远端分支和PR恢复，不假定自动唤醒。

以下为此前交付时点的原始状态，新的合入与生产约定以上段及实际Git为准；真实已发布样例仍绑定运行源6ca72ef，不能称作后续工具提交的新游戏构建。

## 2026-10-22 Cloud生产与交付（最新）

草稿[PR103](https://github.com/zhipijun1996/gunman-rush/pull/103)，分支 `chore/cloud-production-system`，运行源 `6ca72efb1cbdb38cf83ae91c097d192a35403ccd`，未合main。四模式、交付选择、独立托管、影响选择和工作线模板见[生产入口](cloud_production.md)；[真实交付及失败](evidence/cloud_production_01/README.md)包含MP4／Preview和公开全字节／真实GUI。主站build-info前后同一703f9b040e5f/source9c349f44；新开发站独立，没有替换main。

原158检查及profile前缀保留，新增14/30/25专项fresh通过，独审技术ACCEPT；本地完整docs因稀疏缺旧证据实际失败，未追认为通过。首轮PR CI因新增交付测试先于ffmpeg安装失败，安装顺序已修、复验待；完整集成／Release及用户／真机仍未验。PR自动Integration，本地Development，main／手动原完整Release；默认不合main。

[提效审计](cloud_efficiency_audit.md)：历史证据8392.57MiB，占93.7%；同blob工作树冗余660.50MiB已在Git对象去重。先做partial+sparse必要输入预检、稀疏隔离修复与可恢复冷归档试点；不批量删除当前历史依据。

恢复命令：`python3 tools/production_plan.py --base origin/main --stage integration --plan`；当前稀疏工作区先jobs1，补齐原检查实际依赖再执行。源码与包来源分开，不能把文档后续提交冒称新游戏构建。


2026-10-22，开发现状已通过[PR102](https://github.com/zhipijun1996/gunman-rush/pull/102)收口到 `main`，合并提交 `9c349f44caa7e230b7784a340a839906cac58d0e`；森林[PR101](https://github.com/zhipijun1996/gunman-rush/pull/101)也已merged。原93个开发head及新integration均为main祖先，本地已切回main；纯部署产物分支排除，旧分支未删除。后续从最新origin/main开独立主题分支／worktree，PR直接向main。[收口与原始证据](main_closeout_20261022.md)。

源码／测试／资源／CI子树与767627f8一致，其完整Godot core39734737843及docs39734738277实际success；本轮新文档29项fresh通过。新main CI39741355698／docs39741355652已自动启动，此时尚未完成，公开版本以build-info为准。任务 FOREST-VARIETY-04 仍开发中，整森林未完成；本页以下旧“未合main”属于收口前历史时点。

## 当前公开试玩

[新版探索原型](https://zhipijun1996.github.io/gunman-rush/?v=e361af714d54)，build `e361af714d54`，运行源 `263afd4fbdd535df6b4e80b1f4b584a05b55c7ea`，已公开。入口 **DEVELOPMENT DEMOS → SELECT REGION → FOREST PLACES MAP 1 / MAP 2**。普通 THORN_FOREST 仍旧v15；新内容用显式开发入口。

[Pages39733962550](https://github.com/zhipijun1996/gunman-rush/actions/runs/39733962550)实际success；公开完整PCK SHA／长度与原已验证Web07一致，两图×鼠标／模拟DOM触屏四入口及暂停恢复12项检查通过、无引擎错误。[原始发布证据](evidence/forest_variety_04/public_v18_01/README.md)。这是试玩原型，ART_REWORK、网状拓扑／更丰富模块／真人时长／真机等仍未完成，没有合main或签整区验收。

此前公开的12ac19e2ec02是旧v15恢复包；上一轮81e4f0ab只推源码／交本地包，没有上站。用户再次明确只通过试玩站体验，本次复用同源Web07发布，不重建／不重跑完整CI；后续交付以网页链接与实际公开版本为准。旧恢复收据仍在[历史原件](evidence/forest_variety_03/public_restore/report.json)。

## 新候选 v18

保留用户肯定的 v15 核心、早段休整侧根、旧 HH／螺旋技巧线；默认入口仍 v15。新显式 FOREST PLACES MAP 1/2 接入双窗树腹、7型高枝回落、Z折根内外路、倒木上下路；图二另有固定果 H 后反向射击到背枝高奖励。Z／倒木次序由真正的 root seed 决定，两图取相反顺序，另有结构变体。Boss 完整 factory 随最终出口后移，无需清空宝箱才能开门。

奖励是实际金币或音符二选一：七型／倒木4或1、Z6或2、背枝5或2。不是更多短平台梯，不改物理／Motor／资源／能力／保存；活果渡口仍未实现。当前是多个分流汇流场所的链，尚非充分网状地图；没有把顺序／几何签名当作趣味性证明。

用户每图正常8–12分钟、充分探索15–20分钟为初步真人目标，未计时验证。实际路线证据只证明所列出生点／fixture旅程到 Boss 门前，不能换算真人游玩时长或 Boss 战验收。

## 质量与待办

[设计与范围](design/forest_exploration_v18.md)、[原件及失败索引](evidence/forest_variety_04/README.md)、[十一维记录](quality/records/FOREST-VARIETY-04.json)。33项原轮在600秒超时，保留原 FAIL；基础路线和新模块库已拆成可选开发检查，预算／守卫不变，原80/full/CI不变。

实际App04独审拒绝倒木直角L框；18.3已改真实外弯根腹，App05独审确认有实质轮廓改善，仅允许继续玩法验证，没有 ART 通过。Z细悬臂／倒L、背枝浮空平梁／通屏恢复层及森林材质仍需定稿。两条树皮材质尝试失败均保留、未接入。不能把原型当整区美术或用户认可；本次依用户试玩方式通过独立FOREST PLACES入口发布，保留旧默认。

继续先完成森林含美术，再优化风铃平原。两份完整Bible、共享 Underworld16px/32wu 家族与自然覆生荆棘平台要求有效；BGM由用户后续引入，未生成或替换。整体难度曲线、更多有趣模块、充分网状探索、人类时长和实体设备／玩家认可仍未完成。

最新限定技术结果：新库16项fresh inner／outer通过（334.075秒）；倒木18.3之后两图正式出生点主路线fresh通过（135.791秒），全源稳定。不追认原33超时，不签全量回归、真人时长或ART。

首次Web构建真实失败：旧Foundry池的basis包含整个generation目录，新增区域脚本使其失配。已用原工具实际重新验证36短语／18连续路线与回放，只更新开发池JSON／export stamp；没有直接换SHA或改guard，森林几何／动作／参数字节未动。第一次失败保留，Web重试结果另记。

Web06导出与PCK检查通过，但实际候选点击后browser截图30秒超时，保留失败且未增timeout。已定位并实现精确边界邻居粗筛：两完整世界3000断言逐项几何相同，11对跨区App／GPU图逐像素相同；同一原生App初始化27.23秒降至5.527秒，仅限定该样本。旧style-v3保持原字节，新v4和creative-v8显式重绑；首次遗漏current方向绑定的Bible测试失败也保留，补齐后六项受影响harnessfresh通过。浏览器重试与最终本地包结果另记。

最终本地Web原型已完成：运行源 `263afd4fbdd535df6b4e80b1f4b584a05b55c7ea`，build `e361af714d54`；两图×鼠标／模拟DOM触屏共4入口、12项实际组装／暂停恢复检查通过，errors为空，四次完整PCK身份一致。仅签这些GUI入口，未签浏览器全程、手机真机、趣味性或人类时长。完整本地包为 `build/gunman-rush-forest-v18-e361af714d54.zip`（298440075字节，SHA `e8312144a72e071b2e4162a1492e44c88d5b376b53b086597f1c22ef10c7a69a`），解压后运行 `python3 -m http.server 8000`，打开localhost:8000；DEVELOPMENT DEMOS → SELECT REGION → FOREST PLACES MAP 1/2。包内含许可与README，全部成员读回核对。原浏览器06失败保留，未增加超时；本次GUI通过不重签美术。当时尚未发布新Pages；后续公开交付见页首当前公开试玩，仍未合main。详见[最终原件索引](evidence/forest_variety_04/README.md)。
