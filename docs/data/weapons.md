# 武器与技能

同一时刻使用一种武器家族及其当前分支。Lv.3 保持该分支的普通攻击，增加独立技能；正式授予与动作练习的自由选择分开。射击、空中瞄准慢时和共鸣分别遵守 [资源合同](../bible/combat_and_recharge.md)。

## 攻击与移动

| 武器／分支 | 玩家感知的行为 |
| --- | --- |
| 普通枪 → 三连机关枪 | 单发或一包三连，攻击包按当前规则结算反冲与弹药；连续命中和空发运动清楚 |
| 恒流激光枪 | 持续输入发出受墙体截止的真实射线；起始停顿后有限推进，松开、耗尽或取消结束，重新释放后才能再次起动 |
| 影步 → 散华手里剑 | 出刃后反向瞬闪；散华第二段延迟后采用新的瞄准方向，身体受碰撞约束 |
| 遥控回旋刃 | 单一飞刃向外飞行、可控方向并有限返航；情境操作沿当时直线召回，墙体能阻挡，真实接刃才产生第二段位移 |
| 反冲炸弹 → 磁吸遥爆雷 | 基础炸弹在接受释放时近身即时爆发；地面磁雷可投放、附着和遥爆，空中按近身爆发规则；距离和遮挡影响借爆 |
| 坍缩奇点 | 在角色当前位置形成有限牵引与固定，轻目标靠近接触停止环，再按选择方向弹射；不能穿墙或无限悬停 |

### 三级主动技能

下列技能已有动作实现，可在动作练习中选择；正式演进授予和全分支平衡仍按 [当前状态](../project/current_state.md) 判断。三级普通攻击沿对应二级分支，技能独立消耗共鸣并有冷却，技能伤害不自充共鸣。

| 分支／技能 | 玩家感知的行为 | 数值配置 |
| --- | --- | --- |
| 三连机关枪／弹幕风暴 | 蓄力后连续发出多轮扇状弹幕，发射过程伴随反向推进，需规划持续出手后的落点 | [machine_storm](../../resources/weapons/machine_storm.tres) |
| 恒流激光枪／日晷贯穿炮 | 蓄力后瞬间发出贯穿敌人的炮击并反向爆发位移；实体墙仍截止，区别于持续激光普攻 | [laser_cannon](../../resources/weapons/laser_cannon.tres) |
| 散华手里剑／千刃绽放 | 向更宽扇面出刃并完成强化反向瞬闪，不追加普通散华的延迟二闪 | [blade_bloom](../../resources/weapons/blade_bloom.tres) |
| 遥控回旋刃／噬月回刃 | 保留控刃、受阻与真实接刃，主动召回接住时产生强化第二段位移；未接住不凭空位移 | [moon_boomerang](../../resources/weapons/moon_boomerang.tres) |
| 磁吸遥爆雷／磁暴猎杀雷 | 投出可附着的强化磁雷，可遥爆并在合法邻近目标间连锁；借爆仍受距离和遮挡限制 | [magnetic_storm](../../resources/weapons/magnetic_storm.tres) |
| 坍缩奇点／吞星坍缩 | 在当前位置保持有限固定与扩大牵引，结束爆发并沿选择方向弹射；不能无限延长固定 | [star_collapse](../../resources/weapons/star_collapse.tres) |

基础与二级数值分别见 [普通枪](../../resources/weapons/pulse_gun.tres)、[影步](../../resources/weapons/shadow_shuriken.tres)、[反冲炸弹](../../resources/weapons/recoil_bomb.tres)、[三连](../../resources/weapons/triple_machine_gun.tres)、[激光](../../resources/weapons/sustained_laser.tres)、[散华](../../resources/weapons/fan_shuriken.tres)、[回旋刃](../../resources/weapons/remote_boomerang.tres)、[磁雷](../../resources/weapons/magnetic_mine.tres)、[奇点](../../resources/weapons/collapse_singularity.tres)。

## 手感与输入

瞬闪清除旧惯性并完成身体碰撞裁剪，落点有可读停顿；散华二闪重新采样方向。激光普攻的有限推进与三级瞬间炮击分开，结束不残留突兀下降速度。回旋自动接刃与主动召回的位移收益不同，控刃慢时仍受共享 AirFocus 约束。

键鼠、手柄和触屏提交一致动作，具体映射唯一见 [输入合同](../bible/controls_contract.md)。技能复用主瞄准，触发与射击释放不附送另一攻击；取消、失焦、切装、暂停和死亡清理未完成动作及旧实体。

## 表现与数值

预告、出手、弹体、真实命中、回收和爆发保持同一身体与武器身份，声音和运动时序对应实际结果。贴墙出手不能越墙生成实体，爆炸范围、激光截止和牵引停止可读。

数值唯一在 `resources/weapons/` 及实际武器／运动 Definition 中维护，位移、时长、伤害、射程和共鸣成本不在多页重复设默认值。实现、练习入口和检查见 [模块导航](../project/module_map.md)。
