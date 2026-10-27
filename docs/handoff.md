# 当前交接（2026-10-24）

## 2026-10-27 ITEM-V5-01恢复入口（当前）

分支`feature/item-v5-catalog`，main基线`879b39eaa869be70cb799dedd1bb6ffc35e0b92f`，冻结运行源`979dbb9ab5f04c82f9c605c775a5e92ee14f7141`。72 件有效道具、16 件同实例成长与9组有效联动已接入正式宝箱／Boss／商店、暂停背包与六个效果家族；21件删除道具不投放。03表H当前建议参数已由用户确认；原表与冲突完整保留。 质量保持review，旧PR110已合且不重开，本新任务不自动合main。

冻结运行源的选定 30 项原 Harness 全部 fresh 通过（0 复用、0 失败）；这是受影响专项，不是 full161 或远端 CI 全通过。 同运行源连续主游戏影片 93 断言／0 失败，实际退出0且源码稳定；准确时长与媒体参数见捕获收据。 最新证据见[evidence](evidence/item_v5_01/README.md)，逐件行为与缺口见[覆盖矩阵](worklines/item_v5_01/consumer_coverage.md)。原失败、source guard、Manifest／森林回归、原始媒体和明确fixture保留；K2影片不冒称修复后整源证据。

恢复先读build/item_v5/checkpoint.json、核git status／进程及实际PR精确head。只有具体失败／反馈才继续修改；不重复无关美术生产、不降原预算。相关命令：`python3 tools/harness.py --profile item-v5 --jobs 1`；正式跨区保留原`forest-campaign`检查，完整CI实际状态另核。`python3 tools/check_quality_diff.py --base 879b39eaa869be70cb799dedd1bb6ffc35e0b92f`；`python3 tools/check_release_evidence.py --commit HEAD`。

P17保留未装备的原全速蓄力基线，装备后按表40%／55%／70%运行，基础规则冲突仍待用户选择；G19的Boss计精英为可调候选，未冒称用户确认。S05／S08／S14待重设计，S03／S04／S11／S16因删除道具禁用。实体安卓／手柄、低端性能、平衡、听感、趣味与玩家G5未验。 不以软件GL代签物理设备；网页Preview容量受阻时交付实际可下载MP4并注明来源，不伪造新网页上线。当前录屏见[evidence](evidence/item_v5_01/movie-979dbb9a/movie.mp4)。下一步核本分支关联PR的完整Production impact结果；公开下载在推送后另验，不把本地文件称已发布。

## 2026-10-26 PR110：最终守门修订与合入恢复

