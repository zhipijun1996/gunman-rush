# ITEM-V5-01：72 件有效道具消费者与行为覆盖矩阵

盘点日期：2026-10-27。工作线与规则来源见 [scope](scope.md)、[有效道具配置](../../../config/items_v5.json)及[联动配置](../../../config/item_v5_synergies.json)。本文件是**当前源码的覆盖盘点，不是 72 件行为完成证明**。本矩阵按实际消费者区分数据、查询、局部行为与正式输入；执行由root统一调度。冻结运行源为979dbb9a，最终选定检查与媒体以本轮证据为准；下列历史开发阶段均保原身份。

配置事实为 **72 有效／21 删除／16 可 Lv1→2→3**。删除原件保留，但不进入新正式池。16 件成长道具为：B03、B04、B06、B11、B18、B21、B22、B26、B29、B33、P03、P08、P17、P29、P31、N01。另有 **16 组历史联动记录，9 组 enabled、3 组待重设计、4 组因删除道具失效**；enabled 不等于实战验收通过。

## 证据层级与缩写

| 缩写 | 实际文件与范围 | 不能据此声明 |
| --- | --- | --- |
| C | [combat runner](../../../tests/item_v5_combat_runner.gd)：`ItemCombatEffects`，真实局部 Damageable/LOS；Host、已接受命中事件、路径通知由 fixture 提供 | 正式输入／伤害策略／自然操作链全部通过。返回倍率的查询断言尤其不是弹体行为断言 |
| I | [inventory runner](../../../tests/item_v5_inventory_runner.gd)：真实 PlayerController、RunInventory、EquipmentService、BuildState；局部初始化与装备会话 | 自然获得、正式关卡或所有成长道具实际三等级效果均通过 |
| D | [defense/time runner](../../../tests/item_v5_defense_time_runner.gd)：真实 ItemRuntime、FrameDamagePolicy、HP/时间域及局部物理对象；伤害请求、资源和场景为初始化 fixture | 正式 DemoApp 场景、自然机关／Boss 操作或 GL 视觉通过 |
| A | [actives runner](../../../tests/item_v5_actives_runner.gd)：主动／召唤模块、真实局部空间查询与 Damageable；Host、能量、标记与成长事件是 fixture | 正式装备准入、原输入／成功回执接线或自然供能链全部通过；例如 Host 的 `skill_cost()` 不是 P02 真实实现 |
| E | [economy runner](../../../tests/item_v5_economy_runner.gd)：真实拥有状态、钱包、装备与 ShopService；击杀／钩索事件、位置及收入为 fixture | 正式敌人死亡／钩索回执自然触发、磁吸动画或商店 GL 通过 |
| K | [core-effects runner](../../../tests/item_v5_core_effects_runner.gd)：真实 Runtime／装备／Motor／资源；B18使用实际Damageable提交后的初始化成功回执envelope，钩索走真实Router/Traversal | B18 envelope不能冒充真实主攻弹体路线；局部真实Motor／钩索不是正式地图自然探索 |
| SE | [synergy-economy runner](../../../tests/item_v5_synergy_economy_runner.gd)：真实Runtime／wallet／spend信号，明确的致死、入账冲突、资源和时间步进fixture | 已真实触发的cue不等于已看GL表现；初始化击杀不是自然战斗清图 |
| F | [formal runner](../../../tests/item_v5_formal_runner.gd)：真实 DemoApp、正式平原两图、原奖励／暂停／商店与 Router→Controller→弹体→Damageable→FrameDamagePolicy→成功回执 | 自然路线、无初始化资源、全部 72 件已在 App 装备验证、GL／实体设备通过 |
| R | [independent review runner](../../../tests/item_v5_review_runner.gd)：真实 Runtime／策略、派生来源撤销、G14/S13、排序与致死优先反例 | 把手工 `runtime.deal()` 当成某道具自身触发已验证；当前新增反例须以它自己的执行日志为准 |
| U | [UI/input runner](../../../tests/item_v5_ui_input_runner.gd)：全部定义／等级的可读文案、原生适配器与 Control 回调守卫 | 文案正确就是该道具数值行为通过；合成键鼠／手柄／触屏输入不等于实体设备验收 |
| M | [连续影片源](../../../tests/item_v5_movie.gd)、[采集器](../../../tools/capture_item_v5.py)：正式标题／Home／出发／宝箱／装备／P24+G15+P14 的计划采集路径 | K2/dbf3a154已实际采集93/0并抽帧独审，后继979源以本轮捕获收据为准；均含明确fixture，不是72件自然路线 |

F 已有历史原始记录 [development-04/formal.log](../../../build/item_v5/development-04/formal.log)：**190 assertions／0 failures，严格 clean exit**。其中初始化位置、训练平台／高 HP 靶、已知奖励、商店收入和 director 完成条件均明确为 fixture。它不是后续生产改动的自动 fresh 签字。原 [formal-02](../../../build/item_v5/development-03/formal-02.log) 的 190／7 失败与更早 parse 失败保留。

