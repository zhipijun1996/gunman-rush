# 最新：独立技术审查通过，执行main合并

2026-10-14；用户授权自主subagent与现有PR65合入main已记录AGENTS。冻结实现98e7e11703520a1885f6fd6bffea31270bfb01e5；独立审查/root/independent_delivery_review对旧八关退休和交付工具技术范围ACCEPT，原REJECT/修复/复审均保留。两处修复：隔离通道新增源码漏检；脚本正常退出后独立会话子进程逃逸。独立核心5676/0、15地区套件、16harness用例、5录像解析用例通过。详情见[审查](evidence/delivery_efficiency/independent_review/review.md)。

当前最终PR/main CI与部署核验继续执行；Documentation测试删改审查阻塞已补齐证据，未伪造设备/用户认可。待全部检查通过后普通merge PR65，并核对main公开metadata/pack指纹和真实浏览器。任务继续review，合并授权不代替游戏主观/真机签收。继承的测试退出ObjectDB/resource警告在审查报告保留，不宣称无泄漏/设备性能通过。

# 最新授权：自主subagent与合入main（2026-10-14）

用户明确允许自主启用subagent、无需逐次授权，并要求将现有改动合入main。该授权覆盖此前禁止启用子代理/默认不合并的本轮限制。已启动独立只读审查：/root/independent_delivery_review，冻结实现7adfcbaaa0992c28452a8b4c7672465cc96800ec。先补齐测试退休与harness/CI审查和最终检查，再合并PR65并验证main部署；独立审查/真机/玩家维度按实际证据分别记录，合并授权不等于主观验收通过。

# DELIVERY-EFFICIENCY-01最新状态

已提交并推送提效改造，旧八关入口/资源移出运行、专属原件归档；31共享生成消费者与15地区套件保留。完整harness追加录像归集5个回归用例后为31项。72实际浏览器检查、最终核心5676/0、连续38.367秒60FPS立体声音画通过；归集字段错误已修复并保留原失败证据。新CI准备已成功，核心/Windows/Web并行，最终状态待获取；Documentation因缺测试删改独立审查未通过。当前公开试玩仍为此前ACTION-BUDGET-01，未发布本次新源、未合并。

阻塞为用户授权只读独立审查代理（AGENTS明确要求启用子代理需用户授权），已发出问题并等待，不能伪造PASS。详情与继续命令见[handoff](handoff.md)及[提效规范](delivery_efficiency.md)。

# 最新：交付提效与旧八小关移除（DELIVERY-EFFICIENCY-01）

2026-10-14；feature/complete-actor-actions / PR65 draft，未合并main。用户授权提效与旧八小关删除。旧入口/profile/资源移出运行范围，14个专属测试保留原件归档；31套共享生成消费者、15套地区回归和现行动作/武器检查保留。缓存仅开发阶段同依赖复用，最终release fresh；隔离并行与CI构建fan-out，发布后自动核对pack指纹。本地完整30项首次558.073秒，原串行记录1203.8秒，比较包含退休旧流程和环境差异。web profile与15项harness故障/隔离/缓存回归通过。规格与命令见[交付提效](delivery_efficiency.md)，原始证据见[evidence](evidence/delivery_efficiency/local_parallel.json)。

当前review：删改测试按既有check_quality_diff规则还需独立审查，AI自评不签PASS；新最终源CI/公开部署尚待完成。当前公开试玩仍以此前ACTION-BUDGET-01冻结版本为准。下一步独立核对删除范围/保留保障，再发布新冻结源；命令python3 tools/deliver.py --jobs 4。独立/真机/玩家签收不能靠技术测试代签。

# 最新：八项动作修订与激光枪口衔接已部署（ACTION-BUDGET-01）

