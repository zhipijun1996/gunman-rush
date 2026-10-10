# 开发任务

新路线P0–P6见[路线图](roadmap.md)。状态done只指该任务定义的证据齐全，不代表依赖PR已合并或真人验收通过。旧任务保留ID与历史Issue；新任务的docs/tasks.md为权威，尚未新建远程Issue。

| ID | 阶段 | 依赖 | 状态 | 交付与验收 |
| --- | --- | --- | --- | --- |
| DOC-01 | P0历史 | — | done | 旧规划基线；被DOC-02正式设计更新，不删除历史证据 |
| DOC-02 | P0 | DOC-01 | done | 新定位、运行/奖励/伤害/家园契约、旧规则纠正、策略状态与新验收；当时26文档/32依赖及契约检查通过，本轮提交/PR记录见handoff |
| ENV-01 | P1 | DOC-01 | review | Godot4.7.2实际可用；Cloud界面设置发布/历史环境人工项待用户 |
| CORE-01 | P1 | ENV-01 | review | 统一Router/Controller/Motor、N跳/可变跳高；自动证据通过、真机手感待验 |
| CORE-02 | P1 | CORE-01 | review | 释放射击攻击弹体/碰撞反冲、0/N资源、慢时/遮罩原型；A05–A08/A31自动通过 |
| BASE-01 | P1 | DOC-02 | done | 冻结77b10ec原型、实际326回归/解析退出0、故意失败1；只技术保留，不认定新系统实现 |
| INPUT-01 | P1 | CORE-02 | awaiting-device | 三指与取消；Android/iPhone Web真机触控待验，原生Android另记 |
| INPUT-PC-01 | P1 | INPUT-01 | awaiting-device | 三输入/重武装/配置提示已实现；实体手柄和A27完整轨迹待验 |
| WIN-01 | P1 | INPUT-PC-01 | awaiting-device | Windows独立导出已通过；Windows实机/通关待验 |
| APK-01 | P1 | INPUT-01 | awaiting-device | 旧debug APK构建证据保留；Web快迭代/原生按需构建，真机性能待验 |
| WORLD-01 | P1历史 | CORE-02 | awaiting-device | 旧机关/补充/检查点已实现；全关reset旧证据仅历史，正式迁移到SEGMENT-01 |
| LEVEL-01 | P1历史 | WORLD-01, APK-01 | awaiting-device | 旧固定挑战/20–30秒/3次通关/性能未证；新规则挑战另列LEVEL-02 |
| FRAME-01 | P2准备 | BASE-01 | done | 模块分类图、资源Definition/State/类型化请求结果/ActorResources组合/HUD边界已接入实际消费者；无全套空服务；module_map与374回归 |
| HEALTH-01 | P2 | FRAME-01 | done | 独立Health/Stamina状态与Definition/接口，保留ActionResources；固定图HP/Stamina/HUD及资源事务已实现；374/0、故意失败1；A32与A47当前原型自动部分通过，不认定RunEnd或正式精力用途 |
| ENEMY-01 | P2 | HEALTH-01 | done | 一种可配置悬浮巡逻Actor/AI/Intent/Motor/Health/表现及现有弹体受击，416/0；A20最小自动部分；不做玩家扣血/Boss、多敌人库 |
| DAMAGE-01 | P2 | ENEMY-01 | done | DamagePolicy批次/去重/怪物无敌、独立环境保护、击退策略空位；A33/A36；本轮固定demo自动证据见handoff/acceptance，正式内容与真机不推定通过 |
| SEGMENT-01 | P2 | DAMAGE-01 | done | 多SegmentAnchor/非致命环境回退/选择性资源恢复；不全世界reset，隔离Legacy即死；A34/A35；本轮固定demo自动证据见handoff/acceptance，正式内容与真机不推定通过 |
| DEATH-01 | P2 | SEGMENT-01 | done | 最小RunLifetime/终局取消与Home占位；零血不回段、不发未结算奖励；不做完整路线/永久经济；A35；本轮固定demo自动证据见handoff/acceptance，正式内容与真机不推定通过 |
| SUPPLY-01 | P3 | DEATH-01 | done | 一个固定补给与HEAL_CURRENT/INCREASE_MAX_HEALTH独立效果；A49/A34防刷；本轮固定demo自动证据见handoff/acceptance，正式内容与真机不推定通过 |
| BUILD-01 | P3 | SUPPLY-01 | done | 最小BuildState/来源Modifier添加撤销/能力与次数变化，不做万能技能编辑器；A42；本轮固定demo自动证据见handoff/acceptance，正式内容与真机不推定通过 |
| REWARD-01 | P3 | BUILD-01 | done | 固定道具二选一/独立ItemDefinition蓝紫金/领取组账本；A39/A49；本轮固定demo自动证据见handoff/acceptance，正式内容与真机不推定通过 |
| SHOP-01 | P3 | REWARD-01 | done | 一个明确测试商品/RunCoin报价/库存/幂等原子购买，正式刷新和价格待定；A41；本轮固定demo自动证据见handoff/acceptance，正式内容与真机不推定通过 |
| RUN-01 | P4 | SHOP-01 | done | 固定3关development_only配置、RunDirector/StageType/主题分离/两出口与manifest固定结果；A37/A38开发部分/A48；本轮固定demo自动证据见handoff/acceptance，正式内容与真机不推定通过 |
| BOSS-01 | P4 | RUN-01 | done | 一个固定核心Boss/阶段/Guaranteed GOLD/同帧死亡批次；暂不外围随机；A21/A40；本轮固定demo自动证据见handoff/acceptance，正式内容与真机不推定通过 |
| HOME-01 | P4 | BOSS-01 | done | 最小家园入口/返回、新局清BuildState；Meta独立内存接口+NO_TRANSFER开发fixture，不造永久经济；A43；本轮固定demo自动证据见handoff/acceptance，正式内容与真机不推定通过 |
| LEVEL-02 | P4 | HOME-01 | awaiting-device | 2026-10-10用户确认初验完成、允许生成设计；分设备三次通关/性能细项未提供，继续分别待验证； 新伤害/回退/3关链固定挑战真实手机三次通关及性能；A15/A16新规则、A34–A43体验；不冒充10关 |
| RUN-TEN-01 | P5 | HOME-01 | done | 正式8关与第8必Boss、正式构建拒绝短profile；大关总数未定保持数据化；A38正式项 |
| UI-01 | 独立 | HOME-01 | done | 主菜单/三关或十关入口/暂停与确认返回家园/设置/操作与构筑；同一Router设置即时生效、菜单不射击、不重置run，真实浏览器检查 |
| GEN-DESIGN-01 | P5 | RUN-TEN-01 | done | 初验后设计：横/纵/方形拓扑、8原创蓝图、类型/难度/镜头/端口/Manifest契约；设计检查不代替物理可玩；A50–A54 |
| GEN-MODULES-01 | P5 | GEN-DESIGN-01 | review | 八个固定样片及MODULE LAB已实现，静态/动态/双路/Boss边界真实Motor及消费者证据见handoff；技术review，手机读图/操作仍待验证。分批制作固定模块样片，先safe_hub/stepped_crossing/descending_switchback，再反冲与动态；真实Motor/动作余量/段回退/可读性 |
| GEN-PREVIEW-01 | P5独立试玩 | GEN-DESIGN-01 | review | 用户明确授权先拼接随机整关；复用已交付模块与唯一Motor，横向安全接缝、CameraRig、Seed/版本化布局Manifest、段回退不重抽；正式类型/三拓扑/真机另验；A55 |
| GEN-SEAM-01 | P5独立试玩 | GEN-PREVIEW-01 | review | 不等尺寸微/大模块直接对接，隐藏装配标记，尖刺与不同半径移动锯轮；Manifest升级/实际Motor/浏览器证据；A56，设备另验 |
| GEN-CHALLENGE-01 | P5独立试玩 | GEN-SEAM-01 | review | 高落差反冲攀升、远平台反冲跨越、连续向上左右摆渡与机关；真实Motor/弹体/携带验证后接随机池；A57，设备另验 |
| GEN-PORTS-01 | P5独立试玩 | GEN-SEAM-01 | review | 多入口/出口数组、资源水平镜像、Seed反向/高攀升路线、多终点一次选择；A58；任意转折分支图后续 |
| PLAINS-GEN-01 | P5独立试玩 | BIOME-DESIGN-01, GEN-SEAM-01 | review | 平原节奏/动作性能包络筛选与Manifest重放；大小跳实测/调整；A63，解析不代替Motor |
| GEN-LAYOUT-01 | P5 | GEN-MODULES-01, LEVEL-02 | planned | 有界图规划/端口接缝/验证保底/CameraRig；先横向，再纵向/方形各独立验证；A50/A51/A53 |
| GEN-DIFFICULTY-01 | P5 | GEN-LAYOUT-01, BIOME-DESIGN-01 | planned | P/C/T/R预算、六类型修正、静态阶段曲线与路线节奏；不暗改玩家物理或抵消道具；A52 |
| GEN-01 | P5 | RUN-TEN-01, GEN-DIFFICULTY-01 | planned | 少量验证模块、独立随机流/完整Manifest/有界保底；Boss外围只用适配模板；A17/A44/A46 |
| LEVEL-GEN-01 | P5 | GEN-01 | planned | 生成关真实Android/iPhone横屏抽样、纵向镜头/瞄准坐标/触控/性能；旧固定初验不代替生成关验收；A54 |
| LOOP-01 | P5 | LEVEL-GEN-01 | planned | 正式8关肉鸽最小循环整体验证，不把新Health/奖励规格挤入旧LOOP任务 |
| META-01 | P6 | LOOP-01 | planned | RunPolicy/Meta永久基础升级与幂等解锁，真实币种/保留先解决Q008/Q012；A43 |
| SAVE-01 | P6 | META-01 | planned | SaveService/版本/迁移/原子写入/损坏备份/本地与Web存储确认；A23/A29/A45 |
| CONTENT-01 | P6 | SAVE-01 | planned | 按一个主题/人物/武器/道具/剧情增量扩展，配置/组件接入；先解决相关待定项 |
| WORLD-STORY-01 | 设计锚点 | DOC-02 | review | 整合用户交接v0.2：世界背景/16区候选白名单/六层叙事/风格与待定项；A60，design-only目录与检查 |
| BIOME-DESIGN-01 | 设计规划 | WORLD-STORY-01, GEN-DESIGN-01 | review | 16候选地区主操作/五类十关曲线/模块与Boss意向/禁用组合/分阶段切片；A62，设计不代表物理或已开放 |
| REGION-ROUTE-01 | P6内容切片 | WORLD-STORY-01, GEN-01 | planned | 大关目的地与小关类型分层；过滤未实现/未解锁/不能到终点的地区；8/Boss8与金奖励后唯一过渡 |
| STORY-01 | P6 | WORLD-STORY-01, REGION-ROUTE-01, SAVE-01 | planned | 层级必经/等效线索、区域支线、Meta发现去重/版本化持久保存；身份结局待定，不抢动作输入 |
| ART-POLISH-01 | 独立美术精修 | WORLD-STORY-01, ART-PLAINS-01 | planned | 用户精美度反馈；平原手绘合屏黄金样板→模块材质/连接件→六动作/机关统一→随机覆盖与手机验收；A61，用户视觉认可前不扩产 |
| ART-PLAINS-01 | 独立 | DOC-02 | review | 复用美术分支平原包接入固定/随机关背景、地形、机关与角色；A59；不改物理或宣称正式十关随机完成 |
| ART-01 | 独立 | DOC-02 | ready | 苦痛之路方向原创样片/音乐工具评估，保持现有灰盒/遮罩；A22，不能宣称完整美术已完成 |