补测开发结果：K [core-effects-02.log](../../../build/item_v5/development-05/core-effects-02.log) **79／0**，SE [synergy-economy-02.log](../../../build/item_v5/development-05/synergy-economy-02.log) **68／0**，root 已实际执行、exit0、严格 clean。它们是 Development 结果，**不是 final 全源回归**。A新增生命周期／成长实伤／S12已实际原生执行：K2/dbf3a154的原Harness日志为102／0；不是仅有源码。当前979源最终状态见最终专项报告。

**保留真实失败：**[正式Boss时间域 runner](../../../tests/item_v5_boss_time_runner.gd)修前 [boss-time-before-04](../../../build/item_v5/boss-time-before-04/boss_time.log) 为 **189／35失败**，暴露停时移除碰撞／接触免疫问题；修复后K2/dbf3a154原Harness正式Boss时间域1178／0、防御178／0，原189／35和后续真实失败均保留。验证实际碰撞、接触伤害、时钟恢复与退出，软件GL／人机体验仍另验。

[catalog suite](../../../tests/item_v5_catalog_suite.gd)、[Python 导入／审计测试](../../../tests/test_item_v5_catalog.py)及 [pool suite](../../../tests/item_v5_pool_suite.gd) 对全部 72 件提供数据、参数、等级、删除项、冻结抽取及准入证据。下表**不会**把这些共同的数据检查充当每一行的行为正例。旧 core／15 武器／gear 回归若没有装备 V5，也不能替代对应道具行为。

## 正式公共接线

正式起局在 [DemoApp](../../../scripts/demo/demo_app.gd) 创建 ItemRuntime／ItemV5Pool／ItemV5ShopPresenter；实际 stage 完成后 `bind_world()`、`map_ready()`，并创建 [ItemEffectView](../../../scripts/items/v5/item_effect_view.gd)。只有已装备且未损坏的拥有实例进入 [ItemRuntime.sync()](../../../scripts/items/v5/item_runtime.gd) 缓存。

主攻与武器技能通过 [ShootAbility](../../../scripts/combat/shoot_ability.gd)、[PlayerProjectile](../../../scripts/combat/player_projectile.gd)或 [WeaponActionRuntime](../../../scripts/combat/weapon_action_runtime.gd)提交伤害；策略成功后 `item_hit_committed()`→[PlayerController.on_weapon_damage()](../../../scripts/player/player_controller.gd)→`ItemRuntime.on_hit()`。防御由 [FrameDamagePolicy](../../../scripts/damage/frame_damage_policy.gd) 的 `defend_request()`／`on_damage()`插点接入。道具主动用独立 `item_skill` 输入，召唤／连锁／DOT 等派生通过 Runtime 授权与原策略结算，不走主攻回能。

表中 `缺` 表示尚未找到所述**行为断言**，不表示配置无定义。`部分`明确指出已测与未测的边界。当前逐件均找到候选生产消费者。初扫发现的 S10“蓄成钟摆提示”缺口已补入cue／View分支并有SE回执，但GL观察仍未验。

## B 系列：29 件

