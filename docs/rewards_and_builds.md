# 道具V5正式运行规则（ITEM-V5-01，2026-10-27）

本节覆盖下方RUN-GEAR-01的“仅Modifier、尚无复杂消费者”、旧扩容价格及旧正式道具池。附件《道具v5.xlsx》原件与十表逐格快照保存在[来源归档](evidence/item_v5_01/source/)；有效72项、删除21项、可成长16项，以01逐件清单和04成长表交叉核对。用户已确认以03「数值参数」H列当前建议值优先；01旧描述、旧JSON及12处矛盾保留溯源，不默默改写原表。

正式连通地区由`ItemCatalogV5`读取`config/items_v5.json`。同一份Definition含稳定ID、版本、稀有度、独立1–5齿轮负荷、价格、成长参数、前置与参数合同；导入器严格拒绝缺失、未知、非有限和不合法零值，`*_by_level`仅由当前等级取一个值。旧resources/items开发fixture保留，用于原回归，不混进新正式池。新增同家族道具主要增加数据；新机制增加一个实际消费者，并补行为与撤销验证，不修改装备事务核心。

| 权威所有者 | 当前职责 |
| --- | --- |
| `RunInventory` | 持有实例、来源收据、等级和持久effect_state；领取成功只入包。成长道具重复领取原子提升同一个稳定实例至Lv2/Lv3，不额外占齿轮；非成长道具拒绝重复，满级不再投放。 |
| `EquipmentService` | 暂停会话与完整装配提案；容量、前置、互斥、锁装、revision与epoch校验通过后原子提交。获取不要求有空槽；背包不设齿轮持有上限。 |
| `BuildState` | 从基础与当前已装备、未损坏实例重算Modifier和效果来源；普通装卸不回血、不补弹、不恢复本次腾空次数。 |
| `ItemRuntime` | 正式玩家与六个局部效果家族之间的明确适配器；只有已装备来源能响应命中、受伤、主动、钩索、回能、击杀和地图事件。沿用原伤害、资源和交易权威。 |
| `RewardService`／`ShopService`／`RunWallet` | 原幂等收据、Manifest、库存与局内金币原子事务。永久音符不变，装备与扩容均不扣永久货币。 |

普通最大HP装卸只改变上限与钳制，不免费回血。P18「心契」按表为明确例外：首次真实装备按比例换血一次，提交实例收据并锁装／禁疗；卸装重装、菜单和地图切换不能重领。B16/B17/B30受真实HP伤害而破损，护盾吸收不计为HP受伤；破损源立即撤销，维修通过原钱包事务重新启用，不回血、不重置一次性收益。

临时护盾共享上限3，数值来自`config/item_v5_runtime.json`。主动使用独立R／手柄RB／触屏按钮，暂停背包可选择当前主动；不占用原武器主攻／副攻或核心能力。P02折扣只用于主动道具技能，不能折扣被动救命；派生伤害进入原FrameDamagePolicy的认证桥，实际HP提交后才触发允许的后续效果，不能递归主攻回能。普通来源卸装、破损、武器动作取消、死亡与切图必须撤销旧请求。

时间域由原AirFocus持有唯一空中瞄准能量与累计两真实秒上限。N01改变世界慢速，P06满血瞄准冻结世界模拟；角色、输入与玩家防护计时继续活动。冻结保留实体碰撞与静态危险，不能附赠穿墙、无敌或无限持续。B06按同次腾空和主攻packet返还时间能量，保留等级上限，不增加两秒预算。

齿轮容量仍8→10→12→14，每次+2，唯一运行配置`config/gear_capacity.json`；本轮按表06将试验价格调整为35／55／80。正式商店三个固定报价、刷新与维修走原账本；权重60／30／10、刷新8金币、三槽及奖励专属名单来自可调`config/item_v5_economy.json`，均为实施候选，不代表经济平衡验收。骰子仅真正装备时每图第一次免费刷新，卸装重装或重开界面不刷新次数。

