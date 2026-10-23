## 2026-10-23 四线集成（合入前冻结检查点）

## 2026-10-23 当前 Demo 集成范围与提效修正（最新）

用户明确“暂时可以不考虑旧存档旧特性兼容”，并指出本次集成过慢。本轮撤回额外旧存档兼容开发，当前画风/方向恢复 style-v7/creative-v10。旧失败保留，历史检查改为显式手动 `legacy-compat`，未跑标延期，不能标通过；当前保存、真实玩法、资源、音画、导出及公开版本校验继续执行。

已定位的浪费：共享 wrapper 后段失败引发整段重跑（generated-consumers 两次约125/129秒）；生态路线退出清理错误耗尽300秒；当前1发免费射击与历史2发耗能fixture混用，引发无关历史修复。修复先单runner复验，最终冻结后一次集中CI，按依赖复用已有证明。当前Root Bell保留40图/物理/11准入反例，Golden默认当前64图；旧165/历史64不冒称通过。另将纯旧版本的 `forest-region-matrix`、`forest-formal-combat`、`plains-action-golden` 移至同一手动profile；当前森林与新版平原专项保留。菜单/BGM退出清理是当前问题，须修复而非忽略。

四线功能已接入的事实与下文真实B/F/E2证据保持各自来源；PR #106尚待新范围的最终Actions结果与普通合并，main自动Release/公开试玩核验随后执行，不预填成功。原作者美术、动作、手感及实体设备边界保留。


## 2026-10-23 四线集成（最终专项冻结，PR #106）

四条授权工作线已集成；黄金切片 `68bd037` 保持暂停。新版 Courier 已成为正式默认人物，家园“织时匠”保留原 id 与位置并可切换经典外观；原 `p1` 定义保留。五首用户提供的原 MP3 已接入家园、平原、平原 Boss、森林与森林 Boss 场景及交叉淡入淡出。上述为功能实现状态，不代表作者美术、手感、趣味性或 G5 人工认可。

技术证据身份保持分离：B 源码 `88560578914de808a6e3cae6d5c4391d96a9205b` 的七项专项为 **1266/0**；真实 Web 包仍属于 F 源码 `fbb417cb4d4d4d8d2500d7c4bed11cebf681dd46`、构建 `7f88f353bfb4`，不得改签为 B、D 或最终 E。F 包的 `browser-final-extra` 已实际完成新版→经典→新版往返及家园身体像素变化，部分报告 **7/7**；随后森林入口 OCR 子进程 `SIGFPE`，该森林后续路径未验。桌面浏览器与模拟触控不等同实体设备认可。

D 的两区方向已重绑为 `creative-v10`，共享画风权威仍为 `style-continuity-20261023-v7`；完整方向检查与原 Bible 32 项、方向 10 项测试通过。原 CI `39900795369` 为主动取消，不能作为通过证据。资源检查器已修正三项独审漏检及真实调用 token 边界。精确 E2 `5c835d58af0a0f1db8d48be1e68594818ce4bcc8` 原路径完整 **152+10+32** 项全部通过；原125方法AST保留，新增27反例。E源断call反例失败与修复前独审原件保留。最终PR Integration与main Release仍待Actions实际结果。上述局部证据不替代完整 Integration、Release 或原作者质量卡结论。


人物b106976、怪物080ac505、UI ea2d6fd及正确美术02031d7已合入集成分支；黄金68bd037暂停不入。新版人物正式默认，家园“织时匠”可切新／经典外观，保留id／位置；当前选择跨本次游戏进区／死亡回家／重开保持，刷新后默认新版。5首用户原MP3接入家园、平原／Boss、森林／Boss，单一SFX服务音量与两voice音乐交叉切换。当前style-v7保留v6原20引用并追加真实人物消费者。

精确B源8856057的7项原Harness fresh通过1266检查；原core／actor-actions／all-weapons／action-budget／R3 energy另外全部通过（5681／2872／2381／7305／140）。F源fbb417c实际Web包7f88f353bfb4与GL证据单列，F→B生产diff为空，不能改签新包。浏览器原24GUI＋4音频输出通过；真实家园／织时匠／新版默认及切经典已观察，后续OCR失败保留，完整往返／森林／五曲逐曲浏览器听音与实体设备未验。技术通过不签审美或G5。