| ID／名称／最高等级 | 实际 module → 正式 consumer／callback | 已有逐件行为断言 | 尚缺或证据边界 |
| --- | --- | --- | --- |
| B01 拾铃磁盘／1 | [Economy](../../../scripts/items/v5/item_economy_effects.gd) `can_magnet_pickup()` → DemoApp `_physics_process()`／`_commit_pickup()`原领取流程 | E.`magnet_policy`：半径、ready_at、coin/note/heart/energy、实墙 LOS、拒绝宝箱／商品／奖励对象、卸装撤销 | 没有正式 App 磁吸领取正例；S07 弧线组合与 GL 未验 |
| B03 薄暮枪管／3 | [Combat](../../../scripts/items/v5/item_combat_effects.gd) `modify_direct_damage()` → Projectile／WeaponActionRuntime | C.`multipliers`：Lv3 1.32 与技能排除；F.`primary`：真实主攻 Lv1 1.12、Lv2 1.22、卸装恢复；同实例成长／不增负荷 | Lv3 的正式输入链仍仅局部倍率查询；没有自然平衡认可 |
| B04 省力扳簧／3 | [BuildState](../../../scripts/builds/build_state.gd) `_modifiers_for()` → AirFocusAbility 的 tuning 消耗 | I.`broken_and_static_sources`：Lv1 .82、升级 Lv2 .72、卸装还原实际 tuning | Lv3、实际持续瞄准的总消耗与正式关卡组合未断言 |
| B05 疾鸣撞针／1 | Combat `weapon_cooldown_multiplier()` → ShootAbility `try_fire()`／`reserve_packet()` | C.`multipliers` 返回 .88 | 仅查询；未量实际发射间隔／冷却下限 |
| B06 回声小匣／3 | [Time](../../../scripts/items/v5/item_time_effects.gd) `on_hit()` → 成功回执、AirFocus stamina 原 grant 账本 | D.`air_refund_committed_pipeline`：真实局部主攻命中返时间能量、单次腾空 20 封顶、不延长 AirFocus 时长、换装不重置 | Lv2／3 数值与正式 App 空中操作未逐级验证 |
| B07 定脚支架／1 | BuildState 参数映射 → RecoilAbility／WeaponMotionDefinition 使用实际 `ground_recoil_multiplier` | I.`broken_and_static_sources`：实际 tuning ×.7、卸装恢复 | 实际地面位移／反冲距离对照未测 |
| B08 止滑钟靴／1 | BuildState 参数映射 → JumpAbility `advance()`／`try_jump()`读取 coyote_time | I 同段：coyote_time +.05、卸装恢复 | 真正离边宽限帧内／外跳跃反例未测 |
| B09 接地回路／1 | BuildState 参数映射 → AirFocusAbility 地面恢复 | I 同段：恢复 tuning ×1.25、卸装恢复 | 实际地面恢复总量／暂停条件未测 |
| B11 心室木匣／3 | BuildState `_commit()` → HealthState `set_max()` | I.`equipped_growth_and_rollback`：三等级 +1/+2/+3、不免费治疗、卸装、组合溢出原子回滚；I.`growth_and_receipts` 覆盖同实例／来源幂等／满级拒绝 | 正式自然领取／装备三等级未演练；U 等级展示只是显示证据 |
| B13 晨露护片／1 | [Defense](../../../scripts/items/v5/item_defense_effects.gd) `map_entered()`／`_commit_entry()` → 共享盾 | D.`barriers_and_map_receipts`：与 B32 入图合计 3、失焦延后、同图防刷、卸装清除；`guard_synergy_geometry` S09 | 正式 App 两图入图盾路径与 GL 未验 |
| B14 苦痛铃歌／1 | Defense `on_damage()` → Runtime `grant_energy()` | D.`breakage_and_one_bell`：真实 HP 伤害每次回能、第三次破损 S15 单铃、修复不重领铃 | 正式敌伤／致死边界的逐件自然组合未验 |
| B15 荆棘铜衣／1 | Defense `on_damage()` → Runtime `burst()` → 策略派生 HP | D.`retaliation_and_crystal_contacts`：真实HP受伤→B15自动派生、表内7秒CD、实际目标HP；另保策略授权／致死优先反例 | 真实局部场景与伤害初始化fixture；正式自然战斗／GL未验 |
| B16 裂纹钱袋／1 | Economy `on_kill()`／`_kill_bonus()`；Defense 破损计数；ShopService 维修 | E.`bonus_and_remainder`／`bonus_rollback`：实际钱包逐敌 8 次预算、换装不刷、冲突回滚 | 未测 B16 自身第三次伤害破损与其维修价格；正式击杀→额外收入、S07 表现未验 |
| B17 裂纹强击栓／1 | Combat `primary_damage_multiplier()`；Defense `on_damage()`破损撤销；ShopService 维修 | D.`breakage_and_one_bell`：第三次 HP 伤害破损、仍占负荷、修复不重发 S15 | **部分：缺主攻增伤数值及破损后实伤撤销**；维修交易价未逐件测 |
| B18 捕魂音叉／3 | PlayerController `on_weapon_damage()`读取额外gain→[CombatEnergyState.committed_hit()](../../../scripts/resources/state/combat_energy_state.gd)共享包上限 | K.`resonance_fork`：实际HP提交后回执，三等级每敌9/10/11、同包多敌仍12、同目标去重、技能/session/weapon epoch排除、卸装撤销 | 成功回执envelope为初始化fixture，未装备B18走完整真实弹体路线；GL未验 |
| B19 梦读铭片／1 | PlayerController `on_grapple_damage()`额外回能；Combat `on_hook_hit()`梦读标记；Companion S02 锁定 | C.`explicit_synergies`：独立梦读标记、4 世界秒、回执防刷新／卸装撤销；A.`_run` S02 单目标最多两机 | **部分：额外钩索共鸣没有数值断言**；钩索→正式标记→机体闭环没有 App 输入链 |
| B20 盗铃钩齿／1 | Runtime `on_hook_hit()` → Economy `on_hook()` → 原钱包 | E.`bonus_and_remainder`：每敌一次、每图 10 金封顶、重复／Boss 排除 | 接受钩索伤害回执的正式输入链未验 |
| B21 长索绕轮／3 | [TraversalAbility._effective_hook_range()](../../../scripts/player/traversal_ability.gd)→request_hook／guide | K.`long_hook`：真实Router/Traversal基线触不到，Lv1的1.15范围触到同一真实anchor、仅入包无效、卸装再触不到且核心权利保留 | Lv2/3实际钩距边界、正式地图路线未验 |
| B22 扩震钟环／3 | Combat `bomb_radius_multiplier()` → WeaponActionRuntime `explode()`／`damage_burst()` | C.`multipliers`：Lv3 返回 1.28 | 仅查询，缺真实炸弹范围边缘伤害／LOS；S14 仍禁用，不作用针雷的设计不能冒称已通过组合 |
| B23 尾摆齿环／1 | Combat `_end_recoil()`／`on_blink()` → ring 实际范围派生 | C.`recoil_and_cooldown`：.4D 端点环、CD／重复／卸装重装防刷 | 路径来自明确接受-Motor通知 fixture；未有正式实际移动输入证明 |
| B24 余火枪片／1 | Combat `on_hit()`建 DOT，`advance()`按世界时间派生 | C.`dots_cloud_and_unload`：3 世界秒总 .35D、零 delta 不结算、到期／卸装取消 | 事件是已接受命中 fixture；正式主攻→DOT、GL 未验 |
| B26 巨腹储鸣罐／3 | Runtime `sync()` → CombatEnergyState `set_capacity_bonus()` | F：实际暂停装备按当前 owned level 扩上限且不填能，正式 map2 保留 cap | 本轮只实际到一个拥有等级，三等级切换／卸装钳制极值未逐级验证 |
| B27 顽固护壳／1 | Defense `monster_iframe()` → FrameDamagePolicy `_monster_until` | D.`player_protection_real_clock`：真实伤害策略保护窗与活动时钟，K2防御178/0 | 局部时钟／请求fixture；正式自然场景与GL未验 |
| B28 逐风鞋簧／1 | PlayerController `physics_tick()`地面move_axis×倍率→唯一PlayerMotor.step() | K.`ground_shoes`：同输入实际地面速度与10 tick位移均×1.05、背包无效、空中不加、卸装恢复、重装不改基础tuning | 局部初始化位置／Controller tick，非正式自然路线／手感认可 |
| B29 薄钟长管／3 | Combat `projectile_range_multiplier()` → Projectile 寿命与 ShootAbility 发射 | C.`multipliers`：Lv3 返回 1.5 | 仅查询；未验证真实射程边缘／飞行中卸装撤销、Lv1/2 |
| B30 易裂心匣／1 | BuildState HP +3；Defense 第三次 HP 损伤破损；ShopService 修理 | I.`broken_and_static_sources` 破损最大 HP 撤销／仍占负荷；D 第三次伤害破损；E.`repairs` 原价 18、重放／余额不足／回滚、不免费治疗；F 近店修理授权 | F 的破损是显式状态 fixture，并未自然打裂；其他三件破损道具不自动继承 B30 各自价格验证 |
| B31 敲钟重锤／1 | Combat `enemy_stagger_multiplier()` → 弹体／武器 context → [EnemyActor](../../../scripts/enemies/enemy_actor.gd)受击硬直 | C.`multipliers`：返回 1.3 | 仅查询；缺真实 EnemyActor 硬直持续时间、Boss／普通敌人边界 |
| B32 晨蓝洪流／1 | Defense `map_entered()`／`_commit_entry()` → 共享盾 | D 与 B13 合计 3、同图防刷／卸装撤销 | 没有正式 App 新图自动授盾／GL |
| B33 小焰触片／3 | [Active](../../../scripts/items/v5/item_active_effects.gd) `preview()`／`activate()` → Runtime 授权 burst | A.`_run`：Lv3 1.9D、实际 LOS、无所有权／零方向／CD拒绝；F：Lv1 原生 R、30 自然共鸣消费、真实 1.10D、无附送普攻／状态跨图保留 | Lv2 未逐级测；F 为训练场 fixture，不是自然路线或手感认可 |

