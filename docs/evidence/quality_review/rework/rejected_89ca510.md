# 89ca510 独立复审：REJECT

审查者 `/root/independent_gameplay_audit`；实现者 `/root`。冻结提交 **89ca510cad97b8940389d25423ab7869313734eb**，对比初审 **5fd9c272d74616ae477809fa4285f609e6b697c6**。本代理只写本报告，没有改生产代码、权威文档或测试。主代理收到发现后开始修改工作区；以下结论仅适用89ca510，不评价这些后续未冻结修改。

采用 gameplay-reviewer 的空间×状态×时间×消费者方法：先看真实调用链，再检查可见绘制与游戏判定、状态迁移与资源、周期/中断、正式与开发入口差异。实际读取新增三个 Skills、production_loop、通用审查方法、规格、所有本轮主要生产 diff 和补充测试。没有把“核心5942/补充350通过”的实施者陈述算作本代理独立运行。

## 初审问题复审

| 初审项 | 89ca510结论 | 证据与限制 |
| --- | --- | --- |
| IQA-01 暂停清普通敌人攻击 | 源码修复成立；冻结GUI未验 | demo_app.gd:700附近已删除 `_cancel_enemy_attacks(true)`，地图/菜单共同冻结SceneTree，保留enemy状态和弹体；质量测试注入正式敌人telegraph状态验证时钟，但该测试没有检查实际飞行弹体。未独立重跑Godot套件。 |
| IQA-02 身体超hurtbox | **未完整修复，出现反向不一致** | fitted_action_scale把所有帧alpha极值缩入固定框，却让idle身体仅约17像素高，32像素hurtbox上方约15像素没有可见身体。见RA-01。 |
| IQA-03 地形周期接缝 | **不通过** | 正式实体已切到新的PlainsTerrainBorders消费者，但薄平台角重叠、草顶站立锚点错误。见RA-02/03。 |

## 必修发现

### RA-01 / P1：单向“可见体包含在hurtbox”制造大块透明受击区

证据：`scripts/enemies/enemy_presentation.gd:99`–110；`EnemyMotor.configure`唯一28×32矩形未变。独立用真实manifest按新函数计算得到：

- beetle scale=.0546875，idle alpha≥128范围 `[-11.046875,-1.2265625]..[11.1015625,16]`。
- sentry scale=.0454545，idle范围 `[-5.954545,-1.772727]..[8,16]`。
- 两者hurtbox仍为 `[-14,-16]..[14,16]`。顶端空白可碰撞带分别约14.77、14.23世界单位，占原碰撞高度近一半。

反例：沿局部 y=-10 发射基础半径3弹体，扫掠矩形会命中，但整个弹体都在可见idle身体上方。接触伤害体还由同一collision_size加margin构造，玩家可在尚未碰到可见身体时受伤。该静态反例确定；尚未实际GUI发射这条精确弹道。

玩家影响：初审“打到头不算”变成“打空气也算/空气有接触伤害”，未达到可见判定一致。`tests/quality_review_runner.gd`仅检查所有alpha边界不超hurtbox，正好无法检测此反向失败。

返工：为主躯干核心、腿翼/武器等装饰分别标注锚点/用途；统一帧比例但让核心身体贴合既有hurtbox。做正反双向真实弹道与身体接触反例，而非继续缩小所有alpha。禁止为图像偷偷改变正式碰撞/伤害公平性。

### RA-02 / P1：短/薄平台的凸角互相覆盖，几何plan通过不代表四角实际存在

证据：`scripts/art/plains_terrain_borders.gd:110`–115。每个角一律画48×48，只clip到整块rect，没有分配各角独立区域。对于 `Rect2(0,0,8,8)`，四个凸角目标都覆盖整块8×8；后绘制角覆盖先绘制角。对于24高长台，上、下角在整个24高范围重叠，bottom贴片覆盖top贴片。角源像素不相同，因此不是无害重复绘制。

