# 全怪物程序结构 · ENEMY-STRUCTURE-01

本文件说明本轮实现边界；运行和审查结果以同目录证据索引为准。品质拒绝未撤回，本文不是新的美术验收机制。

## 从配置到真实实例

普通怪物使用 `EnemyBehaviorRegistry` 的有限登记，集中行为、Definition与场景路径及验证family。`EnemyFactory` 返回未加入场景的Motor及独立Definition；位置、Manifest、场地规则继续由Stage拥有。实验候选走显式Lab/Studio配方，不靠分散覆写猜测最终数值。基础校验和森林专有参数校验分工，未知行为不再静默生成通用攻击器。

普通攻击的共享状态机保留冷却、epoch、目标合法性、保护区、并发、状态提交及弹体所有权。冲锋、俯冲、跳扑、炮哨与扇射分别提供运动／角度策略，不再把这些运动公式放进一个行为ID分支。森林各专有机制继续拥有其独立状态与物理对象。

Boss使用 `BossFactory` 的8场景／9配置有限配对，保原资源共享及调用者在parent前配置的顺序。生成Manifest的场景路径／契约不变；未知配对不能回退到另一Boss。激活、场地、目标、弱点、奖励和恢复仍由具体Encounter及App拥有。

## 表现只能观察机制

`EnemyActor.presentation_state()` 提供隔离的只读状态；Boss家族通过 `presentation_state()` 生成 `BossPresentationState`，由实际owner解释自己的递增／递减时钟及并行phase轴。表现动作helper消费这些语义；不为动作伪造AI状态，也不让draw推进AI。

铃、锁定点、可用平台、织网位置等由窄查询返回展示值。展示查询不交出可写机制节点；碰撞／弱点判定仍由原对象负责。普通和Boss保留各自协调器与状态轴，不能为统一破坏双目标与网络机制。

## 最终身体与生命周期

`EnemyPresentationBinding` 记录实际实例、最终renderer、profile、身体key与主题。scene／pixel／underworld／forest／prototype有明确来源。`aerial`继续描述运动；现有俯冲／扇射飞行身体由显式行为映射选择。森林fine身体只在实际Bible安装时启用 `forest_bible` 主题，Lab默认几何继续保留；不会因祖先metadata移动而换身体。

换装统一经过 `replace()`，同profile幂等；重复Pixel安装不能降级已经安装的Underworld。旧host从树中移除时解绑其信号与自持表现资源。

普通表现共用 `EnemyPresentationLifecycle`：bind、实际epoch初始化同步、暂停守门、一次推进、自持资源清理及幂等dispose。专有H/D样本与公共HitTemplate各有明确clock owner；原身体、弱点和死亡政策保留。完整App恢复位置／方向／行为之后调用 `synchronize_presentation()`，同epoch同步不会伪造受伤或死亡事件。

Stage通过 `presentation_remains()` 能力取得舞台持有的尸体，不再列举UnderworldEnemy／EnemyPresentation具体类型。只有原有留尸怪提供该能力；其他暗体／隐藏／Boss退出不被强制改成留尸。

## 后续维护

新增普通物种先登记Definition、scene、behavior family与创建者；基础攻击若有不同运动则提供局部策略，专有森林机制保自己的Behavior。实际renderer登记绑定并接入生命周期，安装者明确theme。新增Boss为实际Encounter提供状态快照及确需的窄几何查询，再登记合法场景／配置配对。不要新增一套资产来源表，也不要为满足接口发明不存在的恢复态或弱点。

每次变更核对正式创建消费者、最终body分支、暂停／终态／恢复与卸载；运行结构测试和对应原回归。素材补帧、动作设计、视听品质及用户验收另按后续共同确定的生产流程处理。
