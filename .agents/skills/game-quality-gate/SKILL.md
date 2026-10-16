---
name: game-quality-gate
description: 统筹重要游戏内容与关卡生产的 G0–G5、十一维记录、专业技能路由和完成声明。
---

# game-quality-gate

## 实际失败后的生产与证据边界

沿[原生产循环](../../../docs/quality/production_loop.md)按实际消费者选短专项，再做集成和最终fresh回归；一个包的失败前缀只阻断其后继，不阻断无依赖家族。完整交付预检须选择实际完整profiles，不能把单个docs检查的依赖清单称为全流程已物化。单方向额度用task.max_calls约束，失败/重试/中断计数保留；换task名不是预算退款。

复用既验证输入摘要也验证实际归档/默认工作区原件，特别实测jobs1和隔离lane，不能只人工放一个cache目录。声明的非标准build产物根加入artifact_paths并保持原生日志；路径及所有祖先symlink不得带来外部原件。计时命令`--output`只观察产物，日志要`--log-file`真实捕获；exit0不代替内层ERROR/资源退出守门。阶段包络与纯模型compute分开，重叠不相加，历史未知不补造。

真实[连续岩壁校准失败](../../../docs/evidence/production_capability_repair/continuous_calibration/actual_failed_core/calibration.json)说明工程工具可通过而资产仍失败：原core覆盖0.984501低于冻结0.995不改阈值，周边用途另列而不追认完整家族。[实际工程闭环](../../../docs/quality/production_capability_repair/harness_report.md)使用原nonce、真实不同作者、原controller和零新调用恢复；模拟调度反例只验证执行器，不签模型生产或艺术完成。

## 视觉导演任务仍共用原门槛

画面品质/空间深度任务自动路由 [visual-director](../visual-director/SKILL.md) 统筹，art-director管风格/资产家族，scene-composer管围合/焦点/真实镜头，animation-vfx管环境动态，region-generator提供正式空间语义，gameplay-reviewer只读独审。沿用原production_loop、内容类型、G0–G5及十一维，不以新增视觉分数或process检查代签实际art内容。

先冻结核心玩法/生成/物理/资源、代表Seed/路线/能力/相位/镜头及预算，记录当前实景失败；资产来源合法不豁免新用途审查。G0先大轮廓/负空间/焦点/景层和正确空间资产家族，G2先静态黄金再动态，G3真实正式消费者，G4实际看像素的不同代理与有界返工；G5用户审美和实体设备依然独立。内部黄金的技术/AI专业准入足够继续授权内第二空间验证，不因缺最终用户签字反复询问普通步骤，也不宣称用户认可。

实际入口为 `python3 tools/visual_director.py route --help`、`run --help`、`capture --help`、`inspect --help`、`compare --help`，合同见 [视觉合同](../../../docs/quality/visual_director_contract.md)。route或未execute的run只是计划，真实宿主/CLI工作、修改、采集、独审和复验各存原件/退出码/耗时。全片录制不实时PNG读回，片终抽帧写video frame/time；保存原失败，不能更换输入、Seed、源码标签或降低阈值把旧失败冲成通过。

预算分别记模型/图生编辑/实现/采集/审查/返工/Harness真实次数与时间；API未暴露价格/用量写not_exposed。连续两轮独审无实质画面改善、关键工具不可用或预算达到，保留失败并停止相应依赖，不靠新建包隐形重开。只跑受影响快查，交付仍执行完整适用profile。技术passed、AI审美判断、用户认可、手机缩小代理与真机性能分开；未达商业目标明确未完成，大任务结束按已授权要求部署试玩并报HTTPS/build_id/source，不以部署签品质完成。

可复用经验进入既有知识记录，附真实像素来源、修复/反例、源和母版版本、空间/消费者范围及待验，不把一次局部判断升全局规则。黄金先于泛化；第二空间是新的空间需求推导与真实Godot接入，不能旋转/复制首场景或以静态概念图证明自动生产成立。

## 触发与边界

重要游戏内容总流程、质量门槛与完成声明；普通修复按风险轻量验收。 从仓库根目录调用 `$game-quality-gate`。使用 [总门槛](../../../docs/development_quality.md)；重要内容由 game-quality-gate 建立一次任务，专业技能补充同一记录，不重复执行共用阶段。

## 输入与依赖

读取当前AGENTS及当前状态；按任务消费者读取相关设计与架构，保留目标、完整SHA、任务/内容版本、路径、已知失败和能力来源；缺证据写unverified。