设计整合轮已完成DOC-02+BASE-01；本轮按用户要求完成FRAME-01再HEALTH-01，ENEMY-01作为基线保留；本轮按用户多任务授权分阶段完成DAMAGE-01至HOME-01的固定demo范围。用户已确认初验，GEN-DESIGN-01交付空间/模块/难度设计。GEN-MODULES-01静态批次已交付：四个真实场景、Motor轨迹与MODULE LAB。动态及最后环庭/Boss样片批次已交付；下一技术阶段GEN-LAYOUT（依赖review和LEVEL-02设备门槛）；LEVEL-02详细设备记录继续并行跟踪。P2固定代码可在原型已可运行基础上推进，人工验证继续单独跟踪；D054新用户授权允许平原十关生成demo技术切片先行，LEVEL-02/LEVEL-GEN真机证据继续独立待验。HEALTH/REWARD/SHOP只在实际消费者出现时实现接口，不先建所有空系统。

## 历史Issue入口

ENV-01 #1、CORE-01 #2、CORE-02 #3、INPUT-01 #4、APK-01 #5、WORLD-01 #6、LEVEL-01 #7、GEN-01 #8、LOOP-01 #9、ART-01 #10，地址前缀https://github.com/zhipijun1996/gunman-rush/issues/ 。旧Issue描述未在本轮批量重写，新正式依赖/验收以本文件与各权威文档为准；后续实现时逐项同步，不能把旧Issue“检查点重生”当新正式规则。

