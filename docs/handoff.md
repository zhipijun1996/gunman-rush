# FOREST-GRAPPLE-02：实现与验证交接

2026-10-19交付跟进：S2 `6adc5ff30515d7adaf598d5bbba0268d42af44f4` 的选定CI39200142616实际FAIL：Web、Windows和serial18成功，parallel在原80路线第33例（hollow-04／图1／growth）死亡，core失败，deploy／verify_public跳过。干净单例复现确认固定短跳驾驶在钩拉途中碰到原巡逻甲虫，受伤后驾驶未恢复；真实完整跳跃后R→H已通过同例，生产敌人、地形、身体、射程及原判定不变。强完整跳跃→H无R对照也成功，仅慢8帧并省弹，故该冠叉RH的R属于可选策略，组合必要性／密度仍REVISE。修正驾驶的原整组80／600秒本地实际超时600.167s，59例完整严格通过、下一例中断、其余未验；不能签80通过。已有轨迹离线json读取0.174s／带profiler校验0.275s，尚未定位原生耗时，不为此改校验器或预算。S1历史fixture故障及S2历史authority限定修复均保留。完整原件见[本轮后续证据](evidence/forest_grapple02/release02/README.md)；修正后最终同源CI与Web仍待，旧线上仍为v11，整体REVISE／in_progress。

2026-10-19：工作分支 `feature/thorn-forest-depth`，基线 `6c61faadd511c48a267b975550da897e701fd09f`，PR83保持draft，未合并main。最新实现／原失败／专项及当前源16/16通过见[当前状态](current_state.md)和[本轮证据](evidence/forest_grapple02/README.md)。当前脚本、配置、测试和工具冻结，唯一Motor／24×36／231射程／重力反冲资源未改；只有用户明确授权的钩索接近、停留与15%瞄准合同升级。生态阻挡及返程接口已真实修复，清脚绕跳方案因重复劳动已淘汰。最终源两图正常60fps影片已严格通过，原240s预算不变；随后执行同一冻结SHA的正式CI原固定80／600s、gameplay/art89项、Web/Windows及部署，再核对公开PCK和GUI。旧原件不覆盖，预算不加；publisher沿实际checkpoint恢复。新洞口03实证前5句9H后可经普通J→旧catch→JR提前W，851帧/HP5；保留为较易尾路，不称高难或七句必经，上层吸引力仍REVISE。FOREST-GRAPPLE-02及父任务保持in_progress／REVISE，有限测试迁移子process独审通过不代签地区。下方旧身份与命令背景仅为历史。

