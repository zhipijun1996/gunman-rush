# 独立世界组件与重置边界

对象为独立Godot场景+定义Resource+局部状态，只依赖StageContext（现有WorldContext渐进演进）的明确服务；不通过绝对NodePath找玩家/HUD/具体房间。固定与随机摆放共用对象。

| 对象 | 职责与扩展 |
| --- | --- |
| 锯轮/尖刺/熔岩 | Visual/Motion/HazardContact；提交ENVIRONMENT DamageRequest，不直接决定die/回退 |
| 机关 | Trigger/Mechanism/Motion；周期/开关/压力板/门/移动平台，保留局部clock/相位 |
| 怪物 | Actor/AI/Motor/Health/Attack；统一伤害契约，AI与玩家输入无关 |
| 补给 | Trigger/RewardEffect/ConsumptionPolicy；独立射击补充/回血等，不把两类血量效果合并 |
| SegmentAnchor | 段安全起点与激活验证，不全关reset、不保存永久档 |
| StageEntry / Exit | 初始安全点；ExitOffer显示类型并向RunDirector提交唯一转场选择 |
| RewardChoice / Shop | 引用RewardService/ShopService与稳定账本；重复点击/回退不重刷 |
| BossArena | 核心/兼容外围布局及战斗边界，战斗结果不写PlayerController |
| HomeEntry / SavePoint | 终局进入家园；保存交互只调用SaveService，不当作段检查点 |

StageContext按实际需要注入RunToken/StageToken、clock、actor registry、damage/reward/shop/segment服务及可选save adapter。对象stable_id+definition_version提供activate/deactivate及明确范围reset(policy)；序列化时再实现capture/restore，卸载取消计时/订阅/拥有的攻击。

SegmentRespawn仅变actor_epoch/玩家运动输入，保留敌人生命/状态、机关相位、补给消耗、库存与领取账本；StageTransition卸载旧关对象而保留RunState；RunEnd取消所有本局事件、返回家园。不能把旧WorldContext.respawn的clock=0+reset全部对象当公共回退API。旧SafeCheckpoint场景可作为SegmentAnchor安全验证的迁移起点，旧即时死亡与全局reset只留显式Legacy测试。

补给默认每stage实例一次成功消费，满资源不消费；是否刷新是独立ConsumptionPolicy，不随段回退刷新。新局/新小关按所属scope建立对象，而不是“每次生命”复活；奖励/交易去重作用域见rewards_and_builds。机关对象同帧多形状接触不重复扣血。

连接采用导出对象引用或稳定ID+类型化局部信号；复制两实例运行状态独立，跨两图复用不改玩家代码，卸载/回退后旧事件拒绝，安全出生与不会刷奖励分别验收。

动态样片遵循[模块批次契约](platforming_modules.md)：局部clock/初始相位定义，ENVIRONMENT扫掠接触消费FrameDamagePolicy，包络验证所有出生点；单AnimatableBody平台携带只由Motor的Godot碰撞路径发生。模块静态危险与动态包络分别提供，动态包络仅安全验证，不能整个包络都变成持续伤害区域。