随机上下文仅使用根Seed和稳定地区／地图／宝箱／Boss／商店角色，不混入每局随机的收据前缀；Manifest记录上下文与算法版本，交易／库存／领取键仍保持本局唯一。

随机池先按当前武器／核心能力／持有成长上限筛选；当前能否装备与持有合法性分开。宝箱、Boss金奖励和商店都调用原服务入包；候选固定在独立随机流Manifest，菜单不能重抽。同帧已入队的玩家伤害优先于开店、购买、装备和奖励，零血取消未提交事务。Boss金道具与区域核心能力始终独立，不把随机道具当作主路必需能力。

宝箱表现由 `config/chest_art.json` 管理：`medium` 为蓝色平盖箱，`high` 为紫色拱盖箱，`region_top` 为金色紧凑钟箱，各有关闭／开启两态。平原 Sprite2D 和森林专用 ChestArtLayer 共用 ChestArtLibrary；状态只读取原 `claimed`，成功提交奖励才开盖，取消、拒绝或保存失败不改变箱态。重载读取原地区账本，不补发物品。森林原 `hard_optional` 资源箱只借用金箱外观，不改变奖励类型。图像、完整ROI、同档共同等比缩放及足点均在数据配置中；美术不持有奖励或碰撞。当前是六张静态姿态，不含开盖动画。

九项有效联动由`config/item_v5_synergies.json`记录原行与当前参数；三项缺设计条件和四项已删除联动明确禁用。G19在当前无独立精英标签的正式地图中暂将Boss计入进化精英，配置标记为implementation_candidate；P17与既有Lv3蓄力全速移动的规则冲突仍待用户选择，不能把问答中的默认推荐视作确认。完整逐件消费者与验证范围见[覆盖矩阵](worklines/item_v5_01/consumer_coverage.md)，缺失画面、玩家和实体设备证据维持未验证。

同一局跨地图／地区与存活环境回退保留实例、等级、状态、装备、齿轮、钱包与收据；地图内实体、标记和旧epoch回调按原边界清理。真正结束本局清空全部局内来源与扩容。无新增永久成长或旧存档迁移。

---

正式地图 Manifest 的 capability_snapshot 另写 item_sources_version=1、实际已装备实例的定义版本／指纹／等级／破损状态及 gear_capacity／gear_level。BuildState 与 RunManifest 使用同一稳定顺序的 Modifier 解析，从当前基础重建地图生成属性；只持有未装备的道具不进入此快照。载入拒绝不完整元数据、伪造等级／负荷／互斥与属性不匹配；整组不存在时保留原资源式回放路径。该快照用于内容重建，不是恢复 HP、主动技能冷却或完整背包的中途存档，也不认证所有权历史。

# 本局背包、装备与齿轮负荷（RUN-GEAR-01，2026-10-26）

本节覆盖下文历史原型中“获得即生效”“获取时按装备互斥过滤”和将随机道具作为必需大能力的描述。当前正式流程为：领取／购买 → 本局背包 → 点击暂停直接打开背包 → 装备 → 效果生效。未装备道具不消耗负荷，也不进入能力快照。核心能力解锁、当前武器选择与随机道具独立。

暂停默认背包页：左侧上方显示齿轮形状的容量槽和已装备图标，下方为独立滚动的背包图标网格；右侧显示选中实例的图标、名称、稀有度、负荷、实际效果、装卸／替换及扩容操作。点击或焦点选中图标仅更新详情，确认装备才提交。顶部左右箭头、Q/E、手柄LB/RB切换背包／旅途／设置／帮助；网格方向键继续选择道具。旅途页提供结束本局，顶部继续或Esc关闭恢复玩法。离开背包立即关闭装备会话，回来重新读取；详情选择变化也作废旧动作按钮。见[本轮反馈范围](worklines/run_gear_01/ui-feedback-02.md)。