[来源、修复、验证与后续](integration/four_lines_20261023.md)、[原始/失败/独审证据](evidence/four_line_integration_20261023/README.md)。这是PR创建前可知状态，不预填未来merge SHA或CI成功；合入用户已授权，由总控在原Integration守门后执行，main自动原Release／完整PCK公开核验。四线作者卡review／in_progress保留；以下为历史时点。

## 2026-10-23 SPATIAL-RHYTHM-07 沿途疏密与留白

## 2026-10-23 ART-SESSION-CLOSEOUT-09 会话归整与skills回流

本会话01–08轮17笔提交已完整累积在`art/formal-fine-depth`，最后运行源6befe56、上轮交付head42f673c。[归整索引](art_session_20261023.md)记录各轮采用/替代关系、正式消费者、历史证据/视频、未验与恢复；本轮仅文档/skills，不合main、不新开触发Integration的PR。修正六份skills当前入口的旧v4/16px指向，增加[共享执行说明](quality/art_consistency_workflow.md)和现有Asset Specification像素字段，区分全局规格/区域身份/资产接口；不修改原Bible/style-v4/v5、运行参数或素材。仅定向文档/记录核对，不跑完整CI或重导出/发布。Git最新head与远端一致性以收口证据为准；跨区品质、用户与真机仍不代签。其他工作区须先取得本分支提交，不假定main已含。


## 2026-10-23 FOREGROUND-CONTINUITY-08 固定前景与稳定恢复