## P 系列：26 件

| ID／名称／最高等级 | 实际 module → 正式 consumer／callback | 已有逐件行为断言 | 尚缺或证据边界 |
| --- | --- | --- | --- |
| P02 共鸣整流器／1 | Runtime `skill_cost()`→武器／道具active原consume；不用于G04原价救命 | D证明G04仍扣65；SE.`idle_credit_once_per_map`真实B33付27／有信用付22，`ordinary_grants_and_floor`实际debit最低15、重放不重复、非主动不折扣 | 正式App多种武器／道具主动组合未验；A Host `skill_cost()`仍不是P02证据 |
| P03 术式增幅石／3 | Combat `modify_direct_damage(skill=true)` → WeaponActionRuntime／特殊弹体 | C.`multipliers`：真实 Lv3 武器定义时技能倍率 1.4，主攻独立 | 仅 handler 数值；真实 LV3技能命中链、Lv1/2 未测 |
| P04 悬空回响／1 | Combat `on_hit()`→`primary_packet_started()`→`modify_direct_damage()` | C.`next_shot_and_marks`：空中命中只强化下一包、强化包不自续、卸装撤销飞行中倍率 | 正式连续空中输入／1.5 秒窗口临界尚未覆盖 |
| P05 末息轮芯／1 | Combat `primary_damage_multiplier()`读取 HP 比例 | C.`multipliers`：满血无效、2/5 HP +35%、技能不套主攻加成 | 正式 App 实伤／阈值恰好相等边界未验；S05 仍待重设计 |
| P06 满月枪歌／1 | Time `world_scale()`／WorldFreezeScope，AirFocus消耗与腾空预算仍归原能力 | D局部ALWAYS/Timer/平台/RigidBody冻结与玩家可动；正式Boss时间域runner已真实构造反例 | 正式Boss修前189/35 FAIL保留；K2原Harness修后1178/0，实际floor/collider与冻结接触伤害及释放恢复通过。GL仍未验，M没有此组合承诺 |
| P08 穿响音叉／3 | Combat `extra_pierce()` → PlayerProjectile 扫掠／次目标预算 | C 查询 Lv3 .95D；F.`two_target_packet`：真实输入单弹两目标、Lv1 次目标 .65D、同包回能恰 12 | Lv2 .8D 与 Lv3 的实际扫掠命中未逐级测 |
| P09 弹震继电匣／1 | Combat `on_hit()`→ Runtime `burst()` → 策略派生 | R.`source_revocation_before_derived_commit` 用 P09 为手工 `deal()`来源，验证撤销／重装／武器 epoch；E 商品池包含此定义 | **缺：P09 本身命中爆炸触发、倍率、CD、范围／LOS**。来源生命周期通过不等于道具触发通过 |
| P10 腐蚀尾铃／1 | Runtime `on_skill_started()` → Combat 布置 primed 窗口，后继主攻一团 cloud | C.`dots_cloud_and_unload`：一次技能仅一云、3 秒总 .45D、表现 cue 一次 | 技能开始通知／命中为 fixture；实际主动→主攻→云与窗口边界未验 |
| P12 刃影回纹／1 | Combat `_observe_path()`／`_path_committed()`／`on_blink()` | C.`recoil_and_cooldown` 实际目标接触 .25D、重复／CD；`explicit_synergies` S06 后继包才可引爆 | 位移通知由 fixture 提供，未真实 Router→Motor 反冲路径验收 |
| P13 追索徽记／1 | Combat `on_hook_hit()`普通钩索标记→`modify_direct_damage()`；Companion `mark_key()` | C.`next_shot_and_marks`：标记回执、倍率 1.2、技能排除、过期、换图清除；A G08 标记 fixture | 真钩索物理回执→主弹的正式输入链未验；与 B19 梦读标记明确分离 |
| P14 游钟机群／1 | [Companion](../../../scripts/items/v5/item_companion_effects.gd) `sync()`三机→`advance()`／`_fire()`实际派生 | A：三机数量、世界停时不攻击、G08 标记首击、S02 独立目标锁；M/dbf3a154已采集真实正式配置路径（已知奖励和训练靶fixture） | A Host 手动标记／效果集合不等于正式准入；K2影片采样／实际收据已观察三机攻击；并非自然全路线 |
| P15 续鸣装配匣／1 | Runtime `combat_energy.spent`→`_energy_spent()`→Companion `on_energy_spent()` | K.`assembly_threshold_and_s01`：真实44+1 debit/spent信号召机、去重／不足／上限、.35D真HP、8世界秒到期、不自充／递归、卸装保部分进度；A新增生命周期源码补边界和节点释放 | K已开发79/0；A新增已在K2原Harness102/0执行；正式App自然供能／召唤链及GL未验 |
| P16 循时梦盾／1 | Defense `_advance_guard()`真实扫掠拦截 EnemyAttackProjectile／允许的 BossProjectile | D.`guard_synergy_geometry`：实际弹体拦截、12 秒／S09 .9CD、unblockable与不可见Boss攻击代理排除 | 正式 Boss 实战与 GL 读性／同帧多弹边界未验 |
| P17 游鸣聚能体／3 | Combat `charge_move_multiplier()`→PlayerController真实charge phase的move_axis | C.`multipliers`：仅Lv3查询.7；pool拒绝不存在蓄力技能的武器；K显式输出UNVERIFIED | **用户基础蓄力选择pending；无真实蓄力移动正例**。root已把未装备fallback从实际0修为1以保旧baseline；装备.4/.55/.7仍是表值候选，不是用户或实发验证 |
| P18 暮钟心契／1 | BuildState 首装原子 `set_max_preserving_ratio()`／持久锁，HealthState 禁疗唯一闸 | I.`covenant_atomic_lock` 全原子／容量失败／观察者禁疗／只转换一次／清局解除；D.`heart_covenant_and_healing` 针与入图治疗也被拒绝 | 正式 App 的选择风险／手感未验；它是唯一明确允许按比例改变当前 HP 的例外 |
| P20 残影晶刺／1 | Defense `on_damage()`→`_spawn_crystal()`→`advance()`真实 targets/LOS 派生 | D.`retaliation_and_crystal_contacts`：实际HP受伤生成原位晶刺、12秒CD、真实接触.60D、同敌一次和5世界秒到期；K2防御178/0 | 局部物理／伤害初始化fixture；正式自然地图和GL未验 |
| P23 奇点余振环／1 | Combat 查询 → WeaponActionRuntime singularity hold／blast damage | C.`multipliers`：hold +.12、倍率 1.1 | 仅查询；真实奇点吸引持续时间和爆炸实伤未测 |
| P24 回环飞轮／1 | Active `activate()`／`_step_flywheel()`真实往返扫掠 | A：往返两次接触／清理、与 G15 双向 .805D／侧、一个技能包／一次 35 消费；R 真 Runtime 双向方向；M/dbf3a154实际五次主攻命中供35共鸣、R输入和两侧实伤；训练目标fixture | 局部 A 的能量是 fixture；正式 App 输入／GL 以实际新影片回执另核 |
| P25 落地针雷／1 | Active `_ground_placement()`／`_step_trap()`真实地面探测与近敌引爆 | A：空中拒绝不扣能、真实 Motor 地面、最多两枚、第三枚拒绝、每枚 .9D 一次 | 真实移动支撑宿主／寿命到期与正式 App 交互未测；S14 禁用 |
| P26 回声护幕／1 | Defense `activate()`→`defend_request()`，Runtime 真实活动时钟 | D.`rescue_and_real_active_time`：一次 80 消费、3 活动秒无敌、慢世界不延长／菜单不计时、CD拒绝不重复消费 | 正式 Boss／环境例外实景和 GL 未验 |
| P27 随身修补针／1 | Defense `activate()`→Runtime `heal()`→HealthState 原治疗事务／每图次数 | D.`healing_and_barrier_success`：实际扣65治1、同图两次上限、卸装不刷、新图恢复预算；另保P18禁疗拒绝 | 初始化HP／共鸣fixture；正式地图主动输入和GL未验 |
| P29 雷丝引线／3 | Combat `on_hit()`／`_chain()` → Runtime 授权派生 | C.`chains_and_third_round`：Lv3 两个 .45D、实墙 LOS、同包去重／不递归；F：真实主攻→Lv1 .3D 第二目标，派生不额外回能 | Lv2 和不同类型主动的正式输入链未逐级验收 |
| P31 刻风膛室／3 | Combat 空中命中 pending→`_advance_recoil()` | C.`recoil_and_cooldown`：Lv3 .85D 与路径／端点独立、同收据去重、旧 session 拒绝 | 位移／通知是 fixture；Lv1/2、真实 Motor 反冲停止条件尚缺 |
| P33 恒辉折镜／1 | Combat 查询→WeaponActionRuntime `_wide_beam_damage()`，beam visuals 同倍率 | C.`multipliers`：返回 1.12 | 仅查询；缺真实扩宽边缘目标命中／窄侧拒绝和 GL 光束宽度对照 |
| P34 连奏梭轮／1 | Combat `on_hit()`检查 MACHINE／shot_index==3→burst | C.`chains_and_third_round`：第一发不触发、第三发 .30D 波一次 | burst 事件手工给出，缺正式真实 Machine 第三弹／取消连发组合 |
| P39 盗贼旧誓／1 | Economy `settle_kill_coins()` → DemoApp `_settle_enemy_drops()`冻结实际掉落 | E.`bonus_and_remainder`：四个一金币共 5、余数持久／重放冻结、不因 HP 伤害扣金 | 正式敌人死亡→原 drop→入账闭环未验 |