## 阶段流程与交付物

识别 enemy/boss/level_module/region/art/animation/mechanic/ui_feedback/process/small_fix，填写同一个任务记录。重要内容必须启用相关专业技能，不能把整项 Boss 工作拆成若干 small_fix 逃避验收。
- 主角→player-creator，武器及升级→weapon-creator，新能力→ability-creator，新敌人→enemy-creator，新 Boss→boss-creator，新挑战→level-module-creator，随机区域→region-generator，新美术→art-director，动作/特效→animation-vfx，独立审查→gameplay-reviewer；Git 整理可用 project-integration。
- 输入用户目标、最新分支/PR/提交、正式消费者、已有契约/能力/未验项目。先 fetch 并比较 ancestry 和累积内容，不能默认 main 最新。
- G0：明确体验、趣味来源、差异、核心操作、反冲关系、学习/策略、视听/UI、失败恢复与可证伪验收。重大创意标 proposed，取得真实用户依据后才能写 user_confirmed。
- G1：真实输入、PlayerMotor、弹体、碰撞、资源与开始结束流程，保留成功/失败/边界反例。禁止传送、改位置、直接结算冒充实际操作。
- G2：专业技能提供正式画面合屏、连续正常速度录像、过渡与事件同步；原画、导入与静态姿态不能代替。
- G3：列出真正消费者和调用路径，验证入口、实例、池、奖励/保存、暂停/死亡/回退/重载、epoch 取消、对象和性能。
- G4：实际执行相关 harness 与反例，交给独立审查者。没有独立执行条件就 unverified；保留 REJECT 和复审链。
- G5：分别记录功能、GUI、美术、动作、趣味、设备和玩家认可。用户未认可的主观维度不能最终通过。
- process 只做 G0/G4、design/technical；small_fix 另按 formal_impact 检查 GUI。文案修复不用走 Boss/素材/设备全流程，范围扩大立即重新分类。

## 设计要求

使用 [专用模板](../../../docs/templates/iteration.md) 写场景/前置、方法、可观察结果和失败条件。复用真实配置/Definition/架构，禁止重复数值默认值、无消费者框架或为通过测试改基础物理。占位仅限明确标注的原型，不能冒充最终内容。

## 消费者覆盖闭环

执行 [审查方法的覆盖闭环](../../../docs/quality/review_method.md)：先从正式实例和分支盘点消费者，再逐项对应实际输出证据。未修改、不同物理语义和已有辅助测试都不是豁免依据。新任务的 consumer_coverage 将运行 inventory 与观察一一对应；缺项、错场景、仅 helper 通过不能宣称正式通过。最终声明不得超出记录的 scope；缺画面写 unverified，用户拒绝保留失败链。

## 自动验收

大任务按 [生产循环](../../../docs/quality/production_loop.md) 拆依赖包，先黄金样板后扩展；允许有界反复调用专业 Skills 与独立审查，遇创意/玩家验收或无进展必须保留现场。

先运行 tools/quality.py init，再按范围运行 harness；tools/quality.py check --require-complete 用于最终声明。检查文档、证据 SHA/版本、状态一致性、实际退出码、正式路径和测试没有降标。脚本只检查证据结构，不会评出“好玩”。 记录实际命令、环境、退出码、日志和版本；计划命令不算执行。执行 [质量检查](../../../tools/quality.py)；静态检查、运行测试、实际宿主调用分别记证据。

## 人工审查

逐条比较设计与实际体验，识别换皮/数值堆叠/素材拼贴和遗漏消费者。用户确认仅记录可溯源原话，不能用 AI 自评替代。

## 人物动作扩展（2026-10-13）

读取 [设计入口](../../../docs/design/player_actions/README.md)、[动作与harness规划](../../../docs/quality/player_action_plan.md)，使用 [动作覆盖卡](../../../docs/templates/player_action_coverage.md)。

武器/能力整套工作按动作规划拆包，单武器不产生跨武器并行组合，但同武器实体上限和能力衔接不能漏验。先inventory、输入/Runtime最小切片，再黄金样板与逐分支扩产；计划中的检查不得注册空runner或写PASS。新运行内容另建相应内容类型记录，不能借ACTION-DESIGN-01的process结果签完成。

## V2：关卡生产仍使用原质量体系

读取 [Level Design Harness V2](../../../docs/level_design_harness_v2.md) 和 [关卡验收卡](../../../docs/templates/level_experience_acceptance.md)。生产工具/合同/Skill 的任务仍归 process；实际地区/模块/资产分别沿用 region/level_module/art 等现有类型，不新增冲突的 G 编号或第十二维。技术片和正式地区必须分开声明，不能用 process 完成签地区完成。

