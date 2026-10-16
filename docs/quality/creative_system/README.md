# CREATIVE-SYSTEM-01：已实现的升级、实际拒绝与未完成边界

本轮基线为最新 main `e8ee34446aa82b4e64f5cdc414a22f5b6e2a6ca7`，已包含PR66–70累积开发、合并的PR71钩索修复和两个准备包发布workflow提交。没有把仍开放的叠加PR误当main之外唯一新源。工作分支`feature/theme-driven-production`，不合并main。

当前结论：原生产系统上已实现三阶段路由、版本总谱强制绑定、创意决策、紧凑历史交接和首次原生导入预检；原observer工程阻塞获得限定修复。用户已选择草海方向，但本轮艺术样板的空间/资产制作方法被独审RETHINK，停止扩产；当前森林H样板真实启动却严格退出失败。**没有完成商业品质区域、完整艺术垂直切片或完整自主地区生产，也没有将本轮当作已发布。**

## 1. PR66–70实证审计

详见[逐PR问题与成本](pr66-70-audit.md)、[消费者/Skill审计](dependencies-audit.md)、[六类依赖与调用图](dependencies.json)。审计基于源码、原报告、机器账本、失败和返工，不按文件数判冗余。

| 能力/问题 | 实际证据与结论 |
| --- | --- |
| 原有有效能力 | 原Harness严格退出、源与产物指纹、隔离并行lane、nonce/独审身份、production_loop阶段检查点和零新调用恢复均保留。现有视觉导演已有大形/合屏要求，不能说过去完全没有整体构图流程 |
| 创意权威缺口 | 原`level_design.route_request`没有区域总谱依赖；原`production_loop.RESULT_SCHEMA`只有accept/reject等，方向失败只沿原task返工。现在在原函数中扩展，不重建质量框架 |
| 短Prompt断层 | 原auto把未来地区收为一个G0/G1原型，九包计划保留但不推进。现在默认预制作→版本总谱→完整九包分解，明确活跃宿主续推边界 |
| 历史与当前混用 | 旧森林runner显式使用冻结长钩索，不能证明最新231px/24px。旧v3/v8资产仍有正式preload/Atlas消费者，不能整包归档；原失败家族已经在export排除，不重复宣称本轮才隔离 |
| PR69失败并非一种原因 | 模板curl超时、terrain退出错误、录制墙钟输入时序、重复返工和未达商业画面各有证据；不能统称网络或“文件太多” |
| PR70具体失败 | 未提交9证据路径、冻结资产恢复、terrain/Ogg严格退出与encounter永久await链是不同根因。后者已独立修复，其余历史失败原文保留 |
| 新实跑暴露的缺口 | 初版loop可绕过完整总谱schema/authority SHA，独审REJECT后统一full loader。真实host首次导入新增3UID触发只读源漂移，保留3calls原失败后新增零worker导入预检 |

PR66–68的有限接受不代表整区通过；PR67/68真实独审已拒绝画面/体验，后续补材质反复没有形成完整商业黄金。主张改创作方式有实际像素与失败链支持，但不把所有技术验证称作低价值。

## 2. 可逆瘦身与实际量化

[原Skill逐字归档](../../archive/skill_history/manifest.json)16/16与Git基线SHA一致；[入口和旧循环原文](../../archive/creative_system_baseline/manifest.json)完整保留。现行专业职责、原测试、有效资产、冻结失败候选没有物理删除。

- 原16Skill为186,700 bytes。精简后16份175,749 bytes，加新创作导演3,513后17份179,262；净减7,438 bytes / 3.98%。这是文本字节，不能换算token、实际工时或价格；不得沿用初轮尚未恢复守门标题的6.06%数字。
- AGENTS/current_state/handoff三个默认入口136,456→13,376 bytes，少123,080 bytes / 90.20%。新增共同契约另有字节，未偷偷计成零；这是这三个入口的读取量，不是完整worker总上下文节省。
- 首个真实方向worker prompt 67,147 bytes、review 87,256 bytes，已实际记录。仍包含权威抽取上下文和独审Skill，未宣称上下文已极小。新compact仅传最新结果/证据索引，完整磁盘历史不删；旧轮未解决问题仍可按索引追读。
- 两个runner的“runtime source map+各自额外hash”统一为`level_formal.source_files(extra_paths=...)`，实际字典等价和缺依赖反例通过；不合并其物理测试、进程或并行能力。既有`run_tests.run_engine`已被多个runner共用，没有再造同义launcher。
- 文档扫描排除生成的根build/.godot/.git，当前与历史正式docs仍扫描；实际“build坏链不阻塞”正例和“当前docs坏链必须拒绝”负例保留。
- [实际PCK目录比较](../../evidence/creative_system/pack-comparison.json)：基线normal 97,384,332 bytes，当前normal 97,394,384，**增加10,052 bytes，没有包体瘦身收益**。未准入艺术候选在当前normal的raw/remap/imported纹理条目均为0；只在显式review包出现6个候选条目/4,243,109 bytes。
- 没有删除任何原有效测试，也没有减少原正式full的既有覆盖。history是显式索引，尚未把所有冻结专项从原full完全解耦；在当前等效强验/严格退出仍不足时没有硬拆。新未准入森林样板仅用于显式creative-prototype，不偷改正式开放范围。