| 所有者 | 职责 | 不承担的职责 |
| --- | --- | --- |
| `RunInventory` | 持有每个独立实例；稳定实例ID、定义ID、定义版本、来源ID与来源类型；持有数量／同源幂等 | 不校验齿轮、互斥或修改玩家属性 |
| `EquipmentService` | 本局容量、升级等级、已装备实例ID；校验完整提案并原子提交；暂停编辑会话 | 不发奖励、不扣永久音符 |
| `BuildState` | 仅从已装备来源和唯一基础属性重新计算Modifier，提供通用效果来源 | 不把背包道具当作已生效来源 |
| `RewardService`／`ShopService` | 保留原收据、候选、库存、金币和交易边界；成功只入包 | 不自动装备，不要求当前有空余负荷 |

`BuildState.can_add/add_item/owned_items/count_item` 暂作旧调用方的兼容门面，实际委派给背包；`BuildState.item_ids()`明确返回已装备定义ID，奖励／结算的持有统计使用`inventory.item_ids()`。实例快照、定义、报价和收据都返回副本，外部修改不能改变权威持有或装备。

背包无齿轮容量限制。`duplicate_policy=REJECT`禁止重复持有同类，`STACK`允许独立实例并受`stack_limit`限制；每个实例独立占用`gear_cost`，Modifier按实例相加。`equip_limit`可进一步限制同类同时装备数量；0跟随持有上限。互斥只约束装备，不阻止同时收藏。相同定义ID的冲突版本／内容不能混入同一局。唯一实例ID在同一局跨地图、菜单和环境回退保持稳定，同来源重试不会生成第二个实例。

齿轮数值唯一运行来源为`config/gear_capacity.json`：初始8，局内可购买10／12／14容量，每次+2；试验价依次10／18／28金币。各ItemDefinition独立定义1–5的`gear_cost`，与蓝／紫／金稀有度无对应关系。当前定义包含蓝色5负荷和金色1负荷。容量购买通过原ShopService交易收据账本与RunWallet扣款，不能重复扣款或跨级重放；本局结束清理扩容，不改永久音符与成长。

换装提交完整实例ID列表。先校验会话、Run／Stage／Actor token、输入epoch、存活／焦点、revision，以及持有、实例重复、装备数量、负荷、互斥、标签／核心能力／武器前置和属性合法性，全部通过后一次更新。替换失败保留原装备、属性与容量，不收金币。暂停编辑可自由装备、卸下或选择已装备道具再替换。关闭／切页／失焦／切图／死亡取消会话，旧按钮及请求不能提交。

Modifier继续按稳定来源排序，从Character／Meta后的基础快照重算，不逆减累积结果。增加最大HP不回血，卸下仅钳制当前HP；不复活零血玩家。换装立即单调钳制当前飞行的跳跃／射击容量和已有弹药，不重置腾空次数、不补弹、不改速度或重新武装能力；暂停中卸下后再装备也不能恢复本次腾空的上限。接地、命中、核心恢复仍走原有规则。核心能力的容量下限保留。

`ItemEffectComponent`提供`effect_id/channel/modifiers`及装备实例来源，通道预留PASSIVE／ACTIVE／WEAPON／GRAPPLE。本轮只执行声明的属性Modifier；没有新增主动技能、武器行为或钩索技能。未来效果消费者应使用`BuildState.effect_sources()`的实例来源生命周期，不在PlayerController按道具ID加分支。

同一局切地图／地区保留背包、装备、容量、钱包、库存与收据。存活环境伤害回退只失效旧Actor操作；真正结束本局统一清理。随机Manifest仍记录固定候选与实际交易，装备／扩容另写版本化输出。装备不能成为未授予核心能力的替代保障。

新增常规道具时，在`resources/items`新增独立`stable_id`并维护`definition_version`、图标、稀有度、`gear_cost`、持有／装备上限、标签及前置；声明已有`BuildModifier`或`ItemEffectComponent`，再将定义接入原奖励／商店数据池。无需修改装备提交核心。新复杂效果由独立消费者读取`effect_sources()`并遵守Run／Stage／Actor与来源撤销契约；`channel`预留分类不代表本轮已实现触发技能。

