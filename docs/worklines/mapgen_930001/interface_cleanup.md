# 固定地图接入后的接口收敛建议

用户问“是不是现在很多套接口，全乱了？是否需要先重构？”这是实际调用链审计与下一步范围建议，尚未执行重构，不把本轮97/0与网页发布冒称架构已收敛。

当前运行玩家、FrameDamagePolicy、RunWallet、DemoLifetime由主DemoApp创建，fixed_map.bind_existing注入相同引用，模块没有再造玩家或跨门补资源；真正结算由主Director负责。多的是兼容入口和奖励包装器，而不是多套玩家物理。

实际链：DemoApp.start_fixed_plains→start_demo→_load_delivery_stage→fixed_map.bind_existing→materialized_registry.instantiate_materialized→11个宿主薄adapter继承交付各版native loader。registry根据get_method_list与callv选择6/8参bind_player，这一外部兼容差异应收在明确边界中。

原包的original_pickups_v4与original_region_chests_v5内部创建停用_ready/process/physics的DemoApp子类、占位Stage和IN_STAGE的Director，后者还建空BuildState，以借用DemoApp私有领奖函数。玩家/钱包/lifetime虽共享，输入、模态和记录责任却交叉：registry需关闭辅助App输入，fixed_map需钻helper.app.reward_modal检查暂停，领奖记录写各自offline-module-* Manifest。registry还直接访问policy._targets/_queue/_seen及reward._claimed/_receipts。这里存在真实维护债务。

建议先做边界重构，再扩seed或游戏内生成；不开展全游戏推倒重写：

1. 优先把DemoApp的拾取和宝箱守卫、收据与提交逻辑抽为明确事务服务。原App函数先委托服务保语义，再让宿主适配层替代辅助App壳，奖励事件写入真实当局记录。原ZIP不改。
2. 拆分独立诊断宿主与地图Stage；由主App或诊断bootstrap拥有RunContext，地图仅借用有类型的服务。11个兼容adapter统一显式绑定入口，消除registry运行时数参数反射。固定图与原生成区域都实现同一实际关卡契约。
3. 为实例释放、受支持奖励快照/恢复增加受校验的公开API，清除registry对内部字典的写入；保同钱包/同lifetime/同instance限制，复杂敌人模块继续拒绝未支持的重建。

每步用当前97项真实主流程、原845项地图套件与受影响原回归守门；不删失败或降低目标。保持玩家物理、伤害优先级、实例幂等、原怪物/奖励及交付SHA。先迁移现有两个真实消费者，不先造万能框架。

M24是独立交付几何缺口：PortC封口[256,0,128,32]覆盖奖励唯一支撑[288,32,64,16]，领取region[300,-10,80,56]内无完整真实身体站点。整理API不能解决，需上游明确修订后的新交付版本重新核SHA与物理；不能移动现ZIP奖励、开封口或调玩家参数签绿。