2026-10-18最新可试玩交付：[build5fd40a31c4be](https://zhipijun1996.github.io/gunman-rush/?v=5fd40a31c4be)，游戏源码 `5a9f4bdaf846a635eb2659080d563b865758ab87`，默认 `forest-expedition-airborne-v11`。[实际证据及边界](evidence/forest_depth_v2/forest_feedback01/release01/README.md)。选定CI39160856629完整SUCCESS：86项gameplay/art同源汇总、Web/Windows/deploy/verify_public通过；公开PCK校验与GUI02八入口20/20通过，森林两图实际v11。原GUI01 OCR失败、原本机600秒/长片240秒失败不覆盖；仅浏览器采证工具窗口后修并独审负例，不冒称后续工具/文档HEAD重新构建游戏。CI ZIP受proxy403阻断，publisher live_verified仍false，原包72未执行。原质量记录glob漏覆盖已doc-only修正且push/PR两docs通过。整体REVISE/in_progress，摆荚价值、QueenH、巨木轮廓/荆棘宿主、真人/设备/商业仍未认可。以下H与其他旧交付段仅为历史。


2026-10-18四项反馈续轮：默认布局已改为 `forest-expedition-airborne-v11`；扩大实际探索到5630px，接入H→H、R→H、四连和经删动作对照保留的五连，新增方向盾甲虫与摆荚，所有实际支持面消费森林结构/材质身份。详见[本轮设计](design/forest_feedback_expedition.md)和[证据及未通过项](evidence/forest_depth_v2/forest_feedback01/README.md)。原固定80案例已同源分组实测且独审逐原raw通过；原整组Harness600秒仍超时失败，不由分组覆盖改签。实际原速两图影片、最终CI/Web发布与浏览器以证据页最新结果为准。质量记录FOREST-FEEDBACK-01及父任务保持in_progress／REVISE，尤其摆荚实际路线收益、QueenH、初见手感、真人／真机与商业品质仍未认证。以下旧v10与H交付段为历史检查点，不覆盖此默认布局，也不冒充新版已发布。


交接身份：分支 `feature/thorn-forest-depth`；实际可玩源 `367b7c1a594beaa99df60c3cd8fc7e5ebe73d7e0`，build `ab99155b1b88`。[源／包／部署边界](evidence/forest_depth_v2/H_release01/README.md)。

2026-10-18最新交付：[H技术发布原件与边界](evidence/forest_depth_v2/H_release01/README.md)。H `367b7c1a`／CI39105617804实际SUCCESS：85=67+18及serial5附加，Web／Windows／两docs22／deploy／verify_public通过；准确原包72/72、errors0、359.125秒。publisher verified，试玩[build ab99155b1b88](https://zhipijun1996.github.io/gunman-rush/?v=ab99155b1b88)。额外公开森林GUI因IPv6网络不可达0/20执行，属blocked_network，既非20通过也非玩法失败。独审仅技术ACCEPT，整体REVISE／in_progress及QueenH、探索密度、真人设备缺口保持。旧pending段为当时快照，最新段只覆盖对应已实证技术结果；bare1481=0cf不等于prepared56Foundry同旧版。


最新有界跟进：[G真实FAIL与依赖／词法计算收口](evidence/forest_depth_v2/G_bounded_followup01/README.md)。G整轮为failure非cancel：serial16PASS后旧asset缺失、parallel11PASS后原87超时60.041秒；Web／Windows／两docs成功，准确CI包浏览器72/72（build30220a607325）不代全CI。补两真实bee旧raw后原历史matrix60与formal27/0一次严格PASS；单次词法memo保FS每次新读，原87本地24.368秒PASS获限定独审。历史与局部成功不重签G失败，H完整同源CI／HTTPS仍待，整体REVISE不升。


最新限定修复：[F旧平原体验夹具实际退出泄漏](evidence/forest_depth_v2/plains_experience_release01/README.md)。F serial负例8/2之外真实6对象／2资源泄漏被原严格拒绝；whole run终态cancelled，Web／parallel等取消、Windows成功，core缺lane失败。复用原AudioTeardown的两文件修复后唯一原CLI49.675秒PASS、292/0与9/2／cleanup真／无leak获限定独审；原动作／180和900预算不变。F PRdocs87dots／60timeout与同FpushdocsPASS分列，1.432秒preflight不证根因；E未知仍未知。新源完整CI／部署／浏览器／HTTPS待，整体REVISE不变。


最新CI跟进：[E旧平原体验检查与原件收集](evidence/forest_depth_v2/plains_experience_artifacts01/README.md)。E的serial原plains-experience-golden实际FAIL且inner未收；root取消余下parallel，整轮terminal cancelled／core不完整，Web／Windows／docs实际PASS。唯一原CLI本地53.483秒PASS与255/0、预期negative8/2、42变造拒绝分账，CI原因UNKNOWN。仅profile三行artifact_paths补收inner获限定独审，不是已证根因修复；publisher exit1／ci_failed，无部署或E浏览器。新源最终CI待运行，整体REVISE不变。


交付验证跟进：[Git临时夹具生命周期隔离](evidence/forest_depth_v2/git_fixture_lifecycle01/README.md)。D的PR docs／选定Web job实际清理FAIL，随后root停止其余长core，整轮为cancelled／非完整CI；同D先前pushdocs与Windows成功。两行本地Git配置后原87测试32.892秒PASS、342断言／清理／60秒预算不变，独审仅限定ACCEPT；原CI写入者未证。pubcheckpoint为ci_failed，未部署／无新D Web包或浏览器验证；仍待修后最终同源验证，整体REVISE。


当前交付边界：[Twin01–02停止档案](evidence/forest_depth_v2/twin_port_rejected01/README.md)。真实上H／一弹／右岸12只属局部进展，两整段仍FAIL；独审DROP且不做第三驾驶修。生产Boss几何未改，实验fixture／CLI已恢复e840，runner／UID已封后删除。本轮有实据淘汰，尚未填平QueenH核心、随机探索与密度缺口；仍是可玩候选／整体REVISE，非商业完成。最终同源CI／Web／浏览器／HTTPS及真人设备认可仍待，不标done；原电影仅可按0cf游戏字节绑定复用，不冒新片。


最新探索取舍：[root11入口v11退休档案](evidence/forest_depth_v2/root11_entry_rejected01/README.md)。四路线JSON／原生PASS及兼容126/0保留；新growth比旧W多527帧且末少1HP，自动拾心并非主动claim，冠路短327帧不等于整体探索改进。root据独审决定DROP此扩展，六源已精确恢复6b132007，默认仍v10。后续双洞黄金亦已淘汰，整体REVISE／未商业完成，不关闭whole任务。


最新黄金结论：[trailing-bud01–03停止档案](evidence/forest_depth_v2/trailing_bud_rejected01/README.md)。03真实cast／fly后miss，未到达且整体3FAIL；固定对照935击杀／HP5保持。独审DROP当前120px方案，不等于物理不可能。已封927成员实际源，生产／消费者指定文件恢复0cf原字节，whole-body与尾苞实验组件已删除；不重签旧CI或体验。后续root11探索黄金已实测后退休，原件见对应档案。


最新玩法返工：[whole-body实验淘汰档案](evidence/forest_depth_v2/mobile_anchor_rejected01/README.md)。9ca／5bd真实普通、H-only与mixed-chase对照后独审DROP；技术PASS不改设计淘汰，原context／partial-foot／死亡FAIL保留。内容未商业完成，整体REVISE；该时点trailing-bud仅opt-in G0；后续03已停止，非当前v10。后续实际移除与尾苞停止结果见最新段。


CI基础设施跟进：0cf旧身份reader失败后，A/df3f定向7通过；实测单core60分钟风险后，原85项按67/18分机、原预算不增。C路径独审REVISE保留；C2（`5ec5e9e3`）仅基础设施独审ACCEPT。新CI待运行；原浏览器4项FAIL／未证根因和整体体验REVISE不变。[限定记录](quality/records/FOREST-DEPTH-CI-LANES-01.json)。

最新验证跟进：[原CI失败与限定修复](evidence/forest_depth_v2/release_followup01/README.md)。0cf完整CI49项通过（含当前固定80路线），Guardian原生25/0后因旧map2身份reader失败；df3f版本严格迁移已获独审，干净源原Harness定向7实际通过，非最终完整CI。当前0cf正常影片的16px结标记已获实景限定接受，“岸”正式objective未展示；原浏览器首20/24与唯一诊断24/24分账，首发根因仍未证，另两组48/48不消除原FAIL。整体仍REVISE，最新完整CI／部署以PR与元数据实际终态为准。

2026-10-18，`/workspace/gunman-rush-design`，分支 `feature/thorn-forest-depth`。PR76仍OPEN/DRAFT，基线 `bee850c66b2f402d644d7daa4c13db91c8abe8f8`；实现历史 `9fdf7fad08550ea0da46b59ef7126fa721571f28` 与生态检查点 `dd214dde`保留，不改写／压掉。当前实际实现见[当前状态](current_state.md)，以最新源与独立证据为准。

默认v10／Canopy-v3已接入真实地图、自然入口、封场和奖励消费者。女王两部正常完整片、三种黄金完整打法、正式App03真实保存恢复和24HP击杀、9个实际畸形原子拒绝、GOLD/D/Home闭环均已有[便携证据](evidence/forest_depth_v2/canopy_app03/README.md)。原01／02失败不覆盖；03战斗HP4→4，恢复按原checkpointS，HP/E/上限保持，不能称保留空中位置。原生读取器与后续离线补强分账。

新N推荐回程已由单root00／map2／growth真实1013帧严格通过；最初1ULP方向误比较失败保留，修复只观测真实Router队列，不改输入、Player或原exact断言。旧V7／V9整Manifest与原哈希重建126/0；旧版本、旧Queen194／schema13 App强回归仍必跑，当前默认另验精确Canopy scene/resource／v10，不能互相代签。

H已实际完成适用gameplay/art85项（67+18）及serial5额外、两docs各22检查，Web／Windows／deploy／verify_public成功。实际源H与build_id见顶部最新交付；不因本次文档记录重跑H整套原生长测。公开森林GUI额外20项因网络0执行，待可用网络；内容／玩家／设备仍未认可。PR基于`feature/playable-thorn-forest`保持draft，不合main。

质量记录仍in_progress／整体REVISE：H核心与大部分区域的体验价值、广泛探索差异、有效遭遇密度、高结保留／诱导收益、初见可读性、音频、玩家与真机均未认证。普通快解保留，不靠加血、缩台、加刺或禁普通策略突出钩索。新16px活结文字后补0cf正常片／密帧获限定接受，headless不签像素，正式“岸”目标未展示。技术回归不能签商业品质。

仅用Godot4.7.2及现有工具链。全局`build/verification/engine.lock`单引擎；派生缓存清理26／27只涉及终止快照import／shader，源／raw／收据／电影SHA均保持，终态N02的可重建导入缓存已回收，源码／raw／收据前后SHA保持。源码、失败与正常影片原件不得删除；重放旧快照可能需重新导入。

发布命令沿用 `python3 tools/publish_playtest.py --ref feature/thorn-forest-depth --repo zhipijun1996/gunman-rush --expected-commit <SHA> --checkpoint build/verification/publish-playtest/<SHA>/checkpoint.json`。同一dispatch轮询超时用同checkpoint的`--resume`，不盲重派失败CI；必要修复须先有明确诊断和新提交。最后验证真实CI产物的鼠标／仿触屏入口、暂停及元数据，物理设备仍awaiting-device。后续内容以[森林设计](design/forest_depth_v2/README.md)和[新女王设计](design/thorn_queen_canopy_v3.md)的未通过项继续，不重新扩张已淘汰候选。

上一检查点交接全文（含其他阶段背景）按原字节保留为[历史交接](archive/handoff_before_canopy_v3.md.txt)，来源和SHA见[归档说明](archive/handoff_before_canopy_v3.provenance.json)；历史待办不覆盖本页。


四项反馈续轮已推送游戏5a9f与记录修复c5d；后续只收采证工具ROI和文档，不合main。不要因旧publisher waiting_ci误派新CI：原run39160856629已完整成功并实际部署5fd40a31c4be，只是本机取CI ZIP遭proxy403，原checkpoint不verified。后续优先处理森林场景宿主/轮廓和摆荚真正路线价值、QueenH体验；全局引擎锁沿用，当前无需重跑已成功86项。最终工具差异与两次GUI必须分别绑定，真人/真机仍待，不标done。