验收、操作与未验边界见[本轮工作线](worklines/run_gear_01/scope.md)与[执行证据](evidence/run_gear_01/README.md)。下文保留旧版本来源，冲突以上述当前规则为准。

---

> 2026-10-23 DEMO-UI-01 R3 用户新规则覆盖旧 D079：开枪不消耗/不受时间能量限制；只有实际空中瞄准慢时消耗时间能量（枪械与钩索共用 AirFocus 唯一状态）。基础空中弹药一发，命中补弹、接地补弹和既有能力恢复事件保留。接地按真实秒渐回能量；慢时累计上限与耗尽再武装沿用既有规则。旧两发/射击精力只用于显式历史 fixture。详见[本轮范围](worklines/demo_ui_01/r3/scope.md)。

# 奖励、道具、构筑与商店契约

> D080 最新探索操作差异、资源宝箱与稳定性道具见 [实际实现](plains_exploration_expansion.md)。只平原两张非线性地图，保留 D079 精力与基础物理；旧条目按历史回归解释。

> D079 最新正式平原规则：[多维体验与射击精力](plains_experience_energy.md)。开枪消耗精力、真实命中返还，空中提交伤害返还一发；覆盖本文冲突历史规则。一跳/未命中基础两发、既有物理和两图探索保留；道具统一 AI 图标、介绍与实际 Modifier。

D076最新正式流程：[平原两张随机连通探索图](plains_two_maps_fog.md)，第一张较简单/小Boss，第二张较难/大Boss。下方D075一张图描述为历史；大能力/下一地区仅在第二张后显示开发边界。公开试玩更新也列入交付。


> D075 最新正式契约优先：一个地区一张随机连通地图，平原固定首区；六地区为长期流程，本次仅平原。大能力在平原 Boss 后首次选择，尚未实现时明确提示并安全回家。旧八关/第八 Boss/出口房间奖励的段落只描述保留的开发回归，不再约束正式入口。实现与验证见 [连通地区迁移](plains_connected_region.md)。

本轮D062优先补充见[分岔挑战修订](plains_branch_revision.md)：普通房不强制全清；中途分岔→两条挑战路线→末端单门。旧“defeat_targets普通房”和途中门属于被替代的历史实现，Boss条件不变。
本文件是奖励经济与构筑权威规格；P3已接入最小来源Modifier、回血补给、二选一、RunCoin钱包与商店消费者；完整经济和内容池仍分阶段扩展。正式精力用途、经济数值和稀有度权重未锁定。

## 类型与职责

RewardKind至少为RUN_COIN、META_NOTE、HEAL_CURRENT、INCREASE_MAX_HEALTH、ITEM，后续注册其他类型。HealEffect仅恢复当前血量至上限；MaxHealthEffect仅改变上限，不自动恢复当前血量，若奖励同时包含两者须显式组合两个效果。血量奖励关选择何种效果待决策。蓝/紫/金仅为ItemDefinition.rarity，不强迫金币/回血奖励拥有稀有度。

ItemDefinition={id,version,rarity BLUE/PURPLE/GOLD,effect_components,tags,duplicate_policy,stack_limit,exclusive_tags,appearance_weight}。权重非负、有可选候选时总权重须正；重复获取、上限、互斥可配置，具体平衡与跨局保留待定。效果可加属性、修改能力、增加N跳/射击、启用技能或改变武器行为，通过声明组件执行，不能写某道具ID的PlayerController分支。

CharacterDefinition引用基础属性/初始能力/WeaponDefinition；WeaponDefinition引用冷却/射速、弹体/伤害、反冲、散布、资源CostPolicy与行为组件。ShotRequest仍来自释放沿；火力提升不自动改变发射方式。未来其他触发方式待决策。CostPolicy不默认关联Stamina。

