# 奖励、道具、构筑与商店契约

本文件是奖励经济与构筑权威规格；P3已接入最小来源Modifier、回血补给、二选一、RunCoin钱包与商店消费者；完整经济和内容池仍分阶段扩展。正式精力用途、经济数值和稀有度权重未锁定。

## 类型与职责

RewardKind至少为RUN_COIN、HEAL_CURRENT、INCREASE_MAX_HEALTH、ITEM，后续注册其他类型。HealEffect仅恢复当前血量至上限；MaxHealthEffect仅改变上限，不自动恢复当前血量，若奖励同时包含两者须显式组合两个效果。血量奖励关选择何种效果待决策。蓝/紫/金仅为ItemDefinition.rarity，不强迫金币/回血奖励拥有稀有度。

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

供给使用SupplyHealEffect只恢复当前HP，MaxHealthEffect独立改变上限；当前地图中的+2HP补给一关只能消费一次，段回退不刷新。健康奖励关正式采用哪种效果仍待定。六类型注册表不表示六种地图内容全部已制作；当前可玩路线覆盖combat/shop/item_reward/boss，coin_reward/health_reward定义与独立效果供后续接入。

固定demo在物理伤害批次之后开放交互事务；玩家零血立即失效token，未提交奖励/交易不能抢先于终局。所有实际验收结果记录于[交接](handoff.md)，不以接口描述替代运行证据。
