# 当前状态

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