BuildState保存本局item_instance_id、技能来源、当前武器/行为与Modifier集合。Modifier复用source_id/stat_id/operation/value/priority/duration契约：从Character基础、Meta基础修正和局内来源重新推导，删除来源重新计算，不逆减累加后的数值。同类override取最高priority，同级以稳定source_id排序确定胜者；具体排序在实现测试固定。增减次数遵守ability_components，不赠送未定义的空中次数。

新增最大血量不等于回血；移除最大血量来源时钳制current≤max，不复活零血人物。重复source应用去重，临时来源过期或死亡清理同时撤销能力/武器行为及其延迟请求。获得新技能时生成capability_snapshot用于地图兼容，不保证任意流派适配任意地图。

## 奖励生成与二选一

RewardService.generate_offer(context,definition)返回RewardOffer：offer_id、所属run/stage、source_id、候选reward IDs、claim_group_id、生成版本。候选持久在StageState/Manifest，不因段回退或重开UI重抽。

道具关完成后恰有两个候选，choose-one组最多领取一个。暂定优先两种不同且符合构筑互斥/叠加条件的定义；不足两种时用预先验证的保底池，仍不足则显式阻止关卡配置/报告生成失败，不复制同一道具伪造二选一。领取命令ClaimReward带当前token、offer_id/option_id/claim_id；先校验玩家存活/关卡完成/候选合法，再原子锁组、应用效果、写账本/manifest并发布RewardClaimed。同claim重复返回原收据，不再给效果；另一个候选、过期token、重复来源、终局状态拒绝。

Boss固定GuaranteedRewardPolicy只从GOLD池生成一个必得道具。是否自动入包或交互领取待决策；有效胜利必须有一个金道具权益，生成/授予与Boss defeat_id绑定且只一次，不能被概率池降级/抽空。若用交互领取，进入下大关/成功结算前须保证兑现，不能用可跳过领取把必得降级为可能获得；之后真正死亡仍取消未提交项。缺有效金池是内容错误，不能伪装普通奖励。玩家同帧死亡按DamagePolicy先结束run，取消未结算Boss奖励。

## 最简商店与交易

ShopService.get_offers(stage_context)、quote(offer_id)、purchase(command)、get_receipt(transaction_id)预留局部接口。ShopOffer={shop_id,offer_id,definition_version,currency_type,price:int≥0,stock:int≥0,quote_version}，quantity必须正整数；RunCoin与MetaCurrency类型不同，最小局内店只接受显式RunCoin报价。实际价格、可售内容、刷新、折扣/退款政策待定，不自动提供付费商城。

PurchaseCommand={run_id/run_epoch/stage_epoch/actor_epoch,shop_id,offer_id,quantity,quote_version,transaction_id}。原子校验存活、币种、最新报价、余额、库存、构筑合法性 → 扣币/扣库存/应用效果/写收据与账本，任何失败全部不变。相同transaction_id且同payload返回同收据，payload不同拒绝；并发买最后一个库存至多一笔成功，余额/库存不负，过期报价不扣币。明确的下一次合法购买必须用新transaction_id。

段回退保留钱包、已领组、库存、报价、收据与BuildState；不调用商店/奖励reset补库存刷道具。当前actor_epoch令未提交交易失效，但未领offer仍可凭新token重新申请，claim_group锁不会因actor_epoch重置。结束run取消pending，不补发奖励。

## 提交边界

帧伤害/零血终局先于未提交奖励/购买。RunLedger按run_id+stable_stage_id+source/claim_group/transaction持有，不能只按会变化的actor_epoch去重。RewardClaimed/PurchaseCommitted带具体收据与run/stage token，UI只订阅结果。确定性effect应用和账本写入在同一逻辑提交中，失败不得留下部分Modifier或钱包扣款；P3实际消费者出现才实现最小事务，不提前建万能经济引擎。

