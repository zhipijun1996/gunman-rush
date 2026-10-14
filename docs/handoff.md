# 最新：八项动作预算修订验证中（ACTION-BUDGET-01）

2026-10-14；feature/complete-actor-actions / PR65 draft。用户明确只改激光普攻，Lv3大招保留瞬间炮击。[最新合同](quality/action_budget_spec.md)覆盖旧同主题位移、钩索与技能瞄准；源码已实现，连续GPU音画、完整harness与网页验证进行中。当前公开版本仍为下文旧版，部署成功前不称已更新。独立、实体设备、用户最终视听与手感未验，不合并main。

# 最新交接：六项武器手感已发布（WEAPON-FEEL-01）

2026-10-14；feature/complete-actor-actions/PR65 draft，main未合并。运行冻结5fe5075055c286f0ab29986a222d8625e08dd63e；0bcc9d3只证据/来源登记与浏览器定位修正，后续继续只记录。公开[0edaa46ab83e](https://zhipijun1996.github.io/gunman-rush/?v=0edaa46ab83e) build-info精确匹配冻结。CI38500143870 core/web/Pages success；首轮PR docs38500149894缺旧assets/manifest来源关联，wrapper PR docs38501264842已success，不绕守门或修改素材许可。

六项行为见[合同](quality/weapon_feel_spec.md)。瞬闪由唯一Motor清速、当帧完整形体扫掠/碰撞投影，基础枪/炸弹反冲与刃/回旋首段距离共用PlayerTuning；炸弹释放帧结算并有分层爆炸。持续激光不走普通衰减、反速度持续累积。二闪候选 .30游戏秒，间隙能改向；回旋候选680射程/300速度，同速自动返航不送手动二段，F/X当帧锁线扫掠/接刃，墙阻不送位移；空中控刃有限预算慢时延长。HUD无键盘焦点避免Space顺便重开练习。

精确冻结29 gameplay/art检查全pass，CI原artifact11866476065 SHA2563545b4daaba5a3b980c84e00dd7e142613bfd05f6471b8178c5712ca176ba320已下载校验，原报告source=5fe5075。native1221/0、全武器2668/0、Studio37/0；工坊36短语/18连贯路线、原43/15套件、实际GPU与Windows/Web通过。公开14新动作+40实际鼠标/触屏各15装备及模式/取消+8旧操作全部通过，错误0，无键盘替代菜单点选/无状态注入。冻结23.033秒/60FPS/48kHz stereo连续录像已归档；六练习段重启明确，不冒充完整流程。

[证据](evidence/weapon_feel/summary.json)、[连续录像](evidence/weapon_feel/actions.mp4)、[失败链](evidence/weapon_feel/failures.md)。解析API/已释放实体访问、贴地斜向停住、菜单外灰色噪点与手机首项高亮、HUD抢Space、windup提前改向/投刃撞平台与右键点在HUD边缘均保留，并保持原断言/错误/退出守门。候选参数不等于用户定稿；G2/G3/G4/G5依相关主观/设备/独立维度未验，review不标done。

采用weapon-creator/animation-vfx/game-quality-gate/project-integration，碰撞投影与累积推力经验已写weapon-creator。正式进化/保存/16地区与Lv3候选平衡未扩展。后续收集新版真实玩家/设备反馈；无权限合并main。命令：python3 tools/run_weapon_feel_tests.py；python3 tools/verify_weapon_feel_browser.py URL；python3 tools/verify_studio_click_browser.py URL；python3 tools/verify_all_weapon_browser.py URL；python3 tools/harness.py --profile gameplay --profile art。Godot4.7.2；X100，HTTP8765本地构建，公开源以build-info为准。

---

# 最新交接：武器实际点选与默认巡逻已部署（STUDIO-INPUT-01）

2026-10-14；feature/complete-actor-actions/PR65 draft，main未合并。原运行源3e954bd4b85896a1cfbb76de0fd4b3202fde354d在CI38491054860被质量记录与任务表状态不一致拒绝；c98ab2a16a7fba58c698b68c8edb9dbc4ddd5bec只同步任务状态，运行代码完全相同。已通过CI38491498426 core/web/Pages，完整gameplay/art/生成/GPU/Windows/Web成功。公开[e2fb1e6470a4](https://zhipijun1996.github.io/gunman-rush/?v=e2fb1e6470a4) build-info精确匹配c98ab2a。

已修：停止每帧覆盖菜单焦点；PopupTouchAdapter在所属子Viewport接收触屏，菜单坐标转根Viewport后由原嵌入Window/PopupMenu鼠标链处理，正常选择信号装备，不直接调用攻击/移动；同装备不重复取消现有包。引擎ed1daf0bf PopupMenu未处理ScreenTouch，window_input过滤内部事件、对子Viewport push_input不走其原生处理，原失败保留。当前Web丢touchcancel标记，DOM capture回调仅菜单范围关闭并清理，退出移除监听。场景输入节点在游戏射击前拦外侧关闭指针的按下/松开，不能泄漏到身体动作。

附近四个对象原本静止训练靶，现默认原EnemyPatrolAI/Motor/Definition巡逻，不造新AI；“敌人：巡逻 / 静止靶”按钮切换并重启本段；保留原8敌人/3Boss遭遇。全武器视频/GUI案例明确选静止模式，既有共鸣/伤害/唯一Motor规则不变。正式成长/保存/地区未扩展。

本地实际鼠标/触屏逐项15装备，无键盘替代，模式/取消合计40真检查全通过、错误0；native24/0、人物2932/0、全武器2639/0。已下载校验冻结CI artifact且frozen_harness.json source=c98ab2a、全部check passed。公开40项与旧8武器操作已串行复验全部通过，浏览器错误0，真实点选无键盘替代，summary/质量记录已归档。

[合同](quality/studio_input_spec.md)、[证据](evidence/studio_input/summary.json)、[失败链](evidence/studio_input/failures.md)。旧5d30桌面单项可选、手机真实触屏未选装；旧键盘导航没有此覆盖。中间Window/Viewport尝试无效、自动化总高度错选相邻行、38/40取消失败、桌面误射和触屏cancel翻译release以及首次CI状态不一致均保留，守住期望ID/一次装备/零错误/取消门槛。指针定位按实际radio标记，非固定行高侥幸。

采用quality/enemy-creator/project-integration，输入通路/真实指针覆盖经验写入project-integration。review不签用户最终接受/实体Android/独立审查。公开复验已完成；本次证据包装提交只文档/技能，不带发布标记，运行冻结不变；PR保持draft。后续收集用户新版与实体设备反馈。命令python3 tools/verify_studio_click_browser.py URL；python3 tools/verify_all_weapon_browser.py URL；python3 tools/run_studio_input_tests.py；python3 tools/check_quality.py。Godot4.7.2，HTTP8765当前源导出；本地build-info标记提交前HEAD，不当公开源证据。

---

# 最新交接：全武器与360°钩索已发布（ALL-WEAPONS-01）

2026-10-14；feature/complete-actor-actions，PR65仍draft；运行冻结1198fe9767568e742edc20f6e67d2a737b86d90a，后续提交仅包装文档/证据/技能经验。main仍37c2153d9378e3e774fa9191c02318305af47ca5，未合并。公开[新版5d30e7185549](https://zhipijun1996.github.io/gunman-rush/?v=5d30e7185549)已确认source_commit精确匹配；ce5a559a0228是旧横向版，不代表本轮。

实际入口：“动作练习/ACTIONS” → 装备下拉框 → “武器靶场”。15装备：3基础、6Lv.2、6Lv.3候选主动技能且保留分支普攻；共用唯一ShootAbility/WeaponActionRuntime/有限WeaponEntity。F/X召回/遥爆，Q/Y技能60共鸣；手机移动/射击/独立第三HOOK摇杆，按需情境与技能区。实际伤害产共鸣、包/目标去重有界、技能不自充，死亡清池；切换/回退/旧epoch清实体/请求。手里剑反闪/散华二次闪、直线召回接刃、附着磁雷与有限链击、当前位置奇点固定牵引/弹射、持续激光递增消耗及向下升力均已接真实Motor。360°H从真实hook原点发射，合法目标身体免伤覆盖拉近/踢跳/有限离开宽限，其他伤害正常，取消即清；成功踢跳恢复D/H仍保留。

验证：同冻结[CI38459052817](https://github.com/zhipijun1996/gunman-rush/actions/runs/38459052817) core/web/Pages success，Android未请求而skipped；完整gameplay/art与原43/15套件、真实GPU木桥、Foundry及Windows/Web导出通过。下载CI原artifact校验SHA256，frozen_harness.json source为1198fe9且所有checks passed。核心5942/0、动作2932/0、全武器2639/0，含六Lv.2/Lv.3普攻等价、30/60/120Hz激光、真实接触HP保护、墙前出手、远爆不推本人、有限轻敌击退/打断冷却、atomic共鸣与epoch退出。公开原基础6项和新武器8项均零失败/零浏览器错误。

[证据汇总](evidence/all_weapons/summary.json)、[正常速度录像](evidence/all_weapons/actions.mp4)、[合同](quality/all_weapons_spec.md)、[失败链](evidence/all_weapons/failures.md)。最终52.383秒/3142ticks GPU音画，含1041个实际普通枪earn帧攒共鸣再播放六技能，分段练习重启明确，不是整局通关。四个真实Health训练对象无成长奖励，原8遇敌/3Boss数组保留。生产源码fingerprint与冻结匹配；本地Web是提交前生成，metadata旧HEAD51b，明确不能当公开源标记。

失败原件保留：肩膀双平移破坏枪口/碰撞包络，改单Transform后5942/2639通过；奇点当帧重力漂移改零速Motor请求；GPU旧显示死，换:99；录像资源农场走入敌人，改安全地面真实命中；120HP点条溢出改比例条；菜单初始焦点差异必须验真实选中ID；快速返航轮询漏采改只读物理过渡；并发导出删worklet导致404，等导出完成零错误重验；激光耗尽重复拒绝音，释放前不自动重试。公开首次两个浏览器并发的选装步骤失败，原脚本同版单独八项通过，确切并发时序未独立验证，未改断言。

采用game-quality-gate、weapon-creator、ability-creator、player-creator、animation-vfx、art-director、enemy-creator、project-integration。经验已写animation-vfx。任务review，不伪造独立/真机/用户最终美术与动作认可；六Lv.3平衡候选、移动平台奇点固定完整验证、正式成长/保存及16区为后续工作。下一步收集新版实际反馈与设备/独立验收，用户可直接试玩全部装备，不需要再问实现授权。

复验：python3 tools/harness.py --profile gameplay --profile art --profile web；python3 tools/verify_all_weapon_browser.py https://zhipijun1996.github.io/gunman-rush/?v=5d30e7185549；python3 tools/verify_actor_actions_browser.py URL。Godot4.7.2；Xvfb:99，DISPLAY=:99；HTTP8765服务build/web。原AVI和完整本地失败产物在build/，不要提交。GitHub CLI认证失效，app连接器提交有效；binary按196608bytes块传并核对git blob SHA。文档证据包装不带发布标记；已有运行冻结/线上版本不变。

---

# 最新交接：墙跳/钩索返工已发布（TRAVERSAL-REWORK-01）

运行冻结16695dc8f937be6cac26110fe1d1891de4785542；feature/complete-actor-actions，PR65仍draft，未合并main。用户指出旧公开版6fd2332仍为旧动作/按钮；当时新返工未发布，已明确解释并保存公开旧版Android UA/CDP画面与原话。现在已发布 [新版ce5a559a0228](https://zhipijun1996.github.io/gunman-rush/?v=ce5a559a0228)，主菜单“动作练习/ACTIONS”，公开build-info精确匹配运行冻结。

实现：全身双掌双脚贴真实墙面，两格完整新手绘图接入镜像/接触锚点，未改Motor位置；专用蹬墙速度由-610到-970，基础跳跃/重力不改。钩索接受发射→可见伸出→合法目标才拉近；失败短停→可见回收，全部逐帧重绘，射程有限460px。成功拉近后0.10秒踢腿，再(±620,-580)斜上弹出，弹出时才恢复D/H。手机保留移动与射击摇杆，新增金色独立HOOK摇杆，拖动瞄准/松手发射；PC鼠标/手柄右摇杆共用瞄准，RMB/E/LB按下单次发射。方向保持原横向合同，未把全角度候选伪称用户确认。正式平原能力授予/保存未扩展。

验证：2092/0专项、多帧率实际墙跳145..185px、空钩有限距离/回收、真实Motor接触踢腿→斜上弹出及资源时序；完整gameplay/art/web通过；Foundry36短语/18连续路线；实际GPU25.53秒正常速度带音轨录像。线上 [CI38425060669](https://github.com/zhipijun1996/gunman-rush/actions/runs/38425060669) core/web/Pages均success，公开桌面/CDP触屏六项0失败。证据 [汇总](evidence/traversal_rework/summary.json)、[录像](evidence/traversal_rework/actions.mp4)、[规格](quality/traversal_rework_spec.md)。

失败原件保留：提高W后旧墙顶不够高导致测试越顶，扩大同一测试墙以保留不穿墙断言；钩索新接触阶段使旧0.6秒观察不足，改逐阶段检查与有界完成；30Hz专用蹬跳初版143px不足145，提高专用W速度并重验，不降高度门槛；空钩观察窗按返回速度补齐且在空中fixture排除合法落地重置；质量证据归因/格式曾拒绝，已补真实用户回复并修正；初次GPU显示服务失败，清理确认僵尸的display98锁后实测通过，不修改guard。边界不完整的生成纠正版未准入，PNG原图/来源/许可记录保留。

本轮采用ability-creator、player-creator、animation-vfx、art-director、game-quality-gate、project-integration；持续绘制/真实接触锚点/实际触屏和发布区分的经验写入animation-vfx。任务review，独立审查、实体设备、最终美术/动作连贯性/手感未验；CI不是用户认可，未签G5。后续收集用户新版反馈与真机验证，正式成长消费者另行推进。复验命令：python3 tools/harness.py --profile gameplay --profile art --profile web；python3 tools/verify_actor_actions_browser.py https://zhipijun1996.github.io/gunman-rush/?v=ce5a559a0228。

---

# 最新交接：空中恢复规则与已更新试玩（AIR-REFILL-01）

2026-10-13；feature/complete-actor-actions，发布冻结6fd233224ebea4bc9b9eaab8eb3ebade2fbaf6bd。用户授权更新试玩并明确三类成功动作恢复D/H；未合并main。

已发布 [试玩9e1522fab3fc](https://zhipijun1996.github.io/gunman-rush/?v=9e1522fab3fc)，主菜单“动作练习/ACTIONS”。成功蹬墙、钩索飞行→合法目标→真实Motor拉近→前上踢腿小跳、空中子弹对敌人提交伤害，恢复额外跳跃/一次钩索；能力未授予不赠送，上限不叠加，空钩/阻挡/取消/重复与旧回调不刷，原射击包费用与返还上限不变。正式平原默认普通枪/一跳，能力发放/存档未扩展。采用ability-creator、game-quality-gate、project-integration，视听沿用并复验原连续动作。

同一冻结版本的 [CI38399891565](https://github.com/zhipijun1996/gunman-rush/actions/runs/38399891565) core（完整gameplay+art、实际GPU、Foundry36/18与Windows导出）、web和Pages成功，线上build-info精确匹配冻结SHA。核心5942、动作1612、原43/15suite、GPU1054通过；公开桌面/CDP触屏六项GUI零失败。正常速度25.53秒带音轨/次数时间轴和全部失败证据见 [汇总](evidence/air_refill/summary.json)、[合同](quality/air_action_refill.md)、[录像](evidence/air_refill/actions.mp4)。

失败和修正：最初钩拉观察窗不足；旧GUI只看跟随镜头中的人物坐标，改为静态地形配准还原世界位移且保留3px门槛，暂停等待渲染稳定仍要求零位移；一次本地平台退出资源ERROR严格拒绝，实际GPU/同版复查和最新CI通过，不改guard；干净CI未创建动作证据目录导致失败，修正入口并加文件打开断言，在空输出目录实测1612/0。包装期间哈希/冻结证据过期也被质量检查拒绝，修正来源后再验。临时gh/Git CLI认证失效，已连接GitHub应用正常提交/核验；仅本分支含显式[发布标记]的提交走原core→web→Pages门槛，不让普通证据提交自动发布。

任务保持review：独立审查、实体设备、最终主观美术/连续性/手感未验，不签G5。PR65继续draft；后续审查与设备验收、正式成长消费者另行推进。命令：python3 tools/harness.py --profile gameplay --profile art；python3 tools/verify_actor_actions_browser.py URL；python3 tools/publish_playtest.py --ref feature/complete-actor-actions（需要有效CLI认证），或此分支明确[发布标记]提交（实际标记见environment.yml）。

---

# 当前交接：人物连续动作实现（ACTOR-ACTIONS-01）

2026-10-13；分支feature/complete-actor-actions，依赖PR64设计规划，main基线37c2153。用户授权全部现有人物动作，武器仅普通枪/Lv.2三连，明确加二段跳、爬墙跳、钩索，要求连续美术动画。

实现：共享单武器ShootAbility/WeaponDefinition三连动作包、一次费用/资格和包内一次返还，逐发最新方向与取消；TraversalAbility及独立Definition实现H/W/D，唯一Motor受理运动；三端钩输入、暂停恢复；手绘动作扩展/独立机关枪图、脚底锚点/羽翼/钩阶段/重复反冲/受伤落地与过渡；现有敌人/Boss/工匠连续表现。主菜单ACTIONS进入ActionStudio真实装备/授予/碰撞/伤害/资源，可玩全部当前动作；不代替六阶段正式成长，平原默认不变。候选guard/moth和旧Guardian不进正式池。

人物清单与验收分别见docs/quality/actor_inventory.md、actor_actions_spec.md；任务记录ACTOR-ACTIONS-01。新actor-actions专项已接gameplay/art/full，实际Studio盘点8敌人/3Boss；构建因旧Foundry basis被拒后按原36短语/18连段重新真实验证，保留来源匹配。正常速度视频有音轨和输入/事件时间轴；分段reset仅初始化，不冒充一条通关链。

失败与修正保留：新姿态曾影响旧精确瞄准断言，恢复枪口方向合同；钩到30px浮点卡停和站立地面误取消均已修复并加回归；原Guardian已销毁弹体typed filter修正；背景抢眼、中文缺字/低对比经实际GUI发现后修正。第一次整组回归木桥1041/0后因退出资源ERROR被guard拒绝；原guard未改，复测标准1041及GPU1054均通过，不能删除该失败。

复查追加修正：暂停保留墙跳分离/重贴资格，D用独立capacity_floor不覆盖其他跳数来源；特效读取已接受枪口快照，手臂随姿态转换连续过渡。新增正反测试已1002/0；之前full因源修正中断保留日志，重新冻结后整组验证。独立只读Codex审查因401/登录失效失败，不能签独立PASS。最终冻结提交、harness、连续音画与Web实测结果在后续证据记录补充。未做真机/用户认可时按实际未验；不自签独立PASS。不自动合并PR。继续命令：python3 tools/harness.py --profile full；DISPLAY=:98 python3 tools/run_wood_platform_tests.py --capture；python3 tools/run_actor_action_tests.py。

实现冻结96ad74691de30db61f3a352e3c29f6632fd5242d；最终干净core+art和web均通过，核心5942/0、动作1052/0、GPU1054/0、实际桌面/触屏GUI六项0失败，原36/18Foundry已按最新basis重跑。见 [实现报告](quality/actor_actions_report.md)、[证据汇总](evidence/actor_actions/summary.json)、[25.53秒带音轨录像](evidence/actor_actions/actions.mp4)。全量阶段性日志与拒绝保留；最终相关检查已齐，不称同快照一次fullPASS。任务review，不因技术通过关掉独立/设备/玩家待验。

交付：[PR65](https://github.com/zhipijun1996/gunman-rush/pull/65)（draft）已创建并推送feature/complete-actor-actions；依赖PR64设计整合已包含，未合并main。实现冻结96ad746，证据包装a0274a0。本轮采用game-quality-gate、player-creator、weapon-creator、ability-creator、animation-vfx、art-director和project-integration；实际独立gameplay-reviewer调用失败已如实记录。原敌人/Boss按对应技能契约验证，不改AI/生成池晋级。下一步审查PR与正常速度音画、实体设备及正式成长消费者。

---

# 当前交接：人物动作设计与harness规划（2026-10-13）

任务 ACTION-DESIGN-01（process/review）；基线 main 37c2153d9378e3e774fa9191c02318305af47ca5；分支 docs/player-action-harness-plan。本轮用户授权收录三附件、记录单武器限制并规划动作harness/skills；没有运行实现或合并授权。

设计入口 docs/design/player_actions/README.md；原始附件 sources/*.md.txt逐字节保留与SHA256；整理版修复旧链接/V0.7指令引用，保留LOCKED/PROPOSED与历史基线。最新单武器规则覆盖全局：只有一个当前武器Runtime，不等于只一弹体；H/W/D独立；局中切换未定。新W与核心能力独立奖励覆盖旧未来缓降/金道具描述。

规划 docs/quality/player_action_plan.md 与 docs/templates/player_action_coverage.md 包括八类待实现专项、动作阶段/转换、输入回放扩展、正常速度带音轨证据、设备/用户分开以及任务依赖。现有六个相关skills已增加入口和职责。新增专项均planned，未注册空runner；不改变scripts/scenes/resources/config/assets、世界连边或正式参数。

后续先 ACTION-INVENTORY-01 盘点正式角色，再输入/Runtime最小切片，Courier三连+W黄金样板及共鸣最小切片，逐条六分支/H/D，三级候选定稿后实现，再地区锁与设备。按规划给新内容独立质量记录。主角样板不能外推所有人物。

验证和交付结果见本页后续记录与 docs/quality/records/ACTION-DESIGN-01.json。本轮不声明新动画、独立审查、实际生产循环或真机通过。继续命令：python3 tools/harness.py --profile docs；python3 tools/check_quality_diff.py --base origin/main。

本轮验证：冻结内容提交 f7f88ce628d42f9adb3253f56d0af29fe0e5f438，docs harness 10项全部通过，报告 [docs/report](evidence/player_action_plan/docs/report.json)。首次检查因新任务索引review与初始化记录planned不一致失败，修复记录后复跑；[首次结果](evidence/player_action_plan/initial/report.json)保留。三附件来源逐字节及哈希核对通过，见 [来源检查](evidence/player_action_plan/provenance.json)。独立审查/新运行专项不在本轮验证范围。

交付：[PR64](https://github.com/zhipijun1996/gunman-rush/pull/64) 已创建，文档与skills实现冻结 f7f88ce，验证包装 befeed5。分支已推送；未合并main。下一任务 ACTION-INVENTORY-01。使用的skills为game-quality-gate、project-integration，并补充player/weapon/ability/animation-vfx/gameplay-reviewer工作要求。

---

# 当前交接：单向木桥返工与覆盖纠正（2026-10-13）

基线 main db1a27ef2778405908c91a54f9c02699684884e9；分支 fix/one-way-platform-boundaries；任务 PLAINS-TERRAIN-03（review）；冻结实现 62a7ef8。[PR61](https://github.com/zhipijun1996/gunman-rush/pull/61) 记录本次修复；此前石灰岩正式接入 PR60 的交接保留于 [历史](archive/handoff_terrain_production.md)。

用户正式截图（包指纹 f6134e79）暴露单向木桥端头。根因是正式路径循环整张带端头图，而旧测试检查未被该路径使用的 helper；此前石台样板/入口截图的覆盖被错误外推。保留单向语义不代表旧表现免检。原石灰岩认可不撤回，但“全部空中平台已完成”的概括撤回。

修复：PlatformingModule 为单向面使用 PlainsWoodPlatformArt，两端唯一、中部无端帽采样及透明颜色正确混合。碰撞、PlayerMotor、随机生成、奖励及原图未改。Skills 和质量检查要求运行消费者 inventory 与输出证据逐项对应，漏项/helper/错场景/旧版反例会被拒绝；静态校验仍不能证明画面漂亮或 inventory 完备。

冻结运行：实际两图枚举61/83单向实例；同一正式模块的尺寸/平移及GPU边界检查1054断言通过，旧实际绘制隔离负例7失败、退出1符合预期。7项覆盖规则反例通过。原始日志、代表合屏和失败图见 [证据目录](evidence/one_way_platforms)，[规格及限制](quality/one_way_platform_rework.md)，质量记录 docs/quality/records/PLAINS-TERRAIN-03.json。正式合屏是审查镜头取景，未传送玩家或声称路线通关；正常入口GUI和完整harness结果由命令记录补充。

状态：最终木桥视觉认可、独立审查、手机和性能仍未验证；实现者自检不签独立PASS。极窄8/24压力样本缩小且长条仍有重复节奏，不签美术完美。未重新验收其余材质、装饰、Boss、全Seed和回退消费者，不借本次关闭历史问题。

继续命令：python3 tools/harness.py --profile gameplay --profile art；DISPLAY=:98 python3 tools/run_wood_platform_tests.py --capture（需要可用X服务器）；python3 tools/verify_terrain_production_browser.py URL；python3 tools/check_quality_diff.py --base origin/main。正常GPU测试不能换成headless来签像素通过。

CI 补充：Godot core 工作流在原harness之后运行 xvfb-run 下的实际GPU像素检查，并上传图片/inventory；无GPU环境不能静默替换成headless签通过。冻结游戏/测试实现仍为62a7ef8，后续提交补充CI接线和交付证据。

最终本地回归：首次 gameplay+art 在新增 headless 退出资源 guard 处失败，未签全量通过；Core5942、legacy43、region15及其前序检查通过。诊断保留后仅将新测试host改为真实时间 max-fps=60，保留ERROR拒绝；连续3次各1041断言通过，art全profile复验通过。合并两次运行的25项检查无缺项，见 regression-summary.json；不是一次无中断full PASS。冻结Web13项、正常入口GUI及Web木桥可见性通过，浏览器包3b23691de8fc。游戏/着色器代码仍与62a7ef8相同。既有套件的退出资源警告保留，性能维度未签通过。

2026-10-13 用户明确指令“合入到main。”，授权 PR61 普通合并。合并前 dfe9627 的 push/PR 两套 docs、core（含新增 Xvfb GPU 检查）和 web 均 SUCCESS，见 [CI](https://github.com/zhipijun1996/gunman-rush/actions/runs/38353756518)。本次仅更新交接文字后合并，游戏与测试实现不变；实际合并提交和部署结果以 PR61 与 main 工作流为准。Git 合并授权不代替最终木桥美术、独立审查和设备验收，质量任务继续 review。


实验室合并与增强进行中，旧工坊交接见[归档](archive/handoff_foundry_before_main.md)。

## 实验室持续测试与main整合

用户授权本轮验证后合并到main。基线7f0e433（PR61），整合8712fdd，反馈/敌人及键盘源提交0e4891250c41d2e300b1bd798977d59b75501445。保留主线harness/软件GPU平台不变量、平台边界和正式两张地图。新schema2意见导出兼容旧数组，包含manifest/basis、位置、能力及敌人计划；AI任务保留原文和整段关联。敌人开关为最多3个既有巡逻敌人手动预览，真实射击/接触伤害，无强制全清和永久奖励；不声称带敌人路线已验证。

Native反馈11/0、回放34/0、触屏438/0；完整gameplay+art harness通过，Web harness通过；独立触屏中文输入/下载、死亡反馈、模态拦截、弹体击伤与实例清理通过。死亡不能反馈、HUD叠层、虚拟键盘重点击不能输入的反例及修复留在[审查](evidence/foundry_main/review.md)。有Native退出资源诊断；实际Android/iOS键盘、手感/趣味与正常速度录像待验。FOUNDRY-MAIN-01保持awaiting-device。合并/公开构建验证后补充结果。

最终已按用户授权合并[PR62](https://github.com/zhipijun1996/gunman-rush/pull/62)至main **a165fbdda462d890b7c1cdf8ffd468ddf43c89b5**。[main CI38371668137](https://github.com/zhipijun1996/gunman-rush/actions/runs/38371668137)Core/Web/deploy全部成功，保留原harness和软件GPU平台检查。公开版 **[2765b0e93bb8](https://zhipijun1996.github.io/gunman-rush/?v=2765b0e93bb8)** source_commit准确匹配main；[构建](evidence/foundry_main/public_build_info.json)。公开844×390触屏实测：重新点击输入框后中文输入、保存、下载schema2含原始Manifest、敌人开关与模态屏蔽通过；[线上结果](evidence/foundry_main/public-touch-result.json)。真实手机系统键盘/手感/趣味仍awaiting-device，后续增加模块遵循foundry_agent_workflow；新增敌人模式仅手动预览，不能冒充敌人路线完整验证。

## 空中动作恢复与公开试玩更新（AIR-REFILL-01）

用户明确要求更新试玩网页，并规定蹬墙跳、钩索命中拉近后的踢腿小跳、空中射击实际命中敌人恢复二段跳/钩索资格；本轮覆盖旧“不补二跳”候选合同，不合并main。沿用ability-creator、game-quality-gate、project-integration；共享Traversal/Jump/Controller与实际Projectile committed回调实现，空钩消耗一次，重复/旧回调不刷，射击包费用返还不变。详见quality/air_action_refill.md。新增30/60/120Hz实际连招及边界；第一次观察窗不足失败保留，拉近完成后恢复。正式平原未授予H/D仍不自动开放。验证与分支Pages发布进行中，最终版本/网址/CI见后续记录；真机、独立审查和用户手感仍待验。