反例/验证：画8×8、24高长台、30宽竖台，再叠加每个实际draw destination及最终像素归属；不能只检查boundary中faces=4、corners=4。现有 `boundary_contract()` 恰好列入8×8却只检查plan数量，未走实际绘制证据。

修复应限制角区半宽/半高并一致计算source采样/比例，明确边、角、填充的最终像素归属。L/T并集的内部边界提取在所读代码中方向合理，但它不能弥补孤立短台的实际覆盖错误；凹角跨slab分片仍需要实际合屏，不授予完整PASS。

### RA-03 / P1：top素材没有站立锚点，草顶被画到实体内部

证据：`plains_terrain_borders.gd:54`–60 固定归一化source；`:104`–109 把top目标顶直接对齐物理rect.y。实际查看原图 `assets/plains_v7/terrain_borders_candidate.png`，top source上方有透明/叶片区，真正连续草顶并不在source顶；代码没有standline/solid-edge anchor。将source完整缩入48高目标并clip实体内部，必然把连续草顶压进实体。

实际图像旁证：已查看主代理 `build/verification/quality-review-after-gui/formal-entry.png`（画面build **34264e26**，是89ca前dirty构建，不能当冻结89ca包通过证据）。图中主角脚底/碰撞站立面约y528，连续草顶却在平台中部约y558；端头顶部为硬裁切裸岩。修角覆盖仍不足以修这个素材坐标问题。

返工：测量各边素材的实体边基准，以基准对齐真实碰撞；允许的草尖/根须外溢与主实体必须分开。验证长/短/高/薄、四边凸角凹角的实际像素与碰撞，不只证明rect覆盖和不越界。该项关于可站面语义是客观不一致；整体绘画品质仍单列用户待审。

### RA-04 / P2：Boss登场前后存在位移跳变，重建intro会重播演出

证据：`scripts/bosses/boss_arrival_presentation.gd:19`–37。非intro时subject.position=ZERO，subject本身仍可见；进入intro第一帧把当前剩余clock存为duration，progress=0，subject直接移到±130或y=-100。没有从先前可见位置连续进入准备动作。

重建反例：旧实例intro已进行一半，clock为原始duration的一半；保存/重载后新演出组件把这个剩余clock当完整duration，progress重新为0，位移重新跑全程，`_impact_played=false`可能再次播冲击声。游戏Boss状态可正确恢复，演出却不等价。两者是源码确定路径，未实际观看冻结版本连续录像。

修复：定义dormant的可见性和准备位；用稳定总时长/演出时间或持久化演出状态计算绝对进度，保证mid-intro重建幂等。验证dormant→intro、intro0/50%/90%重建、skip、暂停/恢复、死亡/卸载；记录正常速度画面与音频，不能只有渲染对象数无泄漏测试。

## 新增范围审查

### Boss接触、镜头与正式消费者

- 正式demo_app及ModuleBossTrial使用统一 `body_contact_enabled()`；Windkeeper/Bellstrider继承的intro/phase_transition保护明确，active/terminal检查也明确。此次源码未发现原mini仅roll模式伤害残留。补充测试仅调用谓词，不是玩家真实碰到Boss后HP变化的端到端证明；真实接触与同帧阶段迁移仍unverified。
- StageCameraRig从真实slide collision识别支撑，将支撑transform共同位移提前加入相机与anchor，离地不沿用支撑；比按地面绝对速度弹簧跟随更符合参考系契约。现有补充测试覆盖实际移动平台横向往返和跳离，属于有效技术证据；本代理未重跑，也未看冻结版本正常速度镜头。竖向/旋转支撑、接地转换、边界clamp、反冲下的画面仍需适用范围声明。
- 地形union实现真正由PlatformingModule与PlainsGroundSupports正式消费，非仅fixture；但RA-02/03证明“接入消费者”不等于“实际画面通过”。

### 两个开发敌人候选

确认仅Module Lab候选入口创建，不在正式生成池、保存/正式奖励内；UI与规格明确candidate/unapproved。不能因候选不完善宣称正式池回归，也不能以两种行为脚本宣称最终丰富度完成。