按目标路由：优化已有地区/制作新地区→region-generator；连续动作设计→challenge-choreographer；模块物理实现→level-module-creator；战斗平台/奖励/路线节奏→encounter-director；空间构图→scene-composer；风格与资产生产→art-director；独立体验反证→gameplay-reviewer。新三 Skill 只覆盖旧技能缺少的编舞、联合节奏和空间构图，不接管敌人/Boss/动作实现。

G0 统一地区、挑战、能力、遭遇、构图意图与失败条件；G1 真实 Motor/输入/资源及连续衔接；G2 正式比例合屏与正常速度视听；G3 正式两图/RunManifest/随机流/保存/成长消费者；G4 V2 专项和原 Harness、正反例、独立审查；G5 玩家对探索/技巧/美术与真实设备认可。六层设计是内容分层，G0–G5 是验收阶段，二者不得混淆。

输入和产出沿用任务 ID/质量记录，附 BiomeDesignProfile、RoomIntent、ChallengeSequence、CapabilityRequirements/Snapshot、EncounterPlan、SceneComposition、LevelExperienceReport 的实际版本和消费者。设计意图、生成结果、运行状态、Motor 证据、主观评价分栏；只使用实际实现的字段和 CLI，格式以 V2 文档为准。

自动执行 V2 route 检查自动路由，validate 检查合同，analyze 读取真实 Manifest/轨迹，compare 对比同依据报告；每个新增检测保存通过例和故意失败例。仍执行原 harness docs/gameplay/art 等适用检查，不能用专项替代原回归。缺依赖、空报告、错误版本/能力/Manifest、错误消费者均不得 PASS；阈值变化须说明基线和校准依据。

人工验收把审美、手感、趣味、设备分别留证；缺项维持 unverified/review/awaiting-device。失败归属拓扑/能力/编舞/遭遇/构图后最小返工，重跑受影响门槛，不无限重抽种子。正式准入依现有 policy 的全部适用维度，技术诊断成功不是好玩结论。

示例：本轮“建立生产体系”只可在有真实检查/失败反例/独立审查后声明工具完成；未来“制作森林”还须新机制、完整地区集成、黄金美术、玩家与设备证据。两者共用任务/质量系统而非重建流程。

## 自主生产闭环与 Q1–Q8

把Q1–Q8作为同一任务的质量目标和审查发现索引，按统一映射回现有十一维。地区标准源自动加载后才路由；本轮实际平原切片归region/相关内容类型，工具扩展归process，不用process通过代签内容。森林仅按原S2-H权威做dry-run。

组织真实有界循环：冻结基线与授权/路径→专业设计备选→真实实现→适用测试→新只读审查→结构化返工→复验。把实际worker prompt/事件/退出码、修改快照、Godot/GUI证据、审查身份和修复版本放同一记录；假worker/mission计划仅测执行器，不能签自主制作。本轮至少一正式优化切片、≥10不同root Seed覆盖两图/不同路线和正式敌人画面，缺项明确未验。

修复执行不因常规步骤请求用户确认；预算、无进展、越界或外部工具依赖阻塞才保留现场并停止对应依赖。相同输入指纹可恢复，源码/任务变动使旧通过失效；日志不删、拒绝不覆盖、失败不重抽。新CLI按实际--help和已注册runner调用，未实现不写可执行。

知识回流写来源/观察/推断/范围/正例/反例/版本/待验，不能把一次seed经验变全局规则。若技术第一轮已通过，不人为污染生产制造失败；隔离演练标scope，真实发现按真实修复链存证。最终设备/玩家未验仍保留，不影响授权范围内独立可推进的修复。

## 平原实战后的收尾守卫

任务/质量卡/portable证据都是实施产物：分配租约前确认 docs/tasks.md、本任务记录和证据目录均在可写范围；不准越界后悄悄补写。执行 `python3 tools/check_quality.py` 检查索引与卡一致，`quality.py check` 不能替代它。纯技术阶段仍是 in_progress/review，不自动标内容done。

原 production_loop 的阶段绑定要求卡顶层 production_snapshot。全部非record文件写完后，用该模块的 `digest({p:h for p,h in snapshot().items() if not p.startswith("docs/quality/records/")})` 写入；再以本任务contract实际调用 check_task_quality，确认scope_complete及明确的content_complete。currentSnapshot自定义对象不是替代字段。缺失绑定或状态不一致必须保留真实停止；元数据修正不冒称重跑物理，源码改变则必须重新验证。