仍存在的成本：整个旧证据树依然可追溯，完整Git获取和production_loop全仓快照仍受约4GiB证据影响；同工作树任务循环仍串行写入，跨专业实际并行需隔离工作树和整合者。本轮observer移入冻结工作树消除了实际写冲突，但未宣称已有自动并行创作调度器。

## 3. 实际可执行的新工作流

唯一创作入口：[区域总谱](../../creative_direction/README.md)。专业协议：[当前生产循环](../production_loop.md)。原policy/G0–G5/十一维、物理/输入/HP/资源/RNG/保存和正式CI保留。

Pre-production由region-creative-director比较完整方向并选定；不是visual-director同义文件。Production每任务引用总谱path/SHA/region/version，包含具体贡献、协作、体验变化、主题冲突和真实游戏验证；先完整可玩样板再拆模块。Validation独审整体一致性与工程事实，ACCEPT仍由原质量卡判断。

REWORK沿原预算；RETHINK停止后继并回预制作；DISCARD停止投入并要求隔离。DISCARD控制面不会擅删/撤出消费者，物理隔离要另做可逆变更。本轮艺术样板已实际关闭默认加载且三preset排除，并以真实PCK验证；不能以一个标记冒充完成隔离。两次相同非空独审finding触发RETHINK，改无关文件不能假装进展；Harness失败单独归工程。

总谱full loader每次复验12类覆盖、2–3候选、认可来源及实际authority SHA；手工mission不能绕过。缺覆盖、伪user_confirmed、重复JSON键、权威改变但总谱未改均calls0拒绝。原独立REJECT→修复→限定ACCEPT链见[审查原件](../../evidence/creative_system/creative-loop-review.md)。

首次native_import_preflight在worker前运行原pinned Godot；只接受对应既有不变源的新UID，其余源码变更/未知产物/引擎错误calls0阻断。原实际sidecar漂移失败不改签；[真实Godot预检](../../evidence/creative_system/native-preflight-actual/native_import_preflight.json)15.109秒、0worker、0源变更通过。模拟边界测试与真实原生回执分开。

## 4. 风铃平原：方向已选，样板制作方法RETHINK

[总谱](../../creative_direction/windchime_plains.json)比较“逆风送钟草海/沉钟浮岛/缝风工坊”：分别围绕反冲逆势、纵向沉没探索、风带编织周期，空间/生态Boss/成本不同，不是换色。用户原始选择已按direction-only记录，不代签画面、手感、设备或整区完成。

实际联动实现为正式RootBell joint_space中的新钟肋围合、真实solid内部岸体/悬顶重绘，以及真实pulse_committed后才驱动的远钟动态。保留真实Player、敌人、齿轮/机关、动作、地形、HUD与原事件声音，没有为画面修改碰撞、AI时序、HP、资源或RNG。原角色/UI/声音未成套重作，不能把“它们在场”写成已完成全专业新制作。

- [当前真实同屏](../../evidence/creative_system/media/window_0_candidate.png) / [基线](../../evidence/creative_system/media/window_0_baseline.png) / [中岸](../../evidence/creative_system/media/window_1_candidate.png)。
- [准确当前源20.067秒/60fps音画](../../evidence/creative_system/media/current-20s.mp4)：1204帧、真实跳跃/射击/敌预警，玩家HP5→3、敌3→2；明确一次模块入口fixture之后真实输入，不签完整去返或无伤。
- [较早视觉版本85.85秒完整去返](../../evidence/creative_system/media/previous-visual-85s.mp4)：5145ticks/5151frames、15cases/9pulses、原验证/反例通过；精确旧源冻结，不能代替当前顶面/隔离版本回归。
- 原采证固定坐标/已释放stage错误、短SHA拒绝、旧输入策略63tick失败、首次遮钟构图均在[原失败清单](../../evidence/creative_system/art-slice-summary.json)保留。未靠换策略把旧失败改绿。

[实际独审](../../evidence/creative_system/art-independent-review.md)判RETHINK空间/资产制作方案：顶端硬裁矩形、平直岸体、材质缝仍主导；尚未让“反冲跨隙—恢复岸—远钟目标”形成同屏因果。停止当前母版扩产、不默认启用。下一步应联合level/encounter/scene重新布置一个真正裂口/围合的大形，然后再资产化；不能再给这个矩形场景加背景和粒子。

## 5. 独立工程阻塞：原observer修复

[报告](../../evidence/creative_system/observer-report.json)、[完整原件ZIP](../../evidence/creative_system/observer-candidate2-evidence.zip)、[独立接受](../../evidence/creative_system/observer-skills-review.md)。修复只动5个测试观察器：终止后协作返回，传播失败、停止新请求，等驾驶栈结束再卸载。不是删物理负例、换HP或永久悬等另一个signal。

