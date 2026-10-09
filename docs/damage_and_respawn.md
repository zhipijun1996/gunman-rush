# 血量、伤害、段内回退与真正死亡

本文件替代正式玩法“环境碰撞直接die+整场景reset”。当前scripts/world/saw_hazard.gd仍直接die，WorldContext.respawn仍重置clock/全部对象；这是待迁移的历史灰盒，不是本文件已实现。阶段2保留这些旧用例须增加明确LEGACY_INSTANT_DEATH测试模式，正式配置不能使用该策略。

HEALTH-01已实现独立Health/Stamina状态、Definition、局部请求/收据与HUD，见[模块分类](module_map.md)；以下DamagePolicy/段回退/RunEnd仍待后续任务，不以资源零血终态代替完整死亡流程。

## 资源与请求

Health={current,max,alive}，max>0、0≤current≤max，零血为终态直到新局，不由回血/Modifier恢复。Stamina={current,capacity}、ActionResources={jump/shot counts,flight ledger}分别持有状态，资源接口grant/try_consume/clamp/get_snapshot发布类型化变更事件；策略决定消费来源。HealthDefinition、StaminaDefinition、ActionResourceDefinition存初值与上限/时间域，不保存运行状态。

DamageRequest={run_id/run_epoch,stage_id/stage_epoch,target_actor_id/actor_epoch,event_id,source_id,attack_id或exposure_id,physics_tick,kind MONSTER/ENVIRONMENT,amount,hit_direction}。正伤害、阵营、实例/token合法后收集到本tick批次；同攻击/接触暴露ID去重。Monster含接触、近战、敌弹；Environment含尖刺、齿轮、熔岩/越界。Health只扣血，不知道关卡、家园或传送位置。

## 两类行为

| 情况 | 血量与位置 | 其他处理 |
| --- | --- | --- |
| 怪物伤害且存活 | 扣血，保留当前位置 | 短时怪物受击无敌，持续时间/时钟域可配置；击退尚未确定，默认不启用候选策略 |
| 环境伤害且存活 | 扣血，回当前挑战段安全起点 | SegmentRespawn清运动、反冲、持续慢时与旧输入/请求；安全出生验证/短保护 |
| 任意已接受伤害后current=0 | 结束run，返回家园 | 优先于环境回退/Boss胜利/未提交奖励；取消run token与回调，不回段起点 |

DamagePolicy选择响应，SegmentRespawn通过唯一Motor提供安全定位/清运动入口，不直接改PlayerController.position、不在同tick第二次move_and_slide。玩家运动完成后统一结算碰撞伤害，再决定回退/终局，UI只消费DamageResult。

## 帧事务与暂定边界（D028）

以下是可替换策略候选，不是用户已确认的平衡：

- 怪物受击无敌仅挡MONSTER，不能免疫ENVIRONMENT；环境回退出生保护单独计时，短时挡两类来源。持续时间须正且可配置；候选使用游戏物理时钟，受全场慢时影响，不使用渲染帧数。
- 每目标每物理tick最多接受一次伤害。先过滤旧事件/阵营/保护/重复，再暂定环境优先，同类取最高amount，再稳定source_id、event_id升序打破平局。未选伤害不跨帧积压；策略可调整，但同批顺序不得影响结果。
- 持续接触以exposure_id和可配置contact_interval防重；离开再进入产生新暴露。发动一次近战/一颗弹体用固定attack_id不能多碰撞形状重复伤害；环境回退递增actor_epoch，旧暴露/异步命中拒绝。
- 对所有目标冻结帧开始资格并收集请求，统一提交各Health结果，再判玩家零血，再判Boss胜利，再提交奖励/购买/转场；不能因Boss先回调死亡而吞掉本tick已有合法攻击。
- 非致命环境回退恢复可用跳跃/射击到配置上限（安全出生接地），保留已消耗精力和射击冷却；只清持续效果/运动/动作缓冲，不靠现有Controller.reset_at的全资源重置实现。
- 回退保留敌人生命与AI状态、敌弹、机关clock/相位、补给消耗、商店库存、钱包、已领/未领奖励与BuildState。销毁旧actor_epoch的玩家弹体并拒绝旧玩家目标回调；敌弹仍属当前stage，新接触受出生保护检验。世界不整场景reset。

零血后的RunDirector.end_run是一次性事务，取消RunLifetime、失效全部run/stage/actor请求，停止攻击/慢时/输入并撤销局内临时构筑，再进入HOME。返回家园不是恢复满血原场景；新局才按Character/Meta基础配置建立新Actor与资源。

## 四种出生/存储概念

SegmentAnchor={segment_id,stage_id,stable_spawn_id,safe_transform,safety_version}：同小关内可有多个，仅玩家存活且通过安全验证后激活。StageEntry：进入小关的初始安全点。HomeEntry：运行终态进入家园。PersistentSavePoint：可选保存交互，调用SaveService，不当作段回退锚点。

安全出生必须校验人物完整碰撞体、可站立地面、危险运动包络与必要保护，不能靠无敌掩盖出生在熔岩。暂定当前anchor不可用时按已验证先前anchor→StageEntry有界回退，仍不可用则报告地图错误/安全停止，不死循环扣血或送到出口。具体保护时长和击退待决策，不锁数值。

## reset范围与防刷

| 操作 | epoch变化 | 重置范围 |
| --- | --- | --- |
| SegmentRespawn | 仅actor_epoch | 人物位置/运动/输入/玩家旧弹体；按上文资源策略，保留整关账本与世界状态 |
| StageTransition | stage_epoch及actor_epoch | 卸载旧关对象/回调，保留RunState/BuildState/钱包与run奖励账本 |
| RunEnd | run_epoch失效 | 取消所有本局回调/未结算奖励与交易；清局内临时状态，保留Meta |
| NewRun | 新run_id与各epoch | 新局基础配置与空账本；永久进度由RunPolicy注入，不恢复上一局地图 |
| LegacyTestRestart | 仅明确测试配置 | 允许旧全场景reset/相位归零；不能用于正式回退或真实死亡 |

同帧Boss与玩家死亡暂定玩家失败优先、无金奖励/无下一大关，不由回调顺序决定（D029）。这些候选在HEALTH/DAMAGE/SEGMENT任务按反序事件注入测试；新验收通过前旧即死断言只证明历史测试模式。