本轮起点PR #19仍OPEN，docs/procedural-layout-design叠加feature/ten-stage-menus；最新main已fetch，不假定main含未合并工程，不自动合并。所有平台与真机证据单独记录；3关测试配置不修改正式10关。

RUN-TEN-01/UI-01已完成固定可玩实现与1012/0自动回归、Chromium触屏菜单检查、三平台分别导出；不是GEN/跨大关终局/真机验收。六房间、9→Boss10和完整十关SceneTree证据见[本轮交接](handoff.md)。

八样片技术交付转review，不把手机读图或组合生成标done；完整GEN-LAYOUT仍依赖该任务及LEVEL-02。八个样片的分批自动证据范围与未验项见[模块目录](platforming_modules.md)及[交接](handoff.md)。

2026-10-10追加：用户认为样片过少过简单，明确要求先尝试拼接随机整关看效果。GEN-PREVIEW-01作为独立开发试玩可先行，技术依赖为已完成GEN-DESIGN与现有模块代码；不把GEN-MODULES手机review或LEVEL-02冒称通过，不改正式GEN-LAYOUT/GEN-01门槛。


| ID | 阶段 | 依赖 | 状态 | 交付与验收 |
| --- | --- | --- | --- | --- |
| WALL-SLIDE-01 | 后续能力 | BUILD-01, PLAINS-GEN-01 | planned | 指定GOLD道具来源授予、贴墙缓降/Motor仲裁/取消/资源不刷新；Q016先细化，A64 |
| WALL-ROUTE-01 | 后续能力路线 | WALL-SLIDE-01, REGION-ROUTE-01 | planned | 后期地区明确门槛、前置确定授予、撤销安全策略/模块实际轨迹与Manifest；A64，不以掉落概率保证 |


