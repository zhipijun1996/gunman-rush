# 可增减人物能力

## 组件与数据

PlayerController 只协调能力，不硬编码“只能二段跳”。AbilitySet 保存启用的能力 ID；JumpAbility、ShootAbility、RecoilAbility 分别处理动作规则，Motor 独占位移。禁用射击不自动禁用跳跃；无反冲武器是否允许由 WeaponDefinition 指定。
AbilityDefinition（Resource）保存 id、version、enabled、action_type、优先级及参数；运行时实例持有冷却与消耗状态，定义资源不得保存玩家当前状态。AbilityContext 提供只读角色状态、资源服务和动作请求入口，不引用具体关卡或 UI。

接口契约：can_execute(context,request) 返回允许/原因；execute 只提交事务化动作效果，不自行移动节点；on_landed/reset/dispose 清理运行状态。冲突由 Controller 的确定顺序处理，不依赖子节点遍历顺序。MVP 只实现跳跃/射击/反冲所需接口，不提前做万能技能编辑器。

## 次数与配置

max_jumps 可取 0/1/2/3/N；0 禁用跳跃。jump_speeds 使用数组，索引超出时用最后一项；启用时数组须非空。max_air_shots 可取 0/N；0 禁用射击资源。默认二段跳、两次空中射击仅是默认配置，不是框架限制。
JumpState 记录 used_jumps。步行离地土狼超时只消耗第一跳资格，remaining=max(0,max_jumps-used_jumps)。射击与跳跃各自恢复策略。补充可以针对资源 ID，不把所有能力绑到弹药。

Modifier：source_id、stat_id、operation、value、priority、duration。同优先级按 source_id 确定排序，先 override 再 add 再 multiply，再范围钳制；同类 override 取最高优先级、同优先级按 ID 确定胜者。删除来源后从基础配置重新计算，不逆减可能已变化的值。首个局内强化出现前只定义契约，不实现整个 modifier 框架。

## 热变更边界

增加上限不立即赠送次数：本次腾空保留已用次数，下次落地恢复新上限；明确的奖励策略可例外。减少上限立即钳制剩余量。移除能力清其待处理请求与冷却，取消相关持续效果，不能残留旧动作。死亡移除局内临时状态还是保留由 RunPolicy 决定；检查点重生与整局重开分别定义。

## 地图兼容

能力变更生成 capability_snapshot/version。固定关卡注明最低能力组合；生成器依据 snapshot 筛模块并重新验证。撤销关键能力时阻止产生死局或提供安全回退，不宣称一套地图适配所有能力组合。

测试配置矩阵：单跳/双跳/三跳/无跳；0/1/2/3 射击；空中增减上限；禁用能力；补充点；重生；modifier 添加移除；同帧冲突。验证真实资源事务，不能只测配置读取。

## 可变跳高

JumpAbility独占跳跃升程状态；Controller按原始顺序交付jump/jump_release，然后处理射击，再更新跳跃持有计时，Motor仍唯一移动者。配置variable_jump_enabled、jump_min_hold_duration、jump_hold_duration、jump_release_speed来自player_tuning.json；次数与速度数组仍支持0/N。射击成功撤销跳跃升程控制，不清尚未消费的跳跃缓冲。有效新跳跃可结束已有爆发，同tick先跳后射的规则不变。

## AirFocusAbility与精力

AirFocusAbility组合于玩家场景，与JumpAbility/ShootAbility解耦，拥有精力、耗尽锁、单次腾空累计慢时时长及全局倍率恢复状态。configure/reset/advance/stop分别配置、重生、按真实时间推进及无退款结束慢时；禁用不会禁用射击或跳跃。PlayerTuning添加容量、消耗、接地恢复、time_scale、max_air_duration、rearm_stamina，供后续能力道具修改。修改容量只钳制当前值，不凭空回满。零恢复允许、倍率必须在(0,1]，容量/消耗/上限必须正数，恢复阈值不超过容量。未创建无消费者的通用道具框架。
