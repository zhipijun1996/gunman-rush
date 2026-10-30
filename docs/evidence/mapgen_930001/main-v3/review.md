# 普通主游戏入口阶段独审

2026-10-30；MAPGEN-930001-01；固定 delivery 0.1.0／seed 930001。审查源码 `71a46558e217633836df0b0b34380c7c0df7a5f2`，实现者 root，审查者独立 child agent `/root/review`。本报告只写独审，不修改生产或测试、不运行 Godot。独立方法为源码反例、实际原始报告／日志和快照核验；引擎运行者为 root。**独立源码审查成立，审查者亲自操控／独立运行 G1/G4 仍 UNVERIFIED。**

用户本轮已要求普通出发直接进入该地图，并授权主游戏试玩发布。此授权改变入口及部署范围，不表示用户接受地图品质，也不表示可以清除 M24 失败、扩展其他 seed 或默认合 main。此前[地图／表现独审](../art-v2/review.md)的范围仍有效。

## 阶段结论

**ACCEPT：普通主游戏接入的本轮技术实现及三处旧消费者测试迁移。** 已报的 V5 Boss 合法伤害拒绝、隐藏预览键、配置来源漏记、正式 HUD 未驱动和 bind 部分赋值问题均已修正；下面列明实际证据与限制。

**整张地图端到端完成仍 BLOCKED；Web 发布／最终浏览器普通入口待验。** M24 原三项失败、全图自然路线、动态最坏相位、完整 168 项、实体设备、完整音画／听感和用户 G5 不因这次入口通过而通过。

## 源及原件

- [最终专项](final-report.json)在精确 `71a4655` 实际 **94 checks / 0 failures / source_stable=true**。读到的运行输入 3380 项 before==after；原生日志未发现 SCRIPT／SHADER／原生 ERROR、ObjectDB 泄漏或退出资源占用。runtime SHA-256 `369e158664eef87d82b8a1fb717f71fbb5f6587ab4f47d1584fbaa8e3a40bfca`。
- 复核时生产／测试字节与该快照相符；Foundry 的 batch、export_basis 和 replay 资源已有随后原生重建变化，因此不声称当前全工作树与该快照相同，后续 Web 必须绑定实际导出源。此前 dev05 同为 94/0，但其 report 准确保留当时 `0fcc085` dirty 工作树来源，不重标成最终提交。
- [相关 Harness 回执](related-report.json)的 commit 为 `71a4655`，underworld-ui、home-codex、underworld-formal、item-v5-manifest 四项均 passed、exit0、reused=false。underworld-ui 原生为 **294/0**。更早 [失败 related 回执](failed-related-report.json)整体 failed，其中 demo-ui-time-energy 确实 fresh passed，underworld-ui 则真实失败；不把这份整体回执写成通过，也不冒称前者在最终 SHA 又重跑。
- [core-dev02](core-dev02.log.gz)实际 5686/0，为此前开发源的原生 Core 证据，非本次完整 168 项。早期 String(int) 编译错误、出生前移动导致 unsafe anchor、Manifest 跨类型比较错误和旧 UI 消费者失败原件均保留。

## 生产反例与复审