## G 系列：15 件

| ID／名称／最高等级 | 实际 module → 正式 consumer／callback | 已有逐件行为断言 | 尚缺或证据边界 |
| --- | --- | --- | --- |
| G01 微核回响／1 | Combat `_echo()`／`_detonate_echo()`，P12 `_path_committed()`可消费旧标记 | C.`next_shot_and_marks`：不同包引爆 .65D、同包重复忽略；`explicit_synergies` S06 原目标 CD、不无中生有／递归 | 真实输入后继包／反冲路径、GL 未验 |
| G02 无忧余音／1 | Defense `on_damage()`累计真正 HP hit→`grant_barrier()`共享上限 | D.`barriers_and_map_receipts`：盾吸收不计 HP hit、共享 cap／卸装盾 | D.`healing_and_barrier_success`已有三次真实HP伤害后产一盾、盾吸收不计、换图计数保留；正式自然战斗和GL仍未验 |
| G03 春归铃枝／1 | Defense 入图快照→`_commit_entry()`→Runtime heal | D：新图治疗 1、同图不重领、P18 禁疗、换装不刷 | 正式两图真实入图消费者未逐件演练 |
| G04 零时护心／1 | Defense `defend_request()`致死前原价 65 支付与残血 1 | D：原价扣65不享P02、一图一次、第二次致死、fall不救、死亡优先 | 正式 Boss 关键帧与玩家体验未验 |
| G05 永恒钟卫／1 | Companion `activate()`→真实付费large_drone→`_fire()` | 原A数量／限量；新增A.`companion_lifetimes_and_damage`：实扣50、1.8秒首击.60D真HP、18世界秒边界到期、节点释放／无幽灵攻击、再次必须付费 | 新增断言K2原Harness A102/0；局部Host不是正式Runtime输入链，GL未验 |
| G06 千鸣钟冠／1 | Combat `on_hit(primary)`／`_chain()` | C：独立目标数／.25D、实墙 LOS、主攻通道限制由代码接入 | 没有正式 App 原输入回执正例；S08 仍禁用，不宣称额外有效联动 |
| G07 王钟残辉／1 | Economy `advance()`真实活动时钟→Runtime grant，S10 `on_idle_recovery()` | E独立预算；SE：真实恢复达到5才蓄成、20上限／每图一次、暂停不涨、满能量不虚构恢复、原active消费信用并发cue | SE已开发68/0；正式App脱战时钟组合与蓄成提示GL未验 |
| G08 空白钟芯／1 | Companion `_target()`／`_fire()`→标记优先、实际提交后一次首击信用 | 原A的P14组合；新增A.`growth_damage_and_s12`：G19远处标记优先、首次桥拒绝不消费信用、首真HP命中×1.3、同标记重装不刷、新标记一次 | 新增S12断言K2原Harness A102/0；标记仍为初始化身份，非正式钩索回执链 |
| G10 不朽钱袋／1 | Economy `_kill_bonus()`唯一每图敌人账本，与B16装备互斥 | E：新图六次每次 2 金、不重领、失活拒绝、背包共存而装备互斥 | 正式击杀原回执／稳定掉落展示未验 |
| G11 不朽心匣／1 | BuildState通用`max_hp_add`映射→HealthState；与B30装备互斥 | K.`immortal_health`：G11仅入包无效、装备+3不补HP、卸装撤销／实际current钳制、重装不找回损失HP／不叠加 | G11/B30互斥的逐件正反例、正式App自然配置未验 |
| G12 错位命运骰／1 | [ShopService](../../../scripts/shops/shop_service.gd)冻结概率／刷新账本；正式 Presenter 读取 Runtime effect | E.`rerolls`：真实权重转移、负蓝概率拒绝、首免费／次收费、同收据／旧报价、失败不改库存或RNG、卸装不得伪造免费 | F 实际 8 金刷新没有装备 G12；近店 UI 下的 G12 组合尚未正式验证 |
| G14 飞雷钟樽／1 | Active `_step_throw()`／`_explode_throw()`→Runtime 原 G14 origin 的命中与传导 | A：1.3D直击＋.35D传导、墙阻挡／不回能；R.`g14_real_runtime_chain`：实际Runtime／policy两额外目标 .35D，补原Host掩盖的来源授权问题 | 正式 App R 输入与 GL 未验；仅 THROW 模式，不能声称部署模式 |
| G15 双响投架／1 | Active `activate()`分裂P24/G14，一次消费／总预算；P24第二方向取负向 | A：真实两侧往返总 1.4D×1.15、共一包／单扣35；R.`s13_opposite_trajectories`；M/dbf3a154已实际采集 | G14分裂预算/方向独立反例尚缺；不是全类型主动都复制 |
| G16 钟匠裁决／1 | Active `_step_pulses()`锥形筛选／LOS → 三段真实派生 | A：3×.9D、一次65、不搬角色、不被G15复制 | 锥体边角／遮挡更多反例、正式 App 与 GL 未验 |
| G19 灰铃侍钟机／1 | Companion `on_kill()`精英账本→`evolution`；`_fire()`按成长提高实际伤害 | 原A成长次数／持久状态；新增A.`growth_damage_and_s12`：真HP损伤.30D→.36D→.42D、非精英／旧图／重复排除、S12首真命中5.46@D10 | 新增断言K2原Harness A102/0。`boss_counts_as_elite=true`仍为候选，非用户确认；装备Lv仍1，机体成长不是道具Lv3 |