已发现一个确定的候选实现缺陷：`module_enemy_prototypes.gd:9` 从plains_sentry复制蛾定义，而该定义 `patrol_speed=0`；setup没有覆盖速度。`prototype_moth_behavior.gd:13`的orbit运动量始终limit_length(0)，所以实际Motor完全不悬停移动，只有sprite小幅抖动。这不是轨道移动已实现。应修候选或收窄宣称，不作为已入正式池的缺陷。

护盾前方拒绝、recovery开放以及蛾两次锁定方向的真实弹体复用现有DamagePolicy是合理原型接入；测试使用显式fixture设置初始位置、暂停AI与指定状态，已在注释诚实注明。它证明局部交易/弹体，不证明玩家自然诱导、反冲绕背、两个敌人联合压力或趣味。prototype表现另有独立尺寸/摆动，没有沿用新的fitted_action_scale；要单独做核心体/装饰/碰撞校准，不能假定普通敌人表现修复覆盖它们。

### production_loop与三个Skills

静态未发现本轮需要阻断流程交付的确定缺陷：有任务依赖顺序、round/call/timeout上限、只读review角色、越界变更检查、失败停机、source/mission指纹、原始调用/检查日志、明确终态；生产任务还绑定task_id、quality_record和当前production_snapshot。只读smoke跳过内容完成门槛是明确窄范围，不伪称游戏G5通过。路径检查是误改检测而非安全隔离，文档已明确。

**独立实际执行** `python3 -m unittest discover -s tests -p test_production_loop.py`：8 tests、exit0；这是使用fake worker的控制器契约测试，不能证明实际Codex执行/独立评审质量。此复审未再次运行真实codex mission，也未审到最终冻结SHA对应的完整mission execution证据，因此“实际生产循环已完成一次完整内容任务”仍unverified。

player/weapon/ability Skills有合理触发、共享质量记录、G0–G5、正式能力授予/装备/保存消费者、动作视听与设备用户边界；weapon明确DPS/颜色变化不足，ability明确不能只改max_jumps。没有声称新能力已实装。相关Skill之间的调用关系应理解为协调专业职责，不是无条件递归执行；当前文档没有要求新建多份重复任务。

`python3 tools/quality.py check`：exit0，3份记录结构一致；PLAINS-QUALITY-01、QUALITY-LOOP-01均 `task_complete=false/verdict=UNVERIFIED`，没有虚假done。执行时工作区已有主代理后续修复，故此命令仅列实际执行事实，不当作冻结89ca完整技术验收。未重复重型harness；主代理正在执行的全套结果不冒充本代理独立执行。

## 结论与返工门槛

**REJECT 89ca510的游戏品质修复通过声明。** IQA-01的源码根因已修，IQA-02/03仍不通过，新Boss演出有RA-04生命周期问题。RA-01/02/03/04已及时反馈主代理，应分别保留失败并用新冻结SHA复审。

| 维度 | 本次状态 |
| --- | --- |
| design | unverified：新候选玩法价值/最终视觉未认可 |
| technical | unverified：独立Python8测试通过，不代表Godot全套 |
| formal_integration | passed（仅源码接入检查）：正式地形/暂停/Boss统一消费者已接入 |
| visual | failed：RA-01/02/03 |
| animation | failed：RA-04源码时序反例；连续画面总体未验 |
| audio_vfx | unverified：未听音频，重建重播风险见RA-04 |
| gameplay | failed：RA-01可见判定不一致 |
| performance | unverified：没有独立测目标设备/长期帧时 |
| independent_review | passed：实际不同代理只读审查与主动反例；不等于内容已通过 |
| device | unverified |
| player_acceptance | unverified：没有真人原话/认可来源 |

后续至少补冻结包身份、真实短/薄/高/L/T平台合屏、主躯干双向命中边界、Boss登场完整序列/重建、候选普通输入遭遇。用户画风/趣味与设备仍保持待验，不能把本次独立审查或更多断言数作为它们的替代。