| ID／范围 | 发现、修改与检查结果 |
| --- | --- |
| MAIN-R1／普通入口 | Home requested_plains 和再次出发进入 start_fixed_plains；显式 start_plains、debug region 和原 generated 算法保留。新增单图 profile boss_stage=1，不将旧 formal 两图目标改小。原 start_demo 仍创建唯一玩家、Build、钱包、Meta、输入和永久升级；初始 grapple 只在该新局 actor 创建时授予。 |
| MAIN-R2／borrowed 所有权 | bind_existing 在入树前接收原 controller、policy、lifetime、wallet、segment、meta、region_state。类型、active 与 scope 先检查后赋值，拒绝不留下部分 borrowed 字段。map 覆盖 DemoStage._ready／physics／draw，不调用其旧地形 super；hosted 不造第二玩家／touch／HUD，不再 CAP.apply、enable energy 或 return_to_segment 补资源。初始 actor DISABLED 到原碰撞装配完成后启用，避免地形缺失首帧位移。 |
| MAIN-R3／V5 Boss | 初审发现 map Boss 只接收 shot_id，主游戏原来允许的独立 ItemRuntime 伤害被拒绝。现读取同一 player.item_runtime 的 authorizes_effect，另外校验 source_actor_id、session_id，仍保留 started、实际 arena、lifetime 和 native_sink。伪造 flag 不能授权。 |
| MAIN-R4／记录与兼容 | 从原 generated loader 原样抽出 record_configuration／capability_snapshot helper，两入口复用；fixed 另记录实际 stage_tuning、装备来源／level／fingerprint 与双 SHA delivery receipt。fixed compatible 要求固定 profile／seed／单 boss／空 offers 和 decisions／双 SHA，先 Dictionary／Array 守门再比较，拒绝 generated_layout，沿原 _region_tuning 从合法来源重建而非信任任意 tuning。旧 generated 分支输出和调用位置保留。 |
| MAIN-R5／输入与 HUD | hosted 的独立 Enter／F5／Esc／M 处理直接退出，普通入口只由 App 的原菜单与输入管理。fixed 分支显式驱动原 DemoHUD、context／touch／navigation，隐藏旧 blackboard；overview、pause 和 M29 原生 modal 保留各自所有权。原生正常 INFO／暂停／M29／隐藏键测试支持技术结论，尚缺最终 Web 和设备画面。 |
| MAIN-R6／取消与结算 | App 转发原 post-damage action queue、environment return 和取消；map hosted 不结束借入 lifetime。Boss accepted combat 后 complete_stage→finish_delivery→原 run_ended／Meta settlement／cleanup→Home，不造 GOLD、不进第二图。旧 token、死亡、退回 Home、再次出发和服务清理均在专项中。 |

单图 Director 的负例实际覆盖 stage 未完成、旧 token、fake GOLD／success、第二图／下一区域／exit 拒绝、结算幂等、旧 formal profile 不接受 finish_delivery。原 formal/development 的 profile 定义与 API 没有改为 fixed 行为。Manifest 负例实际从主游戏 ready snapshot 深复制，修改 root_seed、receipt seed、两个 SHA、profile 字段、第二 stage、offers、数组 outputs／receipt、tuning／capability 类型、gravity、item fingerprint 和 physics hash，逐项 compatible=false、from_snapshot=null。

94 项包含真实 Title／Home／BEGIN／总结再次出发指针，第一段用原玩家射铃并从 M01 走到 M02；这段没有位置 fixture。prebind 资源保留采用明确的原生伤害／钱包／装备／能力 fixture，不能写成自然获取。新局 actor、武器与永久升级、单 player/router/keyboard/policy/audio/music/touch 及旧 token 拒绝分别记录。

V5 复审不是只看 flag：从原装备服务装备 G01，经 Runtime.deal 的真实授权 context，在第一次转交 policy 去重之前构造 unregistered event／错误 actor／错误 session／错误 amount 四个负例；原 context 不改，policy 实际将 Boss 36→35。卸装后旧 proof 即时撤权，新 deal 拒绝，未手动还原 HP；之后 35 发原生弹、三个阶段将 Boss 35→0、玩家存活并结算 completed_runs=1。该 G01 deal 是明示 API fixture，**不等于从普通玩家动作触发完整道具效果的体验测试**；Boss arrival 也是 fixture，不是自然全图到达。M29 领取为实际 W 和原生鼠标 OR 菜单，仍不签自然 arrival。

18 普通敌人的 V5 metadata 目前采用原 motor 的进程实例 ID 字符串，**只声明当前 run 唯一**，不提供跨重建／进程恢复的稳定内容 ID；复杂敌人模块卸载继续拒绝。原机关、奖励、伤害事务仍使用其既有 instance_key 隔离。Boss target_id 仍含 run／map／instance。此限制已向实现者核实，未为持久化扩展本轮范围。

## 三处旧 UI 测试迁移

**接受守门迁移，不是为绿灯修改产品流程。** 用户已经要求普通出发固定地图，旧测试若仍把该产品入口认作 PlainsRegionStage 则断言过时：

- demo_ui_01/contract_runner 和 underworld_plains/test_underworld_ui 均先真实 Home 指针断言 fixed 930001，再原生 abandon／回 Home 后，显式 start_plains 原 seed 执行原 generated fog、HUD、触控、小屏和退出用例；旧断言没有删除，fixture 边界写明。后者增加清理与显式入口断言，原预算未提高。
- home_codex_movie 只把普通出发的旧 stage 类型断言改为 fixed 身份，仍要求新的 run prefix、唯一 Lv1 inactive Home carry、来源身份和后续原装备／资源条件，不改变 Home 携带规则。