冻结`e8ee3444`+补丁的真实矩阵：11正例、3物理负例、32证据突变拒绝；原生106断言/17cases、正式返回2287帧、30帧预算取消、10边界均过。原kill负例816帧、33事件、11资源收据、22策略观察、诊断/HP/结果逐字段不变，仍5断言/2失败/exit1；20ObjectDB/7resources→0。独审ACCEPT_SCOPED。

两次真实source drift和一处候选1取消传播遗漏均保留；候选2通过后没有把候选1绿挪签。这个修复不自动证明所有外部motion回调通用取消、当前整合全专项、全部历史兼容或完整CI通过。

## 6. 短Prompt真实演练与失败回流

输入为“制作荆棘森林。”。实际完成三方向比较、专业推荐听风棘廊、S2仅H总谱与9包协作分解。原harness真实host运行[3个租约原件](../../evidence/creative_system/actual-short-prompt-original.zip)：不同实现/只读审查者接受方向核实scope，随后真实启动当前H CLI。不是fake worker、只有计划或用平原回归代森林。

该演练没有通过：当前132帧/152断言零玩法失败，真实jump→H→全身落枝→shoot recoil→恢复→返回成立，但107ObjectDB/63resources/7TextureRID严格退出失败。实际宿主这次只跑正例就被严格拒绝，两个负例未启动；另一个明确分源原生诊断才有删anchor/无H的exit1反例，不串成一次全pass。

控制器还因首次导入3个UID判只读源漂移blocked，[原失败](../../evidence/creative_system/actual-short-prompt-source-drift.json)与native泄漏是两个不同原因。前者已添加真实导入预检；后者load-only也复现，world弱引用确已释放，仍工程阻塞，停止继续猜测清理。

独审另发现总谱旧consumer命名，现已局部REWORK到creative-v2/当前短钩索consumer，并更新绑定。原creative-v1租约保留原hash，不重标为v2。主题选择未重做，H没有正式授予，森林没有正式开放。

当前入口能从短Prompt启动预制作，并在选定方向后沿continuation逐阶段推进；仍需活跃宿主处理真实lease。九包完整内容没有全部执行，不是脱离宿主的后台整区制造服务，不把G0/G1原型称完整地区。下一恢复应先解决load-only严格生命周期，再在新源/新evidence目录重验，不改旧失败或重用旧completed标记。

## 7. 时间、成本和商业验证

[旧原始账本复算](pr66-70-audit.md)：PR69真实44host调用中27有elapsed，inclusive17682.785秒；14图生中13有wall，合计636.724秒；12deliver步骤3461.096秒。PR70 149事件端点并集6267.742584秒，返工3068.637613秒与其他阶段重叠，不相加。旧57.68分钟“passed”另有3外层/14suite退出错误，不能当严格clean对照。

本轮只报告可见原件：3真实host租约有起止和prompt字节；observer矩阵区间并集112.484秒；当前视频引擎wall约135秒/20.067秒媒体，旧视觉长片约531秒/85.85秒媒体；2次图生未包墙钟计时，精确生成时长、tokens、价格和纯模型compute未知。不能用44→3调用、14→2图生或两轮不同范围宣称生产提速倍率。

新命令阶段时间沿原production_timing ledger保存；最终验证与发布结果另附实际日志。审计/架构45分钟、observer25分钟最多两候选、艺术45分钟最多两图、原型/冻结45分钟为阶段目标；阶段并行不相加当总工时。达到无进展/严格阻塞后对应方向已停止，没有用换包/换任务名退款。

尚未获得真人试玩、市场或实体设备证据。总谱已给可执行方法：至少5位初见玩家保留build/seed/设备、前30秒理解反冲、前10分钟路线/失败归因/再试意愿；PC/手机/手柄分别记操作负担与帧时间。失败按教学反馈/空间/输入/音画归因，同条件复测；小样本和AI评分不作为市场事实。不是以接近某商业作品的画风作为唯一产品目标。

## 8. 可玩产物和发布边界

本地已验证Linux x86_64显式评审包位于ignored `build/creative_system/gunman-rush-creative-review-linux-x86_64.zip`，build_id `5ea858f56b0c`，[准确PCK/版本/启动证据](../../evidence/creative_system/local-review-version.json)。包含官方4.7.2执行文件；`bash play.sh`启动一次声明的RootBell模块入口fixture，之后真实手动控制，无自动driver、不写Meta保存。包内启动360帧exit0、严格日志干净。它不是完整发布门槛通过的成品。

本轮没有发布该RETHINK候选。实际公开metadata已读到旧钩索修复包`c1562ae6a885` / source`8fe31f25a8c4166ec7e70e6bfab7e7cdc2bee5e8`，不能沿PR69/70旧记录继续称公开站点还是PR67，也不能冒称本轮已上线。

冻结验证、构建和PR的最终准确状态见[最终验证补充](validation.md)。若当前完整发布门槛未过，仅交本地已验证产物与原失败；不取消严格退出/历史断言制造虚假上线。