## N 系列：2 件

| ID／名称／最高等级 | 实际 module → 正式 consumer／callback | 已有逐件行为断言 | 尚缺或证据边界 |
| --- | --- | --- | --- |
| N01 迟暮钟摆／3 | Time `world_scale()`→AirFocus world_scale_resolver，与P06全血停时优先级 | D.`world_time_scope`：真实 Engine.time_scale Lv1 .12、原库存成长至Lv2 .10、P06优先／pause恢复 | 正式Boss runner已测N01三等级真实时间比例、B04消耗及原2秒腾空预算；森林实景和GL未验 |
| N02 余鸣护甲／1 | Defense `activate()`→`grant_barrier()`，共享盾／每图使用账本 | D.`healing_and_barrier_success`：实际付费授盾、满盾拒绝、共享上限和换装／地图账本；K2防御178/0 | 初始化资源fixture；正式地图主动输入和GL未验 |

最终专项状态：冻结运行源的选定 30 项原 Harness 全部 fresh 通过（0 复用、0 失败）；这是受影响专项，不是 full161 或远端 CI 全通过。 影片状态：同运行源连续主游戏影片 93 断言／0 失败，实际退出0且源码稳定；准确时长与媒体参数见捕获收据。

## 16 件成长的额外边界

共享库存收据／满级排池已用B11检验，正式App同实例成长用B03检验；这只能证明共享事务路径。当前逐件的**实际等级输出**覆盖为：B11三等级；B03正式1/2与局部3；B04实际tuning1/2；B06局部真实命中1；B22/B29/P03/P17/P31局部查询或事件3；P08/P29正式1与局部3；B33正式1与局部3；N01局部1/2；B26正式当前一等级；K补B18三等级HP提交后回执与B21真实钩索Lv1。配置三等级可解析不能补齐其余等级缺口；P17仍待用户规则确认。