## D054平原十关与音符分阶段任务

| ID | 阶段 | 依赖 | 状态 | 交付与验收 |
| --- | --- | --- | --- | --- |
| ART-LATEST-01 | 表现 | ART-PLAINS-01 | review | 最新3bacc32手绘背景/地形/机关接入；未具独立枪角色不替换；A65，设备及视觉认可待验 |
| PLAINS-MODULES-02 | P5切片 | PLAINS-GEN-01 | done | 更多不等大小模块，真实Motor/镜像验证；A66 |
| PLAINS-TEN-GEN-01 | P5切片 | PLAINS-MODULES-02, RUN-TEN-01 | done | 各关独立seed/manifest、类型预算与安全散落、Boss10核心/外围；A66/A67 |
| NOTES-META-01 | 最小P6切片 | HOME-01 | done | 音符永久币与金币局内币分离、一个可配置永久升级实际消费者；A68 |
| SAVE-NOTES-01 | 最小P6切片 | NOTES-META-01 | done | 版本化原子提交/备份/拒绝错误/幂等及Web刷新；A68，不做续局云同步 |
| PLAINS-TEN-DEVICE-01 | 设备验收 | PLAINS-TEN-GEN-01, SAVE-NOTES-01 | awaiting-device | Android/iPhone网页完整八关、读图/输入/性能，Windows单独验证；不以自动测试代替 |

按模块/生成→类型与十关→永久钱包/存储逐片检查后集成。新增授权不把LEVEL-02/LEVEL-GEN人工记录改done，未完成的任意分支图与其他地区仍单独规划。