2026-10-14；feature/complete-actor-actions / PR65 draft，未合并main。运行冻结862a05b82018244c69151e8a2f5f65153931c13e；公开[029fa9f8167f](https://zhipijun1996.github.io/gunman-rush/?v=029fa9f8167f) build-info精确匹配。[最新合同](quality/action_budget_spec.md)覆盖旧同主题行为。瞬闪清速/短驻；所有上升反冲接顶点缓落；Lv2三连/满激光1.5D、刃/回旋D+0.5D、炸弹/奇点D；空中遥控炸弹使用Lv1即时爆炸；钩索同探测器辅助线/稍宽捕获/快回收、来路侧45°踢出；Lv3复用主瞄准。只改激光普攻，Lv3大招保留瞬间炮击。

逐帧复查追加修复持续激光起点落后枪口8.38世界单位：最终绘制跟随Motor之后的可见枪口，物理伤害事务不变；只读附件接口避免诊断/绘制改变朝向或重绘姿态。真实连续录像36个beam帧附件偏差0。触屏保持按下期间及松手后400ms保护，阻止浏览器device0伪鼠标抢瞄准；后续真实鼠标仍可切设备。

[CI38518413735](https://github.com/zhipijun1996/gunman-rush/actions/runs/38518413735) core/工坊/Windows/web/Pages全部success，30 gameplay/art检查通过。冻结专项5946/0、核心5943/0、全武器2381/0、人物2929/0、旧手感1224/0、Studio37/0。公开24新动作+40实际鼠标/触屏菜单/巡逻/取消+8旧操作均通过，浏览器错误0。38.367秒及19.2秒/60FPS/48k stereo正常速度连续音画、失败链和原生/GUI证据见[记录](evidence/action_budget/summary.json)。技术通过不签主观美术/连贯性/手感；独立、实体Android/iPhone/手柄与目标性能未验，任务review。正式成长和16地区未扩展。

后续提交仅文档/证据；冻结运行不变。下一步为该公开版本真机/玩家/独立视听验收；命令：python3 tools/run_action_budget_tests.py；python3 tools/harness.py --profile gameplay --profile art --profile web；python3 tools/verify_action_budget_browser.py https://zhipijun1996.github.io/gunman-rush/?v=029fa9f8167f。失败原件与修复保留，不降低守门。

# 最新：六项武器手感修正版已部署（WEAPON-FEEL-01）

[新版0edaa46ab83e](https://zhipijun1996.github.io/gunman-rush/?v=0edaa46ab83e)运行冻结5fe5075055c286f0ab29986a222d8625e08dd63e；[六项合同](quality/weapon_feel_spec.md)覆盖旧相关武器行为。Lv1统一配置位移；手里剑清速/完整形体扫掠与碰撞投影瞬闪，基础炸弹释放帧爆炸/分层效果；激光累积反向速度；二闪延迟/可改向；回旋镖远投同速自动返航、当帧直线扫掠召回与空中控刃慢时。Studio HUD不抢Space。

同冻结[CI38500143870](https://github.com/zhipijun1996/gunman-rush/actions/runs/38500143870) core/web/Pages success，29 gameplay/art检查、工坊回放、实际GPU与Windows/Web导出通过。native1221/0、全武器2668/0、Studio37/0；公开14新动作+40鼠标/触屏菜单/模式/取消+8旧武器操作全部通过，浏览器错误0。23.033秒/60FPS/48kHz stereo连续音画与失败链见[证据](evidence/weapon_feel/summary.json)。数值仍候选；独立、实体设备、目标性能与用户最终视听/手感未验，review不合并main。

# 当前项目状态

## 最新返工：实际点选与巡逻练习已部署（STUDIO-INPUT-01）

[新版e2fb1e6470a4](https://zhipijun1996.github.io/gunman-rush/?v=e2fb1e6470a4)运行冻结c98ab2a16a7fba58c698b68c8edb9dbc4ddd5bec。原生弹出菜单补触屏输入，停止覆盖打开菜单焦点，实际点选装备；菜单取消/外侧关闭不选装或误射。附近四只默认复用原巡逻AI，可明确切“敌人：静止靶”，切换重启本段。此前5d30近处对象为静止靶，旧键盘选菜单不能证明手机菜单项点选。

本地鼠标/触屏各15装备加模式/取消40项、浏览器错误0；native24/0、人物2932/0、全武器2639/0。冻结[CI38491498426](https://github.com/zhipijun1996/gunman-rush/actions/runs/38491498426) core/web/Pages成功，完整gameplay/art、生成/Windows/Web通过，公开source_commit匹配。公开40项与旧8项操作全部通过、浏览器错误0；结果见[证据](evidence/studio_input/summary.json)。[合同](quality/studio_input_spec.md)记录引擎输入缺口和取消边界。任务review；独立/实体Android/用户最终体验未验，不合并main。

## 最新：全武器与360°钩索已发布（ALL-WEAPONS-01）

2026-10-14 最新要求覆盖旧横向钩索和只两枪范围。已实现3种Lv.1、6种Lv.2及保留普攻的6种Lv.3候选主动技能，共15装备，同一时刻一种武器。360°钩索、合法目标身体接触保护（拉近/踢跳及有限离开宽限）、独立共鸣、各武器动作/反馈与三端输入已接真实Runtime/Motor。[新版试玩5d30e7185549](https://zhipijun1996.github.io/gunman-rush/?v=5d30e7185549)从“动作练习 → 装备下拉框 → 武器靶场”进入，正式平原成长/保存与16区开放未扩展。详见[合同](quality/all_weapons_spec.md)、[证据](evidence/all_weapons/summary.json)。

运行冻结1198fe9767568e742edc20f6e67d2a737b86d90a；同冻结[CI38459052817](https://github.com/zhipijun1996/gunman-rush/actions/runs/38459052817)完整gameplay/art、Foundry、Windows/Web与Pages成功，公开build-info精确匹配。核心5942/0、动作2932/0、全武器2639/0；公开武器桌面/触屏8项及原基础6项全通过、浏览器错误0。52.38秒正常速度带音轨GPU录像，真实命中攒共鸣后播放六技能，无余额注入。首次并发公开GUI选择失败保留，同版原脚本单独通过，未改断言。

任务review；PR65仍draft，未合并main。独立、实体Android/手柄、目标设备性能和用户最终美术/连贯性/手感未验，不签G5或done。六Lv.3与平衡是候选，移动平台奇点固定参考系没有完整验证；不能把Studio覆盖外推到正式成长与全地区完成。

## 最新：墙跳、钩索与输入返工已发布（TRAVERSAL-REWORK-01）

公开新版 [ce5a559a0228](https://zhipijun1996.github.io/gunman-rush/?v=ce5a559a0228) 运行冻结16695dc，未合并main；旧9e1522fab3fc为被用户指出问题的旧版。全身双掌双脚贴墙、明显蹬高；钩索有限可见伸出与回收，拉近后小踢再斜上弹出，弹出时恢复D/H；手机新增独立HOOK瞄准摇杆，拖动/松手发射。PC/手柄共用瞄准加独立H键，方向保持原横向规则。主菜单动作练习可玩，正式平原能力成长/授予未扩展。详见 [返工规格](quality/traversal_rework_spec.md)、[证据](evidence/traversal_rework/summary.json)。2092/0、完整gameplay/art/web、实际GPU连续音画、同版CI core/web/Pages与公开GUI六项通过。独立、实体设备和用户最终美术/连贯性/手感未验，任务review。

## 最新：空中动作恢复（AIR-REFILL-01）

用户最新要求：成功蹬墙跳、钩索拉近踢腿小跳、空中子弹提交敌人伤害恢复二段跳和钩索资格；空中钩索一次，失败不补，落地重置。覆盖旧ACTOR-ACTIONS-01不补二跳的候选合同。详见 [最新恢复合同](quality/air_action_refill.md)。已授予能力才恢复，不提高上限或额外补满射击资源。已发布 [新版试玩9e1522fab3fc](https://zhipijun1996.github.io/gunman-rush/?v=9e1522fab3fc)，从主菜单动作练习/ACTIONS进入；同版本完整CI与公开桌面/触屏六项检查通过。未合并main，独立/真机与最终手感待验；失败与修复见handoff。

## 最新：人物动作实现候选（ACTOR-ACTIONS-01）

用户授权普通枪/Lv.2三连、羽翼二跳、可重复同墙/双墙攀升与横向钩索踢跳，以及现有人物连续表现。实现使用共享Player/Controller/Motor和单武器资源，主菜单“动作练习/ACTIONS”可实际操作；敌人8变体/3Boss及家园工匠按实际inventory覆盖。详见 [实现合同](quality/actor_actions_spec.md)、[人物盘点](quality/actor_inventory.md)。

新动作/动画/机关枪样板在ActionStudio实际装备授予；正式平原仍普通枪/一跳，不自动授予H/W/D或开放后续地区。新actor-actions专项已接gameplay/art/full；正常速度带音轨录像、旧回归与失败记录另列。尚未最终签主观连贯性、美术、设备与独立审查；不把实现候选写done。

## 最新：武器、操作与人物动作规划（2026-10-13）

ACTION-DESIGN-01已收录三份用户附件，原始字节/哈希与项目整理版见 [设计入口](design/player_actions/README.md)。用户补充同一时刻仅一种当前装备/使用武器；不包含双持，H/W/D独立衔接。新W同墙循环攀升、核心能力与Boss金道具独立等要求覆盖旧未来描述；操作映射、六Lv.3具体方案仍PROPOSED。

[动作规划](quality/player_action_plan.md) 和覆盖卡已加入现有skills；新增harness专项、武器Runtime、共鸣能量、H/W/D完整表现与16区均尚未实现。本轮仅文档与skills，不改正式玩法或配置；技术记录与后续任务分开，不能据此签动画/设备通过。

## 最新：单向平台漏检返工（2026-10-13）

2026-10-13 用户已授权 PR61 合入 main，合并前 docs/core（含GPU）/web CI 已通过；Git 交付不改变主观与设备待验状态。PLAINS-TERRAIN-03 / [PR61](https://github.com/zhipijun1996/gunman-rush/pull/61) 修复独立的单向木桥绘制分支。此前石灰岩样板与入口截图没有覆盖它，旧端帽 helper 测试也不在实际调用链；撤回将石台通过外推为全部空中平台完成的结论。石灰岩母版的用户认可仍有效，木桥最终视觉认可待验。新检查对旧实际绘制负例报7项失败，对修复版实际GPU/实例报1054项通过。Skills加入通用消费者覆盖闭环，详见 [返工报告](quality/one_way_platform_rework.md)。两图固定Seed运行库存与代表画面不是全Seed/全材质/完整路线通过。

## 最新：已认可平原美术正式接入（2026-10-13）

PR59 已合入 main a9a9cd2。用户随后明确认可水粉石灰岩合屏并要求完全接入，本轮 PLAINS-TERRAIN-02 将其设为正式两图默认表现，包含实体空中平台与移动平台；可穿透木桥保持原语义。Skills 已加入可复用制作经验。范围、证据、当前验收见 [接入报告](quality/terrain_production.md) 与 [handoff](handoff.md)。下文旧候选/未合并说明仅为历史，不能覆盖本修订。用户认可该美术不等于其余游戏内容、设备和独立审查已通过。

本页是现行规则导航，覆盖历史说明中冲突的入口/范围。数值仍由实际配置和 Definition 提供。新需求变更时同步本页与所属契约，不在每个 skill 复制玩法默认值。

## 当前运行

- 入口：scenes/demo/demo.tscn，标题 → 可操控家园 → 正式平原两张非线性随机连通地图；第一图鸣铃巡游机（Bellstrider，早期称铃行者），第二图牧风者，Boss 完成后显示后续开发边界并安全回家。
- 仅平原开放；六地区长期计划和 world_regions.json 的十六候选地区不等于已实现。三关/八关、Module Lab 和 RANDOM STAGE 为开发/回归消费者。
- 平原默认一跳，未命中基础两发；射击精力按 ShotEnergyDefinition 扣除，接受的真实命中回能并返还一发空中弹药。移动/跳跃不耗精力，慢时实验预算独立。
- 家园与关卡共享控制；存活环境伤害段回退，零血结束本局。同帧死亡优先，回退不重抽地图/刷新机关/奖励。金币与永久音符、局内与 Meta 状态分离。
- Boss 实体门封场、合法高跳不丢射击资格，击败动画完成后原保证奖励结算；视觉宝箱不新增支付。参数、碰撞、随机流与账本不由表现决定。

## 本轮候选修订（2026-10-13）

[当前质量审查与修复](quality/current_review_spec.md) 覆盖平原空间/表现/参考系/战斗生命周期契约；正式路线和数值来源不变。新敌人仅为开发样板，视觉与玩家验收未通过。Skills自动路由；大任务执行见 [生产循环](quality/production_loop.md)。

## 最新修订入口

| 主题 | 当前优先依据 |
| --- | --- |
| 两图探索、迷雾与流程 | [D076](plains_two_maps_fog.md)、[运行契约](run_and_routes.md)、design_contract.json |
| 精力、道具与反馈 | [D079](plains_experience_energy.md)、[资源契约](combat_and_recharge.md) |
| 路线压力与奖励 | [D080](plains_exploration_expansion.md) |
| 表面机关与平台 Boss | [D081](plains_interactive_platforms.md) |
| 共用控制、封场、地形与掉落 | [D082](plains_cohesion.md) |
| Web 分块、校验、恢复与部署 | [D083](web_loading_resilience.md) |

旧规格中一张图/八关、第八 Boss、正式精力未定等描述保留历史用途；不能按旧段落改回正式入口。D083 没有改变 D082 的玩法。

## 整合基线与未验范围

最新 fix/web-loading-resilience 的 924a8d1 已于 2026-10-12 经 [PR54](https://github.com/zhipijun1996/gunman-rush/pull/54) 合入 main（6568e9a）。运行代码与成功 [CI38232680571](https://github.com/zhipijun1996/gunman-rush/actions/runs/38232680571) 的 26906a4 一致，后续为文档证据。历史发布与失败证据见 [D083归档](archive/handoff_d083.md)。

技术测试和浏览器 GUI 有既有证据；完整真人探索趣味性、Android/iPhone、实体手柄、手机内存/CPU、大陆运营商直连继续待验。国内镜像未部署。本轮整理不把这些任务标完成。

## 项目级质量体系（2026-10-12）

本页兼任 project_status，不另建同义副本。质量体系基于最新未合并 [PR55](https://github.com/zhipijun1996/gunman-rush/pull/55) 的 da76b0aa65f257f5208cde23e98aa8d9b3098ad1，运行目录与 main 6568e9a 相同。分支 chore/game-quality-system 只建设流程、文档和检查，不改游戏版本。统一入口见 [quality](quality/README.md)。

多武器分支升级树、完成地区获得新大能力和后续区域能力锁是未来目标，不能算当前已实现；demo_app 明确在第二图完成后提示开发边界，不授予不存在能力。当前生成事实见 [generation_current](generation_current.md)。

PR55 的严格 harness 已在干净工作树暴露 Web 导出 `Parse Error: Busy`（windkeeper.tscn:13）；导出进程返回 0 仍不应通过。此前宽松导出记录不能覆盖该失败。详见 [本次审计](quality/implementation_report.md)。不修改核心 Boss 或放宽错误签名来掩盖它。

交付前复查：本任务执行期间新增 [PR56](https://github.com/zhipijun1996/gunman-rush/pull/56) / feature/ai-platforming-foundry@4ed7ba6，与 PR55 从 main 分叉，是开发工坊消费者，未并入本质量分支或 main。不能把它的二跳/四发开发配置当正式能力发放；后续整合保留其真实回放、来源指纹和 CI。详见 [并行审计](evidence/quality_system/concurrent_pr56.json)。

## 当前质量返工（2026-10-13）

新 player/weapon/ability Skills 和有界生产循环已实现；真实 Codex 子调用因登录失效 blocked，不能称自动大任务已实证成功。平原镜头/暂停/接触规则修复与新登场仍在 review。第一次地形边框和敌人缩放已被拒绝并撤回；原问题保持未解决，新47邻接材质仅在开发gallery。最新证据与范围见 [迭代报告](quality/iteration_report.md)，不得用此前候选描述覆盖新的 REJECT。

## 最新手绘返工与区域对照（2026-10-13，覆盖同主题旧描述）

分支 feature/quality-review-and-production-loop；运行提交 aa40f9071575325884ed523dc66f92145d41913e，PR59保持draft，不合并不发布。现有11核心Skills自动路由；真实多Skill生产循环仍因Codex认证失败blocked。非整格/薄体候选已接入真实区域开发对照，普通正式入口保持基线。v7褐土及v4密集花草均保留拒绝记录，v5水粉石灰岩继续待用户认可。不要把旧“仅整格gallery”当最新实现，也不要把技术通过当美术完成。

完整范围、实际命令、截图录像、独立审查与剩余缺陷见[迭代报告](quality/iteration_report.md)。下一步是针对实际黄金合屏继续美术反馈；原敌人身体/hurtbox、新敌人正式遭遇、Boss视听和真人/设备仍未完成。常用 `python3 tools/harness.py --profile docs`、`python3 tools/run_quality_review_tests.py`。

## 本轮实验室整合授权

用户明确要求将实验室融合最新main，增加玩家反馈导出给AI与部分敌人；本轮验证后允许合并该范围。实验室保持开发入口，不结算正式奖励；敌人组合预览不标记为平台回放覆盖。质量记录FOUNDRY-MAIN-01，待设备/趣味验证。

实验室整合已通过PR62合入main（a165fbd），公开2765b0e93bb8完成真实浏览器中文反馈下载和敌人开关复测。技术验证通过，FOUNDRY-MAIN-01保留awaiting-device，不表示实际手机/趣味验收完成。