## 9 组有效联动逐组盘点

| 联动／所需道具 | 实际消费者 | 已有组合行为断言 | 当前缺口 |
| --- | --- | --- | --- |
| S01 B18+P15 | 主攻成功回能→CombatEnergyState原spend信号→Runtime `_energy_spent()`→Companion `on_energy_spent()` | K.`assembly_threshold_and_s01`：B18真实HP提交后回执赚能→44+1实际debit→一机、数量／余额不足／重放／到期／不递归、部分进度跨卸装 | K开发79/0；接受命中envelope是fixture，非自然弹体战斗／正式App路线 |
| S02 P14+B19 | Combat梦读标记；Companion `_assign_patrol_locks()`／`_locked_target()`独立锁 | C梦读标记生命周期；A最多每目标两机、第三机独立空闲／另找目标、到期与卸装释放 | 两组局部fixture分离，缺真实钩索回执→正式机体锁定；GL未验 |
| S06 P12+G01 | Combat `_path_committed()`→`_detonate_echo()` | C.`explicit_synergies`：原包不引爆、冷却内不引爆、下一包实际接触消费 .65D、共享6秒CD、不递归、不凭空合成标记 | 接受位移通知fixture，非真实Router/Motor路线 |
| S07 B16+B01 | Economy已入账后`cue(coin,magnet_bonus=true)`→ItemEffectView `_coin()`弧线 | SE.`shared_coin_budget`：真实wallet一笔／一次cue、八金唯一预算、重复尸体／旧收据／冲突回滚、卸装B01取消flag但不换账本、换图新预算 | SE开发68/0；**弧线GL观察仍缺**。视觉返回不能再次算金币收入 |
| S09 P16+B13 | Defense `_advance_guard()`仅扩大glyph外观，拦截CD×.9 | D.`guard_synergy_geometry`：真弹拦截CD10.8、外观scale>1而碰撞radius仍12／盾数量仍1，卸掉B13回12秒 | 正式Boss实景／GL读性未验 |
| S10 G07+P02 | Economy恢复→Runtime蓄成／抵扣／消费；新增`skill_credit_ready`→ItemEffectView钟摆提示 | SE.`idle_credit_once_per_map`：第五点实际恢复才蓄成与cue一次、实际B33支付22、失败不消费、最低15、每图一次／20预算、换装与新图防刷；普通grant不造信用 | SE开发68/0；**新增钟摆提示真实GL尚未验**，cue回执不代签图像 |
| S12 G19+G08 | Companion标记优先；`_fire()`成长倍率／G08提交后首击信用 | 新增A.`growth_damage_and_s12`直接组合：成长后远标记优先、桥拒绝无HP／不耗信用、首提交放大、旧标记不刷、新标记一次 | 新增断言K2原Harness A102/0；精英／标记身份初始化、Host提交，非正式App／自然钩索闭环；Boss算精英仍候选 |
| S13 P24+G15 | Active 两相反方向飞轮、同cast／单扣／分摊1.15预算 | A四接触总1.61D、每侧.805D；R真Runtime方向dot反向；M/dbf3a154原生R与五次主攻自然供能已有实际轨迹／MP4 | 正式App/GL以真实采集回执另核，不用M源码代签 |
| S15 B17+B14 | Defense `on_damage()`首次第三伤破碎→持久 first_break 账本与单次铃 cue | D.`breakage_and_one_bell`：同局仅一次铃，修好再裂不再发；B14保持正常受伤回能 | 当前没有表外额外共鸣数值；不能发明额外奖励。正式破碎反馈GL／玩家认可未验 |