源码迁移与实际 fresh related 原件共同支持本结论。不能把这些 retained generated 用例当成 fixed 地图的 fog／小屏全覆盖，也不能把 native pointer 当成 Web／实体触控。

## 仍待交付的证据

Web 本阶段仍待验。原 export stamp 因 Foundry basis 对 run 脚本变化敏感而拒绝；root 正通过既有 build --count24 --promote 真正重建开发池，不改固定地图、生成目标、预算或守门。旧失败应保留，不能手改 basis 冒充通过。后续需要实际 source/build/PCK 指纹、普通标题→Home→BEGIN→固定地图及返回菜单的浏览器 GUI，再按授权发布并核公开元数据／完整 PCK。发布成功仅代表试玩可达，不表示 M24、自然整图或用户认可已经完成。

此前 standalone-v3 实际仍 **845/3**，三项均 M24，scope 明确 whole_map_continuous_traversal=NOT_RUN。本轮没有消除此阻断，不扩展批量地图。最后结论必须同时报告普通主游戏入口接通与原整图缺口，不能只给 94/0。

## HUD 实机返工补录：55b0760（2026-10-30）

root 随后实际 Web 试玩发现旧 `_title`／`_hud` 仍叠在正式 HP 上。审查者已打开旧 build `4ea38dda9616` 的 `build/mapgen_main/local-live/06-fixed-spawn.png`，确见左上旧英文标题／钱包文字与爱心重叠。这是实际可见缺陷；上文 71 的技术／迁移接受不能外推 Web 画面通过。旧 71、后续 d643cc9 来源、旧 4ea38 图与记录保持原样。已读取 `build/mapgen_main/cancelled-deploy-status.json`：workflow [41085324928](https://github.com/zhipijun1996/gunman-rush/actions/runs/41085324928) 实际 completed／cancelled；取消请求日志不单独当取消完成证明，旧包未获本独审发布接受。

修复提交 `55b07609ea756c6faee771aaa84f080b249917fe` 的生产 delta 仅在 fixed HUD 分支增加 `_title.visible = debug_hud`、`_hud.visible = debug_hud`，与原 generated 分支保持同一显示规则，没有改物理、地图、资源或流程。runner 在 first／second／retry 三局各加 `hud/single_visible_status`，要求正式 DemoHUD 在树中可见，同时旧 title／wallet／resource HUD 在树中不可见；wrapper 将三项全部列为 REQUIRED。它们验证真实节点可见性，不凭变量名或假截图判定；没有删旧断言或放宽预算。

已独立读取 `build/mapgen_main/final-hud/{report.json,runtime.json,native.log,source-before.json,source-after.json}`：精确 55b0760 **97/0、source_stable=true**，3380 项 before==after，当前逐项 SHA 全相符，未发现脚本／原生／退出资源诊断；三项新 HUD 记录均通过，debug=false 时 native_hud=true、三类 legacy=false。runtime SHA-256 `31c80e6613002afda0c7586ada6fb20b16f02dba894db12a2e29a0a13cb137dc`。**接受该两行修复和补充守门；最终 Web GUI 此时仍 PENDING。** 新 build `33925609669e` 的 preparation receipt 只为 prepared_only／published=false，不把导出或准备完成写成上线／画面通过。97/0 不覆盖 M24 或整图自然路线。

## 本地最终浏览器 GUI 复审补录

随后实际打开 `build/mapgen_main/local-final/` 下的原尺寸 `04-departure`、`05-fixed-spawn`、`06-bell-shot`、`07-moved`、`08-overview`、`10-small-backpack`、`11-small-M-guard`、`13-confirm-leave`、`14-return-summary`、`15-home-returned`、`16-warm-title` 共十一张 PNG。05／07 的正式 HP、共鸣和钱包可读，旧英文 title／wallet 叠字消失；04 显示 MAP930001 的普通 BEGIN；06 原铃门视觉打开，07 真实输入后进入下方原平台段。08 显示该地图总览。960×540 的 10／11 均保留背包页，M 没有把背包替换成地图；该页不是设备触控或所有小屏操作覆盖。13 是原离开确认，14 是正常放弃后的旅途暂歇，15 才是实际 Home；16 为同浏览器上下文 reload 后标题。未将放弃总结或 Home 截图写成 Boss 胜利，也未将 reload 写成缓存／弱网性能通过。

已读同目录 console／cmd／done 原件和 browser_live.py：入口通过标题指针、Home 的 D 移动／W 及 BEGIN 指针，后续使用真实 mouse／keyboard／viewport resize，脚本没有赋值游戏位置、HP 或 JS 游戏状态；JS evaluate 仅读取窗口／canvas 尺寸，DOM 读取 build-id。done 原件 build=33925609669e，普通入口 MAPGEN_MAIN_READY=930001，page_errors=[]。console 未见 SCRIPT/native ERROR，保留一条 **type=error 的 Emscripten 主线程阻塞告警**及 ReadPixels stall 警告，不能称所有 console error=0。审查者只独立看原件，没有亲自操作浏览器、完整播放动画或听音。

**本地限定 GUI ACCEPT**：普通进入、所见修复后 HUD、有限射击／移动／总览、原暂停背包、离开确认、返回总结／Home 和 reload 标题。不能外推网页自然 Boss 通关、全地图、实体设备、完整音画或用户 G5。

发布过程又有新事实：`build/mapgen_main/deploy-status-latest.json` 的 workflow [41086077493](https://github.com/zhipijun1996/gunman-rush/actions/runs/41086077493) 为 completed／success；读取 `public-byte-verification.json` 显示公开站 source=55b0760、build=33925609669e，完整 raw PCK HTTP200／230191840 bytes／SHA-256 `33925609669e1f59fc65c2dc8d3f4ee2d88cd127b9817d61544ad3db449a16f2`。这些是 root 的实际公开核验原件，审查者本段未另发起独立 HTTP 下载；公开浏览器普通入口 **仍待后续复审**。原独立 preview 容量拒绝和旧取消发布事实不变，不由成功部署覆盖。

## 公开浏览器最终补录：限定接受并封存

已实际打开公开运行原件 `build/mapgen_main/public-live/05-fixed-spawn.png`、`12-home-returned.png`：前者是当前新版平原／普通固定图出生，正式 HP 与钱包无旧叠字；后者实际返回可玩的风铃聚落 Home，不是只看总结里的“已返回”文字。两图角标均为 33925609669e 的构建前缀。已读取同目录 console、两批 cmd／done：URL 为 [主游戏试玩站](https://zhipijun1996.github.io/gunman-rush/)，done build=33925609669e、page_errors=[]、1280×720；console 同时记录 hosted=true／46 实例／spawn `[96,206]` 以及 ordinary_departure=true／profile fixed_delivery_930001。真实指针／按键记录覆盖 BEGIN、铃射击、D、M、Esc、原离开确认／总结／ENTER HOME；没有游戏状态赋值 fixture。审查者仅独立查看公开运行原件，未亲自操控远端浏览器，也未把仅检查过 cmd 的所有画面声称逐张看过。

公开 console 未见 SCRIPT／SHADER／native ERROR 或 uncaught page error；原 Emscripten type=error 主线程阻塞告警和 ReadPixels 警告仍在，不删、不改成零警告。本轮没有据此签性能、弱网或音频。

再核 `public-byte-verification.json`：status=passed、source=`55b07609ea756c6faee771aaa84f080b249917fe`、build=`33925609669e`，公开完整 PCK 为 HTTP200／230191840 bytes／SHA-256 `33925609669e1f59fc65c2dc8d3f4ee2d88cd127b9817d61544ad3db449a16f2`，与准备包身份一致。公开核验原件还逐项列出 audio-before、perf-04、perf-actions 的 archive_notice=true 与各自原 metadata SHA，保留历史入口归档身份，不把元数据归档表述为删除原 immutable prepared 字节；此处认可 root 记录的公开字节／归档核验范围，并非审查者额外独立全量下载。

**最终限定结论：普通主游戏接入技术、守门迁移、修复后本地 GUI、公开普通入口 GUI 及线上构建字节证据 ACCEPT。** 97/0 的主流程与 845/3 的地图记录同时有效；M24 仍阻断整图完成，网页自然 Boss 到达／通关、全图连续路径、实体设备、完整音画／听感、完整 168 项和用户 G5 均未签。部署成功不升级这些结论。`docs/worklines/mapgen_930001/interface_cleanup.md` 是后续接口收敛建议，未实施，本次测试不能冒称架构重构已完成；API 收敛也不能修复 M24 的原交付几何冲突。

本报告在此补录完成后停止写入，交由 root 归档 SHA／提交；不再改写旧来源或历史失败。