用户已授权合main，先核[PR110](https://github.com/zhipijun1996/gunman-rush/pull/110)真实state／head／checks，禁止因下方旧开发边界再询问授权。原head05200fc的CI40324535594为serial55成功、parallel73成功后style13／14测试失败，尾部15未跑；本地补跑发现持有统计旧指纹，其他14全部成功，原失败保留。

新冻结测试／输入源`56f74fb0918d1cfbd1487a9734403975caf2e85f`：style14及旧v13拒绝、原check追加11个冻结输入（不删旧输入，不改命令／30秒／regex）、两trace仅允许精确1／3处持有统计API替换，保原2 SHA。当前原Harness97／0、独立97／0、7负例拒绝及真实稀疏缺v12阻断均有[便携证据](evidence/run_gear_merge_05/README.md)。游戏仍bb4bf46字节，R2测试入口11a4216、方向契约fae1799的旧证明保各自身份；没有新美术或复杂效果。

下一动作：最新同head的prepare／两full通道／affected全部成功后，用固定head普通merge。若已merged，同步main并核合并树与自动Godot构建，发布不冒称完成；失败只按实际check修，不放宽原门禁。恢复命令：`gh pr view 110 --json state,headRefOid,mergeCommit,statusCheckRollup`。本地当前分支feature/run-gear-inventory；user／实体设备与G5仍独立，任务review。

## 2026-10-26 PR110：已获合入授权，先核实际状态

用户已明确“合入到main”，覆盖下方旧开发阶段不合并边界。工作线`feature/run-gear-inventory`／[PR110](https://github.com/zhipijun1996/gunman-rush/pull/110)。运行源仍`bb4bf46`（R2入口测试源11a4216）；新增`fae1799`仅把creative契约测试的精确v16期望改v17，不改游戏／资源／工具或美术。全量CI的真实版本失败、不同作者独立10／0和历史拒绝见[本轮证据](evidence/run_gear_merge_04/README.md)。

下一步核精确PR head的prepare、完整parallel／serial及affected汇总：全部通过后正常merge，保原预算和全部守门；失败先定位具体check，不使用admin绕过。若已merged则同步／核main树和自动Godot构建，不重启旧PR或重复合并。主站发布以新构建的真实结果为准；合并不是设备／玩家G5签字。恢复命令：`gh pr view 110 --json state,headRefOid,mergeCommit,statusCheckRollup`。

## 2026-10-26 RUN-GEAR-UI-02：暂停直达背包与参考图分页

本轮用户反馈已实现于`feature/run-gear-inventory`／[PR110](https://github.com/zhipijun1996/gunman-rush/pull/110)，运行源`bb4bf464a639af6c20828b84a5ac1df3785f393b`：暂停一次打开背包，左已装备／齿轮形状负荷槽／独立滚动网格，右选中详情及装卸，顶部箭头、Q/E、LB/RB换页，关闭继续。选择只更新详情，离页会话失效，旧详情动作失效；不改变核心物理或交易。原规则见[权威文档](rewards_and_builds.md)，范围和独立分工见[反馈工作线](worklines/run_gear_01/ui-feedback-02.md)。

实际GL独立159／0、8／10／14槽及两尺寸像素通过；正式标题／Home／出发／平原新背包试片34／0并严格clean。一次宝箱位置fixture明确显示，不能称自然平台挑战路线；原三房间影片保留历史身份。最终选定Harness10项全部通过、正式主游戏影片27.47秒／34断言／0失败、UI contract149与R2新入口208通过；准确分源和技术复核见[本轮证据](evidence/run_gear_ui_02/README.md)为准。原R1–R5失败和前轮CI失败保留，不重签旧证据。

独立Preview预算942,360,001／943,718,400字节，新增完整Web包受阻；未删旧入口或增加预算。本轮公开短片与截图交付，旧试玩网页尚未包含本候选。质量保持review，用户审美／手感、物理安卓／手柄与低端性能未签。main未合并。

恢复后先核同PR状态与精确source，不重复旧PR108或整套无关美术。只跑受影响原Harness，失败先窄runner；最终媒体需干净源与真实source_guard。

## 2026-10-26 RUN-GEAR-01：局内背包与齿轮装备候选

实现分支`feature/run-gear-inventory`，基线main`26e7f2a`，冻结运行源`91ea8850f308cc3c955bcece2c35cd66f75e7bda`。后续只追加证据／文档，PR面向main且不自动合并。[交付与可下载完整操作录屏](evidence/run_gear_01/README.md) · [独审](evidence/run_gear_01/independent-review.md) · [权威规则](rewards_and_builds.md)。

当前道具先入无齿轮上限背包，暂停构筑装卸／原子替换后才生效；8→10→12→14容量与价格唯一来自config/gear_capacity.json。保持武器、核心能力和永久音符独立；保留收据幂等、死亡优先、跨图／地区／存活环境回退，真结束清理。新增常规道具走Definition／效果组件，复杂主动／武器／钩索技能本轮未开发。

同源独立15项原Harness fresh全部通过，core5685、gear107、正式UI64、campaign67、森林App92、地区当前15组及40图回放等零失败；另实际GL67／原触控44通过。最终原生操作片20.47秒、20断言／0失败、源码稳定且退出clean：固定开发关卡自然射击／行走／领取→入包→装备／生效→卸下／撤销→扩容；正式区域消费者另有实际App验证，不能冒称正式自然全路线。

所有真实失败和F1–F14修复链保留。当前技术ACCEPT／质量review，未做实体安卓／实体手柄、数百道具低端性能及玩家G5；扩容价格为试验值。27条旧独立路线及legacy-compat未跑，不记通过。当前style-v14／creative-v17仅重绑DemoApp，另35引用、原Bible和旧档字节保留，不继承美术／设备认可。

恢复命令：`git switch feature/run-gear-inventory`；相关检查见证据的原Harness命令与收据；`python3 tools/check_quality_diff.py --base 26e7f2a4459623f35613a857da8a75e89daa3e62`。完整PR CI以实际Actions为准；下一步只处理具体审查／用户设备反馈，不重启旧PR108合入或无关美术生产，不自动合main。


当前仅校验器收尾：f2CI实际Home184/0被旧181／四服务外层拒绝；现精确184/194／五runtime服务、39校验器测试、真实headless/GL及剩余22原serial全部通过，原门禁/预算保留。[准确分源收据](evidence/playtest_feedback_20261024/home-wrapper-contract/README.md)。f657只改三Python验证/录像工具，游戏仍b761/5ce，无需重导Web；最终head、CI和main状态继续核PR108，旧失败不改签。

## PR108 合入入口（当前）

[当前真实试玩](https://zhipijun1996.github.io/gunman-rush/?build=5cebbdc37404)，源码b7610b8a，build5cebbdc37404，Pages40061834215成功，完整公网184493060B PCK已核。修复五项反馈及集成发现的实际遮挡／小屏MENU冲突；左状态固定，其余导航／Toast保留保护，原UI139触屏断言未放宽。最终原Harness8/10/15 fresh126.817s与独立UI270/139/HUD61/GL通过，当前style13/creative16。

用户已授权合main。下一动作先核[PR108](https://github.com/zhipijun1996/gunman-rush/pull/108)实际状态与最终head：若未合且affected完整通过，执行普通合并；若已merged，核main树／运行源与自动Release，不重复合并或重启已通过检查。此页为预合入证据快照，最终CI及合并SHA以PR实际收据为准；准备产物分支不并源码。实际来源、失败保留和新公网GUI见[精选证据](evidence/playtest_feedback_20261024/hud-integration/README.md)。

仅Web像素密度与软件GPU观测已验，正常world保护扫描恢复；首次下载仍186MB，完整自然战斗／听感、用户和实体设备未签。原main旧Foundry音频Release失败保持其旧身份。

小屏集成修订：保留本帧响应式地图／暂停位置作为避障候选，避免桌面缓存fallback覆盖真实触屏MENU。原960×540失败与4fc独审REVISE保留；两行修复后原UIcontract139/0，最终同源专项／独审和新Web以实际结果为准。

PR108合入跟进：用户已授权main合并。1b25的Integration40056228724在真实平原场景失败，地图／Toast实际遮挡且透明状态VBox判定过宽。当前四文件纠正固定左状态、恢复其余保护并收窄共鸣；原Harness8路线/10native/15篡改拒绝通过130.281s，HUD61/0，原180/900预算不变。正常world扫描已恢复，不能复用e525无扫描CPU声明。style-v13/creative-v16仅再绑DemoApp，35项与旧版本保原。[当前修复证据](evidence/playtest_feedback_20261024/hud-integration/README.md)。独立渲染审查、新源码Web与最终冻结提交CI待实际结果；下方e525公开身份是此前候选。源码/tmp/playtest-feedback-20261024，保持单一引擎窗口；未合main，不重签旧通过。

任务PLAYTEST-FEEDBACK-20261024已完成候选实现与真实试玩交付，当前工作线`fix/main-playtest-feedback-20261024`。运行源e5254559，后续元数据/证据提交不改运行源。[直接试玩](https://zhipijun1996.github.io/gunman-rush/?build=2ed80c618b79)，build2ed80c618b79，Pages40053591706 success；公网完整184492580B PCK SHA与原导出一致。

实际实现、全部来源/失败及未验边界见[交付README](evidence/playtest_feedback_20261024/README.md)。Web原生HiDPI仅Web=off+nearest合成，HUD固定、普通hit模板14种22链及8Boss接入且死亡/弱点独立，原arms工坊3种Lv1会话选择，标题Start进入Home。基础炸弹仅补真实acceptedshot身份，不放宽原机制/Boss/rune/墙挡/站位/TTL/epoch。

独审e525原生270/139/56/597、源稳定/严格清理/34旧style引用与原Bible字节通过；作者原all-weapons2381/0、enemy426/458、GL12等保自身前阶段身份。真实新Web DPR1/2/mobile3鼠标/触屏通过；公网DPR2固定旧Seed/同Manifest正式平原、另一个实际行走/跳台阶/W工坊三选择case通过，后者没有出发，不混称路线。

用户已明确授权将本工作线PR108合并main。首轮Integration40054683541的parallel通道在quality检查发现本任务缺少五列表格索引行，原失败保留；已补齐与质量记录一致的review行，不修改运行源或门禁。下一动作：核最终head的实际affected汇总，通过后普通合并，核main提交与试玩运行源一致。完整CI、自然完整Boss战/路线、连续听感、实体设备与用户审美/手感仍按实际结果分别记录。首次加载仍约186MB；软件GPU的DPR2约7.78→23.68FPS随物理buffer减至CSS，不能称同物理分辨率算法收益或真人FPS。

源在/tmp/playtest-feedback-20261024；/workspace满盘未写。Godot安装原位，所有临时XDG与build用/tmp，模板只读引用。原Foundry36/18正常生成缓存已压缩逐成员SHA验证保存，导出后恢复原tracked源，不把它当新关卡内容或伪造旧通过。

当前style-v11/creative-v14，技术重绑仅DemoApp/HomeScene；原34引用/旧v10v13原件未变。原main四线已合cd4989；旧main Release Foundry音频失败保留，不被快速候选部署改写。避免再跑旧PR106/旧主线整合或用旧包冒充本轮。