本轮技术完成证据：旧5703/0、新5suite2594/0（代表Motor路线与流程注入范围分别记录）、GUI7/0；Web/Windows分别导出，真实设备任务保持awaiting-device。见handoff及plains_ten_browser。

## 平原反馈分阶段迭代

| ID | 阶段 | 依赖 | 状态 | 范围与验收 |
| --- | --- | --- | --- | --- |
| WEB-LOAD-01 | 表现/工具 | PLAINS-TEN-GEN-01 | done | 实际冷热加载、压缩/缓存/更新恢复；A69 |
| PLAINS-VIEW-01 | 表现 | ART-LATEST-01 | review | 低饱和雾化视差、角色镜头比例；A70，设备待验 |
| HOME-UI-02 | P4表现 | SAVE-NOTES-01 | done | PR33标题/真实Home/NPC与合法消费者；A71 |
| PLAINS-VARIETY-02 | P5 | PLAINS-TEN-GEN-01 | done | 类型配方/局部反射/左下出生/高低出口；A72 |
| EXIT-REWARD-02 | P3/P5 | PLAINS-TEN-GEN-01 | done | 自动出口与一次奖励弹窗，死亡优先；A73 |
| FEEL-VFX-01 | 表现/调参 | PLAINS-TEN-GEN-01 | review | 地面反冲/慢时20%/有界动作特效；A74 |

D058本轮技术证据：旧完整5703/0；最终九suite3981/0，全部退出0；Web/Windows分别导出。最终39edfde252ed本地GUI8/0，实际捡音符4→5后返Home与刷新仍5；实际WebGL灰雾/差速视差成立，冷启动同包流量减少51.8%。VIEW/FEEL保持review，最终美术、独立粒子视觉与真机手感/性能未验；详细边界见handoff与plains_polish_browser。

## D060 八关与空间体验切片

旧RUN-TEN/PLAINS-TEN任务ID保留历史；当前正式8/Boss8以D060为准，旧设备任务验证目标同步8关。

| ID | 阶段 | 依赖 | 状态 | 范围/验收 |
| --- | --- | --- | --- | --- |
| RUN-EIGHT-01 | P5修订 | PLAINS-TEN-GEN-01 | done | 正式8/Boss8、旧manifest明确拒绝、完整推进；A75 |
| GEN-SPATIAL-01 | P5优先 | PLAINS-VARIETY-02 | review | 分岔汇合/折返/纵向实际坐标与主支路Motor、弱能力保底；A76 |
| EXIT-CONFIRM-01 | P3/P5 | EXIT-REWARD-02 | done | 奖励预览、Enter/Stay/离区重武装、唯一结算、死亡优先；A77 |
| PLAINS-ART-02 | 表现 | ART-LATEST-01 | review | 原创自然多层远景、货币/门/甲虫/荆棘，GPU与来源；A78，用户视觉待验 |
| HURT-FEEL-01 | 表现/调参 | FEEL-VFX-01 | review | 实际受伤姿态与闪光、段回退清旧地点；大跳降低而小跳不变；A79 |
| HK-COMPARE-01 | 参数报告 | PLAINS-GEN-01 | done | 来源/单位/实际比例与测量、不冒称官方参数；A80 |

D060技术源679660e：实际八关App127/0、批次回归54/0、出口37/0；紧凑空间1529/0、反冲挑战120/0、弱能力367/0、生成2770/0。14suite最终整组/远端CI以[验证报告](plains_eight_validation.md)更新；GEN-SPATIAL/美术/手感保持review，手机/Windows实际试玩不记done。

## D062 分岔动作与移动端迭代

| ID | 阶段 | 依赖 | 状态 | 交付与验收 |
| --- | --- | --- | --- | --- |
| GEN-BRANCH-01 | P5切片 | GEN-SPATIAL-01 | review | 空间分岔图、两条末端路线与端口验证；A82 |
| GEN-LIBRARY-02 | P5切片 | GEN-BRANCH-01 | review | 不等尺寸反冲/摆渡/荆棘/锯轮模块与真实轨迹；A83 |
| TOUCH-FLOAT-01 | 输入 | INPUT-01 | review | 浮动半透明摇杆、跳跃右置与多指取消；A81 |
| ENEMY-DROP-01 | P3/P5切片 | GEN-SPATIAL-01 | review | 非Boss自由出门、空中敌人、独立掉落与碰触爱心；A84/A85 |
| PLAINS-SCALE-01 | 表现 | PLAINS-ART-02 | review | 增大画面比例、动态爱心与单门表现；A86 |