已提交操作的完全相同重试可只读返回原收据，不重新发事件/授予/切换；不同payload拒绝。所有未提交命令仍必须通过当前token/存活检验，旧token不能作为新交易，RunEnd后只能读已归档结果。此规则同时适用于Reward/Shop与出口选择，避免“重试返回收据”和“旧请求拒绝”混淆。

## 当前 demo 实现边界

`scripts/builds/build_state.gd`从原型基础重新推导max_jumps、max_air_shots、projectile_damage、shot_burst_speed、recoil_impulse、max_health。可撤销来源、重复/上限/互斥预览和有限数值校验已接入玩家；override优先级最高，同级稳定source_id字典序后者胜，随后ADD再MULTIPLY。删除来源重新计算；空中获得次数不赠送当前飞行中未定义的额外次数。零血清构筑不复活玩家。蓝加跳、紫加空中射击和金战斗强化都是可替换fixture，不是完整角色/武器Definition与所有新技能系统。

RewardService在当前run/stage账本持有候选与来源，二选一只能锁定一次；同claim重试只读收据，冲突/过期/终局拒绝。Boss开发fixture提供一个金候选，靠近并领取后才结束成功局；交互领取只是demo测试政策，不把Q009正式领取方式升级为已确认。生成候选失败必须显式报告，不能降级金奖励。商店fixture售一次加跳，价格5 RunCoin、库存1；战斗关发10 RunCoin，均不是正式经济平衡。ShopService校验报价版本、数量、余额、库存、构筑与token，成功才统一扣款/应用/写收据。

供给使用SupplyHealEffect只恢复当前HP，MaxHealthEffect独立改变上限；当前地图中的+2HP补给一关只能消费一次，段回退不刷新。健康奖励关正式采用哪种效果仍待定。当前六种类型均有实际消费者；旧固定地图用于回归，正式平原各类采用独立配方与内容。

固定demo在物理伤害批次之后开放交互事务；玩家零血立即失效token，未提交奖励/交易不能抢先于终局。所有实际验收结果记录于[交接](handoff.md)，不以接口描述替代运行证据。


## 后续必备能力道具

指定金色道具将解锁贴墙缓降，见[后续契约](wall_slide_design.md)。能力来源授予可撤销/去重；后期必需路线必须保证前置取得，不用随机权重替代保障。前置Boss的唯一GOLD是否指定该道具仍待Q016，不改变现有Boss一金与二选一只能领一个。


## 平原生成拾取物与双货币

金币使用RunWallet，本局商店购买后扣局内余额；金币关按安全平台锚点散布多个独立拾取物，而非出口集中发整袋。音符外观为音符符号，使用Meta永久钱包，不进入RunWallet。拾取ID包含唯一run receipt prefix、stage index与content instance ID；环境回退不重新实例化、不重发，重新开局不能复用旧epoch收据。拾取请求在伤害批次后校验活跃token/Health，零血同帧取消未结算拾取。

散布点来自生成模块的安全落点，内容流与地图流分离，奖励种类/数量写入实际RunManifest。金币收集是否必须全部完成仍Q013；本轮金币房允许少拿推进作为明确demo规则，不强制在危险处刷怪/刷回退。音符保留/升级内容与价格见D056及home_and_save，不设兑换。

本轮用户出口确认规则替代D058自动触碰结算：靠近已解锁出口显示下一类型和奖励摘要，暂停游戏并提供ENTER/STAY。靠近本身不结算、不锁定最终路线；STAY不领取、不切关，离开145世界单位后该出口重新武装，可转往另一出口。ENTER校验Run/Stage/Actor token、存活状态后仅结算一次并锁定路线；道具二选一与Boss必出金道具在确认后显示独立选择面板，只能领取一次后继续（Boss返回家园）。环境回退取消未提交弹窗与动作而不重置奖励账本；真正死亡优先并取消全部未结算奖励。固定开发回归仍使用显式交互，不覆盖正式流程。