禁用的 S03/S04/S11/S16 涉及删除道具；S05/S08/S14 待重设计。它们不属于本轮“9有效”行为通过数，也不能因为组合基础效果各自存在就重启旧配方。

## 已向 root 报告的补测／消费者缺口

1. **初扫缺口已有开发补测结果**：K的B28、B18三等级／12封顶、B21 Lv1钩距、G11、S01为79/0；SE的P02、S07与S10为68/0。仍需冻结全源final回归，不能回写初始缺口为“此前已经覆盖”。
2. **防御补测已有实际历史结果**：B15、P20、B27、P27、N02等已在K2防御178/0实际执行；P06正式Boss原189/35失败保留，修后1178/0。当前冻结源结果另见最终报告，不反签旧失败。
3. **追加断言已有实际历史结果**：A新增G05/P15攻击倍率／世界寿命边界／节点释放、G19成长真HP、S12直接组合；局部Host限制保留。B17主攻增伤撤销、B19额外钩索共鸣以及P09自身命中爆炸仍需对应逐件断言；G02的真实HP计数产盾已补防御断言。B16独立破损／修理价不能继承B30。
4. **表现缺口修复与未验分开**：S10现有实际`skill_credit_ready` cue／View消费分支，SE已经测cue；S07现有真实弧线consumer且SE测唯一入账／flag。两者实际GL看图均未验。
5. **广泛仍仅局部查询的接线**：B05/B22/B29/B31/P03/P23/P33/P17等已有正式消费者，但当前测试只返回倍率／时长参数，没有逐件实发冷却、范围、硬直或激光边界测量。不能将全武器基础回归替代带该道具的实际行为。

所有 72 件的键鼠／实体手柄／触屏设备、玩家手感／平衡与趣味认可均为 **unverified**。GL可读性、画面遮挡、连续VFX与音轨也须依实际同源MP4／截图／独审另列；本盘点没有自然通关或商业完成声明。