语义路线必须检查每个实际step、方向、进入状态的门条件和基础能力，并有删边/倒向/未授能力锁反例。单模块/全身Motor通过不能赦免虚构路线。参见[实际空间候选与返工](../../../docs/quality/plains_redesign_spatial.md)。

规划实施租约要包含真实消费者使用的Definition Resource（如resources/generation/modules的具体.tres），不能只列生成器脚本；必要路径遗漏须真实停止、保留计数后在剩余额度建立新scope，不能就地改已活跃mission/nonce。恢复时只读当前host_request.expires_at，不沿用上一轮时间。用官方quality初始化或显式同步record/evidence内容版本，避免复制父任务元数据冒充本阶段；真实失败不能被静态PASS冲销。

最终验证使用生产Harness实际调用的入口：测试类写在unittest.main之后时，discover通过更多用例不能替代原CLI入口漏跑。保留直接入口与discovery计数对照，让新增反例确实进入CI。独立审查须同时看原生事实与验收器反证；发现漏检先真实拒绝并保留原件，再有界返工，不把原通过日志改标为已覆盖。

离线固定FPS不保证输入墙钟新鲜：真实Router可能按墙钟丢弃旧队列。录制不能和大量原生/生成检查争抢CPU；记录实际线程环境、负载、producer源、原生输出和MP4自己的终态。请求无accepted/rejected须先区分过期/取消/epoch/玩法拒绝，不能直接归因关卡无解；不要改Router过期规则、刷新timestamp或注资源换通过。同条件受控重采要保留原受干扰轨迹，避免用不同输入/负载解释内容收益。[真实TTL小复现与限度](../../../docs/evidence/plains_redesign/render_timing_diagnosis/report.md)不代表实体设备性能已验。

实际内容版本升级须走原注册CLI，而非只过fixture单测：有限支持表应和当前生产者字面版本做快测，逐层验证RunManifest/实际Manifest身份，未来/混版本/降标签仍拒绝。分析消费者源码更新后原producer回执若source_changed，应保留旧失败并真实重采，禁止回填来源。

严格体验比较因已审定core或导出配置字节变化拒绝时，不能放宽比较器或改旧回执；保留not_comparable和准确差异，另以独立同源真实采集验证可比正例。所有原因果/奖励/非击杀反例继续执行，技术入口成功不代表旧新内容改善。

包装器失败必须同时暴露原始report.error、有界内部native日志与源指纹，并将该原目录加入既有CI artifact；只上传外层harness目录会使真实失败失去可诊断依据。同源码旧绿/本地绿不能冲销最新CI红；正例断言零失败但退出ERROR仍按原守门拒绝，不把另一次本地复现擅称远端同因。[实际失败与诊断修复](../../../docs/evidence/region_production_v3/final_delivery_50fb10c/README.md)仅证明可观测性修复，未签根因解决或发布通过。

真实退出案例：功能summary/native0不能冲销ObjectDB/resource终态错误，重定向内层log同样要拒绝。测试世界只在原玩法观察完成后，按实际GameAudio/独立播放器弱引用释放或deferred部件入树状态有界清理，超时传播失败；不可用固定sleep、verbose偶然clean或合法负例exit1来掩盖额外泄漏。实际实现与正反例见tests/audio_teardown.gd及docs/evidence/production_capability_repair/release/lifecycle_expansion/。

## 准入退出与返工

按[共同契约](../../../docs/creative_direction/README.md)及原G0–G5准入退出；设计失败RETHINK、局部REWORK、不适候选DISCARD。保留失败原件，重跑受影响检查并独立复审，不降工程门槛。

## 完成与证据

按[共同契约](../../../docs/creative_direction/README.md)记录原十一维、版本/SHA、消费者、实机证据和未验范围；缺审查/用户/设备不宣称完成，旧证据保留原来源。

## 共同创作契约

[预制作→制作→验收及版本总谱](../../../docs/creative_direction/README.md)是共同执行依据。总谱SHA变更须RETHINK并复验；交付写贡献、协作、新行为/视觉、主题冲突和实机验证。REWORK局部修复，DISCARD隔离候选；ACCEPT只限真实已验范围，审美不绕过工程红灯。

历史复现按需读取[原始Skill与迁移索引](../../../docs/archive/skill_history/README.md)，不默认加载旧轮授权、PR实录或失败数字。