D064：平原取消二段跳；正式平原普通道具池与商店不提供额外跳跃，保留通用N跳Modifier及开发fixture。后期每大关获得一个新能力已确认，具体发放时点、与Boss金奖励关系及跨局保留规则待定。

## 后续单武器与成长输入（2026-10-13）

[最新设计入口](design/player_actions/README.md) 明确同一时刻仅一种当前装备/使用武器；U1选定当前武器Lv.2分支，U2沿同分支升级。Boss金道具与通关核心能力是独立权益。局中换武器未定；本次不添加切换消费者或修改既有奖励。

## 道具配置与表现资源的扩展边界（2026-10-28）

`config/items_v5.json`保存原表生成基表；`config/item_v5_authoring.json`分开声明组件身份、设计覆写、已实现静态效果的新增与下架。下架只停止新投放，不删除本局已持有定义或冻结报价。目录工厂严格校验并按真实配置字节缓存；调参不写RunInventory实例身份，不改变Equipment原子提交与BuildState仅装备重算的职责。具体命令和可用参数见[item_authoring](item_authoring.md)。全新效果机制仍须实现明确组件和回归，不能靠伪造tag获得空技能。

`config/item_v5_art.json`将72个独立图标及世界recipe与玩法参数分离。图集region、锚点、尺寸、变体与时间轴由数据描述，ItemPresentation／ItemArtLibrary共用资源；View／Entity读取原效果状态和已接受回执。施放前捕获来源及生命周期上下文，回调中卸装或重装不能给旧表现重新授信。伤害命中、治疗、护盾、金币等反馈分别等待真实结果，不由贴图帧回调决定数值。纯属性道具不强加常驻粒子。新增常规图标／已支持表现family不需改背包装备核心；新机制需明确组件，资源预算仍受64MiB上界约束。

## 家园道具图鉴与出发携带（HOME-CODEX-01）

`ItemCatalogV5` 是本地只读道具数据库，JSON 保存定义和参数、Resource 提供效果组件；当前无需额外 SQLite。`config/home_items.json` 只维护家园准入、默认及逐件音符解锁价格，`HomeItemCatalog` 合成家园条目，不复制一份道具定义。新增当前支持机制的道具仍从原目录进入图鉴。

每份存档单独保存 `discovered_items`、`unlocked_home_items` 和 `selected_home_item`。正式 RewardService／ShopService 的 COMMITTED 获得收据及成功出发入包才记录发现，重复回放、修理、扩容、装备和浏览不创造获得记录。未发现条目显示问号并隐藏名称、图标、效果。默认需曾获得才能永久解锁，可由家园策略配置；蓝5／紫12／金25音符是可调试验价。音符扣款与永久解锁经原 MetaProgression 账本和原子存档统一提交，保存失败不收费。按钮绑定实际显示报价、档案会话及revision，旧价格／旧页面／失焦请求不能提交。

家园原 `relics` 建筑开放图鉴，与成就档案、武器工坊和核心能力独立。玩家可以单选一个已解锁条目或选择不携带；每次正式出发加入一个 Lv.1 的 `home_carry` 实例，不自动装备、不重复扣音符、不消耗永久解锁。RunInventory 持有、EquipmentService 装备校验与齿轮、BuildState 只重算已装备效果的职责不变。地图重载、地区切换和存活回退不再次发放；结束本局清空局内实例，保留永久记录及携带选择。

下架／移除 ID 保留存档历史，但不能新解锁或带出，界面始终提供“不携带道具”以免过期选择阻止出发。存档 envelope 升至schema3，迁移当前schema2并保留原Web存储key；历史结算里确实记录过的有效道具可恢复发现，不免费解锁。获得记录若保存失败，当前档案会话内重试；主动切换／重载档案时丢弃尚未保存的旧会话请求，绝不写入另一个存档。完整范围见[图鉴工作线](worklines/home_codex_01/scope.md)。