本轮D062五项实现与针对性测试已交付review；证据见[分岔验证](plains_branch_validation.md)。18项完整回归19519/0、核心5704/0已通过；源CI/公开部署另记交接；涉及触控、视觉、手感的设备验收保持awaiting-device，不以headless代替。


## D063 输入舒适度与变化度规划

| ID | 阶段 | 依赖 | 状态 | 交付与验收 |
| --- | --- | --- | --- | --- |
| INPUT-COMFORT-01 | 输入 | TOUCH-FLOAT-01 | review | JUMP左移/大命中区，稳定两档与设置，300速度真实路线；A87 |
| SEED-FRESH-01 | P5修复 | GEN-BRANCH-01 | review | 默认新局新Seed，显式Seed复现；A88 |
| GEN-VARIETY-DESIGN-01 | P5设计 | GEN-BRANCH-01 | done | 固定种子/骨架根因、六候选与首批三骨架、组合规则/指标，plains_variety_design.md |
| GEN-RECOIL-GATE-02 | P5 | GEN-LIBRARY-02, INPUT-COMFORT-01 | planned | 按D064平原一跳包络区分可选/必需反冲，零枪反例与真枪正例；升级能力另测 |
| GEN-ARCHETYPE-01 | P5 | GEN-VARIETY-DESIGN-01, GEN-RECOIL-GATE-02 | planned | 三骨架固定样片→反向端口→真实双路线→有界集成；A89 |
| GEN-ENCOUNTER-01 | P5 | GEN-ARCHETYPE-01 | planned | 各骨架两种段落与动作预算、可选收集路线；A89 |
| GEN-NOVELTY-01 | P5 | GEN-ENCOUNTER-01, SEED-FRESH-01 | planned | 骨架袋/标签去重、版本化重放、同条件200Seed指标；A89 |

## D064 平原能力与段落扩充

| ID | 阶段 | 依赖 | 状态 | 交付 |
| --- | --- | --- | --- | --- |
| PLAINS-SINGLE-JUMP-01 | P5 | GEN-LIBRARY-02 | review | 默认一跳，平原奖励不随机恢复二跳；保留通用能力扩展与旧高级测试 |
| ROUTE-SIGN-01 | P5 | GEN-LIBRARY-02 | review | 分岔告示牌显示实际下一房型与方向，无切关副作用 |
| GEN-ENCOUNTER-02 | P5 | GEN-LIBRARY-02 | review | 扩充有效机制编排与段落组合，记录版本/能力/有界保底与物理验证 |

## D065 连续趣味性切片

| ID | 阶段 | 依赖 | 状态 | 交付 |
| --- | --- | --- | --- | --- |
| GEN-BLUEPRINT-02 | P5 | GEN-ENCOUNTER-02 | review | 横渡/攀升两种实际编排与完整双路线；不替代折返/环路 |
| GEN-RISK-01 | P5 | GEN-BLUEPRINT-02, ROUTE-SIGN-01 | review | 稳妥/挑战预告与额外拾取、防重复领取 |
| GEN-RECOVERY-01 | P5 | PLAINS-SINGLE-JUMP-01 | review | 正常零枪/失误负例/一枪救回真实轨迹 |
| GEN-RHYTHM-01 | P5 | GEN-BLUEPRINT-02 | review | Seed槽位交替与版本化计划复核，不冒充全部标签去重 |


## D066 镜头反馈

| ID | 阶段 | 依赖 | 状态 | 交付 |
| --- | --- | --- | --- | --- |
| CAMERA-COMFORT-01 | P5 | GEN-BLUEPRINT-02 | awaiting-device | 死区/有限前瞻/临界阻尼/回退切镜头，A97自动对照与手机防晕分开验收 |