用户明确选择固定前景物件＋离屏回收＋提前淡化＋稳定后恢复。`art/formal-fine-depth`运行源6befe56：固定世界身份/尺寸/风相位，完整框+4wu离屏才回收；动态危险64wu提前淡化，安全0.3秒后渐入；常驻HUD/边缘使用即时局部strict mask，保留全部保护。实际Home506采样/23身份失败0、GPU387080保护像素差0及非零前景贡献、六正式定位窗（Home/两图×两Seed）失败0。原首版常驻HUD全抹草叶失败另存。完整CI未跑，不合main；用户/真机/完整战斗仍review。[证据与命令](evidence/foreground_continuity_08/README.md)。[24秒实机视频/截图](https://zhipijun1996.github.io/gunman-rush-previews/reviews/FOREGROUND-CONTINUITY-08/6befe56/)已公开验证播放与完整字节，Pages39887917620 success；观察页，不是可玩Web更新。


用户否定06中景均匀满铺，要求有的地方多、有的地方空旷，前进不断变化。运行源f554e6b、art/formal-fine-depth：低草坡连续底景与独立世界锚定风车/钟塔组分离，缩小地标并留无建筑窗口；Home焦点归还人物/功能屋，06前景完整保护不变。正式30张（29个Underworld窗口：25组景/4无建筑；Forest独立背景不冒充空段），旧景层450/0。真实24.283秒电影：4s家园输入+20s图一8400wu连续镜头诊断，不代表正常行走/通关。独立看11图确认局部改善，草坡密度、侧肩雾化与正常节奏/设备/用户仍review。完整CI未跑，不合main。[证据/恢复](evidence/spatial_rhythm_07/README.md)；[公开连续视频/对照页](https://zhipijun1996.github.io/gunman-rush-previews/reviews/SPATIAL-RHYTHM-07/f554e6b/)已验证完整字节、实际浏览器播放及全图加载，Pages39882280474 success；仅观察评审，不是可玩Web。

## 2026-10-22 TERRAIN-DENSITY-04 同母版47格粗细实验

## 2026-10-23 DEPTH-FRAME-06 中景与前景迭代

用户要求更大、更丰富的风车钟塔中景，以及人物前方可见的氛围层。`art/formal-fine-depth`，运行源4a41fd7：新细源三风车/两塔/层叠石村，移开主角背后的主塔并把假路石桥改为远谷断桥；原高细母版Atlas前景、较大侧枝/草与稀疏世界候选，整框+3wu功能/HUD避让保持。正式两图×三Seed、Home/Forest30图通过，21镜头有可见前景，采样保护重叠0，原景层450/0；实际24.3667秒MovieWriter，前12秒真实Home输入、后2×6秒平原镜头诊断。详情与恢复见[evidence](evidence/depth_frame_06/README.md)。review而非done；大钟塔重复、低处偏满和显隐跳变仍需审美/运动复核，未签用户/设备，不跑完整CI、不合main。[公开视频/前后对照](https://zhipijun1996.github.io/gunman-rush-previews/reviews/DEPTH-FRAME-06/4a41fd7/)已验证完整字节与Chromium实际播放；Pages39877020268 success，未声称更新可玩Web。


分支 `art/authored-terrain-density-study`，基线7f332ff。完整AI外框/洞口母版→切取四边/四内角→原47格配方×三草沿，细32px/32wu、同源降采样粗16px/32wu；默认游戏不变。暖光固定；最终五镜头×四模式20实机图，退出0无错误，包含“仅地形粗”以隔离角色细节损失。独审确认隔离正确，新母版较上一斜岩纹更适合继续，但草沿厚/重复、石包边与岩体层次弱，未签定稿。首母版布局错误和首GPU白边shader错误原件均保留，不追认。

[证据、失败、来源与命令](evidence/terrain_density_04/README.md)，[十一维](quality/records/TERRAIN-DENSITY-04.json)。运行 `bash tools/godot.sh --path . scenes/dev/authored_terrain_study.tscn`。用户指定快速实验不跑CI；未做CI/Harness、Web发布、连续运动/真机/玩家验收，不合main。下一步等用户选颗粒方向，再修草沿和边缘，不扩产当前未定稿母版。最终local checkpoint见Git。

## 2026-10-22 HIGH-DENSITY-TERRAIN-03 提升地形密度实验

分支 `art/high-density-terrain-study`，基线0c1d1e5。按用户要求不跑CI、快速实机图，反向提高到原生32px/32wu、1wu采样，保留人物/建筑/背景细节；默认入口和全局设置未改。新增 `scenes/dev/high_density_terrain_study.tscn`。最终五窗口×四版本20张Godot静态图，退出0；首AI碎石遭用户否定，第二轮岩体主次改善但斜纹重复、地区身份仍未定稿，独审仅支持继续密度路线。不签全区/运动/真机/玩家认可。

[证据、失败、恢复命令](evidence/high_density_terrain_03/README.md)，[十一维记录](quality/records/HIGH-DENSITY-TERRAIN-03.json)。运行 `bash tools/godot.sh --path . scenes/dev/high_density_terrain_study.tscn`；下一步看用户对高密度和材质结构的反馈，先单个结构性黄金样板，不批量替换。未运行CI/Harness、未合main、未发布或替换试玩站。最终本地checkpoint见Git。

## 2026-10-22 PIXEL-LIGHT-STUDY-02 像素／灯光续轮

用户要求先像素对齐，保留Underworld像素风格，只学Animal Well打光；继续快速实验不跑CI。分支 `art/pixel-grid-lighting-study`，基线35a9cd8。新增独立 `scenes/dev/pixel_light_study.tscn`，默认游戏不动。已做物件固定2wu采样／纯表现snap／世界2px输出，HUD与标签清晰；保留原配色，真实局部点光／地形遮光／小bloom。最终5×4共20张Godot静态原图，原生退出0且无脚本错误；独审推荐暖灯继续，保留小物体细节损失／平原光池弱，未验运动或真机。

[证据与失败](evidence/pixel_light_study_02/README.md)，[记录](quality/records/PIXEL-LIGHT-STUDY-02.json)。运行 `bash tools/godot.sh --path . scenes/dev/pixel_light_study.tscn`；采图追加 `-- --capture --output=res://build/<fresh>`。下一步看用户对A颗粒与B灯光反馈，再决定细化；不签定稿，不合main，不替换试玩站，不以截图查看器冒充可玩Web。提交见本分支Git。

## 2026-10-22 LIGHT-STUDY-01 快速光感实验

分支 `art/light-study`，基线 e9ab0e0743466b8983e34cc7de17bab1abf9d53a。用户本轮明确要求三方向实机图／快速迭代、不跑CI；仅新增显式 `scenes/dev/light_study.tscn`，默认美术、物理、生成、保存不动。已采四窗口×四版本16张真实Godot定位静态图，最终原生退出0；不同只读代理看五图，推荐晨光默认、青绿局部，保留草边／反光／标签问题。素材未重画，未签全区、玩家或设备认可，未跑CI/Harness或发布。

[源绑定、失败与精选截图](evidence/light_study_01/README.md)，[质量记录](quality/records/LIGHT-STUDY-01.json)。运行 `bash tools/godot.sh --path . scenes/dev/light_study.tscn`，底部切三方向与原版／家园和平原。下一步先看用户方向反馈，再细化光源／邻近反光与草边疏密。最终提交见本分支实际Git；没有合main或替换试玩站。

# 最新交接：探索场所原型 v18

## 2026-10-22 FINE-SPACE-05 最新交付

FINE-SPACE-05，art/formal-fine-depth，运行源efd784349efa31502cb428b14bde10ea517bdd9a（后续提交只文档/UID）。30张正式定位图含2maps×3Seeds；GPU239910/0、scenery450/0、支撑21572/0、formal96/0、HUD42/0；本地Web5入口实际正常，非全程/CI。公开[24秒影片与对照](https://zhipijun1996.github.io/gunman-rush-previews/reviews/FINE-SPACE-05/efd7843/)部署39837638359成功；Web build524396d0cd10 ZIP在/workspace/artifacts，公开Web被cap/新repo权限挡住。未合main，勿默认删历史或提高cap。当前技能/素材来源/失败/恢复命令见[evidence](evidence/fine_space_05/README.md)及[quality](quality/records/FINE-SPACE-05.json)。下一步围绕森林承载造型与真实前景功能遮挡做局部视觉复核，不重复生成已选细粒度母版。


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


## 当前主线收口（最新覆盖）

2026-10-22已按用户明确要求通过PR102合main，合并SHA `9c349f44caa7e230b7784a340a839906cac58d0e`，PR101已merged，本地当前分支main且与远端一致。原93个开发head和新integration全部已含；5旧art head原祖先保留、当前树未切旧画风；15playtest＋1deploy产物不入源码，未删除旧分支。[盘点／独审／真实合入／源等价／docs29原件](evidence/main_closeout_20261022/README.md)。后续从最新origin/main独立分支／worktree直接提PR到main，勿继续串旧实验分支。

基线767627f8完整CI已成功，新main CI39741355698／docs39741355652自动执行中，不能混作同一次fresh。后续纯文档提交保存回执，运行文件与合并提交完全不变。公开仍e361原型source263afd；main自动发布另核实际PCK。森林ART_REWORK／拓扑／模块库／真人计时／设备及平原未完成，不因Git收口升通过。下列原“未合main”及分支名为历史交接。


2026-10-22，分支 `feature/region-bible-v2-forest`，草稿 [PR101](https://github.com/zhipijun1996/gunman-rush/pull/101) 未合 main。准确提交以 Git 为准。公开已更新为[探索原型 e361](current_state.md#当前公开试玩)，入口FOREST PLACES MAP 1/2，普通THORN_FOREST保留旧v15。

## 已实现和边界

用户已选每图正常8–12分钟、充分探索15–20分钟作为初步真人目标；没有真人计时，不能用原生帧数换算。v18 新显式 FOREST PLACES 入口保留 v15 核心／早段休整根／HH和螺旋技巧线，加入双窗、7型高枝回落、Z内外折返、倒木上下路，图二另有固定果 H＋反向射击背枝。真正root Seed改变Z／倒木顺序，两图反排；Boss完整factory后移到最终出口。真实奖励为金币或音符二选一且幂等，没有清空支线开门锁。

当前仍是带多处分流汇流的场所链，非充分网状森林，也不是完整模块库。活果渡口未实现；固定果不冒称活目标。森林含美术优先，平原仍planned；BGM未生成或替换。普通森林 default15 与历史producer保留，没有修改Motor／物理／资源／能力／保存。

## 实际失败与继续点

原33项在600秒超时，29项完成不能追认为整轮通过。App04独审拒绝Fallen巨L；18.3真实西根外弯、东根凹窝及心木底面已改，App05八张源稳定且独审确认有实质改善，只允许继续候选通行验证，未签ART。Z的细悬臂／倒L、Back浮空平楔／通屏夹层、倒木长地板和木质识别仍待定稿。两条失败材质方向完整归档，未进入runtime。不能再用纹理、更多变体或测试计数覆盖构图失败，不能把原型覆盖旧公开包。

新开发反馈分成 `python3 tools/harness.py --profile forest-places-feedback --release --jobs 1`（core20）和 `--profile forest-library-feedback`（library16）。根据改动选，不每次部署整套；保90import/240native/600whole、fixed60、串行引擎和严格非空／完整输入／完整脚／OR结算守卫。旧80/full/CI未改，本轮没有重签完整CI。

精选原始源码、全轨迹、失败、静图、独审和每成员完整SHA在[证据索引](evidence/forest_variety_04/README.md)；当前质量状态见[记录](quality/records/FOREST-VARIETY-04.json)。新浏览器 `--forest-places` 只实际OCR点击候选入口并校验组装18，默认四入口不变；只验GUI，不签奖励／手感。

## 操作与存储

root唯一Godot/import/GPU/browser租约；运行源与Git冻结期间禁止并行写生产。只用 `bash tools/godot.sh` / Godot4.7.2 Standard。不动 `/workspace/gunman-rush-ci-H`、原始附件、`.git/.godot` 或历史失败。audit SHA保持 `c47e366e9fbc1e3584a7c7e3eb8b983422156e21eb420a34456a2d8eb7219791`。

先 `df -h /workspace /tmp`。旧564份大JSON以完整字节/SHA读回验证后可逆存于 `build/storage-preservation-20261022/large-json-lossless.zip`，旁有RESTORE-INDEX.json；旧平原run_vs12o4rc原件同目录lossless.zip和RESTORE-INDEX.json。不是删除不可恢复证据。运行时快照仅复制实际源与必要资产，不复制海量历史build。

合入/完整交付另跑适用原profile。新试玩按已有快速流程复用同源已验包或仅Web重建和必要检查；当前艺术未过，不以新原型替换旧公开包。完成更多有趣机制与网状拓扑后再验人类时长、手感、手机性能和玩家认可。

本轮最终新库16项inner／outer均exit0，334.075秒；新倒木之后两图正式主路线分别55.099／79.963秒通过，整轮135.791秒，源稳定。不是fresh完整core20、原80或fullCI。静图是明确摆位fixture，不作自然游玩／动态证据。

文档／流程29项fresh通过；具体证据路径已普通Git归档。PR实际base仍7be8c340372d1e20db6685cbd6a559191821eb0e，需保持差异与commit-tree证据闭包检查。

首次Web构建真实失败：旧Foundry池的basis包含整个generation目录，新增区域脚本使其失配。已用原工具实际重新验证36短语／18连续路线与回放，只更新开发池JSON／export stamp；没有直接换SHA或改guard，森林几何／动作／参数字节未动。第一次失败保留，Web重试结果另记。

Web06导出与PCK检查通过，但实际候选点击后browser截图30秒超时，保留失败且未增timeout。已定位并实现精确边界邻居粗筛：两完整世界3000断言逐项几何相同，11对跨区App／GPU图逐像素相同；同一原生App初始化27.23秒降至5.527秒，仅限定该样本。旧style-v3保持原字节，新v4和creative-v8显式重绑；首次遗漏current方向绑定的Bible测试失败也保留，补齐后六项受影响harnessfresh通过。浏览器重试与最终本地包结果另记。

最终本地Web原型已完成：运行源 `263afd4fbdd535df6b4e80b1f4b584a05b55c7ea`，build `e361af714d54`；两图×鼠标／模拟DOM触屏共4入口、12项实际组装／暂停恢复检查通过，errors为空，四次完整PCK身份一致。仅签这些GUI入口，未签浏览器全程、手机真机、趣味性或人类时长。完整本地包为 `build/gunman-rush-forest-v18-e361af714d54.zip`（298440075字节，SHA `e8312144a72e071b2e4162a1492e44c88d5b376b53b086597f1c22ef10c7a69a`），解压后运行 `python3 -m http.server 8000`，打开localhost:8000；DEVELOPMENT DEMOS → SELECT REGION → FOREST PLACES MAP 1/2。包内含许可与README，全部成员读回核对。原浏览器06失败保留，未增加超时；本次GUI通过不重签美术。当时尚未发布新Pages，后续实际上线以最新段落为准；仍未合main。详见[最终原件索引](evidence/forest_variety_04/README.md)。

## 最新补齐：公开试玩交付

用户明确“我都是通过试玩网站试玩的”；上一轮只推远端／本地ZIP未满足该方式，已纠正并补到AGENTS／project-integration。现已[公开e361原型](https://zhipijun1996.github.io/gunman-rush/?v=e361af714d54)，DEVELOPMENT DEMOS → SELECT REGION → FOREST PLACES MAP 1/2；旧默认THORN_FOREST不变。原Web07同源复用，Pages39733962550成功，公开完整PCK141811380字节／完整SHA一致，四实际GUI入口＋暂停恢复12项通过、errors[]。准确PCK source263afd；workflow helper81e4f0ab／prepared297bb91，最终文档提交不冒称运行源。[全部原件与边界](evidence/forest_variety_04/public_v18_01/README.md)。

没有修改运行代码／重建／全CI／合main，也不抵销ART_REWORK和其他未完成项。后续仍先网状探索、多难度真正不同的模块与自然结构美术，再真人验证每图8–12／15–20分钟，最后平原。用户只通过网页体验，不能仅给本地包结项。
